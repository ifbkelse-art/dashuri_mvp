package gifts

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"time"

	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/modules/keyset"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/clock"
)

// Deps are the ports this module needs.
type Deps struct {
	Repo     Repository // nil without a database → 503
	Realtime Publisher  // optional (hints only)
	Rules    economy.Rules
	Limits   Limits
	Clock    clock.Clock
	// Enabled is GIFTS_ENABLED (default off). Customer and host endpoints
	// answer 503 gifts_disabled while off; admin catalogue tools still work.
	Enabled bool
	// BeanHold is how long gift Beans stay on hold (the economy's hold).
	BeanHold time.Duration
}

// Realtime events (hints; the API is the source of truth).
const (
	// EventGift goes to call:<id> after a gift commits.
	EventGift = "call.gift"
	// EventChatMessage mirrors chat.message so open chat panels show the
	// gift line at once (payload shape of chat.ChatMessageHint).
	EventChatMessage = "chat.message"
	// EventWalletUpdated goes to user:<id> of both participants: balances
	// changed, re-read GET /v1/wallet.
	EventWalletUpdated = "wallet.updated"
)

// Service implements gifting.
type Service struct {
	deps  Deps
	newID func() string
}

func NewService(d Deps) *Service {
	if d.Clock == nil {
		d.Clock = clock.System{}
	}
	if d.Limits == (Limits{}) {
		d.Limits = DefaultLimits()
	}
	if d.BeanHold == 0 {
		d.BeanHold = d.Rules.BeanHoldPeriod
	}
	return &Service{deps: d, newID: newUUID}
}

func newUUID() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:])
}

func (s *Service) now() time.Time { return s.deps.Clock.Now().UTC() }

func (s *Service) repo() (Repository, error) {
	if s.deps.Repo == nil {
		return nil, apperr.Unavailable("database_unavailable", "database not configured")
	}
	return s.deps.Repo, nil
}

// userRepo is repo() for customer/host endpoints (flag-gated).
func (s *Service) userRepo() (Repository, error) {
	if !s.deps.Enabled {
		return nil, apperr.Unavailable("gifts_disabled", "gifts are not available yet")
	}
	return s.repo()
}

func mapErr(err error) error {
	switch {
	case err == nil:
		return nil
	case errors.Is(err, ErrNotFound):
		return apperr.NotFound("gift")
	case errors.Is(err, ErrInsufficient):
		return apperr.BusinessRule("insufficient_diamonds", "not enough Diamonds for this gift")
	case errors.Is(err, ErrExists):
		return apperr.Conflict("gift_exists", "a gift with this id already exists")
	}
	if apperr.As(err) != nil {
		return err
	}
	return apperr.Internal(err)
}

func toGift(i Item) Gift {
	return Gift{
		Id: i.ID, Name: i.Name, Description: i.Description, Emoji: i.Emoji, IconAsset: i.IconAsset,
		AnimationAsset: i.AnimationAsset, AnimationDurationMs: i.AnimationDurationMs, SoundAsset: i.SoundAsset,
		Tier: i.Tier, SortOrder: i.SortOrder, DiamondPrice: i.DiamondPrice,
	}
}

func toEvent(t Transaction) GiftEvent {
	dur := t.AnimationDurMs
	if dur <= 0 {
		dur = 5000
	}
	return GiftEvent{
		GiftTransactionId: t.ID, GiftId: t.GiftID, GiftName: t.GiftName, Emoji: t.Emoji, Tier: t.Tier,
		DiamondValue: t.DiamondPrice,
		Sender:       GiftParty{UserId: t.SenderID, DisplayName: t.SenderName},
		Recipient:    GiftParty{UserId: t.RecipientID, DisplayName: t.RecipientName},
		CallId:       t.CallID, AnimationAsset: t.AnimationAsset, AnimationDurationMs: dur,
		ChatMessageId: t.ChatMessageID, SentAt: t.CreatedAt,
	}
}

// GetCatalogue: GET /v1/gifts/catalogue — gifts that can be sent now.
func (s *Service) GetCatalogue(ctx context.Context, _ auth.Principal) (Catalogue, error) {
	repo, err := s.userRepo()
	if err != nil {
		return Catalogue{}, err
	}
	items, err := repo.Catalogue(ctx, false)
	if err != nil {
		return Catalogue{}, mapErr(err)
	}
	now := s.now()
	out := Catalogue{Items: []Gift{}}
	for _, it := range items {
		if it.UpdatedAt.After(out.UpdatedAt) {
			out.UpdatedAt = it.UpdatedAt
		}
		if it.SellableAt(now) {
			out.Items = append(out.Items, toGift(it))
		}
	}
	return out, nil
}

// RequestHash binds an Idempotency-Key to one logical send.
func RequestHash(callID, giftID, recipientID string) string {
	sum := sha256.Sum256([]byte(strings.ToLower(callID) + "|" + giftID + "|" + strings.ToLower(recipientID)))
	return hex.EncodeToString(sum[:])
}

