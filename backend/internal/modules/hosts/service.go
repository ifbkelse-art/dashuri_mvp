package hosts

import (
	"context"
	"errors"
	"time"

	"dashuri/backend/internal/modules/economy"
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
	case errors.Is(err, ErrNoApplication):
		return apperr.BusinessRule("verification_not_applied", "the host has no verification application")
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
		MinRatePerMinute: r.MinRatePerMinute, MaxRatePerMinute: r.EligibleMaxRate(level, false), Level: level,
		LevelMaxRatePerMinute: r.LevelMaxRate(level), VerifiedRateThreshold: r.VerifiedRateThreshold,
		VerificationStatus: VerificationNotApplied,
	}
	if level < len(r.XPThresholds) {
		next := r.LevelMaxRate(level + 1)
		out.NextLevelMaxRatePerMinute = &next
	}
	if !h.Exists {
		return out, nil
	}
	verified := h.VerificationStatus == VerificationVerified
	out.State, out.KycState, out.IsAvailable, out.FreeCallOptIn = h.State, h.KycState, h.IsAvailable, h.FreeCallOptIn
	out.KycRejectionReason = h.KycRejectionReason
	if h.OnlineSessionID != nil && h.OnlineSince != nil && h.IsAvailable {
		out.OnlineSession = &OnlineSessionView{Id: *h.OnlineSessionID, StartedAt: *h.OnlineSince}
	}
	out.VerificationStatus, out.IsVerified, out.VerificationNote = h.VerificationStatus, verified, h.VerificationNote
	out.MaxRatePerMinute = r.EligibleMaxRate(level, verified)
	// The price customers pay on the next call: the stored rate, capped to
	// current eligibility (call creation persists the same cap).
	out.RatePerMinute = r.CapRate(h.RatePerMinute, level, verified)
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

// SetRate: PUT /v1/host/rate. The Go API is the authoritative validator:
// the host's level and Verified Host status are read under the host row lock
// in the same transaction as the write, never taken from the client. The new
// rate applies to the next call; live calls keep their snapshotted rate.
func (s *Service) SetRate(ctx context.Context, p auth.Principal, in SetRateRequest) (HostStatus, error) {
	if err := s.approvedHost(ctx, p); err != nil {
		return HostStatus{}, err
	}
	r := s.deps.Rules
	err := s.deps.Repo.UpdateRate(ctx, p.UserID, func(ps PricingState) (int64, error) {
		if !ps.Exists || ps.State != "approved" {
			return 0, apperr.BusinessRule("host_not_approved", "hosting is not approved yet")
		}
		return in.RatePerMinute, rateError(r.CheckRate(in.RatePerMinute, r.LevelForXP(ps.LifetimeXP), ps.Verified()))
	})
	if err != nil {
		return HostStatus{}, mapErr(err)
	}
	return s.status(ctx, p.UserID)
}

// rateError maps a pricing-rule failure to its API error.
func rateError(err error) error {
	switch {
	case err == nil:
		return nil
	case errors.Is(err, economy.ErrRateBelowMinimum):
		return apperr.BusinessRule("rate_below_minimum", "the minimum price is 500 Diamonds/minute")
	case errors.Is(err, economy.ErrRateRequiresVerification):
		return apperr.BusinessRule("verification_required_for_rate", "prices above 3,000 Diamonds/minute need an active Verified Host status")
	default:
		return apperr.BusinessRule("rate_outside_level_limits", "rate is outside your level's limits")
	}
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
