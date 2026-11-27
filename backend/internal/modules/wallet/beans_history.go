package wallet

// Host Beans history (GET /v1/host/beans/history and /summary).
//
// Every line is a real ledger entry of the host's Bean accounts, so the list
// reconciles to the Earnings balances by construction:
//
//	balance (held + available) = sum of every item's `beans`
//
// Pending payout is not part of that balance (those Beans have left it), and
// is reported separately. The pure mapping below has no I/O.

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/modules/ledger"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
)

// BeanRow is one Bean-affecting journal entry of one host, with the details
// the repository could resolve (all optional: a missing call or gift row
// never hides the entry).
type BeanRow struct {
	EntryID    string
	EntryType  string
	OccurredAt time.Time

	// Signed postings to each of the host's Bean accounts.
	HeldDelta, AvailableDelta, PendingDelta int64
	// BalanceAfter is held + available after this entry (running total).
	BalanceAfter int64

	PeerName    string // the customer (call or gift)
	CallID      string
	CallSeconds *int64
	CallRate    *int64
	GiftName    string
	GiftEmoji   string

	// For a release: what was released.
	SourceType string // ledger entry type of the released earning
	// For an earning: when it was released from hold (nil while on hold).
	ReleasedAt *time.Time
}

// BeanTotals are lifetime and recent sums for the summary header.
type BeanTotals struct {
	FromCalls, FromGifts, FromFreeCalls int64
	CallCount, GiftCount                int64
	Reversed                            int64 // clawbacks, as a positive number
	Adjustments                         int64 // signed
	PaidOut                             int64 // payouts that reached the bank
	Today, Last7Days, Last30Days        int64 // earned (calls + gifts + free calls)
}

// BeanHistoryItem is one line of the history (wire type).
type BeanHistoryItem struct {
	ID         string     `json:"id"`
	OccurredAt time.Time  `json:"occurred_at"`
	Type       string     `json:"type"`
	Title      string     `json:"title"`
	Subtitle   *string    `json:"subtitle,omitempty"`
	Beans      int64      `json:"beans"`
	MovedBeans *int64     `json:"moved_beans,omitempty"`
	Balance    int64      `json:"balance_after"`
	Status     *string    `json:"status,omitempty"`
	ReleasesAt *time.Time `json:"releases_at,omitempty"`
	ReleasedAt *time.Time `json:"released_at,omitempty"`
	CallID     *string    `json:"call_id,omitempty"`
	PeerName   *string    `json:"peer_name,omitempty"`
}

// BeanSummary is the header of the history screen (wire type).
type BeanSummary struct {
	Balance        int64 `json:"balance_beans"`
	OnHold         int64 `json:"beans_on_hold"`
	Available      int64 `json:"beans_available"`
	PendingPayout  int64 `json:"beans_pending_payout"`
	LifetimeEarned int64 `json:"lifetime_earned"`
	FromCalls      int64 `json:"from_calls"`
	FromGifts      int64 `json:"from_gifts"`
	FromFreeCalls  int64 `json:"from_free_calls"`
	CallCount      int64 `json:"call_count"`
	GiftCount      int64 `json:"gift_count"`
	Reversed       int64 `json:"reversed"`
	PaidOut        int64 `json:"paid_out"`
	Adjustments    int64 `json:"adjustments"`
	EarnedToday    int64 `json:"earned_today"`
	Earned7Days    int64 `json:"earned_7_days"`
	Earned30Days   int64 `json:"earned_30_days"`
}

// Filters of the history list. The empty string means all.
var beanFilters = map[string][]string{
	"calls":       {string(ledger.EntryCallSettlement), string(ledger.EntryFreeCallCompensation)},
	"gifts":       {string(ledger.EntryGiftSend)},
	"released":    {string(ledger.EntryBeanRelease)},
	"withdrawals": {string(ledger.EntryWithdrawalRequested), string(ledger.EntryPayoutPaid), string(ledger.EntryPayoutFailed)},
	"other":       {string(ledger.EntryBeanClawback), string(ledger.EntryAdjustment)},
}

