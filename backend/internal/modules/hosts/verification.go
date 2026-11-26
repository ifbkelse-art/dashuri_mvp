package hosts

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"log/slog"
	"slices"
	"time"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
)

// Verified Host workflow (founder spec 2026-11-23).
//
//	not_applied ─submit─▶ submitted ─start_review─▶ under_review ─approve─▶ verified
//	                         │  ▲                       │   │                 │  ▲
//	                         │  └──resubmit── info_required ◀─request_info    │  │
//	                         └──────reject──────────────┴───┴─▶ rejected   suspend reinstate
//	                                                                          ▼  │
//	                                     revoked ◀────────revoke──────── suspended
//
// Hosts submit; only moderators and admins act on an application; nobody
// acts on their own. Rejected and revoked hosts may submit a new
// application; a suspended host waits for staff. Every change writes an
// audit.events row (actor, time, action, reason, application id).

// RequiredEvidence must be part of every new application.
var RequiredEvidence = []string{"face_video", "id_document_front"}

// EvidenceReadTTL is how long a staff evidence URL stays valid.
const EvidenceReadTTL = 5 * time.Minute

// EvidenceBucket is the private Storage bucket for verification evidence.
const EvidenceBucket = "host-verification-evidence"

// adminTransition is an allowed staff action.
type adminTransition struct {
	from           []string // allowed current host verification statuses
	to             string   // new host verification status
	app            string   // new application status
	reasonRequired bool
	audit          string
}

var adminTransitions = map[string]adminTransition{
	"start_review": {from: []string{VerificationSubmitted}, to: VerificationUnderReview, app: "under_review", audit: "review_started"},
	"request_info": {from: []string{VerificationSubmitted, VerificationUnderReview}, to: VerificationInfoRequired, app: "info_required", audit: "info_requested"},
	"approve":      {from: []string{VerificationUnderReview}, to: VerificationVerified, app: "approved", audit: "approved"},
	"reject": {from: []string{VerificationSubmitted, VerificationUnderReview, VerificationInfoRequired},
		to: VerificationRejected, app: "rejected", reasonRequired: true, audit: "rejected"},
	"suspend":   {from: []string{VerificationVerified}, to: VerificationSuspended, app: "suspended", reasonRequired: true, audit: "suspended"},
	"reinstate": {from: []string{VerificationSuspended}, to: VerificationVerified, app: "approved", reasonRequired: true, audit: "reinstated"},
	"revoke": {from: []string{VerificationVerified, VerificationSuspended}, to: VerificationRevoked, app: "revoked",
		reasonRequired: true, audit: "revoked"},
}

// canSubmit: statuses from which the host may (re)submit.
func canSubmit(status string) bool {
	switch status {
	case "", VerificationNotApplied, VerificationRejected, VerificationRevoked, VerificationInfoRequired:
		return true
	}
	return false
}

func (s *Service) view(st VerificationState) VerificationView {
	v := VerificationView{
		Status: st.Status, IsVerified: st.Status == VerificationVerified, VerifiedAt: st.VerifiedAt,
		CanSubmit: st.HostState == "approved" && canSubmit(st.Status), RequiredEvidence: RequiredEvidence,
		Evidence: []EvidenceItem{},
	}
	if v.Status == "" {
		v.Status = VerificationNotApplied
	}
	if a := st.Current; a != nil {
		v.ApplicationId, v.DecidedAt = &a.ID, a.DecidedAt
		sub := a.SubmittedAt
		if a.ResubmittedAt != nil {
			sub = *a.ResubmittedAt
		}
		v.SubmittedAt = &sub
		v.Note = noteFor(st.Status, a)
	}
	for _, e := range st.Attached {
		v.Evidence = append(v.Evidence, EvidenceItem{Id: e.ID, Kind: e.Kind, Submitted: true, UploadedAt: e.CreatedAt})
	}
	for _, e := range st.Pending {
		v.Evidence = append(v.Evidence, EvidenceItem{Id: e.ID, Kind: e.Kind, UploadedAt: e.CreatedAt})
	}
	return v
}

