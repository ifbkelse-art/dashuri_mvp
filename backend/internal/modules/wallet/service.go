package wallet

import (
	"context"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
)

// Service implements the wallet module's use cases. Every method is a
// scaffold that returns 501 until implemented; the documented steps are the
// required behaviour (see docs/architecture).
type Service struct {
	deps Deps
}

func NewService(d Deps) *Service { return &Service{deps: d} }

// GetWalletSummary: GET /v1/wallet — Balances from the ledger projection; available = purchased + promotional − reserved.
func (s *Service) GetWalletSummary(ctx context.Context, p auth.Principal) (WalletSummary, error) {
	return WalletSummary{}, apperr.NotImplemented("wallet.GetWalletSummary")
}

// ListWalletEntries: GET /v1/wallet/entries — Ledger history for this account.
func (s *Service) ListWalletEntries(ctx context.Context, p auth.Principal, page PageRequest) (Page[WalletEntry], error) {
	return Page[WalletEntry]{}, apperr.NotImplemented("wallet.ListWalletEntries")
}
