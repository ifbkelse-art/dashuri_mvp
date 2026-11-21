package ledger

import (
	"errors"
	"time"
)

// Templates build the only entries the application may post. Handlers and
// services never assemble postings by hand.

// PurchaseCredit: a verified Google Play purchase adds purchased Diamonds.
func PurchaseCredit(userID, purchaseID, tokenHash string, diamonds int64, rules string, at time.Time) Entry {
	return Entry{
		Type: EntryPurchaseCredit, IdempotencyKey: "purchase_credit:" + tokenHash, RuleSetVersion: rules,
		Reference: purchaseID, OccurredAt: at,
		Postings: []Posting{
			{System(SystemDiamondIssuedPurchased), Diamond, -diamonds},
			{User(userID, UserDiamondPurchased), Diamond, diamonds},
		},
	}
}

// CallCharge is the server-computed outcome of one paid call.
type CallCharge struct {
	CallID, CustomerID, HostID string
	FromPromotional            int64 // Diamonds taken from the promotional bucket
	FromPurchased              int64 // Diamonds taken from the purchased bucket
	HostBeans                  int64 // BeansForDiamonds(total), computed once
	RuleSetVersion             string
	At                         time.Time
}

var ErrNothingToSettle = errors.New("ledger: call has no charge")

// CallSettlement moves spent Diamonds to consumption and credits the host's
// Beans into the 7-day hold. One entry per call (key = call id).
func CallSettlement(c CallCharge) (Entry, error) {
	total := c.FromPromotional + c.FromPurchased
	if total <= 0 {
		return Entry{}, ErrNothingToSettle
	}
	var ps []Posting
	if c.FromPromotional > 0 {
		ps = append(ps, Posting{User(c.CustomerID, UserDiamondPromotional), Diamond, -c.FromPromotional})
	}
	if c.FromPurchased > 0 {
		ps = append(ps, Posting{User(c.CustomerID, UserDiamondPurchased), Diamond, -c.FromPurchased})
	}
	ps = append(ps, Posting{System(SystemDiamondConsumed), Diamond, total})
	if c.HostBeans > 0 {
		ps = append(ps,
			Posting{System(SystemBeanIssued), Bean, -c.HostBeans},
			Posting{User(c.HostID, UserBeanHeld), Bean, c.HostBeans},
		)
	}
	return Entry{
		Type: EntryCallSettlement, IdempotencyKey: "call_settlement:" + c.CallID, RuleSetVersion: c.RuleSetVersion,
		Reference: c.CallID, OccurredAt: c.At, Postings: ps,
		Metadata: map[string]string{"customer_id": c.CustomerID, "host_id": c.HostID},
	}, nil
}

// FreeCallCompensation credits the ₹10-equivalent Beans for an eligible free-call minute (S4).
func FreeCallCompensation(freeCallID, hostID string, beans int64, rules string, at time.Time) Entry {
	return Entry{
		Type: EntryFreeCallCompensation, IdempotencyKey: "free_call_comp:" + freeCallID, RuleSetVersion: rules,
		Reference: freeCallID, OccurredAt: at,
		Postings: []Posting{
			{System(SystemBeanIssued), Bean, -beans},
			{User(hostID, UserBeanHeld), Bean, beans},
		},
	}
}

// BeanRelease moves Beans whose 7-day hold has ended to available.
// Key includes the source entry so each held amount is released once.
func BeanRelease(hostID, sourceEntryID string, beans int64, at time.Time) Entry {
	return Entry{
		Type: EntryBeanRelease, IdempotencyKey: "bean_release:" + sourceEntryID, Reference: sourceEntryID, OccurredAt: at,
		Postings: []Posting{
			{User(hostID, UserBeanHeld), Bean, -beans},
			{User(hostID, UserBeanAvailable), Bean, beans},
		},
	}
}

// WithdrawalRequested reserves available Beans for the next payout cycle.
func WithdrawalRequested(hostID, withdrawalID string, beans int64, at time.Time) Entry {
	return Entry{
		Type: EntryWithdrawalRequested, IdempotencyKey: "withdrawal:" + withdrawalID, Reference: withdrawalID, OccurredAt: at,
		Postings: []Posting{
			{User(hostID, UserBeanAvailable), Bean, -beans},
			{User(hostID, UserBeanPayoutPending), Bean, beans},
		},
	}
}