// noteFor is the text shown to the host for the current status.
func noteFor(status string, a *Application) *string {
	switch status {
	case VerificationInfoRequired:
		return a.InfoRequest
	case VerificationRejected, VerificationSuspended, VerificationRevoked:
		return a.DecisionReason
	}
	return nil
}

func (s *Service) verifiedHost(ctx context.Context, p auth.Principal) (VerificationState, error) {
	if err := s.ready(); err != nil {
		return VerificationState{}, err
	}
	st, err := s.deps.Repo.Verification(ctx, p.UserID)
	if err != nil {
		return st, mapErr(err)
	}
	if !st.HostExists || st.HostState != "approved" {
		return st, apperr.BusinessRule("host_not_approved", "hosting is not approved yet")
	}
	return st, nil
}

// GetVerification: GET /v1/host/verification.
func (s *Service) GetVerification(ctx context.Context, p auth.Principal) (VerificationView, error) {
	st, err := s.verifiedHost(ctx, p)
	if err != nil {
		return VerificationView{}, err
	}
	return s.view(st), nil
}

func (s *Service) evidenceReady() error {
	if s.deps.Evidence == nil || !s.deps.Evidence.Configured() {
		return apperr.Unavailable("storage_not_configured", "verification uploads are not available")
	}
	return nil
}

// CreateEvidenceUpload: POST /v1/host/verification/evidence. Returns a
// signed upload URL for one object in the PRIVATE evidence bucket. The path
// is random and never returned by any API after this response.
func (s *Service) CreateEvidenceUpload(ctx context.Context, p auth.Principal, in EvidenceUploadRequest) (EvidenceUploadTicket, error) {
	st, err := s.verifiedHost(ctx, p)
	if err != nil {
		return EvidenceUploadTicket{}, err
	}
	if !canSubmit(st.Status) {
		return EvidenceUploadTicket{}, apperr.BusinessRule("verification_not_allowed", "verification evidence cannot be added now")
	}
	if len(st.Pending) >= 10 {
		return EvidenceUploadTicket{}, apperr.BusinessRule("too_many_uploads", "submit or wait for older uploads to expire")
	}
	if err := s.evidenceReady(); err != nil {
		return EvidenceUploadTicket{}, err
	}
	id, err := newUUID()
	if err != nil {
		return EvidenceUploadTicket{}, apperr.Internal(err)
	}
	ext := map[string]string{"video/mp4": "mp4", "video/quicktime": "mov", "image/jpeg": "jpg", "image/png": "png"}[in.ContentType]
	path := fmt.Sprintf("%s/%s.%s", p.UserID, id, ext)
	url, err := s.deps.Evidence.SignUpload(ctx, path)
	if err != nil {
		return EvidenceUploadTicket{}, apperr.Unavailable("storage_unavailable", "upload could not be prepared")
	}
	now := s.deps.Clock.Now()
	if err := s.deps.Repo.CreateEvidence(ctx, Evidence{ID: id, HostID: p.UserID, Kind: in.Kind, ContentType: in.ContentType,
		StoragePath: path, CreatedAt: now}); err != nil {
		return EvidenceUploadTicket{}, mapErr(err)
	}
	return EvidenceUploadTicket{EvidenceId: id, UploadUrl: url, ExpiresAt: now.Add(2 * time.Hour)}, nil
}

