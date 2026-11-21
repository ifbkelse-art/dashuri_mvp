// Package economy holds Dashuri's business rules as data. Every number here
// is configurable and versioned (table economy.rule_sets); code reads the
// active Rules instead of hard-coding constants. Every ledger entry records
// the rule-set version it was computed with.
package economy

import (
	"errors"
	"math"
	"time"
)

// Rules is one immutable, versioned rule set.
type Rules struct {
	Version string

	// Conversion: BeansNumerator Beans per DiamondsDenominator Diamonds spent.
	// Founder decision S3: 16,670 Diamonds spent = 10,000 Beans.
	BeansNumerator      int64
	DiamondsDenominator int64

	// Bean value as a fraction of a paisa: 1 Bean = ₹0.005 = 1/2 paisa (S3).
	PaisePerBeanNumerator   int64
	PaisePerBeanDenominator int64

	// Host rates in Diamonds per minute (S2: 500–10,000). LevelRateCaps[i]
	// is the max rate at level i+1; nil until the ladder is decided.
	MinRatePerMinute int64
	MaxRatePerMinute int64
	LevelRateCaps    []int64

	// XP = XPDiamondWeight × Diamonds purchased + XPBeanWeight × Beans earned (R3-3, S8).
	XPDiamondWeight int64
	XPBeanWeight    int64
	// XPThresholds[i] is the XP needed for level i+1. UNRESOLVED (P12 proposal used).
	XPThresholds []int64

	// Wallet and payouts (C19, S5).
	BeanHoldPeriod         time.Duration
	MinWithdrawalPaise     int64
	PromoDiamondTTL        time.Duration
	MinStartBalanceSeconds int64
	LowBalanceWarnSeconds  int64

	// Free Call Card (S4).
	FreeCallSeconds          int64
	FreeCallHostCompPaise    int64
	FreeCallMaxPerHostPerDay int

	// Call metering (S6). Interruptions at least this long are not billed.
	// TECHNICAL ASSUMPTION, not a founder decision; tune with real data.
	InterruptionThreshold time.Duration
	// Order in which Diamonds are spent. UNRESOLVED; "promotional_first" assumed.
	SpendOrder string
}

// Founder returns the rule set confirmed on 2026-11-17. Values marked
// UNRESOLVED are proposals and must be confirmed before launch.
func Founder() Rules {
	return Rules{
		Version:                  "2026-11-17-founder",
		BeansNumerator:           10000,
		DiamondsDenominator:      16670,
		PaisePerBeanNumerator:    1,
		PaisePerBeanDenominator:  2,
		MinRatePerMinute:         500,
		MaxRatePerMinute:         10000,
		LevelRateCaps:            nil, // UNRESOLVED
		XPDiamondWeight:          8,
		XPBeanWeight:             1,
		XPThresholds:             []int64{0, 32000, 100000, 250000, 600000, 1500000, 3500000, 8000000, 18000000, 40000000}, // UNRESOLVED (P12)
		BeanHoldPeriod:           7 * 24 * time.Hour,
		MinWithdrawalPaise:       50000, // ₹500
		PromoDiamondTTL:          30 * 24 * time.Hour,
		MinStartBalanceSeconds:   60,
		LowBalanceWarnSeconds:    30,
		FreeCallSeconds:          60,
		FreeCallHostCompPaise:    1000, // ₹10
		FreeCallMaxPerHostPerDay: 20,
		InterruptionThreshold:    10 * time.Second,
		SpendOrder:               "promotional_first",
	}
}

var (
	ErrRateOutOfRange = errors.New("rate_outside_level_limits")
	ErrOverflow       = errors.New("amount_overflow")
)

// BeansForDiamonds converts Diamonds spent to Beans earned, rounding DOWN.
// Apply it once to a call's total, never per second, so rounding cannot
// accumulate. The sub-Bean remainder is not credited to anyone (residue
// policy UNRESOLVED; see financial-ledger-design.md).
func (r Rules) BeansForDiamonds(diamonds int64) (int64, error) {
	if diamonds < 0 {
		return 0, errors.New("negative diamonds")
	}
	if diamonds > math.MaxInt64/r.BeansNumerator {
		return 0, ErrOverflow
	}
	return diamonds * r.BeansNumerator / r.DiamondsDenominator, nil
}

// DiamondsForSeconds is per-second proportional billing, rounded DOWN in the
// customer's favour, computed once on the final billable seconds (S6).
func (r Rules) DiamondsForSeconds(ratePerMinute, seconds int64) int64 {
	if seconds <= 0 || ratePerMinute <= 0 {
		return 0
	}
	return ratePerMinute * seconds / 60
}

// SecondsAffordable is how long a balance lasts at a rate.
func (r Rules) SecondsAffordable(balance, ratePerMinute int64) int64 {
	if ratePerMinute <= 0 || balance <= 0 {
		return 0
	}
	return balance * 60 / ratePerMinute
}

// CanStartCall: the balance must cover MinStartBalanceSeconds (S6).
func (r Rules) CanStartCall(availableDiamonds, ratePerMinute int64) bool {
	return r.SecondsAffordable(availableDiamonds, ratePerMinute) >= r.MinStartBalanceSeconds
}

// PaiseForBeans converts Beans to INR paise, rounding DOWN.
func (r Rules) PaiseForBeans(beans int64) int64 {
	return beans * r.PaisePerBeanNumerator / r.PaisePerBeanDenominator
}

// BeansForPaise converts a paise amount (e.g. ₹10 free-call compensation) to Beans.
func (r Rules) BeansForPaise(paise int64) int64 {
	return paise * r.PaisePerBeanDenominator / r.PaisePerBeanNumerator
}

// MinWithdrawalBeans is the ₹500 minimum expressed in Beans.
func (r Rules) MinWithdrawalBeans() int64 { return r.BeansForPaise(r.MinWithdrawalPaise) }

// XP for lifetime eligible purchases and earnings. Never decreases with
// spending or withdrawals; reversals subtract the original grant.
func (r Rules) XP(eligibleDiamondsPurchased, eligibleBeansEarned int64) int64 {
	return r.XPDiamondWeight*eligibleDiamondsPurchased + r.XPBeanWeight*eligibleBeansEarned
}

// LevelForXP returns the 1-based shared account level.
func (r Rules) LevelForXP(xp int64) int {
	level := 1
	for i, t := range r.XPThresholds {
		if xp >= t {
			level = i + 1
		}
	}
	return level
}

// MaxRateForLevel applies the level ladder if one is configured, always
// within the platform range.
func (r Rules) MaxRateForLevel(level int) int64 {
	maxRate := r.MaxRatePerMinute
	if len(r.LevelRateCaps) > 0 {
		i := min(max(level, 1), len(r.LevelRateCaps)) - 1
		maxRate = min(maxRate, r.LevelRateCaps[i])
	}
	return max(maxRate, r.MinRatePerMinute)
}

// ValidateRate checks a host's chosen rate against the platform range and
// the host's level cap (S2).
func (r Rules) ValidateRate(ratePerMinute int64, level int) error {
	if ratePerMinute < r.MinRatePerMinute || ratePerMinute > r.MaxRateForLevel(level) {
		return ErrRateOutOfRange
	}
	return nil
}
