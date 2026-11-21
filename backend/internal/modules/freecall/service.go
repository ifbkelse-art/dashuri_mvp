package freecall

import (
	"context"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
)

// Service implements the freecall module's use cases. Every method is a
// scaffold that returns 501 until implemented; the documented steps are the
// required behaviour (see docs/architecture).
type Service struct {
	deps Deps
}

func NewService(d Deps) *Service { return &Service{deps: d} }

// GetFreeCallCard: GET /v1/free-call/card — Free Call Card status for this account/device.
func (s *Service) GetFreeCallCard(ctx context.Context, p auth.Principal) (FreeCallCard, error) {
	return FreeCallCard{}, apperr.NotImplemented("freecall.GetFreeCallCard")
}

// RequestFreeCall: POST /v1/free-call/requests — Use the card: random match with an opted-in available host (Android only).
//  1. Verify the Play Integrity token server-side; bind the card to phone number AND device (S4: one card per phone and device).
//  2. In one transaction: lock the user's free_call_cards row; refuse if used.
//  3. Pick a random available host with free_call_opt_in and fewer than 20 free calls today (FreeCallMaxPerHostPerDay); lock that host's daily counter row.
//  4. Create a call with is_free_call = true and a 60-second server cap; no Diamonds reserved.
//  5. Host compensation (₹10 = 2,000 Beans) is posted only when the server confirms an eligible free-call minute (ledger.FreeCallCompensation).
func (s *Service) RequestFreeCall(ctx context.Context, p auth.Principal, in FreeCallRequestBody) (FreeCallRequest, error) {
	return FreeCallRequest{}, apperr.NotImplemented("freecall.RequestFreeCall")
}

// GetFreeCallRequest: GET /v1/free-call/requests/{requestId} — Match status.
func (s *Service) GetFreeCallRequest(ctx context.Context, p auth.Principal, requestId string) (FreeCallRequest, error) {
	return FreeCallRequest{}, apperr.NotImplemented("freecall.GetFreeCallRequest")
}
