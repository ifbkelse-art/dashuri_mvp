package calls

import (
	"context"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
)

// Service implements the calls module's use cases. Every method is a
// scaffold that returns 501 until implemented; the documented steps are the
// required behaviour (see docs/architecture).
type Service struct {
	deps Deps
}

func NewService(d Deps) *Service { return &Service{deps: d} }

// RequestCall: POST /v1/calls — Customer calls a host at the host's current rate.
//  1. Check caller and host eligibility, host available, no block either way, caller not already in a call (unique partial index on active calls per user).
//  2. Snapshot the host's rate on the call (rate cannot change mid-call).
//  3. In one transaction: lock the customer's Diamond balance rows (FOR UPDATE); check CanStartCall (60 s at the rate); create a reservation for the first billing window.
//  4. Create the call (phase ringing), the provider call, and publish call.updated to user:<host> (incoming call).
func (s *Service) RequestCall(ctx context.Context, p auth.Principal, in CallRequestBody) (CallSession, error) {
	return CallSession{}, apperr.NotImplemented("calls.RequestCall")
}

// GetCall: GET /v1/calls/{callId} — Call state for a participant.
func (s *Service) GetCall(ctx context.Context, p auth.Principal, callId string) (CallSession, error) {
	return CallSession{}, apperr.NotImplemented("calls.GetCall")
}

// AcceptCall: POST /v1/calls/{callId}/accept — Host accepts a ringing call.
func (s *Service) AcceptCall(ctx context.Context, p auth.Principal, callId string) (CallSession, error) {
	return CallSession{}, apperr.NotImplemented("calls.AcceptCall")
}

// DeclineCall: POST /v1/calls/{callId}/decline — Host declines; reservation released.
func (s *Service) DeclineCall(ctx context.Context, p auth.Principal, callId string) (CallSession, error) {
	return CallSession{}, apperr.NotImplemented("calls.DeclineCall")
}

// EndCall: POST /v1/calls/{callId}/end — Either participant ends the call; the server settles from its own metering.
//  1. Transition to ending with an optimistic phase check.
//  2. Compute billable seconds with calls.BillableSeconds from the provider-event timeline (never from the client).
//  3. Diamonds = DiamondsForSeconds(rate, billable), capped by the reservation; Beans = BeansForDiamonds(total) once.
//  4. Post ledger.CallSettlement (idempotency key call_settlement:<call_id>) and release the unused reservation in the same transaction.
//  5. Award XP for Beans earned; publish call.updated; request moderation evidence retention if a report was filed.
func (s *Service) EndCall(ctx context.Context, p auth.Principal, callId string, in EndCallRequest) (CallSession, error) {
	return CallSession{}, apperr.NotImplemented("calls.EndCall")
}

// GetCallCredentials: POST /v1/calls/{callId}/credentials — Short-lived video-provider token for this participant and call.
func (s *Service) GetCallCredentials(ctx context.Context, p auth.Principal, callId string) (CallCredentials, error) {
	return CallCredentials{}, apperr.NotImplemented("calls.GetCallCredentials")
}

// VideoProviderWebhook: POST /v1/webhooks/video/{provider} — Video provider server events (participant joined/left, tracks, call ended). Signature-verified; no user auth.
//  1. Verify the provider signature over the raw body; reject replays by event id (unique table).
//  2. Append to call_media_events; recompute phase (active/paused) and push call.updated.
//  3. Extend the reservation window while active and the balance allows; send call.low_balance 30 s before exhaustion; end the call at zero.
//  4. During the first 3 minutes, route frame-check jobs to the moderation module (S7).
func (s *Service) VideoProviderWebhook(ctx context.Context, provider string, raw []byte, headers map[string]string) error {
	return apperr.NotImplemented("calls.VideoProviderWebhook")
}
