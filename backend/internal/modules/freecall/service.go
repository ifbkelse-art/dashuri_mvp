package freecall

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"log/slog"
	"strings"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/clock"
)

// Service implements the Free Call Card (S4): one card per phone number and
// device, Android only, a random opted-in host, 60 s, ₹10 to the host.
type Service struct {
	deps Deps
}

func NewService(d Deps) *Service {
	if d.Clock == nil {
		d.Clock = clock.System{}
	}
	return &Service{deps: d}
}

// PlatformHeader names the client platform when the body has no platform.
const PlatformHeader = "X-Client-Platform"

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
		return apperr.NotFound("free call request")
	case errors.Is(err, ErrCardUsed):
		return apperr.BusinessRule("card_already_used", "the Free Call Card has already been used")
	case errors.Is(err, ErrDeviceUsed):
		return apperr.BusinessRule("device_already_used", "a Free Call Card was already used on this device")
	case errors.Is(err, ErrCallerInCall):
		return apperr.BusinessRule("caller_in_call", "you are already in a call")
	case errors.Is(err, ErrIntegrityFailed):
		return apperr.BusinessRule("integrity_check_failed", "this device could not be verified")
	}
	if apperr.As(err) != nil {
		return err
	}
	return apperr.Internal(err)
}

func newID() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:])
}

// DeviceHash is the stored device binding (SHA-256 of the attested value).
func DeviceHash(binding string) string {
	sum := sha256.Sum256([]byte("device:" + binding))
	return hex.EncodeToString(sum[:])
}

func normPlatform(p string) string { return strings.ToLower(strings.TrimSpace(p)) }

// GetFreeCallCard: GET /v1/free-call/card — card status for this account and platform.
func (s *Service) GetFreeCallCard(ctx context.Context, p auth.Principal, platform string) (FreeCallCard, error) {
	if err := s.ready(); err != nil {
		return FreeCallCard{}, err
	}
	if normPlatform(platform) == "ios" {
		return FreeCallCard{Status: "unavailable_on_platform"}, nil
	}
	if !s.deps.Enabled || !p.AgeEligible || p.Restricted() {
		return FreeCallCard{Status: "not_eligible"}, nil
	}
	c, err := s.deps.Repo.Card(ctx, p.UserID)
	if err != nil {
		return FreeCallCard{}, mapErr(err)
	}
	if c.Exists {
		switch c.Status {
		case "used":
			return FreeCallCard{Status: "used", UsedAt: c.UsedAt}, nil
		case "revoked":
			return FreeCallCard{Status: "not_eligible"}, nil
		}
		return FreeCallCard{Status: "available"}, nil
	}
	hash, err := s.deps.Repo.PhoneHash(ctx, p.UserID)
	if err != nil {
		return FreeCallCard{}, mapErr(err)
	}
	if hash == "" {
		return FreeCallCard{Status: "not_eligible"}, nil
	}
	used, err := s.deps.Repo.PhoneUsedByOther(ctx, p.UserID, hash)
	if err != nil {
		return FreeCallCard{}, mapErr(err)
	}
	if used {
		return FreeCallCard{Status: "not_eligible"}, nil
	}
	return FreeCallCard{Status: "available"}, nil
}

// RequestFreeCall: POST /v1/free-call/requests — use the card.
func (s *Service) RequestFreeCall(ctx context.Context, p auth.Principal, in FreeCallRequestBody, platformHeader string) (FreeCallRequest, error) {
	if err := s.ready(); err != nil {
		return FreeCallRequest{}, err
	}
	if !s.deps.Enabled {
		return FreeCallRequest{}, apperr.Unavailable("free_call_disabled", "the Free Call Card is not available right now")
	}
	platform := normPlatform(platformHeader)
	if in.Platform != nil {
		platform = normPlatform(*in.Platform)
	}
	token := ""
	if in.PlayIntegrityToken != nil {
		token = strings.TrimSpace(*in.PlayIntegrityToken)
	}
	if platform == "ios" || (token == "" && platform != "android") {
		return FreeCallRequest{}, apperr.BusinessRule("free_call_unavailable_on_platform", "the Free Call Card is available on Android only")
	}
	if token == "" {
		return FreeCallRequest{}, apperr.BusinessRule("integrity_check_failed", "a Play Integrity token is required")
	}
	if !p.AgeEligible {
		return FreeCallRequest{}, apperr.BusinessRule("not_age_eligible", "confirm you are 18 or older first")
	}
	if p.Restricted() {
		return FreeCallRequest{}, apperr.BusinessRule("account_restricted", "calls are restricted on this account")
	}
	if s.deps.Integrity == nil {
		return FreeCallRequest{}, apperr.Unavailable("integrity_not_configured", "device verification is not configured on this server")
	}
	if s.deps.Calls == nil {
		return FreeCallRequest{}, apperr.Unavailable("video_not_configured", "video calls are not configured on this server")
	}
	phone, err := s.deps.Repo.PhoneHash(ctx, p.UserID)
	if err != nil {
		return FreeCallRequest{}, mapErr(err)
	}
	if phone == "" {
		return FreeCallRequest{}, apperr.BusinessRule("phone_required", "a verified phone number is required")
	}
	verdict, err := s.deps.Integrity.Verify(ctx, token)
	if err != nil {
		if errors.Is(err, ErrIntegrityFailed) || apperr.As(err) != nil {
			return FreeCallRequest{}, mapErr(err)
		}
		slog.WarnContext(ctx, "play integrity", "err", err)
		return FreeCallRequest{}, apperr.Unavailable("integrity_unavailable", "device verification is temporarily unavailable")
	}
	if verdict.DeviceBinding == "" {
		return FreeCallRequest{}, mapErr(ErrIntegrityFailed)
	}
	r := s.deps.Rules
	req, err := s.deps.Repo.Match(ctx, MatchParams{
		UserID: p.UserID, PhoneHash: phone, DeviceHash: DeviceHash(verdict.DeviceBinding),
		CallID: newID(), RuleSetVersion: r.Version, MaxPerHostPerDay: r.FreeCallMaxPerHostPerDay, Now: s.deps.Clock.Now(),
	})
	if err != nil {
		return FreeCallRequest{}, mapErr(err)
	}
	if req.Status == "matched" && req.CallID != nil {
		if err := s.deps.Calls.LaunchCreatedCall(ctx, *req.CallID); err != nil {
			return FreeCallRequest{}, err
		}
	}
	return FreeCallRequest{RequestId: req.ID, Status: req.Status, CallId: req.CallID}, nil
}

// GetFreeCallRequest: GET /v1/free-call/requests/{requestId} — match status (own requests only).
func (s *Service) GetFreeCallRequest(ctx context.Context, p auth.Principal, requestId string) (FreeCallRequest, error) {
	if err := s.ready(); err != nil {
		return FreeCallRequest{}, err
	}
	if !isUUID(requestId) {
		return FreeCallRequest{}, apperr.NotFound("free call request")
	}
	r, err := s.deps.Repo.Request(ctx, requestId)
	if err != nil {
		return FreeCallRequest{}, mapErr(err)
	}
	if r.UserID != p.UserID {
		return FreeCallRequest{}, apperr.NotFound("free call request")
	}
	return FreeCallRequest{RequestId: r.ID, Status: r.Status, CallId: r.CallID}, nil
}