// isUUIDv4 checks the Idempotency-Key format the gift API requires.
func isUUIDv4(s string) bool {
	return isUUID(s) && s[14] == '4' && strings.ContainsRune("89abAB", rune(s[19]))
}

// SendGift: POST /v1/calls/{callId}/gifts. Exactly-once per (sender,
// Idempotency-Key): a retry with the same key and body returns the stored
// gift without charging again; the same key with a different gift,
// recipient or call is refused (422).
func (s *Service) SendGift(ctx context.Context, p auth.Principal, callID, idemKey string, in SendGiftRequest) (SendGiftResponse, error) {
	if errs := in.validate(); len(errs) > 0 {
		return SendGiftResponse{}, apperr.Validation(errs)
	}
	if !isUUIDv4(idemKey) {
		return SendGiftResponse{}, apperr.Validation(map[string]string{"Idempotency-Key": "must_be_uuid_v4"})
	}
	if !isUUID(callID) {
		return SendGiftResponse{}, apperr.NotFound("call")
	}
	repo, err := s.userRepo()
	if err != nil {
		return SendGiftResponse{}, err
	}
	// Cheap pre-checks; decide re-checks everything under lock.
	if !p.AgeEligible {
		return SendGiftResponse{}, apperr.BusinessRule("not_age_eligible", "confirm you are 18 or older first")
	}
	if p.Restricted() {
		return SendGiftResponse{}, apperr.BusinessRule("account_restricted", "gifts are not available on this account")
	}
	req := SendRequest{
		SenderID: p.UserID, CallID: strings.ToLower(callID), RecipientID: strings.ToLower(in.RecipientUserId),
		GiftID: in.GiftId, ClientRequestID: strings.ToLower(idemKey),
		RequestHash: RequestHash(callID, in.GiftId, in.RecipientUserId), Now: s.now(),
	}
	var available int64
	tx, replayed, err := repo.Send(ctx, req, func(st SendState) (SendPlan, error) {
		plan, err := decide(s.deps.Rules, s.deps.Limits, req, st, s.newID)
		if err == nil {
			available = st.Promotional + st.Purchased - st.Reserved
			if !plan.Replay {
				available -= plan.Transaction.DiamondPrice
			}
		}
		return plan, err
	})
	if err != nil {
		return SendGiftResponse{}, mapErr(err)
	}
	ev := toEvent(tx)
	if !replayed {
		s.announce(ctx, tx, ev)
	}
	return SendGiftResponse{Gift: ev, AvailableDiamonds: max(available, 0), Replayed: replayed}, nil
}

// announce publishes the committed gift (hints only; failures are logged).
// Both participants get call.gift on call:<id>; each gets chat.message on
// their own channel so an open in-call chat shows the gift line at once.
// Clients dedupe by gift_transaction_id / message id.
func (s *Service) announce(ctx context.Context, tx Transaction, ev GiftEvent) {
	if s.deps.Realtime == nil {
		return
	}
	if err := s.deps.Realtime.Publish(ctx, "call:"+tx.CallID, EventGift, ev); err != nil {
		slog.WarnContext(ctx, "gift realtime publish failed", "err", err)
	}
	// The sender's Diamonds and the host's held Beans changed.
	for _, u := range []string{tx.SenderID, tx.RecipientID} {
		if err := s.deps.Realtime.Publish(ctx, "user:"+u, EventWalletUpdated, map[string]any{"reason": "gift", "gift_transaction_id": tx.ID}); err != nil {
			slog.WarnContext(ctx, "gift wallet hint publish failed", "err", err)
		}
	}
	if tx.ChatMessageID == nil || tx.ConversationID == nil {
		return
	}
	msg := map[string]any{
		"id": *tx.ChatMessageID, "conversation_id": *tx.ConversationID, "sender_id": tx.SenderID,
		"body": ChatLine(tx.Emoji, tx.SenderName, tx.GiftName, tx.RecipientName), "sent_at": tx.CreatedAt,
		"context": "call", "read_by_peer": false, "kind": "gift",
		"gift": map[string]any{"gift_transaction_id": tx.ID, "gift_id": tx.GiftID, "gift_name": tx.GiftName,
			"emoji": tx.Emoji, "tier": tx.Tier, "diamond_value": tx.DiamondPrice},
	}
	hint := map[string]any{"conversation_id": *tx.ConversationID, "message": msg, "call_id": tx.CallID}
	for _, u := range []string{tx.RecipientID, tx.SenderID} {
		if err := s.deps.Realtime.Publish(ctx, "user:"+u, EventChatMessage, hint); err != nil {
			slog.WarnContext(ctx, "gift chat hint publish failed", "err", err)
		}
	}
}