// beanFilterTypes returns the entry types for a filter (nil = all).
func beanFilterTypes(filter string) ([]string, error) {
	if filter == "" || filter == "all" {
		return nil, nil
	}
	t, ok := beanFilters[filter]
	if !ok {
		return nil, apperr.Validation(map[string]string{"type": "must_be_all_calls_gifts_released_withdrawals_or_other"})
	}
	return t, nil
}

// ToBeanItem maps one row to its wire form. holdPeriod is how long earnings
// stay on hold (economy rule). Pure.
func ToBeanItem(r BeanRow, holdPeriod time.Duration) BeanHistoryItem {
	it := BeanHistoryItem{ID: r.EntryID, OccurredAt: r.OccurredAt, Balance: r.BalanceAfter,
		Beans: r.HeldDelta + r.AvailableDelta}
	setSub := func(s string) {
		if s != "" {
			it.Subtitle = &s
		}
	}
	setMoved := func(n int64) {
		if n > 0 {
			it.MovedBeans = &n
		}
	}
	peer := r.PeerName
	if r.PeerName != "" {
		p := r.PeerName
		it.PeerName = &p
	}
	if r.CallID != "" {
		c := r.CallID
		it.CallID = &c
	}
	earning := func() {
		if r.ReleasedAt != nil {
			s, at := "released", *r.ReleasedAt
			it.Status, it.ReleasedAt = &s, &at
			return
		}
		s, at := "on_hold", r.OccurredAt.Add(holdPeriod)
		it.Status, it.ReleasesAt = &s, &at
	}

	switch ledger.EntryType(r.EntryType) {
	case ledger.EntryCallSettlement:
		it.Type = "call"
		it.Title = "Call with " + orWord(peer, "a customer")
		setSub(callDetail(r.CallSeconds, r.CallRate))
		earning()
	case ledger.EntryFreeCallCompensation:
		it.Type = "free_call"
		it.Title = "Free Call Card call"
		setSub("Paid by Dashuri for a free minute")
		earning()
	case ledger.EntryGiftSend:
		it.Type = "gift"
		name := orWord(r.GiftName, "Gift")
		if r.GiftEmoji != "" {
			name = r.GiftEmoji + " " + name
		}
		it.Title = name + " from " + orWord(peer, "a customer")
		setSub("Gift during a video call")
		earning()
	case ledger.EntryBeanRelease:
		it.Type = "release"
		it.Title = "Released from hold"
		setMoved(r.AvailableDelta)
		switch ledger.EntryType(r.SourceType) {
		case ledger.EntryCallSettlement:
			setSub("Call with " + orWord(peer, "a customer") + " is now withdrawable")
		case ledger.EntryGiftSend:
			setSub("Gift from " + orWord(peer, "a customer") + " is now withdrawable")
		case ledger.EntryFreeCallCompensation:
			setSub("Free Call Card earnings are now withdrawable")
		default:
			setSub("Now withdrawable")
		}
	case ledger.EntryWithdrawalRequested:
		it.Type = "withdrawal"
		it.Title = "Withdrawal requested"
		setSub("Beans moved to your payout")
	case ledger.EntryPayoutPaid:
		it.Type = "payout_paid"
		it.Title = "Withdrawal paid"
		setMoved(-r.PendingDelta)
		setSub("Sent to your bank account")
	case ledger.EntryPayoutFailed:
		it.Type = "payout_failed"
		it.Title = "Withdrawal failed"
		setSub("Beans returned to your balance")
	case ledger.EntryBeanClawback:
		it.Type = "reversal"
		it.Title = "Earnings reversed"
		setSub("Reversed after a refund or safety review")
	case ledger.EntryAdjustment:
		it.Type = "adjustment"
		if it.Beans < 0 {
			it.Title = "Balance correction (debit)"
		} else {
			it.Title = "Balance correction (credit)"
		}
		setSub("Approved by two staff members")
	default:
		it.Type = "other"
		it.Title = "Beans activity"
	}
	return it
}

func orWord(s, fallback string) string {
	if strings.TrimSpace(s) == "" {
		return fallback
	}
	return s
}

