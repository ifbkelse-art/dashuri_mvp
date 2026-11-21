package safety

import (
	"context"
	"errors"
	"strings"
	"time"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/clock"
)

// ReportWindow is how long after a call ends it may be reported (D-20).
const ReportWindow = 24 * time.Hour

// PriorityFor returns the moderation queue priority (1 = most urgent).
// Nudity and minor safety are handled first (S7).
func PriorityFor(category string) int {
	switch category {
	case "nudity", "minor_safety":
		return 1
	default:
		return 3
	}
}

// liveCallPhases mirror the one-live-call indexes on calls.calls.
var liveCallPhases = map[string]bool{
	"requested": true, "ringing": true, "accepted": true, "connecting": true,
	"active": true, "paused": true, "ending": true,
}

// WithinReportWindow: the call is live, or ended at most 24 h ago.
func WithinReportWindow(c CallInfo, now time.Time) bool {
	if liveCallPhases[c.Phase] {
		return true
	}
	end := c.CreatedAt
	if c.EndedAt != nil {
		end = *c.EndedAt
	}
	return now.Sub(end) <= ReportWindow
}

// Service implements user-facing safety: reports, blocks, enforcement, appeals.
type Service struct {
	deps Deps
}

func NewService(d Deps) *Service {
	if d.Clock == nil {
		d.Clock = clock.System{}
	}
	return &Service{deps: d}
}

func (s *Service) repo() (Repository, error) {
	if s.deps.Repo == nil {
		return nil, apperr.Unavailable("database_unavailable", "database not configured")
	}
	return s.deps.Repo, nil
}

func internal(err error) error {
	if apperr.As(err) != nil {
		return err
	}
	return apperr.Internal(err)
}

// ReportUser: POST /v1/reports. With call_id, the reporter must be a
// participant, the target the other participant, and the call live or
// ended at most 24 h ago (409 report_window_closed).
func (s *Service) ReportUser(ctx context.Context, p auth.Principal, in ReportRequest) (ReportReceipt, error) {
	if errs := in.validate(); len(errs) > 0 {
		return ReportReceipt{}, validationError(errs)
	}
	if in.TargetUserId == p.UserID {
		return ReportReceipt{}, validationError(map[string]string{"target_user_id": "self"})
	}
	repo, err := s.repo()
	if err != nil {
		return ReportReceipt{}, err
	}
	ok, err := repo.UserExists(ctx, in.TargetUserId)
	if err != nil {
		return ReportReceipt{}, internal(err)
	}
	if !ok {
		return ReportReceipt{}, apperr.NotFound("user")
	}
	var callID *string
	if in.CallId != nil && *in.CallId != "" {
		c, err := repo.Call(ctx, *in.CallId)
		if errors.Is(err, ErrNotFound) || (err == nil && c.CallerID != p.UserID && c.ReceiverID != p.UserID) {
			return ReportReceipt{}, apperr.NotFound("call")
		}
		if err != nil {
			return ReportReceipt{}, internal(err)
		}
		if c.CallerID != in.TargetUserId && c.ReceiverID != in.TargetUserId {
			return ReportReceipt{}, validationError(map[string]string{"target_user_id": "not_call_participant"})
		}
		if !WithinReportWindow(c, s.deps.Clock.Now()) {
			return ReportReceipt{}, apperr.BusinessRule("report_window_closed", "calls can be reported up to 24 hours after they end")
		}
		callID = in.CallId
	}
	var details *string
	if in.Details != nil {
		if d := strings.TrimSpace(*in.Details); d != "" {
			details = &d
		}
	}
	rec, err := repo.CreateReport(ctx, NewReport{
		ReporterID: p.UserID, TargetID: in.TargetUserId, Category: in.Category,
		CallID: callID, Details: details, Priority: PriorityFor(in.Category),
	})
	return rec, internalOrNil(err)
}

