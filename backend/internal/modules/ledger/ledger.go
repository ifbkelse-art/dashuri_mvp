// Package ledger is Dashuri's double-entry ledger for Diamonds, Beans and
// INR paise. Balances are never edited: every change is an immutable journal
// entry whose postings sum to zero per currency. Corrections are new
// reversing entries.
//
// User wallet accounts can never go negative (DB CHECK on the balance
// projection). System accounts (issuance, consumption, payout) are allowed
// to go negative because they represent the other side of user balances.
package ledger

import (
	"context"
	"errors"
	"fmt"
	"time"
)

type Currency string

const (
	Diamond Currency = "DIAMOND"
	Bean    Currency = "BEAN"
	Paise   Currency = "INR_PAISE"
)

// AccountKind identifies a balance bucket.
type AccountKind string

const (
	// Customer Diamonds (liability: unspent purchased Diamonds are owed to customers).
	UserDiamondPurchased   AccountKind = "diamond_purchased"
	UserDiamondPromotional AccountKind = "diamond_promotional"
	// Host Beans (liability: owed to hosts).
	UserBeanHeld          AccountKind = "bean_held"           // 7-day hold
	UserBeanAvailable     AccountKind = "bean_available"      // withdrawable
	UserBeanPayoutPending AccountKind = "bean_payout_pending" // in a payout cycle

	SystemDiamondIssuedPurchased AccountKind = "sys_diamond_issued_purchased"
	SystemDiamondIssuedPromo     AccountKind = "sys_diamond_issued_promotional"
	SystemDiamondConsumed        AccountKind = "sys_diamond_consumed"
	SystemDiamondExpired         AccountKind = "sys_diamond_expired"
	SystemDiamondReversed        AccountKind = "sys_diamond_reversed"
	SystemBeanIssued             AccountKind = "sys_bean_issued"
	SystemBeanPaidOut            AccountKind = "sys_bean_paid_out"
	SystemBeanClawedBack         AccountKind = "sys_bean_clawed_back"
)

// AccountRef names an account: a user's bucket or a system account.
type AccountRef struct {
	UserID string // empty for system accounts
	Kind   AccountKind
}

func User(id string, k AccountKind) AccountRef { return AccountRef{UserID: id, Kind: k} }
func System(k AccountKind) AccountRef          { return AccountRef{Kind: k} }

func (a AccountRef) String() string {
	if a.UserID == "" {
		return "system:" + string(a.Kind)
	}
	return "user:" + a.UserID + ":" + string(a.Kind)
}

// Posting changes one account. Positive increases the account's balance.
type Posting struct {
	Account  AccountRef
	Currency Currency
	Amount   int64
}

// EntryType is the business event behind an entry.
type EntryType string

const (
	EntryPurchaseCredit       EntryType = "purchase_credit"
	EntryPromoGrant           EntryType = "promo_grant"
	EntryCallSettlement       EntryType = "call_settlement"
	EntryFreeCallCompensation EntryType = "free_call_compensation"
	EntryBeanRelease          EntryType = "bean_release"
	EntryWithdrawalRequested  EntryType = "withdrawal_requested"
	EntryPayoutPaid           EntryType = "payout_paid"
	EntryPayoutFailed         EntryType = "payout_failed"
	EntryPurchaseReversal     EntryType = "purchase_reversal" // refund or chargeback
	EntryBeanClawback         EntryType = "bean_clawback"
	EntryPromoExpiry          EntryType = "promo_expiry"
	EntryAdjustment           EntryType = "adjustment" // manual; dual control required
)

// Entry is one atomic, balanced journal entry.
type Entry struct {
	Type EntryType
	// IdempotencyKey is unique per business event (e.g. "call_settlement:<call_id>",
	// "purchase_credit:<purchase_token_hash>"). A second insert with the same key
	// is a no-op that returns the first entry. This, not the HTTP key, is what
	// makes money movement exactly-once.
	IdempotencyKey string
	RuleSetVersion string
	Reference      string // e.g. call id, purchase id, payout id
	OccurredAt     time.Time
	Postings       []Posting
	Metadata       map[string]string
}

var (
	ErrUnbalanced      = errors.New("ledger: postings do not sum to zero per currency")
	ErrEmpty           = errors.New("ledger: entry needs at least two postings")
	ErrZeroPosting     = errors.New("ledger: zero-amount posting")
	ErrMissingKey      = errors.New("ledger: idempotency key required")
	ErrCurrencyAccount = errors.New("ledger: currency does not match account kind")
)

// Validate checks structural invariants before any database write.
func (e Entry) Validate() error {
	if e.IdempotencyKey == "" {
		return ErrMissingKey
	}
	if len(e.Postings) < 2 {
		return ErrEmpty
	}
	sums := map[Currency]int64{}
	for _, p := range e.Postings {
		if p.Amount == 0 {
			return ErrZeroPosting
		}
		if want := currencyOf(p.Account.Kind); want != "" && want != p.Currency {
			return fmt.Errorf("%w: %s holds %s, not %s", ErrCurrencyAccount, p.Account, want, p.Currency)
		}
		sums[p.Currency] += p.Amount
	}
	for c, s := range sums {
		if s != 0 {
			return fmt.Errorf("%w: %s sums to %d", ErrUnbalanced, c, s)
		}
	}
	return nil
}

func currencyOf(k AccountKind) Currency {
	switch k {
	case UserDiamondPurchased, UserDiamondPromotional, SystemDiamondIssuedPurchased, SystemDiamondIssuedPromo,
		SystemDiamondConsumed, SystemDiamondExpired, SystemDiamondReversed:
		return Diamond
	case UserBeanHeld, UserBeanAvailable, UserBeanPayoutPending, SystemBeanIssued, SystemBeanPaidOut, SystemBeanClawedBack:
		return Bean
	}
	return ""
}

// Store persists entries. Implementations MUST, in one transaction:
//  1. insert the entry (unique on IdempotencyKey; on conflict return the existing entry, no new postings);
//  2. lock affected balance rows with SELECT … FOR UPDATE in ascending account order;
//  3. insert postings and update the balance projection;
//  4. fail the whole transaction if any user balance would go negative.
type Store interface {
	Post(ctx context.Context, e Entry) (entryID string, replayed bool, err error)
	Balance(ctx context.Context, a AccountRef, c Currency) (int64, error)
}