// callDetail is "1 min 04 s · 500 Diamonds/min" (either part may be absent).
func callDetail(seconds, rate *int64) string {
	var parts []string
	if seconds != nil {
		s := *seconds
		switch {
		case s < 60:
			parts = append(parts, fmt.Sprintf("%d s", s))
		default:
			parts = append(parts, fmt.Sprintf("%d min %02d s", s/60, s%60))
		}
	}
	if rate != nil {
		parts = append(parts, fmt.Sprintf("%d Diamonds/min", *rate))
	}
	return strings.Join(parts, " · ")
}

// ToBeanSummary combines the balances with the totals. Pure.
func ToBeanSummary(b Balances, t BeanTotals) BeanSummary {
	w := Summarize(b)
	earned := t.FromCalls + t.FromGifts + t.FromFreeCalls
	return BeanSummary{
		Balance: w.BeansOnHold + w.BeansAvailable, OnHold: w.BeansOnHold, Available: w.BeansAvailable,
		PendingPayout: w.BeansPendingPayout, LifetimeEarned: earned,
		FromCalls: t.FromCalls, FromGifts: t.FromGifts, FromFreeCalls: t.FromFreeCalls,
		CallCount: t.CallCount, GiftCount: t.GiftCount, Reversed: t.Reversed, PaidOut: t.PaidOut,
		Adjustments: t.Adjustments, EarnedToday: t.Today, Earned7Days: t.Last7Days, Earned30Days: t.Last30Days,
	}
}

// indiaZone is the host-facing day boundary ("today" starts at midnight IST).
func indiaZone() *time.Location {
	if z, err := time.LoadLocation("Asia/Kolkata"); err == nil {
		return z
	}
	return time.FixedZone("IST", 5*3600+1800)
}

// startOfDayIST is midnight IST of the day containing now.
func startOfDayIST(now time.Time) time.Time {
	n := now.In(indiaZone())
	return time.Date(n.Year(), n.Month(), n.Day(), 0, 0, 0, 0, n.Location())
}

func (s *Service) holdPeriod() time.Duration {
	if s.deps.HoldPeriod > 0 {
		return s.deps.HoldPeriod
	}
	return economy.Founder().BeanHoldPeriod
}

// ListBeanHistory: GET /v1/host/beans/history.
func (s *Service) ListBeanHistory(ctx context.Context, p auth.Principal, page PageRequest, filter string) (Page[BeanHistoryItem], error) {
	if s.deps.Repo == nil {
		return Page[BeanHistoryItem]{}, errDB
	}
	types, err := beanFilterTypes(filter)
	if err != nil {
		return Page[BeanHistoryItem]{}, err
	}
	rows, next, err := s.deps.Repo.BeanHistory(ctx, p.UserID, types, page.Cursor, page.Limit)
	if errors.Is(err, ErrBadCursor) {
		return Page[BeanHistoryItem]{}, apperr.Validation(map[string]string{"cursor": "invalid"})
	}
	if err != nil {
		return Page[BeanHistoryItem]{}, apperr.Internal(err)
	}
	out := Page[BeanHistoryItem]{Items: make([]BeanHistoryItem, 0, len(rows))}
	hold := s.holdPeriod()
	for _, r := range rows {
		out.Items = append(out.Items, ToBeanItem(r, hold))
	}
	if next != "" {
		out.NextCursor = &next
	}
	return out, nil
}

// GetBeanSummary: GET /v1/host/beans/summary.
func (s *Service) GetBeanSummary(ctx context.Context, p auth.Principal) (BeanSummary, error) {
	if s.deps.Repo == nil {
		return BeanSummary{}, errDB
	}
	b, err := s.deps.Repo.Balances(ctx, p.UserID)
	if err != nil {
		return BeanSummary{}, apperr.Internal(err)
	}
	now := time.Now()
	t, err := s.deps.Repo.BeanTotals(ctx, p.UserID, startOfDayIST(now), now.Add(-7*24*time.Hour), now.Add(-30*24*time.Hour))
	if err != nil {
		return BeanSummary{}, apperr.Internal(err)
	}
	return ToBeanSummary(b, t), nil
}
