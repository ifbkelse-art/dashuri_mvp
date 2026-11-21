package moderation

import (
	"bytes"
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"log/slog"
	"sort"
	"strconv"
	"strings"
	"time"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/clock"
)

// Service implements the moderation module's use cases.
type Service struct {
	deps Deps
}

func NewService(d Deps) *Service {
	if d.Clock == nil {
		d.Clock = clock.System{}
	}
	if d.Threshold <= 0 {
		d.Threshold = DefaultFlagThreshold
	}
	return &Service{deps: d}
}

// EvidenceRetention is how long evidence metadata is kept (PRO-REVIEW: set
// by legal advice; the retention job enforces it).
const EvidenceRetention = 180 * 24 * time.Hour

// MissingFrameGap: a participant who sends no frame for this long inside the
// moderation window gets a review queued (the call is not ended).
const MissingFrameGap = 60 * time.Second

func (s *Service) ready() error {
	if s.deps.Repo == nil {
		return apperr.Unavailable("database_unavailable", "database not configured")
	}
	return nil
}

func mapErr(err error) error {
	switch {
	case err == nil:
		return nil
	case errors.Is(err, ErrNotFound):
		return apperr.NotFound("case")
	case errors.Is(err, ErrAlreadyDecided):
		return apperr.BusinessRule("already_decided", "this case has already been decided")
	case errors.Is(err, ErrSameReviewer):
		return apperr.BusinessRule("different_reviewer_required", "an appeal must be decided by a different reviewer")
	case errors.Is(err, ErrSelfDecision):
		return apperr.Forbidden("self_review", "you cannot decide a case about yourself")
	case errors.Is(err, ErrInvalidDecision):
		return apperr.BusinessRule("invalid_decision", "this decision is not allowed for this case")
	}
	if apperr.As(err) != nil {
		return err
	}
	return apperr.Internal(err)
}

// DecodeFrame decodes base64 (std or URL alphabet, optional data-URL prefix)
// and checks the 200 KB limit and the JPEG signature.
func DecodeFrame(b64 string) ([]byte, error) {
	if i := strings.Index(b64, ","); strings.HasPrefix(b64, "data:") && i > 0 {
		b64 = b64[i+1:]
	}
	b64 = strings.TrimSpace(b64)
	var img []byte
	var err error
	for _, enc := range []*base64.Encoding{base64.StdEncoding, base64.RawStdEncoding, base64.URLEncoding, base64.RawURLEncoding} {
		if img, err = enc.DecodeString(b64); err == nil {
			break
		}
	}
	if err != nil {
		return nil, apperr.Validation(map[string]string{"image_base64": "invalid_base64"})
	}
	if len(img) > MaxFrameBytes {
		return nil, apperr.Validation(map[string]string{"image_base64": "too_large"})
	}
	if len(img) < 4 || !bytes.HasPrefix(img, []byte{0xFF, 0xD8, 0xFF}) {
		return nil, apperr.Validation(map[string]string{"image_base64": "not_jpeg"})
	}
	return img, nil
}