// ListCallGifts: GET /v1/calls/{callId}/gifts — the canonical gift history
// of one call, oldest first, for its two participants (reconnect recovery).
func (s *Service) ListCallGifts(ctx context.Context, p auth.Principal, callID string) (Page[GiftEvent], error) {
	if !isUUID(callID) {
		return Page[GiftEvent]{}, apperr.NotFound("call")
	}
	repo, err := s.userRepo()
	if err != nil {
		return Page[GiftEvent]{}, err
	}
	c, err := repo.Call(ctx, callID)
	if errors.Is(err, ErrNotFound) || (err == nil && p.UserID != c.CallerID && p.UserID != c.ReceiverID) {
		return Page[GiftEvent]{}, apperr.NotFound("call")
	}
	if err != nil {
		return Page[GiftEvent]{}, mapErr(err)
	}
	rows, err := repo.CallGifts(ctx, callID)
	if err != nil {
		return Page[GiftEvent]{}, mapErr(err)
	}
	out := Page[GiftEvent]{Items: []GiftEvent{}}
	for _, t := range rows {
		out.Items = append(out.Items, toEvent(t))
	}
	return out, nil
}

// PageRequest is a parsed cursor page request.
type PageRequest struct {
	Cursor string
	Limit  int
}

func parsePage(r *http.Request) (PageRequest, error) {
	p := PageRequest{Cursor: r.URL.Query().Get("cursor"), Limit: 20}
	if v := r.URL.Query().Get("limit"); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n < 1 || n > 100 {
			return p, apperr.Validation(map[string]string{"limit": "must_be_1_to_100"})
		}
		p.Limit = n
	}
	return p, nil
}

func (s *Service) history(ctx context.Context, repo Repository, q HistoryQuery, page PageRequest) ([]Transaction, *string, error) {
	cur, err := keyset.Decode(page.Cursor)
	if err != nil {
		return nil, nil, apperr.Validation(map[string]string{"cursor": "invalid"})
	}
	if cur != nil {
		q.BeforeAt, q.BeforeID = &cur.At, cur.ID
	}
	q.Limit = page.Limit + 1
	rows, err := repo.History(ctx, q)
	if err != nil {
		return nil, nil, mapErr(err)
	}
	var next *string
	if len(rows) > page.Limit {
		rows = rows[:page.Limit]
		last := rows[len(rows)-1]
		n := keyset.Cursor{At: last.CreatedAt, ID: last.ID}.Encode()
		next = &n
	}
	return rows, next, nil
}

// ListSentGifts: GET /v1/me/gifts/sent — the customer's gifts, newest first.
func (s *Service) ListSentGifts(ctx context.Context, p auth.Principal, page PageRequest) (Page[SentGift], error) {
	repo, err := s.userRepo()
	if err != nil {
		return Page[SentGift]{}, err
	}
	rows, next, err := s.history(ctx, repo, HistoryQuery{UserID: p.UserID, As: "sender"}, page)
	if err != nil {
		return Page[SentGift]{}, err
	}
	out := Page[SentGift]{Items: []SentGift{}, NextCursor: next}
	for _, t := range rows {
		out.Items = append(out.Items, SentGift{GiftEvent: toEvent(t), DiamondCost: t.DiamondPrice})
	}
	return out, nil
}

func (s *Service) received(t Transaction, now time.Time) ReceivedGift {
	rel := t.CreatedAt.Add(s.deps.BeanHold)
	status := "on_hold"
	if !now.Before(rel) {
		status = "released"
	}
	return ReceivedGift{GiftEvent: toEvent(t), BeansEarned: t.HostBeans, SettlementStatus: status, ReleasesAt: rel}
}

// ListReceivedGifts: GET /v1/host/gifts — the host's gifts, newest first.
func (s *Service) ListReceivedGifts(ctx context.Context, p auth.Principal, page PageRequest) (Page[ReceivedGift], error) {
	repo, err := s.userRepo()
	if err != nil {
		return Page[ReceivedGift]{}, err
	}
	rows, next, err := s.history(ctx, repo, HistoryQuery{UserID: p.UserID, As: "recipient"}, page)
	if err != nil {
		return Page[ReceivedGift]{}, err
	}
	now := s.now()
	out := Page[ReceivedGift]{Items: []ReceivedGift{}, NextCursor: next}
	for _, t := range rows {
		out.Items = append(out.Items, s.received(t, now))
	}
	return out, nil
}

// IST is the calendar used for "today" figures.
var IST = time.FixedZone("IST", 5*3600+1800)

// GetReceivedSummary: GET /v1/host/gifts/summary.
func (s *Service) GetReceivedSummary(ctx context.Context, p auth.Principal) (ReceivedSummary, error) {
	repo, err := s.userRepo()
	if err != nil {
		return ReceivedSummary{}, err
	}
	all, err := repo.HostSummary(ctx, p.UserID, nil)
	if err != nil {
		return ReceivedSummary{}, mapErr(err)
	}
	l := s.now().In(IST)
	day := time.Date(l.Year(), l.Month(), l.Day(), 0, 0, 0, 0, IST)
	today, err := repo.HostSummary(ctx, p.UserID, &day)
	if err != nil {
		return ReceivedSummary{}, mapErr(err)
	}
	return ReceivedSummary{TotalGifts: all.Count, TotalDiamonds: all.Diamonds, TotalBeans: all.Beans,
		TodayGifts: today.Count, TodayBeans: today.Beans}, nil
}