// BlockUser: POST /v1/blocks. Blocking hides both users from each other and
// stops new calls and messages; it does not end a live call by itself.
func (s *Service) BlockUser(ctx context.Context, p auth.Principal, in BlockRequest) (BlockedUser, error) {
	if errs := in.validate(); len(errs) > 0 {
		return BlockedUser{}, validationError(errs)
	}
	if in.UserId == p.UserID {
		return BlockedUser{}, validationError(map[string]string{"user_id": "self"})
	}
	repo, err := s.repo()
	if err != nil {
		return BlockedUser{}, err
	}
	b, err := repo.Block(ctx, p.UserID, in.UserId)
	if errors.Is(err, ErrNotFound) {
		return BlockedUser{}, apperr.NotFound("user")
	}
	return b, internalOrNil(err)
}

// UnblockUser: DELETE /v1/blocks/{userId}. Idempotent.
func (s *Service) UnblockUser(ctx context.Context, p auth.Principal, userId string) error {
	if !isUUID(userId) {
		return apperr.NotFound("block")
	}
	repo, err := s.repo()
	if err != nil {
		return err
	}
	return internalOrNil(repo.Unblock(ctx, p.UserID, userId))
}

// ListBlockedUsers: GET /v1/blocks — newest first.
func (s *Service) ListBlockedUsers(ctx context.Context, p auth.Principal, page PageRequest) (Page[BlockedUser], error) {
	after, err := DecodeCursor(page.Cursor)
	if err != nil {
		return Page[BlockedUser]{}, validationError(map[string]string{"cursor": "invalid"})
	}
	repo, err := s.repo()
	if err != nil {
		return Page[BlockedUser]{}, err
	}
	rows, err := repo.ListBlocks(ctx, p.UserID, after, page.Limit+1)
	if err != nil {
		return Page[BlockedUser]{}, internal(err)
	}
	out := Page[BlockedUser]{Items: []BlockedUser{}}
	if len(rows) > page.Limit {
		rows = rows[:page.Limit]
		last := rows[len(rows)-1]
		next := Cursor{At: last.BlockedAt, ID: last.UserId}.Encode()
		out.NextCursor = &next
	}
	out.Items = append(out.Items, rows...)
	return out, nil
}

// ListEnforcementNotices: GET /v1/me/enforcement — newest first.
func (s *Service) ListEnforcementNotices(ctx context.Context, p auth.Principal, page PageRequest) (Page[EnforcementNotice], error) {
	after, err := DecodeCursor(page.Cursor)
	if err != nil {
		return Page[EnforcementNotice]{}, validationError(map[string]string{"cursor": "invalid"})
	}
	repo, err := s.repo()
	if err != nil {
		return Page[EnforcementNotice]{}, err
	}
	rows, err := repo.ListEnforcement(ctx, p.UserID, after, page.Limit+1)
	if err != nil {
		return Page[EnforcementNotice]{}, internal(err)
	}
	out := Page[EnforcementNotice]{Items: []EnforcementNotice{}}
	if len(rows) > page.Limit {
		rows = rows[:page.Limit]
		last := rows[len(rows)-1]
		next := Cursor{At: last.CreatedAt, ID: last.Id}.Encode()
		out.NextCursor = &next
	}
	out.Items = append(out.Items, rows...)
	return out, nil
}

// SubmitAppeal: POST /v1/appeals — own, appealable enforcement only; one
// appeal per enforcement (409 appeal_exists).
func (s *Service) SubmitAppeal(ctx context.Context, p auth.Principal, in AppealRequest) (AppealReceipt, error) {
	if errs := in.validate(); len(errs) > 0 {
		return AppealReceipt{}, validationError(errs)
	}
	repo, err := s.repo()
	if err != nil {
		return AppealReceipt{}, err
	}
	rec, err := repo.CreateAppeal(ctx, p.UserID, in.EnforcementId, strings.TrimSpace(in.Statement))
	switch {
	case errors.Is(err, ErrNotFound):
		return AppealReceipt{}, apperr.NotFound("enforcement")
	case errors.Is(err, ErrNotAppealable):
		return AppealReceipt{}, apperr.BusinessRule("not_appealable", "this decision cannot be appealed")
	case errors.Is(err, ErrAppealExists):
		return AppealReceipt{}, apperr.BusinessRule("appeal_exists", "an appeal was already submitted for this decision")
	}
	return rec, internalOrNil(err)
}

func internalOrNil(err error) error {
	if err == nil {
		return nil
	}
	return internal(err)
}
