package reels

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"log/slog"
	"math"
	"strings"
	"time"

	"dashuri/backend/internal/modules/keyset"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
)

// ---------------------------------------------------------------- automated pipeline

// Evaluate turns frame maxima into an outcome. Pure (unit-tested).
//
//   - any clear violation → reject (appealable), media kept as evidence;
//   - anything uncertain → human review;
//   - a creator's first reel → human review, even when clean (new-creator rule);
//   - otherwise → automated approve.
func Evaluate(max FrameScores, th Thresholds, firstReel bool, now time.Time) ModerationOutcome {
	scores := map[string]float64{"sexual": round3(max.Sexual), "suggestive": round3(max.Suggestive), "other": round3(max.Other)}
	hold := now.Add(EvidenceHold)
	switch {
	case max.Sexual >= th.RejectSexual:
		return ModerationOutcome{Decision: "reject", ReasonCode: "sexual_content", Priority: 1, Scores: scores, CaseSource: "automated", EvidenceHold: &hold}
	case max.Other >= th.RejectOther:
		return ModerationOutcome{Decision: "reject", ReasonCode: "graphic_or_offensive", Priority: 2, Scores: scores, CaseSource: "automated", EvidenceHold: &hold}
	case max.Sexual >= th.ReviewSexual || max.Suggestive >= th.ReviewSuggest:
		return ModerationOutcome{Decision: "review", ReasonCode: "uncertain_sexual", Priority: 2, Scores: scores, CaseSource: "automated"}
	case max.Other >= th.ReviewOther:
		return ModerationOutcome{Decision: "review", ReasonCode: "uncertain_other", Priority: 3, Scores: scores, CaseSource: "automated"}
	case firstReel:
		return ModerationOutcome{Decision: "review", ReasonCode: "first_reel", Priority: 4, Scores: scores, CaseSource: "automated"}
	default:
		return ModerationOutcome{Decision: "approve", ReasonCode: "automated_clear", Scores: scores, CaseSource: "automated"}
	}
}

func round3(x float64) float64 { return math.Round(x*1000) / 1000 }

// ModeratePending runs the automated check for ready videos (job
// reels-moderate). Fail closed: without a classifier, or after
// ModerationGiveUp of provider errors, the video goes to human review —
// it is never published without a decision.
func (s *Service) ModeratePending(ctx context.Context, limit int) (int, error) {
	repo, err := s.repo()
	if err != nil {
		return 0, err
	}
	now := s.deps.Clock.Now()
	rows, err := repo.StaleVideos(ctx, "pending_moderation", now, limit)
	if err != nil {
		return 0, err
	}
	done := 0
	for _, v := range rows {
		o, ok := s.classify(ctx, repo, v, now)
		if !ok {
			continue // retry next run
		}
		if _, err := repo.ApplyAutomated(ctx, v.ID, o); err != nil {
			slog.ErrorContext(ctx, "reels moderation apply failed", "reel", v.ID, "err", err)
			continue
		}
		done++
	}
	return done, nil
}

func (s *Service) classify(ctx context.Context, repo Repository, v VideoRow, now time.Time) (ModerationOutcome, bool) {
	unavailable := ModerationOutcome{Decision: "review", ReasonCode: "classifier_unavailable", Priority: 2, CaseSource: "provider_unavailable"}
	prov := s.providerFor(v.Provider)
	if s.deps.Classifier == nil || prov == nil || v.PlaybackID == nil || v.DurationMs == nil {
		return unavailable, true
	}
	giveUp := now.Sub(v.UpdatedAt) > ModerationGiveUp
	urls, err := prov.FrameURLs(*v.PlaybackID, *v.DurationMs, s.deps.FrameInterval, 10*time.Minute)
	if err != nil || len(urls) == 0 {
		return unavailable, true
	}
	var max FrameScores
	for _, u := range urls {
		sc, err := s.deps.Classifier.ClassifyURL(ctx, u)
		if err != nil {
			slog.WarnContext(ctx, "reels frame classification failed", "reel", v.ID, "err", err)
			if giveUp {
				return unavailable, true
			}
			return ModerationOutcome{}, false
		}
		max.Sexual = math.Max(max.Sexual, sc.Sexual)
		max.Suggestive = math.Max(max.Suggestive, sc.Suggestive)
		max.Other = math.Max(max.Other, sc.Other)
	}
	approved, err := repo.HasApprovedReel(ctx, v.CreatorID)
	if err != nil {
		return ModerationOutcome{}, false
	}
	return Evaluate(max, s.deps.Thresholds, !approved, now), true
}

