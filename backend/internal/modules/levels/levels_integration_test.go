//go:build integration

package levels_test

import (
	"context"
	"testing"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/modules/levels"
	"dashuri/backend/internal/testsupport/identitytest"
	"dashuri/backend/internal/testsupport/pgtest"
)

func TestGetMyLevelFromXP(t *testing.T) {
	api, admin := pgtest.Pools(t)
	s := levels.NewService(levels.Deps{Rules: economy.Founder(), Repo: postgres.LevelsRepo{Pool: api}})
	u := pgtest.NewUser(t, admin, true)
	lp, err := s.GetMyLevel(context.Background(), identitytest.Principal(u))
	if err != nil || lp.Level != 1 || lp.LifetimeXp != 0 {
		t.Fatalf("%+v %v", lp, err)
	}
	identitytest.XP(t, admin, u, 60000)
	identitytest.XP(t, admin, u, 50000)
	lp, err = s.GetMyLevel(context.Background(), identitytest.Principal(u))
	if err != nil || lp.Level != 3 || lp.LifetimeXp != 110000 || lp.CurrentLevelXp != 100000 || *lp.NextLevelXp != 250000 {
		t.Fatalf("%+v %v", lp, err)
	}
}
