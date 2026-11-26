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

	// Host rates in Diamonds per minute, integers only (founder spec
	// 2026-11-23): every host may charge at least MinRatePerMinute; the
	// maximum is level × LevelRateStep (levels 1–10, so 1,000–10,000), never
	// above MaxRatePerMinute; a rate above VerifiedRateThreshold requires an
	// ACTIVE Verified Host status. See EligibleMaxRate.
	MinRatePerMinute      int64
	MaxRatePerMinute      int64
	LevelRateStep         int64
	VerifiedRateThreshold int64

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
		Version:                  "2026-11-23-verified-pricing",
		BeansNumerator:           10000,
		DiamondsDenominator:      16670,
		PaisePerBeanNumerator:    1,
		PaisePerBeanDenominator:  2,
		MinRatePerMinute:         500,
		MaxRatePerMinute:         10000,
		LevelRateStep:            1000,
		VerifiedRateThreshold:    3000,
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
	ErrOverflow = errors.New("amount_overflow")
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

// LevelMaxRate is the level's own ceiling (level × LevelRateStep), within
// the platform range. Levels outside 1..len(XPThresholds) are clamped.
func (r Rules) LevelMaxRate(level int) int64 {
	level = min(max(level, 1), max(len(r.XPThresholds), 1))
	return max(min(int64(level)*r.LevelRateStep, r.MaxRatePerMinute), r.MinRatePerMinute)
}

// EligibleMaxRate is the highest rate a host may charge: the level ceiling,
// further capped at VerifiedRateThreshold unless the host is an ACTIVE
// Verified Host. It never drops below the platform minimum.
func (r Rules) EligibleMaxRate(level int, verified bool) int64 {
	m := r.LevelMaxRate(level)
	if !verified {
		m = min(m, r.VerifiedRateThreshold)
	}
	return max(m, r.MinRatePerMinute)
}

// Rate validation failures (the API maps them to distinct error codes).
var (
	ErrRateBelowMinimum         = errors.New("rate_below_minimum")
	ErrRateAboveLevelMax        = errors.New("rate_above_level_max")
	ErrRateRequiresVerification = errors.New("rate_requires_verification")
)

// CheckRate validates a host's chosen integer rate against the pricing
// rules. The order of checks decides the error: below the minimum, above the
// level's ceiling, then above the non-verified threshold.
func (r Rules) CheckRate(ratePerMinute int64, level int, verified bool) error {
	switch {
	case ratePerMinute < r.MinRatePerMinute:
		return ErrRateBelowMinimum
	case ratePerMinute > r.LevelMaxRate(level):
		return ErrRateAboveLevelMax
	case ratePerMinute > r.EligibleMaxRate(level, verified):
		return ErrRateRequiresVerification
	}
	return nil
}

// CapRate returns the stored rate clamped to the host's current
// eligibility. Used on verification revocation/suspension, on a level drop
// and before a new call; approvals and level-ups never raise a rate.
func (r Rules) CapRate(ratePerMinute int64, level int, verified bool) int64 {
	return max(min(ratePerMinute, r.EligibleMaxRate(level, verified)), r.MinRatePerMinute)
}