// SubmitVerification: POST /v1/host/verification/submissions. A new
// application needs RequiredEvidence; a reply to an info request may add
// evidence or none.
func (s *Service) SubmitVerification(ctx context.Context, p auth.Principal, in SubmitVerificationRequest) (VerificationView, error) {
	if _, err := s.verifiedHost(ctx, p); err != nil {
		return VerificationView{}, err
	}
	now := s.deps.Clock.Now()
	st, err := s.deps.Repo.ChangeVerification(ctx, p.UserID, func(st VerificationState) (VerificationChange, error) {
		if !st.HostExists || st.HostState != "approved" {
			return VerificationChange{}, apperr.BusinessRule("host_not_approved", "hosting is not approved yet")
		}
		if !canSubmit(st.Status) {
			return VerificationChange{}, apperr.BusinessRule("verification_not_allowed", "an application is already open or the status is "+st.Status)
		}
		kinds := map[string]bool{}
		for _, id := range in.EvidenceIds {
			i := slices.IndexFunc(st.Pending, func(e Evidence) bool { return e.ID == id })
			if i < 0 {
				return VerificationChange{}, apperr.Validation(map[string]string{"evidence_ids": "unknown_evidence"})
			}
			kinds[st.Pending[i].Kind] = true
		}
		ch := VerificationChange{ActorID: p.UserID, AttachEvidence: in.EvidenceIds, HostStatus: VerificationSubmitted,
			ApplicationStatus: "submitted", At: now}
		if st.Status == VerificationInfoRequired {
			ch.Action = "resubmitted"
			return ch, nil
		}
		for _, k := range RequiredEvidence {
			if !kinds[k] {
				return VerificationChange{}, apperr.Validation(map[string]string{"evidence_ids": "missing_" + k})
			}
		}
		ch.Action, ch.CreateApplication = "submitted", true
		return ch, nil
	})
	if err != nil {
		return VerificationView{}, mapErr(err)
	}
	return s.view(st), nil
}

// ActOnVerification: POST /v1/admin/hosts/{userId}/verification/actions
// (moderator or admin). Suspension and revocation cap the stored price at
// min(3,000, level max) in the same transaction; live calls keep their rate.
// Approval and reinstatement never change the price.
func (s *Service) ActOnVerification(ctx context.Context, p auth.Principal, hostID string, in VerificationActionRequest) (AdminVerificationDetail, error) {
	if err := s.ready(); err != nil {
		return AdminVerificationDetail{}, err
	}
	if !isUUID(hostID) {
		return AdminVerificationDetail{}, apperr.NotFound("host")
	}
	if !p.Has(auth.RoleModerator) && !p.Has(auth.RoleAdmin) {
		return AdminVerificationDetail{}, apperr.Forbidden("forbidden", "staff only")
	}
	if hostID == p.UserID {
		return AdminVerificationDetail{}, apperr.Forbidden("self_review", "you cannot act on your own verification")
	}
	t, ok := adminTransitions[in.Action]
	if !ok {
		return AdminVerificationDetail{}, apperr.Validation(map[string]string{"action": "invalid_value"})
	}
	if t.reasonRequired && in.Reason == "" {
		return AdminVerificationDetail{}, apperr.Validation(map[string]string{"reason": "required"})
	}
	if in.Action == "request_info" && in.InfoRequest == "" {
		return AdminVerificationDetail{}, apperr.Validation(map[string]string{"info_request": "required"})
	}
	r := s.deps.Rules
	now := s.deps.Clock.Now()
	_, err := s.deps.Repo.ChangeVerification(ctx, hostID, func(st VerificationState) (VerificationChange, error) {
		if !st.HostExists {
			return VerificationChange{}, apperr.NotFound("host")
		}
		if st.Current == nil {
			return VerificationChange{}, ErrNoApplication
		}
		if !slices.Contains(t.from, st.Status) {
			return VerificationChange{}, apperr.Conflict("invalid_transition",
				fmt.Sprintf("cannot %s a verification in status %s", in.Action, st.Status))
		}
		ch := VerificationChange{ActorID: p.UserID, Action: t.audit, HostStatus: t.to, ApplicationStatus: t.app,
			Reason: in.Reason, InfoRequest: in.InfoRequest, At: now}
		if in.Action == "approve" {
			have := map[string]bool{}
			for _, e := range st.Attached {
				have[e.Kind] = true
			}
			for _, k := range RequiredEvidence {
				if !have[k] {
					return VerificationChange{}, apperr.BusinessRule("evidence_missing", "required evidence is missing: "+k)
				}
			}
		}
		if t.to != VerificationVerified {
			if capped := r.CapRate(st.Pricing.RatePerMinute, r.LevelForXP(st.Pricing.LifetimeXP), false); capped != st.Pricing.RatePerMinute {
				ch.CapRateTo = &capped
			}
		}
		return ch, nil
	})
	if err != nil {
		return AdminVerificationDetail{}, mapErr(err)
	}
	return s.adminDetail(ctx, hostID)
}

