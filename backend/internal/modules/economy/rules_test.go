package economy

import "testing"

func TestConversionMatchesFounderDecision(t *testing.T) {
	r := Founder()
	if b, _ := r.BeansForDiamonds(16670); b != 10000 {
		t.Fatalf("16,670 D → %d Beans, want 10,000", b)
	}
	if p := r.PaiseForBeans(10000); p != 5000 {
		t.Fatalf("10,000 Beans → %d paise, want 5,000 (₹50)", p)
	}
	if b := r.MinWithdrawalBeans(); b != 100000 {
		t.Fatalf("₹500 minimum = %d Beans, want 100,000", b)
	}
	if b := r.BeansForPaise(r.FreeCallHostCompPaise); b != 2000 {
		t.Fatalf("₹10 free-call compensation = %d Beans, want 2,000", b)
	}
}

func TestConversionRoundsDownOnTotalsNotPerSecond(t *testing.T) {
	r := Founder()
	// 1 Diamond → 0.5998 Beans: floor gives 0. Summing per-second floors
	// would systematically under-pay; we convert the call total once.
	if b, _ := r.BeansForDiamonds(1); b != 0 {
		t.Fatalf("got %d", b)
	}
	if b, _ := r.BeansForDiamonds(4333); b != 2599 { // 4333×10000/16670 = 2599.28
		t.Fatalf("got %d", b)
	}
}

func TestPerSecondBillingFounderExamples(t *testing.T) {
	r := Founder()
	cases := map[int64]int64{15: 1000, 30: 2000, 45: 3000, 60: 4000, 65: 4333, 0: 0}
	for secs, want := range cases {
		if got := r.DiamondsForSeconds(4000, secs); got != want {
			t.Errorf("%ds at 4,000/min = %d, want %d", secs, got, want)
		}
	}
}

func TestStartRequiresSixtySeconds(t *testing.T) {
	r := Founder()
	if r.CanStartCall(3999, 4000) {
		t.Fatal("59.98 s of balance must not start a call")
	}
	if !r.CanStartCall(4000, 4000) {
		t.Fatal("60 s of balance must start a call")
	}
}

func TestXPAndLevels(t *testing.T) {
	r := Founder()
	if xp := r.XP(1000, 1000); xp != 9000 {
		t.Fatalf("XP = %d, want 9,000", xp)
	}
	if l := r.LevelForXP(31999); l != 1 {
		t.Fatalf("level %d", l)
	}
	if l := r.LevelForXP(32000); l != 2 {
		t.Fatalf("level %d", l)
	}
}

// Founder spec 2026-11-23: min 500 for every host; max = level × 1,000;
// above 3,000 needs an active Verified Host; integers only.
func TestPricingEveryLevel(t *testing.T) {
	r := Founder()
	for level := 1; level <= 10; level++ {
		levelMax := int64(level) * 1000
		nonVerifiedMax := min(levelMax, 3000)
		if got := r.LevelMaxRate(level); got != levelMax {
			t.Fatalf("L%d level max %d, want %d", level, got, levelMax)
		}
		if got := r.EligibleMaxRate(level, true); got != levelMax {
			t.Fatalf("L%d verified max %d, want %d", level, got, levelMax)
		}
		if got := r.EligibleMaxRate(level, false); got != nonVerifiedMax {
			t.Fatalf("L%d non-verified max %d, want %d", level, got, nonVerifiedMax)
		}
		for _, verified := range []bool{false, true} {
			eligible := r.EligibleMaxRate(level, verified)
			if err := r.CheckRate(499, level, verified); err != ErrRateBelowMinimum {
				t.Fatalf("L%d v=%v 499: %v", level, verified, err)
			}
			if err := r.CheckRate(500, level, verified); err != nil {
				t.Fatalf("L%d v=%v 500: %v", level, verified, err)
			}
			if err := r.CheckRate(eligible, level, verified); err != nil {
				t.Fatalf("L%d v=%v max %d: %v", level, verified, eligible, err)
			}
			want := ErrRateAboveLevelMax
			if !verified && levelMax > 3000 {
				want = ErrRateRequiresVerification
			}
			if err := r.CheckRate(eligible+1, level, verified); err != want {
				t.Fatalf("L%d v=%v max+1: %v, want %v", level, verified, err, want)
			}
			if err := r.CheckRate(levelMax+1, level, verified); err != ErrRateAboveLevelMax {
				t.Fatalf("L%d v=%v level max+1: %v", level, verified, err)
			}
		}
	}
}

func TestPricingVerifiedThresholdBoundary(t *testing.T) {
	r := Founder()
	for level := 3; level <= 10; level++ {
		if err := r.CheckRate(3000, level, false); err != nil {
			t.Fatalf("L%d 3,000 non-verified: %v", level, err)
		}
	}
	for level := 4; level <= 10; level++ {
		if err := r.CheckRate(3001, level, false); err != ErrRateRequiresVerification {
			t.Fatalf("L%d 3,001 non-verified: %v", level, err)
		}
		if err := r.CheckRate(3001, level, true); err != nil {
			t.Fatalf("L%d 3,001 verified: %v", level, err)
		}
	}
	// Level 3 tops out at 3,000 even when verified.
	if err := r.CheckRate(3001, 3, true); err != ErrRateAboveLevelMax {
		t.Fatalf("L3 3,001 verified: %v", err)
	}
	// Out-of-range levels are clamped to the ladder.
	if r.LevelMaxRate(0) != 1000 || r.LevelMaxRate(11) != 10000 {
		t.Fatalf("clamp %d %d", r.LevelMaxRate(0), r.LevelMaxRate(11))
	}
}

func TestCapRate(t *testing.T) {
	r := Founder()
	cases := []struct {
		rate     int64
		level    int
		verified bool
		want     int64
	}{
		{9000, 10, false, 3000}, // revocation: capped to 3,000
		{9000, 10, true, 9000},  // still verified: untouched
		{9000, 6, true, 6000},   // level drop: capped to the new level max
		{9000, 2, false, 2000},  // revoked and dropped to level 2
		{2500, 10, true, 2500},  // approval / level-up never raises a price
		{500, 1, false, 500},
	}
	for _, c := range cases {
		if got := r.CapRate(c.rate, c.level, c.verified); got != c.want {
			t.Fatalf("CapRate(%d, L%d, %v) = %d, want %d", c.rate, c.level, c.verified, got, c.want)
		}
	}
}

func TestOverflowGuard(t *testing.T) {
	if _, err := Founder().BeansForDiamonds(1 << 62); err == nil {
		t.Fatal("expected overflow error")
	}
}
