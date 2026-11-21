package levels

import (
	"context"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
)

// Service implements the levels module's use cases. Every method is a
// scaffold that returns 501 until implemented; the documented steps are the
// required behaviour (see docs/architecture).
type Service struct {
	deps Deps
}

func NewService(d Deps) *Service { return &Service{deps: d} }

// GetMyLevel: GET /v1/me/level — Shared account level and XP.
func (s *Service) GetMyLevel(ctx context.Context, p auth.Principal) (LevelProgress, error) {
	return LevelProgress{}, apperr.NotImplemented("levels.GetMyLevel")
}
