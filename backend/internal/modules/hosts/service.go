package hosts

import (
	"context"
	"errors"
	"time"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/clock"
)

// Service implements the hosts module's use cases.
type Service struct {
	deps Deps
}

func NewService(d Deps) *Service {
	if d.Clock == nil {
		d.Clock = clock.System{}
	}
	if d.KYC == nil {
		d.KYC = ManualKYC{}
	}
	return &Service{deps: d}
}

// IST is the calendar used for "today" figures and daily caps.
var IST = time.FixedZone("IST", 5*3600+1800)

// DayStartIST returns the start of t's IST calendar day.
func DayStartIST(t time.Time) time.Time {
	l := t.In(IST)
	return time.Date(l.Year(), l.Month(), l.Day(), 0, 0, 0, 0, IST)
}

// AgeOn returns the full years between dob and day.
func AgeOn(dob, day time.Time) int {
	years := day.Year() - dob.Year()
	if day.Month() < dob.Month() || (day.Month() == dob.Month() && day.Day() < dob.Day()) {
		years--
	}
	return years
}

func (s *Service) ready() error {
	if s.deps.Repo == nil {
		return apperr.Unavailable("database_unavailable", "database not configured")
	}
	return nil
}

func mapErr(err error) error {
	switch {
	case err == nil:
		return nil
	case errors.Is(err, ErrNotFound):
		return apperr.NotFound("host")
	case errors.Is(err, ErrAlreadyApplied):
		return apperr.BusinessRule("already_applied", "you have already applied to host")
	case errors.Is(err, ErrInCall):
		return apperr.BusinessRule("in_call", "finish your current call first")
	case errors.Is(err, ErrNoKycSession):
		return apperr.BusinessRule("kyc_not_started", "the host has not started verification")
	}
	if apperr.As(err) != nil {
		return err
	}
	return apperr.Internal(err)
}

func (s *Service) status(ctx context.Context, userID string) (HostStatus, error) {
	h, err := s.deps.Repo.Host(ctx, userID)
	if err != nil {
		return HostStatus{}, mapErr(err)
	}
	xp, err := s.deps.Repo.LifetimeXP(ctx, userID)
	if err != nil {
		return HostStatus{}, mapErr(err)
	}
	r := s.deps.Rules
	level := r.LevelForXP(xp)
	out := HostStatus{
		State: "not_applied", KycState: "not_started", RatePerMinute: r.MinRatePerMinute,
		MinRatePerMinute: r.MinRatePerMinute, MaxRatePerMinute: r.MaxRateForLevel(level), Level: level,
	}
	if !h.Exists {
		return out, nil
	}
	out.State, out.KycState, out.IsAvailable, out.FreeCallOptIn, out.RatePerMinute =
		h.State, h.KycState, h.IsAvailable, h.FreeCallOptIn, h.RatePerMinute
	today, err := s.deps.Repo.Today(ctx, userID, DayStartIST(s.deps.Clock.Now()))
	if err != nil {
		return HostStatus{}, mapErr(err)
	}
	out.TodayEarnedBeans, out.TodayCalls = today.EarnedBeans, today.Calls
	return out, nil
}

// GetHostStatus: GET /v1/host.
func (s *Service) GetHostStatus(ctx context.Context, p auth.Principal) (HostStatus, error) {
	if err := s.ready(); err != nil {
		return HostStatus{}, err
	}
	return s.status(ctx, p.UserID)
}

// ApplyAsHost: POST /v1/host/application. The host role is added only on KYC approval.
func (s *Service) ApplyAsHost(ctx context.Context, p auth.Principal) (HostStatus, error) {
	if err := s.ready(); err != nil {
		return HostStatus{}, err
	}
	if !p.AgeEligible {
		return HostStatus{}, apperr.BusinessRule("not_age_eligible", "hosts must be 18 or older")
	}
	if p.Restricted() {
		return HostStatus{}, apperr.BusinessRule("account_restricted", "this account cannot host")
	}
	if err := s.deps.Repo.Apply(ctx, p.UserID); err != nil {
		return HostStatus{}, mapErr(err)
	}
	return s.status(ctx, p.UserID)
}

// StartKyc: POST /v1/host/kyc/sessions (manual provider in the MVP).
func (s *Service) StartKyc(ctx context.Context, p auth.Principal) (KycSession, error) {
	if err := s.ready(); err != nil {
		return KycSession{}, err
	}
	h, err := s.deps.Repo.Host(ctx, p.UserID)
	if err != nil {
		return KycSession{}, mapErr(err)
	}
	if !h.Exists {
		return KycSession{}, apperr.BusinessRule("host_not_applied", "apply to host first")
	}
	if h.State == "approved" || h.KycState == "approved" {
		return KycSession{}, apperr.BusinessRule("kyc_already_approved", "verification is already complete")
	}
	if h.State == "suspended" {
		return KycSession{}, apperr.BusinessRule("account_restricted", "hosting is suspended")
	}
	sid, redirect, err := s.deps.KYC.StartSession(ctx, p.UserID)
	if err != nil {
		return KycSession{}, apperr.Unavailable("kyc_unavailable", "verification could not be started")
	}
	got, err := s.deps.Repo.StartKyc(ctx, p.UserID, sid, "manual")
	if err != nil {
		return KycSession{}, mapErr(err)
	}
	out := KycSession{SessionId: got}
	if redirect != "" && got == sid {
		out.RedirectUrl = &redirect
	}
	return out, nil
}