// ReconcileUploads polls the provider for videos whose webhook never came
// (job reels-reconcile-uploads).
func (s *Service) ReconcileUploads(ctx context.Context, limit int) (int, error) {
	repo, err := s.repo()
	if err != nil {
		return 0, err
	}
	now := s.deps.Clock.Now()
	n := 0
	waiting, err := repo.StaleVideos(ctx, "awaiting_upload", now.Add(-10*time.Minute), limit)
	if err != nil {
		return 0, err
	}
	for _, v := range waiting {
		prov := s.providerFor(v.Provider)
		if v.ProviderUploadID == nil || prov == nil {
			continue
		}
		st, err := prov.UploadStatus(ctx, *v.ProviderUploadID)
		if err != nil {
			continue
		}
		switch st.State {
		case "asset_created":
			if repo.MarkProcessing(ctx, v.ID, st.AssetID) == nil {
				n++
			}
		case "errored", "cancelled", "timed_out":
			if repo.MarkFailed(ctx, v.ID, "upload_"+st.State) == nil {
				n++
			}
		default:
			if now.Sub(v.CreatedAt) > 3*time.Hour && repo.MarkFailed(ctx, v.ID, "upload_expired") == nil {
				n++
			}
		}
	}
	processing, err := repo.StaleVideos(ctx, "processing", now.Add(-5*time.Minute), limit)
	if err != nil {
		return n, err
	}
	for _, v := range processing {
		prov := s.providerFor(v.Provider)
		if v.ProviderAssetID == nil || prov == nil {
			continue
		}
		if _, self := prov.(SelfProcessing); self {
			continue // reels-process-media owns these
		}
		a, err := prov.Asset(ctx, *v.ProviderAssetID)
		if err != nil {
			continue
		}
		if s.applyAsset(ctx, repo, v.ID, a) == nil {
			n++
		}
	}
	return n, nil
}

// ProcessMedia validates and transcodes uploads stored with a
// self-processing provider (R2) and extracts thumbnail and moderation frames
// (job reels-process-media; needs ffmpeg, so it runs in the media worker
// image). Invalid files fail with a reason code; transient errors retry until
// ProcessingGiveUp, then the reel fails as processing_failed. A processed
// reel goes to pending_moderation exactly like a Mux reel, so moderation is
// unchanged and never skipped.
func (s *Service) ProcessMedia(ctx context.Context, limit int) (int, error) {
	repo, err := s.repo()
	if err != nil {
		return 0, err
	}
	now := s.deps.Clock.Now()
	rows, err := repo.StaleVideos(ctx, "processing", now, limit)
	if err != nil {
		return 0, err
	}
	limits := MediaLimits{MaxBytes: MaxUploadBytes, MinDurationMs: MinDurationMs - DurationToleranceMs,
		MaxDurationMs: MaxDurationMs + DurationToleranceMs, FrameInterval: s.deps.FrameInterval}
	n := 0
	for _, v := range rows {
		prov := s.providerFor(v.Provider)
		proc, ok := prov.(SelfProcessing)
		if !ok || v.ProviderAssetID == nil {
			continue
		}
		a, err := proc.Process(ctx, *v.ProviderAssetID, limits)
		var me *MediaError
		switch {
		case errors.Is(err, ErrProcessorUnavailable):
			slog.WarnContext(ctx, "reels media processing needs the media worker (ffmpeg); nothing failed")
			return n, nil
		case errors.As(err, &me):
			if repo.MarkFailed(ctx, v.ID, me.Code) == nil {
				n++
			}
		case err != nil:
			slog.WarnContext(ctx, "reels media processing failed", "reel", v.ID, "err", err)
			if now.Sub(v.UpdatedAt) > ProcessingGiveUp && repo.MarkFailed(ctx, v.ID, "processing_failed") == nil {
				n++
			}
		default:
			a.State = "ready"
			if s.applyAsset(ctx, repo, v.ID, a) == nil {
				n++
			}
		}
	}
	return n, nil
}