// SubmitFrame: POST /v1/calls/{callId}/moderation-frames — a participant's own
// outgoing camera frame during the first 180 s after the call became active.
func (s *Service) SubmitFrame(ctx context.Context, p auth.Principal, callID string, in ModerationFrameRequest) (FrameAccepted, error) {
	if err := s.ready(); err != nil {
		return FrameAccepted{}, err
	}
	if !isUUID(callID) {
		return FrameAccepted{}, apperr.NotFound("call")
	}
	c, err := s.deps.Repo.CallInfo(ctx, callID)
	if errors.Is(err, ErrNotFound) || (err == nil && p.UserID != c.CallerID && p.UserID != c.ReceiverID) {
		return FrameAccepted{}, apperr.NotFound("call")
	}
	if err != nil {
		return FrameAccepted{}, mapErr(err)
	}
	now := s.deps.Clock.Now()
	if c.ModerationWindowEndsAt == nil {
		return FrameAccepted{}, apperr.BusinessRule("call_not_active", "the call has not started")
	}
	if !now.Before(*c.ModerationWindowEndsAt) || (c.Phase != "active" && c.Phase != "paused") {
		return FrameAccepted{}, apperr.BusinessRule("moderation_window_closed", "automated checks run only in the first 3 minutes")
	}
	img, err := DecodeFrame(in.ImageBase64)
	if err != nil {
		return FrameAccepted{}, err
	}
	if !s.deps.Enabled {
		return FrameAccepted{Accepted: false}, nil
	}
	if s.deps.Classifier == nil {
		return FrameAccepted{}, apperr.Unavailable("moderation_not_configured", "frame moderation is not configured on this server")
	}
	score, err := s.deps.Classifier.Score(ctx, img)
	if err != nil {
		if apperr.As(err) != nil {
			return FrameAccepted{}, err
		}
		slog.WarnContext(ctx, "nudity classifier", "err", err)
		return FrameAccepted{}, apperr.Unavailable("moderation_unavailable", "the frame could not be checked; send the next frame")
	}
	flagged := score.Flagged(s.deps.Threshold)
	action := "none"
	if flagged {
		action = "end_call"
	}
	checkID, err := s.deps.Repo.RecordFrameCheck(ctx, FrameCheck{CallID: c.ID, UserID: p.UserID, At: now, Score: score, Flagged: flagged, Action: action})
	if err != nil {
		return FrameAccepted{}, mapErr(err)
	}
	if !flagged {
		return FrameAccepted{Accepted: true}, nil
	}
	if _, _, err := s.deps.Repo.OpenAutomatedCase(ctx, AutomatedCase{
		CallID: c.ID, TargetUserID: p.UserID, Category: "nudity", Reason: "nudity_classifier", Priority: 1,
		Details:     fmt.Sprintf("automated: %s explicit score %.3f (threshold %.2f)", score.Vendor, score.Explicit(), s.deps.Threshold),
		EvidenceRef: "frame_checks/" + strconv.FormatInt(checkID, 10), RetainUntil: now.Add(EvidenceRetention),
	}); err != nil {
		slog.ErrorContext(ctx, "open automated case", "err", err)
	}
	if s.deps.Calls != nil {
		if err := s.deps.Calls.EndCallForModeration(ctx, c.ID); err != nil {
			slog.ErrorContext(ctx, "end call for moderation", "err", err)
			return FrameAccepted{}, err
		}
	}
	return FrameAccepted{Accepted: true}, nil
}

// MaxGap returns the longest interval in [start, end] without a frame.
func MaxGap(start, end time.Time, frames []time.Time) time.Duration {
	ts := append([]time.Time(nil), frames...)
	sort.Slice(ts, func(i, j int) bool { return ts[i].Before(ts[j]) })
	prev, gap := start, time.Duration(0)
	for _, t := range ts {
		if t.Before(start) {
			continue
		}
		if t.After(end) {
			break
		}
		gap = max(gap, t.Sub(prev))
		prev = t
	}
	if end.After(prev) {
		gap = max(gap, end.Sub(prev))
	}
	return gap
}

// CheckMissingFrames is the moderation-missing-frames job: a participant who
// sent no frame for 60 s inside the window gets a review queued (once per
// call and participant). Returns the number of cases opened.
func (s *Service) CheckMissingFrames(ctx context.Context, now time.Time) (int, error) {
	if err := s.ready(); err != nil {
		return 0, err
	}
	if !s.deps.Enabled {
		return 0, nil
	}
	cs, err := s.deps.Repo.FrameWindowCalls(ctx, now)
	if err != nil {
		return 0, err
	}
	opened := 0
	for _, c := range cs {
		end := c.WindowEndsAt
		if now.Before(end) {
			end = now
		}
		if c.EndedAt != nil && c.EndedAt.Before(end) {
			end = *c.EndedAt
		}
		for _, u := range []string{c.CallerID, c.ReceiverID} {
			if MaxGap(c.ConnectedAt, end, c.Frames[u]) < MissingFrameGap {
				continue
			}
			_, created, err := s.deps.Repo.OpenAutomatedCase(ctx, AutomatedCase{
				CallID: c.CallID, TargetUserID: u, Category: "other", Reason: "missing_frames", Priority: 2,
				Details:     "automated: no moderation frames for 60 s during the first 3 minutes",
				EvidenceRef: "calls/" + c.CallID + "/frames", RetainUntil: now.Add(EvidenceRetention),
			})
			if err != nil {
				return opened, err
			}
			if created {
				opened++
			}
		}
	}
	return opened, nil
}