func (s *Service) adminDetail(ctx context.Context, hostID string) (AdminVerificationDetail, error) {
	st, err := s.deps.Repo.Verification(ctx, hostID)
	if err != nil {
		return AdminVerificationDetail{}, mapErr(err)
	}
	if !st.HostExists {
		return AdminVerificationDetail{}, apperr.NotFound("host")
	}
	r := s.deps.Rules
	level := r.LevelForXP(st.Pricing.LifetimeXP)
	status := st.Status
	if status == "" {
		status = VerificationNotApplied
	}
	out := AdminVerificationDetail{HostId: hostID, Status: status, Level: level,
		RatePerMinute: r.CapRate(st.Pricing.RatePerMinute, level, st.Status == VerificationVerified),
		Evidence:      s.view(st).Evidence, History: []HistoryItem{}}
	if a := st.Current; a != nil {
		out.Application = &AdminApplication{Id: a.ID, Status: a.Status, SubmittedAt: a.SubmittedAt, ResubmittedAt: a.ResubmittedAt,
			ReviewerId: a.ReviewerID, ReviewStartedAt: a.ReviewStartedAt, InfoRequest: a.InfoRequest, DecidedBy: a.DecidedBy,
			DecidedAt: a.DecidedAt, DecisionReason: a.DecisionReason}
	}
	hist, err := s.deps.Repo.VerificationHistory(ctx, hostID, 100)
	if err != nil {
		return AdminVerificationDetail{}, mapErr(err)
	}
	for _, h := range hist {
		out.History = append(out.History, HistoryItem{At: h.At, Actor: h.Actor, Action: h.Action, Details: h.Details})
	}
	return out, nil
}

// GetAdminVerification: GET /v1/admin/hosts/{userId}/verification (audited view).
func (s *Service) GetAdminVerification(ctx context.Context, p auth.Principal, hostID string) (AdminVerificationDetail, error) {
	if err := s.ready(); err != nil {
		return AdminVerificationDetail{}, err
	}
	if !isUUID(hostID) {
		return AdminVerificationDetail{}, apperr.NotFound("host")
	}
	if hostID == p.UserID {
		return AdminVerificationDetail{}, apperr.Forbidden("self_review", "you cannot review your own verification")
	}
	out, err := s.adminDetail(ctx, hostID)
	if err != nil {
		return out, err
	}
	if err := s.deps.Repo.Audit(ctx, p.UserID, "host.verification.viewed", hostID, nil); err != nil {
		return AdminVerificationDetail{}, apperr.Internal(err)
	}
	return out, nil
}

// VerificationQueue: GET /v1/admin/host-verifications?status=…
func (s *Service) VerificationQueue(ctx context.Context, status string, limit int) (Page[VerificationQueueItem], error) {
	if err := s.ready(); err != nil {
		return Page[VerificationQueueItem]{}, err
	}
	statuses := []string{"submitted", "under_review", "info_required"}
	if status != "" {
		if !slices.Contains([]string{"submitted", "under_review", "info_required", "approved", "rejected", "suspended", "revoked"}, status) {
			return Page[VerificationQueueItem]{}, apperr.Validation(map[string]string{"status": "invalid_value"})
		}
		statuses = []string{status}
	}
	rows, err := s.deps.Repo.VerificationQueue(ctx, statuses, limit)
	if err != nil {
		return Page[VerificationQueueItem]{}, mapErr(err)
	}
	out := Page[VerificationQueueItem]{Items: []VerificationQueueItem{}}
	for _, q := range rows {
		out.Items = append(out.Items, VerificationQueueItem{ApplicationId: q.ApplicationID, HostId: q.HostID, DisplayName: q.DisplayName,
			Status: q.Status, SubmittedAt: q.SubmittedAt, Level: s.deps.Rules.LevelForXP(q.LifetimeXP)})
	}
	return out, nil
}