func (s *Service) applyAsset(ctx context.Context, repo Repository, videoID string, a AssetInfo) error {
	switch a.State {
	case "ready":
		_, err := repo.MarkReady(ctx, videoID, a, MinDurationMs-DurationToleranceMs, MaxDurationMs+DurationToleranceMs)
		return err
	case "errored":
		return repo.MarkFailed(ctx, videoID, "processing_failed")
	}
	return errors.New("asset not final")
}

// HandleWebhook: POST /v1/webhooks/reels/{provider}. Signature first; then
// idempotent state changes keyed by the provider ids.
func (s *Service) HandleWebhook(ctx context.Context, provider string, headers map[string]string, body []byte) error {
	repo, err := s.repo()
	if err != nil {
		return err
	}
	prov := s.providerNamed(provider)
	if prov == nil {
		return apperr.NotFound("webhook")
	}
	if !prov.Configured() {
		return apperr.Unavailable("video_provider_not_configured", "video hosting is not configured")
	}
	ev, err := prov.ParseWebhook(headers, body, s.deps.Clock.Now())
	if errors.Is(err, ErrWebhookSignature) {
		return apperr.Unauthenticated("invalid webhook signature")
	}
	if err != nil {
		return validationError(map[string]string{"body": "invalid"})
	}
	sum := sha256.Sum256(append([]byte(provider+"|"+ev.DeliveryID+"|"), body...))
	fresh, err := repo.RecordWebhook(ctx, provider, hex.EncodeToString(sum[:]), ev.RawType)
	if err != nil {
		return internal(err)
	}
	if !fresh {
		return nil // duplicate delivery
	}
	switch ev.Type {
	case "upload_asset_created":
		v, err := repo.VideoByUpload(ctx, ev.UploadID)
		if errors.Is(err, ErrNotFound) {
			return nil // not ours (or deleted); acknowledge
		}
		if err != nil {
			return internal(err)
		}
		if err := repo.MarkProcessing(ctx, v.ID, ev.Asset.ID); err != nil {
			return internal(err)
		}
	case "upload_failed":
		v, err := repo.VideoByUpload(ctx, ev.UploadID)
		if err == nil {
			if err := repo.MarkFailed(ctx, v.ID, "upload_failed"); err != nil {
				return internal(err)
			}
		}
	case "asset_ready", "asset_errored":
		v, err := s.videoForAsset(ctx, repo, ev.Asset)
		if errors.Is(err, ErrNotFound) {
			return nil
		}
		if err != nil {
			return internal(err)
		}
		if ev.Type == "asset_ready" {
			ev.Asset.State = "ready"
		} else {
			ev.Asset.State = "errored"
		}
		if err := s.applyAsset(ctx, repo, v.ID, ev.Asset); err != nil {
			return internal(err)
		}
	}
	return nil
}

func (s *Service) videoForAsset(ctx context.Context, repo Repository, a AssetInfo) (VideoRow, error) {
	v, err := repo.VideoByAsset(ctx, a.ID)
	if errors.Is(err, ErrNotFound) && isUUID(a.Passthrough) {
		// asset.ready can arrive before upload.asset_created: link by passthrough.
		if err := repo.MarkProcessing(ctx, a.Passthrough, a.ID); err != nil && !errors.Is(err, ErrNotFound) {
			return VideoRow{}, err
		}
		return repo.VideoByAsset(ctx, a.ID)
	}
	return v, err
}

// PurgeMedia deletes provider assets of deleted/rejected/removed/failed
// videos once any evidence hold has passed (job reels-purge-media).
func (s *Service) PurgeMedia(ctx context.Context, limit int) (int, error) {
	repo, err := s.repo()
	if err != nil {
		return 0, err
	}
	rows, err := repo.PurgeCandidates(ctx, s.deps.Clock.Now(), limit)
	if err != nil {
		return 0, err
	}
	n := 0
	for _, v := range rows {
		if v.ProviderAssetID != nil {
			prov := s.providerFor(v.Provider)
			if prov == nil {
				continue // keep for later; never mark purged without deleting
			}
			if err := prov.DeleteAsset(ctx, *v.ProviderAssetID); err != nil && !errors.Is(err, ErrAssetNotFound) {
				slog.WarnContext(ctx, "reels asset delete failed", "reel", v.ID, "err", err)
				continue
			}
		}
		if err := repo.MarkPurged(ctx, v.ID); err != nil {
			return n, err
		}
		n++
	}
	return n, nil
}

