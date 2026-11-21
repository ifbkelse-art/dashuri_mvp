package levels

import (
	"testing"

	"dashuri/backend/internal/modules/economy"
)

func TestProgress(t *testing.T) {
	r := economy.Founder()
	p := Progress(r, 0)
	if p.Level != 1 || p.CurrentLevelXp != 0 || p.NextLevelXp == nil || *p.NextLevelXp != 32000 {
		t.Fatalf("level 1: %+v", p)
	}
	p = Progress(r, 32000)
	if p.Level != 2 || p.CurrentLevelXp != 32000 || *p.NextLevelXp != 100000 {
		t.Fatalf("level 2: %+v", p)
	}
	p = Progress(r, 50_000_000)
	if p.Level != 10 || p.NextLevelXp != nil || p.CurrentLevelXp != 40000000 {
		t.Fatalf("top level: %+v", p)
	}
	if p := Progress(r, -5); p.Level != 1 || p.LifetimeXp != 0 {
		t.Fatalf("negative xp: %+v", p)
	}
}