// EvidenceAccessURL: POST /v1/admin/hosts/{userId}/verification/evidence/{evidenceId}/access.
// Staff only, never for the host themself, audited, valid for 5 minutes.
func (s *Service) EvidenceAccessURL(ctx context.Context, p auth.Principal, hostID, evidenceID string) (EvidenceAccess, error) {
	if err := s.ready(); err != nil {
		return EvidenceAccess{}, err
	}
	if !isUUID(hostID) || !isUUID(evidenceID) {
		return EvidenceAccess{}, apperr.NotFound("evidence")
	}
	if hostID == p.UserID {
		return EvidenceAccess{}, apperr.Forbidden("self_review", "you cannot review your own verification")
	}
	if err := s.evidenceReady(); err != nil {
		return EvidenceAccess{}, err
	}
	e, err := s.deps.Repo.Evidence(ctx, hostID, evidenceID)
	if err != nil {
		if err == ErrNotFound {
			return EvidenceAccess{}, apperr.NotFound("evidence")
		}
		return EvidenceAccess{}, mapErr(err)
	}
	if e.PurgedAt != nil {
		return EvidenceAccess{}, apperr.BusinessRule("evidence_purged", "this evidence was deleted under the retention policy")
	}
	// Audit before releasing the URL: no unaudited access.
	if err := s.deps.Repo.Audit(ctx, p.UserID, "host.verification.evidence_accessed", hostID,
		map[string]any{"evidence_id": e.ID, "kind": e.Kind, "application_id": e.ApplicationID}); err != nil {
		return EvidenceAccess{}, apperr.Internal(err)
	}
	urls := s.deps.Evidence.SignRead(ctx, []string{e.StoragePath}, EvidenceReadTTL)
	u, ok := urls[e.StoragePath]
	if !ok {
		return EvidenceAccess{}, apperr.BusinessRule("evidence_not_uploaded", "the file was not uploaded")
	}
	return EvidenceAccess{Url: u, ExpiresAt: s.deps.Clock.Now().Add(EvidenceReadTTL)}, nil
}

// PurgeEvidence deletes private evidence whose retention ended (job
// purge-verification-evidence). Objects are deleted first, then the row is
// marked purged; metadata and the audit trail stay.
func (s *Service) PurgeEvidence(ctx context.Context, limit int) (int, error) {
	if err := s.ready(); err != nil {
		return 0, err
	}
	if s.evidenceReady() != nil {
		// No bucket configured: nothing can have been uploaded.
		return 0, nil
	}
	now := s.deps.Clock.Now()
	ret, orphan := s.deps.EvidenceRetention, s.deps.OrphanEvidenceRetention
	if ret <= 0 {
		ret = 90 * 24 * time.Hour
	}
	if orphan <= 0 {
		orphan = 48 * time.Hour
	}
	due, err := s.deps.Repo.EvidenceDueForPurge(ctx, now.Add(-ret), now.Add(-orphan), limit)
	if err != nil {
		return 0, err
	}
	n := 0
	for _, e := range due {
		if err := s.deps.Evidence.Delete(ctx, e.StoragePath); err != nil {
			slog.WarnContext(ctx, "evidence delete failed", "evidence_id", e.ID, "err", err)
			continue
		}
		if err := s.deps.Repo.MarkEvidencePurged(ctx, e.ID, now); err != nil {
			return n, err
		}
		n++
	}
	return n, nil
}

func newUUID() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	h := hex.EncodeToString(b)
	return h[0:8] + "-" + h[8:12] + "-" + h[12:16] + "-" + h[16:20] + "-" + h[20:32], nil
}
