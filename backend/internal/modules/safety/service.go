package safety

import (
	"context"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
)

// Service implements the safety module's use cases. Every method is a
// scaffold that returns 501 until implemented; the documented steps are the
// required behaviour (see docs/architecture).
type Service struct {
	deps Deps
}

func NewService(d Deps) *Service { return &Service{deps: d} }

// ReportUser: POST /v1/reports — Report a user (optionally during/after a call; reporting during a call also ends it client-side).
func (s *Service) ReportUser(ctx context.Context, p auth.Principal, in ReportRequest) (ReportReceipt, error) {
	return ReportReceipt{}, apperr.NotImplemented("safety.ReportUser")
}

// BlockUser: POST /v1/blocks — Block a user (hidden from each other, no calls or messages).
func (s *Service) BlockUser(ctx context.Context, p auth.Principal, in BlockRequest) (BlockedUser, error) {
	return BlockedUser{}, apperr.NotImplemented("safety.BlockUser")
}

// UnblockUser: DELETE /v1/blocks/{userId} — Remove a block.
func (s *Service) UnblockUser(ctx context.Context, p auth.Principal, userId string) error {
	return apperr.NotImplemented("safety.UnblockUser")
}

// ListBlockedUsers: GET /v1/blocks — Blocked users.
func (s *Service) ListBlockedUsers(ctx context.Context, p auth.Principal, page PageRequest) (Page[BlockedUser], error) {
	return Page[BlockedUser]{}, apperr.NotImplemented("safety.ListBlockedUsers")
}

// ListEnforcementNotices: GET /v1/me/enforcement — Enforcement actions on this account.
func (s *Service) ListEnforcementNotices(ctx context.Context, p auth.Principal, page PageRequest) (Page[EnforcementNotice], error) {
	return Page[EnforcementNotice]{}, apperr.NotImplemented("safety.ListEnforcementNotices")
}

// SubmitAppeal: POST /v1/appeals — Appeal an enforcement action.
func (s *Service) SubmitAppeal(ctx context.Context, p auth.Principal, in AppealRequest) (AppealReceipt, error) {
	return AppealReceipt{}, apperr.NotImplemented("safety.SubmitAppeal")
}
