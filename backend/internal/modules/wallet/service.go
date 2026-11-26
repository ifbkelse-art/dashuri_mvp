package wallet

import (
	"context"
	"errors"

	"dashuri/backend/internal/modules/ledger"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
)

// Service is the wallet read model over the ledger.
type Service struct {
	deps Deps
}

func NewService(d Deps) *Service { return &Service{deps: d} }

var errDB = apperr.Unavailable("database_unavailable", "database not configured")

// Summarize builds the summary: available = purchased + promotional − reserved (≥ 0).
func Summarize(b Balances) WalletSummary {
	k := b.ByKind
	s := WalletSummary{
		PurchasedDiamonds:   k[string(ledger.UserDiamondPurchased)],
		PromotionalDiamonds: k[string(ledger.UserDiamondPromotional)],
		ReservedDiamonds:    b.Reserved,
		BeansOnHold:         k[string(ledger.UserBeanHeld)],
		BeansAvailable:      k[string(ledger.UserBeanAvailable)],
		BeansPendingPayout:  k[string(ledger.UserBeanPayoutPending)],
	}
	s.AvailableDiamonds = max(s.PurchasedDiamonds+s.PromotionalDiamonds-s.ReservedDiamonds, 0)
	return s
}

// GetWalletSummary: GET /v1/wallet.
func (s *Service) GetWalletSummary(ctx context.Context, p auth.Principal) (WalletSummary, error) {
	if s.deps.Repo == nil {
		return WalletSummary{}, errDB
	}
	b, err := s.deps.Repo.Balances(ctx, p.UserID)
	if err != nil {
		return WalletSummary{}, apperr.Internal(err)
	}
	return Summarize(b), nil
}

// ListWalletEntries: GET /v1/wallet/entries — one item per journal entry and
// currency, newest first, with a signed amount and a readable description.
func (s *Service) ListWalletEntries(ctx context.Context, p auth.Principal, page PageRequest) (Page[WalletEntry], error) {
	if s.deps.Repo == nil {
		return Page[WalletEntry]{}, errDB
	}
	rows, next, err := s.deps.Repo.Entries(ctx, p.UserID, page.Cursor, page.Limit)
	if errors.Is(err, ErrBadCursor) {
		return Page[WalletEntry]{}, apperr.Validation(map[string]string{"cursor": "invalid"})
	}
	if err != nil {
		return Page[WalletEntry]{}, apperr.Internal(err)
	}
	out := Page[WalletEntry]{Items: make([]WalletEntry, 0, len(rows))}
	for _, r := range rows {
		out.Items = append(out.Items, ToEntry(r))
	}
	if next != "" {
		out.NextCursor = &next
	}
	return out, nil
}

// ToEntry maps a row. Moves between a user's own buckets (Bean release,
// withdrawal request, failed payout) net to zero; they are shown as the
// change in withdrawable Beans instead.
func ToEntry(r EntryRow) WalletEntry {
	amount := r.Net
	if amount == 0 {
		amount = r.Available
	}
	e := WalletEntry{Id: r.EntryID, Currency: r.Currency, Kind: r.EntryType, Amount: amount, CreatedAt: r.OccurredAt,
		Description: Describe(r.EntryType, r.Currency, amount)}
	if r.Reference != "" {
		ref := r.Reference
		e.Reference = &ref
	}
	return e
}

// Describe returns the human-readable line for a wallet entry.
func Describe(entryType, currency string, amount int64) string {
	switch ledger.EntryType(entryType) {
	case ledger.EntryPurchaseCredit:
		return "Diamonds purchased"
	case ledger.EntryPromoGrant:
		return "Bonus Diamonds"
	case ledger.EntryCallSettlement:
		if currency == string(ledger.Bean) {
			return "Call earnings (on hold for 7 days)"
		}
		return "Video call"
	case ledger.EntryGiftSend:
		if currency == string(ledger.Bean) {
			return "Gift received (on hold for 7 days)"
		}
		return "Gift sent"
	case ledger.EntryFreeCallCompensation:
		return "Free Call Card earnings (on hold for 7 days)"
	case ledger.EntryBeanRelease:
		return "Beans released from hold"
	case ledger.EntryWithdrawalRequested:
		return "Withdrawal requested"
	case ledger.EntryPayoutPaid:
		return "Withdrawal paid"
	case ledger.EntryPayoutFailed:
		return "Withdrawal failed, Beans returned"
	case ledger.EntryPurchaseReversal:
		return "Purchase refunded"
	case ledger.EntryBeanClawback:
		return "Earnings reversed"
	case ledger.EntryPromoExpiry:
		return "Bonus Diamonds expired"
	case ledger.EntryAdjustment:
		if amount < 0 {
			return "Balance correction (debit)"
		}
		return "Balance correction (credit)"
	}
	return "Wallet activity"
}
