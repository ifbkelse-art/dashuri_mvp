package calls

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/clock"
)

// Service implements the calls module's use cases. The server is
// authoritative: billing starts, pauses and ends from provider webhooks,
// and settlement runs exactly once in one database transaction.
type Service struct {
	deps Deps
}

func NewService(d Deps) *Service {
	if d.Clock == nil {
		d.Clock = clock.System{}
	}
	if d.ProviderName == "" {
		d.ProviderName = "stream"
	}
	return &Service{deps: d}
}

func (s *Service) now() time.Time { return s.deps.Clock.Now().UTC() }

func (s *Service) ready() error {
	if s.deps.Repo == nil {
		return apperr.Unavailable("database_unavailable", "database not configured")
	}
	if s.deps.Video == nil {
		return apperr.Unavailable("video_not_configured", "video calls are not configured on this server")
	}
	return nil
}

func mapErr(err error) error {
	switch {
	case err == nil:
		return nil
	case errors.Is(err, ErrNotFound):
		return apperr.NotFound("call")
	case errors.Is(err, ErrCallerInCall):
		return apperr.BusinessRule("caller_in_call", "you are already in a call")
	case errors.Is(err, ErrHostBusy):
		return apperr.BusinessRule("host_busy", "the host is in another call")
	case errors.Is(err, ErrInsufficientBalance):
		return apperr.BusinessRule("insufficient_diamonds", "not enough Diamonds")
	case errors.Is(err, ErrIllegalTransition):
		return apperr.BusinessRule("illegal_call_transition", err.Error())
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

func ptr[T any](v T) *T { return &v }

// RequestCall: POST /v1/calls — customer calls a host at the host's current rate.
func (s *Service) RequestCall(ctx context.Context, p auth.Principal, in CallRequestBody) (CallSession, error) {
	if err := s.ready(); err != nil {
		return CallSession{}, err
	}
	if !p.AgeEligible {
		return CallSession{}, apperr.BusinessRule("not_age_eligible", "confirm you are 18 or older first")
	}
	if p.Restricted() {
		return CallSession{}, apperr.BusinessRule("account_restricted", "calls are restricted on this account")
	}
	if in.HostUserId == p.UserID {
		return CallSession{}, apperr.BusinessRule("self_call", "you cannot call yourself")
	}
	r := s.deps.Rules
	var call Call
	err := s.deps.Repo.InTx(ctx, func(tx Tx) error {
		h, err := tx.LockHost(in.HostUserId)
		if err != nil {
			return err
		}
		if !h.Exists || h.State != "approved" || h.AccountStatus != "active" || !h.AgeEligible || !h.Available {
			return apperr.BusinessRule("host_unavailable", "the host is not available")
		}
		if blocked, err := tx.Blocked(p.UserID, in.HostUserId); err != nil {
			return err
		} else if blocked {
			return apperr.BusinessRule("blocked", "you cannot call this user")
		}
		if busy, err := tx.InLiveCall(p.UserID); err != nil {
			return err
		} else if busy {
			return ErrCallerInCall
		}
		if busy, err := tx.InLiveCall(in.HostUserId); err != nil {
			return err
		} else if busy {
			return ErrHostBusy
		}
		promo, purchased, err := tx.LockDiamonds(p.UserID)
		if err != nil {
			return err
		}
		reserved, err := tx.ActiveReservationsTotal(p.UserID)
		if err != nil {
			return err
		}
		available := promo + purchased - reserved
		if !r.CanStartCall(available, h.RatePerMinute) {
			return ErrInsufficientBalance
		}
		amount := min(available, r.DiamondsForSeconds(h.RatePerMinute, ReservationWindow))
		id := newID()
		call = Call{
			ID: id, CallerID: p.UserID, ReceiverID: in.HostUserId, Phase: Ringing,
			RatePerMinute: h.RatePerMinute, ProviderCallID: id, RuleSetVersion: r.Version, CreatedAt: s.now(),
		}
		if err := tx.InsertCall(call); err != nil {
			return err
		}
		return tx.InsertReservation(p.UserID, id, amount)
	})
	if err != nil {
		return CallSession{}, mapErr(err)
	}
	if err := s.launch(ctx, call); err != nil {
		return CallSession{}, err
	}
	return s.session(ctx, call, p.UserID)
}

// LaunchCreatedCall creates the provider call for a call row inserted by
// another module (Free Call Card) and rings the host. On provider failure the
// call is failed and its card or reservation released.
func (s *Service) LaunchCreatedCall(ctx context.Context, callID string) error {
	if err := s.ready(); err != nil {
		return err
	}
	c, err := s.deps.Repo.GetCall(ctx, callID)
	if err != nil {
		return mapErr(err)
	}
	return s.launch(ctx, c)
}

func (s *Service) launch(ctx context.Context, c Call) error {
	if _, err := s.deps.Video.CreateCall(ctx, c.ID, c.CallerID, c.ReceiverID); err != nil {
		if _, _, terr := s.terminate(ctx, c.ID, Failed, "provider_error", false); terr != nil {
			slog.ErrorContext(ctx, "fail call after provider error", "err", terr)
		}
		if apperr.As(err) != nil {
			return err
		}
		slog.ErrorContext(ctx, "video provider create call", "err", err)
		return apperr.Unavailable("video_provider_error", "the video provider could not create the call")
	}
	s.publishCall(ctx, c)
	return nil
}

func (s *Service) participantCall(ctx context.Context, p auth.Principal, id string) (Call, error) {
	if err := s.ready(); err != nil {
		return Call{}, err
	}
	if !isUUID(id) {
		return Call{}, apperr.NotFound("call")
	}
	c, err := s.deps.Repo.GetCall(ctx, id)
	if err != nil {
		return Call{}, mapErr(err)
	}
	if !c.Participant(p.UserID) {
		return Call{}, apperr.NotFound("call")
	}
	return c, nil
}

// GetCall: GET /v1/calls/{callId} — call state for a participant.
func (s *Service) GetCall(ctx context.Context, p auth.Principal, callId string) (CallSession, error) {
	c, err := s.participantCall(ctx, p, callId)
	if err != nil {
		return CallSession{}, err
	}
	if c.Phase == Ringing && s.now().Sub(c.CreatedAt) > RingTimeout {
		if nc, _, err := s.terminate(ctx, c.ID, Missed, "missed", true, Ringing); err == nil {
			c = nc
		}
	}
	return s.session(ctx, c, p.UserID)
}

// AcceptCall: POST /v1/calls/{callId}/accept — the receiver accepts a ringing call.
func (s *Service) AcceptCall(ctx context.Context, p auth.Principal, callId string) (CallSession, error) {
	c, err := s.participantCall(ctx, p, callId)
	if err != nil {
		return CallSession{}, err
	}
	if c.ReceiverID != p.UserID {
		return CallSession{}, apperr.Forbidden("not_receiver", "only the receiver can accept")
	}
	switch c.Phase {
	case Accepted, Connecting, Active, Paused:
		return s.session(ctx, c, p.UserID) // idempotent
	case Ringing:
	default:
		return CallSession{}, apperr.BusinessRule("illegal_call_transition", fmt.Sprintf("call is %s", c.Phase))
	}
	now := s.now()
	if now.Sub(c.CreatedAt) > RingTimeout {
		_, _, _ = s.terminate(ctx, c.ID, Missed, "missed", true, Ringing)
		return CallSession{}, apperr.BusinessRule("call_expired", "the call is no longer ringing")
	}
	err = s.deps.Repo.InTx(ctx, func(tx Tx) error {
		lc, err := tx.LockCall(c.ID)
		if err != nil {
			return err
		}
		if err := Transition(lc.Phase, Accepted); err != nil {
			return err
		}
		ok, err := tx.UpdatePhase(c.ID, lc.Phase, Accepted, PhaseUpdate{AcceptedAt: &now})
		if err == nil && !ok {
			err = ErrIllegalTransition
		}
		c = lc
		c.Phase, c.AcceptedAt = Accepted, &now
		return err
	})
	if err != nil {
		return CallSession{}, mapErr(err)
	}
	s.publishCall(ctx, c)
	return s.session(ctx, c, p.UserID)
}

// DeclineCall: POST /v1/calls/{callId}/decline — the receiver declines; the reservation is released.
func (s *Service) DeclineCall(ctx context.Context, p auth.Principal, callId string) (CallSession, error) {
	c, err := s.participantCall(ctx, p, callId)
	if err != nil {
		return CallSession{}, err
	}
	if c.ReceiverID != p.UserID {
		return CallSession{}, apperr.Forbidden("not_receiver", "only the receiver can decline")
	}
	if c.Phase == Declined {
		return s.session(ctx, c, p.UserID)
	}
	nc, _, err := s.terminate(ctx, c.ID, Declined, "declined", true, Ringing)
	if err != nil {
		return CallSession{}, mapErr(err)
	}
	if nc.Phase != Declined {
		return CallSession{}, apperr.BusinessRule("illegal_call_transition", fmt.Sprintf("call is %s", nc.Phase))
	}
	return s.session(ctx, nc, p.UserID)
}

// EndCall: POST /v1/calls/{callId}/end — either participant ends; the server settles from its own metering.
func (s *Service) EndCall(ctx context.Context, p auth.Principal, callId string, in EndCallRequest) (CallSession, error) {
	c, err := s.participantCall(ctx, p, callId)
	if err != nil {
		return CallSession{}, err
	}
	to := Ended
	if c.Phase == Requested {
		to = Failed
	}
	nc, _, err := s.terminate(ctx, c.ID, to, in.Reason, true)
	if err != nil {
		return CallSession{}, mapErr(err)
	}
	return s.session(ctx, nc, p.UserID)
}

// EndCallForModeration ends a call after an automated nudity flag (S7).
func (s *Service) EndCallForModeration(ctx context.Context, callID string) error {
	if err := s.ready(); err != nil {
		return err
	}
	_, _, err := s.terminate(ctx, callID, Ended, "moderation", true)
	return mapErr(err)
}

// GetCallCredentials: POST /v1/calls/{callId}/credentials — short-lived provider token for this participant and call.
func (s *Service) GetCallCredentials(ctx context.Context, p auth.Principal, callId string) (CallCredentials, error) {
	c, err := s.participantCall(ctx, p, callId)
	if err != nil {
		return CallCredentials{}, err
	}
	switch c.Phase {
	case Accepted:
		var moved bool
		err := s.deps.Repo.InTx(ctx, func(tx Tx) error {
			lc, err := tx.LockCall(c.ID)
			if err != nil || lc.Phase != Accepted {
				return err
			}
			moved, err = tx.UpdatePhase(c.ID, Accepted, Connecting, PhaseUpdate{})
			return err
		})
		if err != nil {
			return CallCredentials{}, mapErr(err)
		}
		if moved {
			c.Phase = Connecting
			s.publishCall(ctx, c)
		}
	case Connecting, Active, Paused:
	default:
		return CallCredentials{}, apperr.BusinessRule("call_not_joinable", fmt.Sprintf("call is %s", c.Phase))
	}
	tok, exp, err := s.deps.Video.IssueToken(ctx, p.UserID, c.ProviderCallID, TokenTTL)
	if err != nil {
		if apperr.As(err) != nil {
			return CallCredentials{}, err
		}
		return CallCredentials{}, apperr.Internal(err)
	}
	return CallCredentials{
		Provider: s.deps.ProviderName, ProviderCallId: c.ProviderCallID, UserToken: tok, ExpiresAt: exp,
		APIKey: s.deps.APIKey, CallType: "default",
	}, nil
}

// VideoProviderWebhook: POST /v1/webhooks/video/{provider}.
//  1. Verify the provider signature over the raw body; dedupe by event id.
//  2. Append to calls.media_events; recompute the phase and push call.updated.
//  3. Extend the reservation while the balance allows; warn 30 s before
//     exhaustion; end the call at zero (and free calls at 60 s).
func (s *Service) VideoProviderWebhook(ctx context.Context, provider string, raw []byte, headers map[string]string) error {
	if provider != s.deps.ProviderName {
		return apperr.Validation(map[string]string{"provider": "unknown_provider"})
	}
	if err := s.ready(); err != nil {
		return err
	}
	events, err := s.deps.Video.VerifyWebhook(raw, headers)
	if err != nil {
		if apperr.As(err) != nil {
			return err
		}
		return &apperr.Error{Kind: apperr.KindUnauthenticated, Code: "invalid_signature", Detail: "webhook signature invalid"}
	}
	for _, e := range events {
		if !isUUID(e.ProviderCallID) {
			continue
		}
		c, err := s.deps.Repo.GetCall(ctx, e.ProviderCallID)
		if errors.Is(err, ErrNotFound) {
			continue
		}
		if err != nil {
			return mapErr(err)
		}
		if e.Kind != EventCallEnded && !c.Participant(e.UserID) {
			continue
		}
		inserted, err := s.deps.Repo.InsertMediaEvent(ctx, c.ID, e)
		if err != nil {
			return mapErr(err)
		}
		if !inserted || Terminal(c.Phase) {
			continue
		}
		if e.Kind == EventCallEnded {
			if _, _, err := s.terminate(ctx, c.ID, Ended, "provider_ended", false); err != nil {
				return mapErr(err)
			}
			continue
		}
		if err := s.evaluate(ctx, c.ID, s.now()); err != nil {
			return mapErr(err)
		}
	}
	return nil
}

// ListCallHistory: GET /v1/calls/history — own calls, newest first.
func (s *Service) ListCallHistory(ctx context.Context, p auth.Principal, page PageRequest) (Page[CallSession], error) {
	if err := s.ready(); err != nil {
		return Page[CallSession]{}, err
	}
	var beforeAt *time.Time
	beforeID := ""
	if page.Cursor != "" {
		at, id, err := decodeCursor(page.Cursor)
		if err != nil {
			return Page[CallSession]{}, apperr.Validation(map[string]string{"cursor": "invalid"})
		}
		beforeAt, beforeID = &at, id
	}
	rows, err := s.deps.Repo.History(ctx, p.UserID, beforeAt, beforeID, page.Limit+1)
	if err != nil {
		return Page[CallSession]{}, mapErr(err)
	}
	out := Page[CallSession]{Items: []CallSession{}}
	more := len(rows) > page.Limit
	if more {
		rows = rows[:page.Limit]
	}
	ids := make([]string, 0, len(rows))
	for _, c := range rows {
		ids = append(ids, peerOf(c, p.UserID))
	}
	peers, err := s.deps.Repo.Peers(ctx, ids)
	if err != nil {
		return Page[CallSession]{}, mapErr(err)
	}
	for _, c := range rows {
		out.Items = append(out.Items, toSession(c, p.UserID, peers))
	}
	if more {
		last := rows[len(rows)-1]
		cur := encodeCursor(last.CreatedAt, last.ID)
		out.NextCursor = &cur
	}
	return out, nil
}

func encodeCursor(at time.Time, id string) string {
	return base64.RawURLEncoding.EncodeToString([]byte(at.UTC().Format(time.RFC3339Nano) + "|" + id))
}

func decodeCursor(s string) (time.Time, string, error) {
	b, err := base64.RawURLEncoding.DecodeString(s)
	if err != nil {
		return time.Time{}, "", err
	}
	at, id, ok := strings.Cut(string(b), "|")
	if !ok || !isUUID(id) {
		return time.Time{}, "", errors.New("invalid cursor")
	}
	t, err := time.Parse(time.RFC3339Nano, at)
	return t, id, err
}

func peerOf(c Call, viewer string) string {
	if viewer == c.CallerID {
		return c.ReceiverID
	}
	return c.CallerID
}

func toSession(c Call, viewer string, peers map[string]Peer) CallSession {
	role := "caller"
	if viewer == c.ReceiverID {
		role = "receiver"
	}
	peerID := peerOf(c, viewer)
	out := CallSession{
		CallId: c.ID, Role: role, PeerUserId: peerID, Phase: string(c.Phase), RatePerMinute: c.RatePerMinute,
		IsFreeCall: c.IsFreeCall, EndReason: c.EndReason, StartedAt: c.ConnectedAt,
		ModerationWindowEndsAt: c.ModerationWindowEndsAt, CreatedAt: c.CreatedAt, EndedAt: c.EndedAt,
	}
	if c.BilledSeconds != nil {
		out.BilledSeconds = *c.BilledSeconds
	}
	if c.DiamondsCharged != nil {
		out.DiamondsCharged = *c.DiamondsCharged
	}
	if pr, ok := peers[peerID]; ok {
		out.Peer = &pr
	} else {
		out.Peer = &Peer{UserID: peerID}
	}
	return out
}

func (s *Service) session(ctx context.Context, c Call, viewer string) (CallSession, error) {
	peers, err := s.deps.Repo.Peers(ctx, []string{peerOf(c, viewer)})
	if err != nil {
		return CallSession{}, mapErr(err)
	}
	return toSession(c, viewer, peers), nil
}

// publishCall pushes call.updated to both users (each from their own
// perspective) and to call:<id> (caller perspective plus both user ids).
// Events are hints; failures are logged, never returned.
func (s *Service) publishCall(ctx context.Context, c Call) {
	if s.deps.Realtime == nil {
		return
	}
	peers, err := s.deps.Repo.Peers(ctx, []string{c.CallerID, c.ReceiverID})
	if err != nil {
		peers = map[string]Peer{}
	}
	caller := toSession(c, c.CallerID, peers)
	receiver := toSession(c, c.ReceiverID, peers)
	s.publish(ctx, "user:"+c.CallerID, "call.updated", caller)
	s.publish(ctx, "user:"+c.ReceiverID, "call.updated", receiver)
	s.publish(ctx, "call:"+c.ID, "call.updated", struct {
		CallSession
		CallerUserID   string `json:"caller_user_id"`
		ReceiverUserID string `json:"receiver_user_id"`
	}{caller, c.CallerID, c.ReceiverID})
}

func (s *Service) publish(ctx context.Context, channel, event string, payload any) {
	if s.deps.Realtime == nil {
		return
	}
	if err := s.deps.Realtime.Publish(ctx, channel, event, payload); err != nil {
		slog.WarnContext(ctx, "realtime publish", "event", event, "err", err)
	}
}
