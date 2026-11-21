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

func TestRateValidation(t *testing.T) {
	r := Founder()
	if err := r.ValidateRate(499, 1); err == nil {
		t.Fatal("below platform minimum accepted")
	}
	if err := r.ValidateRate(10000, 1); err != nil {
		t.Fatal("platform max rejected without a ladder")
	}
	r.LevelRateCaps = []int64{1000, 1500}
	if err := r.ValidateRate(1200, 1); err == nil {
		t.Fatal("level cap not applied")
	}
	if err := r.ValidateRate(1500, 9); err != nil {
		t.Fatal("highest configured cap should apply above ladder length")
	}
}

func TestOverflowGuard(t *testing.T) {
	if _, err := Founder().BeansForDiamonds(1 << 62); err == nil {
		t.Fatal("expected overflow error")
	}
}
