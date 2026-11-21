package moderation

import (
	"context"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
)

// Service implements the moderation module's use cases. Every method is a
// scaffold that returns 501 until implemented; the documented steps are the
// required behaviour (see docs/architecture).
type Service struct {
	deps Deps
}

func NewService(d Deps) *Service { return &Service{deps: d} }

// ListModerationQueue: GET /v1/admin/moderation/queue — Open reports and automated nudity flags, highest severity first.
func (s *Service) ListModerationQueue(ctx context.Context, p auth.Principal, page PageRequest) (Page[ModerationCase], error) {
	return Page[ModerationCase]{}, apperr.NotImplemented("moderation.ListModerationQueue")
}

// DecideReport: POST /v1/admin/reports/{reportId}/decisions — Record a moderation decision and apply enforcement.
func (s *Service) DecideReport(ctx context.Context, p auth.Principal, reportId string, in ModerationDecisionRequest) (ModerationDecision, error) {
	return ModerationDecision{}, apperr.NotImplemented("moderation.DecideReport")
}

// DecideAppeal: POST /v1/admin/appeals/{appealId}/decisions — Decide an appeal (different reviewer than the original decision).
func (s *Service) DecideAppeal(ctx context.Context, p auth.Principal, appealId string, in AppealDecisionRequest) (ModerationDecision, error) {
	return ModerationDecision{}, apperr.NotImplemented("moderation.DecideAppeal")
}