// CleanupDeletedAccounts removes Reels data of accounts deleted by
// execute-account-deletions (job reels-account-cleanup).
func (s *Service) CleanupDeletedAccounts(ctx context.Context, limit int) (int, error) {
	repo, err := s.repo()
	if err != nil {
		return 0, err
	}
	return repo.CleanupDeletedAccounts(ctx, limit)
}

// ---------------------------------------------------------------- reports and appeals

// Report: POST /v1/reels/{id}/reports (Idempotency-Key). minor_safety and
// nudity hide the video at once; ReportHideThreshold distinct reporters
// hide it pending review; any report opens a case.
func (s *Service) Report(ctx context.Context, p auth.Principal, id string, in ReportRequest) error {
	if err := gate(p); err != nil {
		return err
	}
	if errs := in.validate(); len(errs) > 0 {
		return validationError(errs)
	}
	repo, err := s.repo()
	if err != nil {
		return err
	}
	row, err := s.publishedVisible(ctx, repo, p, id)
	if err != nil {
		return err
	}
	if row.CreatorID == p.UserID {
		return apperr.BusinessRule("self_report", "you cannot report your own reel")
	}
	if in.Details != nil {
		d := strings.TrimSpace(*in.Details)
		in.Details = &d
	}
	switch _, err := repo.Report(ctx, p.UserID, id, *in.Category, in.Details, ReportHideThreshold); {
	case errors.Is(err, ErrAlreadyReported):
		return nil // idempotent from the user's view
	case err != nil:
		return internal(err)
	}
	s.recordServerEvent(ctx, repo, p.UserID, "reel_reported", &id, nil)
	return nil
}

// Appeal: POST /v1/reels/{id}/appeals — creator of a rejected or removed reel, once.
func (s *Service) Appeal(ctx context.Context, p auth.Principal, id string, in AppealRequest) error {
	if err := gate(p); err != nil {
		return err
	}
	if !isUUID(id) {
		return notFound()
	}
	if in.Statement == nil || strings.TrimSpace(*in.Statement) == "" {
		return validationError(map[string]string{"statement": "required"})
	}
	st := strings.TrimSpace(*in.Statement)
	if len([]rune(st)) > 2000 {
		return validationError(map[string]string{"statement": "too_long"})
	}
	repo, err := s.repo()
	if err != nil {
		return err
	}
	switch err := repo.Appeal(ctx, p.UserID, id, st); {
	case errors.Is(err, ErrNotFound), errors.Is(err, ErrNotOwner):
		return notFound()
	case errors.Is(err, ErrAppealNotAllowed):
		return apperr.BusinessRule("appeal_not_allowed", "only rejected or removed reels can be appealed")
	case errors.Is(err, ErrAlreadyAppealed):
		return apperr.BusinessRule("already_appealed", "this reel was already appealed")
	case err != nil:
		return internal(err)
	}
	return nil
}

// ---------------------------------------------------------------- moderator tools

func requireModerator(p auth.Principal) error {
	if p.Has(auth.RoleModerator) || p.Has(auth.RoleAdmin) {
		return nil
	}
	return apperr.Forbidden("role_required", "moderator or admin role required")
}

