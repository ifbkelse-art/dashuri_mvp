package hosts

import (
	"context"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
)

// Service implements the hosts module's use cases. Every method is a
// scaffold that returns 501 until implemented; the documented steps are the
// required behaviour (see docs/architecture).
type Service struct {
	deps Deps
}

func NewService(d Deps) *Service { return &Service{deps: d} }

// GetHostStatus: GET /v1/host — Host state, KYC, availability, rate limits for the shared level.
func (s *Service) GetHostStatus(ctx context.Context, p auth.Principal) (HostStatus, error) {
	return HostStatus{}, apperr.NotImplemented("hosts.GetHostStatus")
}

// ApplyAsHost: POST /v1/host/application — Apply to become a host (women-first at launch, C17).
func (s *Service) ApplyAsHost(ctx context.Context, p auth.Principal) (HostStatus, error) {
	return HostStatus{}, apperr.NotImplemented("hosts.ApplyAsHost")
}

// StartKyc: POST /v1/host/kyc/sessions — Start identity verification with the KYC vendor (vendor not chosen).
func (s *Service) StartKyc(ctx context.Context, p auth.Principal) (KycSession, error) {
	return KycSession{}, apperr.NotImplemented("hosts.StartKyc")
}

// SetAvailability: PUT /v1/host/availability — Go online/offline. Requires approved host; refused while in a call.
func (s *Service) SetAvailability(ctx context.Context, p auth.Principal, in SetAvailabilityRequest) (HostStatus, error) {
	return HostStatus{}, apperr.NotImplemented("hosts.SetAvailability")
}

// SendHeartbeat: POST /v1/host/availability/heartbeat — Keeps an online host listed; missing heartbeats mark the host offline.
func (s *Service) SendHeartbeat(ctx context.Context, p auth.Principal) error {
	return apperr.NotImplemented("hosts.SendHeartbeat")
}

// SetRate: PUT /v1/host/rate — Set Diamonds/min within 500–10,000 and the level cap (S2). Applies to the next call.
func (s *Service) SetRate(ctx context.Context, p auth.Principal, in SetRateRequest) (HostStatus, error) {
	return HostStatus{}, apperr.NotImplemented("hosts.SetRate")
}

// SetFreeCallOptIn: PUT /v1/host/free-call-opt-in — Join or leave the Free Call pool (S4).
func (s *Service) SetFreeCallOptIn(ctx context.Context, p auth.Principal, in SetFreeCallOptInRequest) (HostStatus, error) {
	return HostStatus{}, apperr.NotImplemented("hosts.SetFreeCallOptIn")
}

// GetEarnings: GET /v1/host/earnings — Beans on hold, available and pending payout.
func (s *Service) GetEarnings(ctx context.Context, p auth.Principal) (HostEarnings, error) {
	return HostEarnings{}, apperr.NotImplemented("hosts.GetEarnings")
}