// ListModerationQueue: GET /v1/admin/moderation/queue — open cases, highest priority first.
func (s *Service) ListModerationQueue(ctx context.Context, p auth.Principal, page PageRequest) (Page[ModerationCase], error) {
	if err := s.ready(); err != nil {
		return Page[ModerationCase]{}, err
	}
	var after *QueueCursor
	if page.Cursor != "" {
		c, err := decodeQueueCursor(page.Cursor)
		if err != nil {
			return Page[ModerationCase]{}, apperr.Validation(map[string]string{"cursor": "invalid"})
		}
		after = &c
	}
	items, keys, err := s.deps.Repo.Queue(ctx, after, page.Limit+1)
	if err != nil {
		return Page[ModerationCase]{}, mapErr(err)
	}
	out := Page[ModerationCase]{Items: items}
	if out.Items == nil {
		out.Items = []ModerationCase{}
	}
	if len(items) > page.Limit {
		out.Items = items[:page.Limit]
		cur := encodeQueueCursor(keys[page.Limit-1])
		out.NextCursor = &cur
	}
	return out, nil
}

func encodeQueueCursor(c QueueCursor) string {
	return base64.RawURLEncoding.EncodeToString([]byte(strconv.Itoa(c.Priority) + "|" + c.CreatedAt.UTC().Format(time.RFC3339Nano) + "|" + c.ID))
}

func decodeQueueCursor(s string) (QueueCursor, error) {
	b, err := base64.RawURLEncoding.DecodeString(s)
	if err != nil {
		return QueueCursor{}, err
	}
	parts := strings.Split(string(b), "|")
	if len(parts) != 3 || !isUUID(parts[2]) {
		return QueueCursor{}, errors.New("invalid cursor")
	}
	pr, err := strconv.Atoi(parts[0])
	if err != nil {
		return QueueCursor{}, err
	}
	t, err := time.Parse(time.RFC3339Nano, parts[1])
	return QueueCursor{Priority: pr, CreatedAt: t, ID: parts[2]}, err
}

// DecideReport: POST /v1/admin/reports/{reportId}/decisions — record a
// decision; warn / restrict_calls / suspend / ban / escalate_legal create an
// enforcement action, change the account status and write an audit event.
func (s *Service) DecideReport(ctx context.Context, p auth.Principal, reportId string, in ModerationDecisionRequest) (ModerationDecision, error) {
	if err := s.ready(); err != nil {
		return ModerationDecision{}, err
	}
	if !isUUID(reportId) {
		return ModerationDecision{}, apperr.NotFound("report")
	}
	out, err := s.deps.Repo.DecideReport(ctx, ReportDecision{ReportID: reportId, ModeratorID: p.UserID, Action: in.Action, Reason: in.Reason, At: s.deps.Clock.Now()})
	return out, mapErr(err)
}

// DecideAppeal: POST /v1/admin/appeals/{appealId}/decisions — decided by a
// different reviewer than the original decision.
func (s *Service) DecideAppeal(ctx context.Context, p auth.Principal, appealId string, in AppealDecisionRequest) (ModerationDecision, error) {
	if err := s.ready(); err != nil {
		return ModerationDecision{}, err
	}
	if !isUUID(appealId) {
		return ModerationDecision{}, apperr.NotFound("appeal")
	}
	out, err := s.deps.Repo.DecideAppeal(ctx, AppealDecision{AppealID: appealId, ModeratorID: p.UserID, Outcome: in.Outcome, Reason: in.Reason, At: s.deps.Clock.Now()})
	return out, mapErr(err)
}