// Queue: GET /v1/admin/reels/queue — open cases, highest priority first,
// with short-lived review playback.
func (s *Service) Queue(ctx context.Context, p auth.Principal, cursor string, limit int) (Page[QueueEntry], error) {
	if err := requireModerator(p); err != nil {
		return Page[QueueEntry]{}, err
	}
	after, err := decodeKeyset(cursor)
	if err != nil {
		return Page[QueueEntry]{}, err
	}
	repo, err := s.repo()
	if err != nil {
		return Page[QueueEntry]{}, err
	}
	limit = clampLimit(limit)
	items, err := repo.Queue(ctx, after, limit+1)
	if err != nil {
		return Page[QueueEntry]{}, internal(err)
	}
	out := Page[QueueEntry]{Items: []QueueEntry{}}
	if len(items) > limit {
		items = items[:limit]
		last := items[len(items)-1]
		next := keysetEncode(last.CreatedAt, last.CaseID)
		out.NextCursor = &next
	}
	for _, it := range items {
		reel := s.toReels(ctx, p.UserID, []VideoRow{it.Video}, true)[0]
		out.Items = append(out.Items, QueueEntry{CaseId: it.CaseID, Source: it.Source, Priority: it.Priority,
			Scores: it.Scores, Reports: it.Reports, Appeal: it.Appeal, CreatedAt: it.CreatedAt, Reel: reel})
	}
	return out, nil
}

// Decide: POST /v1/admin/reels/{id}/decision (Idempotency-Key). Audited in
// the append-only reels.moderation_decisions. A moderator cannot decide
// their own reel.
func (s *Service) Decide(ctx context.Context, p auth.Principal, id string, in DecisionRequest) (DecisionResult, error) {
	if err := requireModerator(p); err != nil {
		return DecisionResult{}, err
	}
	if errs := in.validate(); len(errs) > 0 {
		return DecisionResult{}, validationError(errs)
	}
	if !isUUID(id) {
		return DecisionResult{}, notFound()
	}
	repo, err := s.repo()
	if err != nil {
		return DecisionResult{}, err
	}
	row, err := repo.Video(ctx, p.UserID, id)
	if errors.Is(err, ErrNotFound) {
		return DecisionResult{}, notFound()
	}
	if err != nil {
		return DecisionResult{}, internal(err)
	}
	if row.CreatorID == p.UserID {
		return DecisionResult{}, apperr.Forbidden("self_review", "you cannot moderate your own reel")
	}
	status, err := repo.Decide(ctx, p.UserID, id, *in.Decision, strings.TrimSpace(*in.ReasonCode), in.Note, s.deps.Clock.Now())
	if errors.Is(err, ErrIllegalDecision) {
		return DecisionResult{}, apperr.BusinessRule("illegal_moderation_transition", "this decision does not apply to the reel's current state")
	}
	if err != nil {
		return DecisionResult{}, internal(err)
	}
	return DecisionResult{ReelId: id, Status: status}, nil
}

// GetAnalytics: GET /v1/admin/reels/analytics?days= — aggregate counts and
// reel-attributed calls (attribution rule in docs/reels/DASHURI_REELS_ARCHITECTURE.md).
func (s *Service) GetAnalytics(ctx context.Context, p auth.Principal, days int) (Analytics, error) {
	if !(p.Has(auth.RoleAdmin) || p.Has(auth.RoleFinance) || p.Has(auth.RoleModerator)) {
		return Analytics{}, apperr.Forbidden("role_required", "admin, finance or moderator role required")
	}
	if days <= 0 || days > 90 {
		days = 7
	}
	repo, err := s.repo()
	if err != nil {
		return Analytics{}, err
	}
	to := s.deps.Clock.Now().UTC()
	a, err := repo.Analytics(ctx, to.AddDate(0, 0, -days), to, AttributionWindow)
	if err != nil {
		return Analytics{}, internal(err)
	}
	return Analytics{From: a.From, To: a.To, Published: a.Published, ActiveCreators: a.ActiveCreators,
		Impressions: a.Impressions, PlaysStarted: a.PlaysStarted, PlaysCompleted: a.PlaysCompleted,
		WatchSeconds: a.WatchMs / 1000, Likes: a.Likes, Follows: a.Follows, Shares: a.Shares, Reports: a.Reports,
		ProfileOpens: a.ProfileOpens, CTAClicks: a.CTAClicks, AttributedCalls: a.AttributedCalls,
		AttributedCompleted: a.AttributedCompleted, AttributedPaidSecs: a.AttributedPaidSecs,
		AttributedDiamonds: a.AttributedDiamonds, AttributionWindowMin: a.AttributionWindowMin}, nil
}

func keysetEncode(at time.Time, id string) string { return keyset.Cursor{At: at, ID: id}.Encode() }