// PayoutSettled closes a withdrawal: paid (Beans leave the platform) or
// failed (Beans return to available).
func PayoutSettled(hostID, withdrawalID string, beans int64, paid bool, at time.Time) Entry {
	if paid {
		return Entry{
			Type: EntryPayoutPaid, IdempotencyKey: "payout_paid:" + withdrawalID, Reference: withdrawalID, OccurredAt: at,
			Postings: []Posting{
				{User(hostID, UserBeanPayoutPending), Bean, -beans},
				{System(SystemBeanPaidOut), Bean, beans},
			},
		}
	}
	return Entry{
		Type: EntryPayoutFailed, IdempotencyKey: "payout_failed:" + withdrawalID, Reference: withdrawalID, OccurredAt: at,
		Postings: []Posting{
			{User(hostID, UserBeanPayoutPending), Bean, -beans},
			{User(hostID, UserBeanAvailable), Bean, beans},
		},
	}
}

// PromoExpiry removes promotional Diamonds 30 days after grant (S5).
func PromoExpiry(userID, grantEntryID string, diamonds int64, at time.Time) Entry {
	return Entry{
		Type: EntryPromoExpiry, IdempotencyKey: "promo_expiry:" + grantEntryID, Reference: grantEntryID, OccurredAt: at,
		Postings: []Posting{
			{User(userID, UserDiamondPromotional), Diamond, -diamonds},
			{System(SystemDiamondExpired), Diamond, diamonds},
		},
	}
}

// PurchaseReversal removes the still-unspent part of a refunded or
// charged-back purchase. Diamonds already spent cannot be taken back from the
// customer; the shortfall is recorded as a loss in the reversal record and
// handled by fraud review (account restriction, Bean clawback from held Beans).
func PurchaseReversal(userID, purchaseID string, unspentToRemove int64, at time.Time) Entry {
	return Entry{
		Type: EntryPurchaseReversal, IdempotencyKey: "purchase_reversal:" + purchaseID, Reference: purchaseID, OccurredAt: at,
		Postings: []Posting{
			{User(userID, UserDiamondPurchased), Diamond, -unspentToRemove},
			{System(SystemDiamondReversed), Diamond, unspentToRemove},
		},
	}
}

// BeanClawback reverses Beans still in hold after fraud or a chargeback.
func BeanClawback(hostID, caseID string, beans int64, at time.Time) Entry {
	return Entry{
		Type: EntryBeanClawback, IdempotencyKey: "bean_clawback:" + caseID, Reference: caseID, OccurredAt: at,
		Postings: []Posting{
			{User(hostID, UserBeanHeld), Bean, -beans},
			{System(SystemBeanClawedBack), Bean, beans},
		},
	}
}

// ErrAdjustment reports an adjustment that cannot be posted.
var ErrAdjustment = errors.New("ledger: adjustment must target a user wallet account with a non-zero amount in its currency")

// Adjustment posts a dual-control manual correction (proposal + a second,
// different approver) to one user wallet account against the currency's
// adjustment system account. History is never edited: a correction is a new
// entry. Key: adjustment:<proposal id>.
func Adjustment(proposalID string, account AccountRef, amount int64, reason, proposedBy, approvedBy string, at time.Time) (Entry, error) {
	cur := currencyOf(account.Kind)
	if account.UserID == "" || amount == 0 || cur == "" || proposalID == "" {
		return Entry{}, ErrAdjustment
	}
	sys := System(SystemDiamondAdjustment)
	if cur == Bean {
		sys = System(SystemBeanAdjustment)
	}
	return Entry{
		Type: EntryAdjustment, IdempotencyKey: "adjustment:" + proposalID, Reference: proposalID, OccurredAt: at,
		Postings: []Posting{
			{account, cur, amount},
			{sys, cur, -amount},
		},
		Metadata: map[string]string{"reason": reason, "proposed_by": proposedBy, "approved_by": approvedBy},
	}, nil
}
