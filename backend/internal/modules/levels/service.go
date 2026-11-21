package levels

import (
	"context"

	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
)

// Service implements the levels use cases (display only, D-16).
type Service struct {
	deps Deps
}

func NewService(d Deps) *Service { return &Service{deps: d} }

// GetMyLevel: GET /v1/me/level — shared account level and XP.
func (s *Service) GetMyLevel(ctx context.Context, p auth.Principal) (LevelProgress, error) {
	if s.deps.Repo == nil {
		return LevelProgress{}, apperr.Unavailable("database_unavailable", "database not configured")
	}
	xp, err := s.deps.Repo.LifetimeXP(ctx, p.UserID)
	if err != nil {
		return LevelProgress{}, apperr.Internal(err)
	}
	return Progress(s.deps.Rules, xp), nil
}

// Progress derives the level and its XP bounds from lifetime XP.
// current_level_xp is the XP at which the current level starts;
// next_level_xp is null at the top level.
func Progress(r economy.Rules, xp int64) LevelProgress {
	if xp < 0 {
		xp = 0
	}
	level := r.LevelForXP(xp)
	out := LevelProgress{Level: level, LifetimeXp: xp}
	if level-1 < len(r.XPThresholds) {
		out.CurrentLevelXp = r.XPThresholds[level-1]
	}
	if level < len(r.XPThresholds) {
		next := r.XPThresholds[level]
		out.NextLevelXp = &next
	}
	return out
}