func (s *Service) approvedHost(ctx context.Context, p auth.Principal) error {
	if err := s.ready(); err != nil {
		return err
	}
	h, err := s.deps.Repo.Host(ctx, p.UserID)
	if err != nil {
		return mapErr(err)
	}
	if !h.Exists || h.State != "approved" {
		return apperr.BusinessRule("host_not_approved", "hosting is not approved yet")
	}
	return nil
}

// SetAvailability: PUT /v1/host/availability. Approved hosts only; refused while in a call.
func (s *Service) SetAvailability(ctx context.Context, p auth.Principal, in SetAvailabilityRequest) (HostStatus, error) {
	if err := s.approvedHost(ctx, p); err != nil {
		return HostStatus{}, err
	}
	if in.IsAvailable && p.Restricted() {
		return HostStatus{}, apperr.BusinessRule("account_restricted", "calls are restricted on this account")
	}
	if err := s.deps.Repo.SetAvailability(ctx, p.UserID, in.IsAvailable, s.deps.Clock.Now()); err != nil {
		return HostStatus{}, mapErr(err)
	}
	return s.status(ctx, p.UserID)
}

// SendHeartbeat: POST /v1/host/availability/heartbeat.
func (s *Service) SendHeartbeat(ctx context.Context, p auth.Principal) error {
	if err := s.ready(); err != nil {
		return err
	}
	return mapErr(s.deps.Repo.Heartbeat(ctx, p.UserID, s.deps.Clock.Now()))
}

// SetRate: PUT /v1/host/rate — within 500–10,000 and the level cap; applies to the next call.
func (s *Service) SetRate(ctx context.Context, p auth.Principal, in SetRateRequest) (HostStatus, error) {
	if err := s.approvedHost(ctx, p); err != nil {
		return HostStatus{}, err
	}
	xp, err := s.deps.Repo.LifetimeXP(ctx, p.UserID)
	if err != nil {
		return HostStatus{}, mapErr(err)
	}
	if err := s.deps.Rules.ValidateRate(in.RatePerMinute, s.deps.Rules.LevelForXP(xp)); err != nil {
		return HostStatus{}, apperr.BusinessRule("rate_outside_level_limits", "rate is outside your level's limits")
	}
	if err := s.deps.Repo.SetRate(ctx, p.UserID, in.RatePerMinute); err != nil {
		return HostStatus{}, mapErr(err)
	}
	return s.status(ctx, p.UserID)
}

// SetFreeCallOptIn: PUT /v1/host/free-call-opt-in.
func (s *Service) SetFreeCallOptIn(ctx context.Context, p auth.Principal, in SetFreeCallOptInRequest) (HostStatus, error) {
	if err := s.approvedHost(ctx, p); err != nil {
		return HostStatus{}, err
	}
	if err := s.deps.Repo.SetFreeCallOptIn(ctx, p.UserID, in.OptIn); err != nil {
		return HostStatus{}, mapErr(err)
	}
	return s.status(ctx, p.UserID)
}

// GetEarnings: GET /v1/host/earnings — Beans on hold, available and pending payout, plus today.
func (s *Service) GetEarnings(ctx context.Context, p auth.Principal) (HostEarnings, error) {
	if err := s.ready(); err != nil {
		return HostEarnings{}, err
	}
	b, err := s.deps.Repo.Balances(ctx, p.UserID)
	if err != nil {
		return HostEarnings{}, mapErr(err)
	}
	today, err := s.deps.Repo.Today(ctx, p.UserID, DayStartIST(s.deps.Clock.Now()))
	if err != nil {
		return HostEarnings{}, mapErr(err)
	}
	return HostEarnings{
		BeansOnHold: b.Held, BeansAvailable: b.Available, BeansPendingPayout: b.PayoutPending,
		AvailableInrPaise: s.deps.Rules.PaiseForBeans(b.Available),
		TodayEarnedBeans:  today.EarnedBeans, TodayCalls: today.Calls,
	}, nil
}

// DecideKyc: POST /v1/admin/hosts/{userId}/kyc-decision (moderator; audited).
// Approval requires a DOB of at least 18 years and sets the verified DOB,
// age_method = kyc_verified, host state approved and the host role.
func (s *Service) DecideKyc(ctx context.Context, p auth.Principal, hostID string, in KycDecisionRequest) (HostStatus, error) {
	if err := s.ready(); err != nil {
		return HostStatus{}, err
	}
	if !isUUID(hostID) {
		return HostStatus{}, apperr.NotFound("host")
	}
	if hostID == p.UserID {
		return HostStatus{}, apperr.Forbidden("self_review", "you cannot decide your own verification")
	}
	now := s.deps.Clock.Now()
	d := KycDecision{HostID: hostID, ModeratorID: p.UserID, Approve: in.Decision == "approve", Reason: in.Reason, At: now}
	if d.Approve {
		dob, _ := time.Parse("2006-01-02", in.DateOfBirth)
		if AgeOn(dob, now.In(IST)) < 18 {
			return HostStatus{}, apperr.BusinessRule("not_age_eligible", "hosts must be 18 or older")
		}
		d.DateOfBirth = dob
	}
	if err := s.deps.Repo.DecideKyc(ctx, d); err != nil {
		return HostStatus{}, mapErr(err)
	}
	return s.status(ctx, hostID)
}
