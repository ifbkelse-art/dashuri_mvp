package chat

import (
	"context"
	"errors"
	"log/slog"
	"time"

	"dashuri/backend/internal/modules/textfilter"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
)

// PhotoTTL is the lifetime of signed peer photo URLs.
const PhotoTTL = time.Hour

// Realtime events (hints only; clients re-fetch from the API).
const (
	// EventChatMessage goes to user:<recipient> after a message commits.
	EventChatMessage = "chat.message"
	// EventChatRead goes to user:<peer> when the reader's marker passed at
	// least one of the peer's messages (drives "Read" on sent messages).
	EventChatRead = "chat.read"
)

// Service implements chat (Go API + Supabase Realtime hints, F5).
type Service struct {
	deps Deps
}

func NewService(d Deps) *Service { return &Service{deps: d} }

func (s *Service) repo() (Repository, error) {
	if s.deps.Repo == nil {
		return nil, apperr.Unavailable("database_unavailable", "database not configured")
	}
	return s.deps.Repo, nil
}

func internal(err error) error {
	if apperr.As(err) != nil {
		return err
	}
	return apperr.Internal(err)
}

// ErrMessageRejected is the contact-details refusal (CH05).
func errMessageRejected() *apperr.Error {
	e := apperr.BusinessRule("message_rejected", "messages cannot contain phone numbers, UPI IDs, emails or links")
	e.Fields = map[string]string{"body": textfilter.ReasonContactDetails}
	return e
}

// canMessage applies the messaging rules from the sender to the peer:
// both 18+ and unrestricted, no block either way, and the peer's privacy.
func (s *Service) canMessage(ctx context.Context, repo Repository, p auth.Principal, peerID string) error {
	if peerID == p.UserID {
		return validationError(map[string]string{"peer_user_id": "self"})
	}
	if !p.AgeEligible {
		return apperr.BusinessRule("not_age_eligible", "complete the 18+ age check first")
	}
	if p.Restricted() {
		return apperr.BusinessRule("account_restricted", "this account cannot send messages")
	}
	peer, err := repo.Peer(ctx, peerID)
	if errors.Is(err, ErrNotFound) || (err == nil && peer.Status != "active" && peer.Status != "restricted") {
		return apperr.NotFound("user")
	}
	if err != nil {
		return internal(err)
	}
	blocked, err := repo.BlockedEither(ctx, p.UserID, peerID)
	if err != nil {
		return internal(err)
	}
	if blocked {
		return apperr.BusinessRule("blocked", "messaging is not possible with this user")
	}
	if !peer.AgeEligible || peer.Status != "active" {
		return apperr.BusinessRule("messaging_not_allowed", "this user cannot receive messages")
	}
	if peer.WhoCanMessage == "past_call_partners" {
		ok, err := repo.HadBilledCall(ctx, p.UserID, peerID)
		if err == nil && !ok {
			// The partner of the call in progress counts (in-call chat).
			ok, err = repo.InLiveCall(ctx, p.UserID, peerID)
		}
		if err != nil {
			return internal(err)
		}
		if !ok {
			return apperr.BusinessRule("messaging_not_allowed", "this user only accepts messages from past call partners")
		}
	}
	return nil
}

func (s *Service) toConversation(row ConversationRow, photos map[string]string) Conversation {
	c := Conversation{
		Id: row.ID, PeerUserId: row.PeerID, PeerDisplayName: row.PeerName,
		Peer:        Peer{UserId: row.PeerID, DisplayName: row.PeerName},
		LastMessage: row.LastMessage, UnreadCount: row.Unread, UpdatedAt: row.UpdatedAt,
	}
	if row.LastMessage != nil {
		pv := preview(row.LastMessage.Body)
		c.LastMessagePreview = &pv
	}
	if row.PeerPhoto != nil {
		if u, ok := photos[*row.PeerPhoto]; ok {
			c.Peer.PhotoUrl = &u
		}
	}
	return c
}

func (s *Service) signPhotos(ctx context.Context, rows []ConversationRow) map[string]string {
	if s.deps.Photos == nil {
		return nil
	}
	var paths []string
	for _, r := range rows {
		if r.PeerPhoto != nil {
			paths = append(paths, *r.PeerPhoto)
		}
	}
	if len(paths) == 0 {
		return nil
	}
	return s.deps.Photos.SignRead(ctx, paths, PhotoTTL)
}

// ListConversations: GET /v1/conversations — newest activity first.
func (s *Service) ListConversations(ctx context.Context, p auth.Principal, page PageRequest) (Page[Conversation], error) {
	after, err := DecodeCursor(page.Cursor)
	if err != nil {
		return Page[Conversation]{}, validationError(map[string]string{"cursor": "invalid"})
	}
	repo, err := s.repo()
	if err != nil {
		return Page[Conversation]{}, err
	}
	rows, err := repo.ListConversations(ctx, p.UserID, after, page.Limit+1)
	if err != nil {
		return Page[Conversation]{}, internal(err)
	}
	out := Page[Conversation]{Items: []Conversation{}}
	if len(rows) > page.Limit {
		rows = rows[:page.Limit]
		last := rows[len(rows)-1]
		next := Cursor{At: last.UpdatedAt, ID: last.ID}.Encode()
		out.NextCursor = &next
	}
	photos := s.signPhotos(ctx, rows)
	for _, r := range rows {
		out.Items = append(out.Items, s.toConversation(r, photos))
	}
	return out, nil
}

// StartConversation: POST /v1/conversations. Returns the pair's existing
// conversation if there is one.
func (s *Service) StartConversation(ctx context.Context, p auth.Principal, in StartConversationRequest) (Conversation, error) {
	if errs := in.validate(); len(errs) > 0 {
		return Conversation{}, validationError(errs)
	}
	repo, err := s.repo()
	if err != nil {
		return Conversation{}, err
	}
	if err := s.canMessage(ctx, repo, p, in.PeerUserId); err != nil {
		return Conversation{}, err
	}
	id, err := repo.EnsureConversation(ctx, p.UserID, in.PeerUserId)
	if err != nil {
		return Conversation{}, internal(err)
	}
	row, err := repo.Conversation(ctx, id, p.UserID)
	if err != nil {
		return Conversation{}, internal(err)
	}
	return s.toConversation(row, s.signPhotos(ctx, []ConversationRow{row})), nil
}

// ListMessages: GET /v1/conversations/{id}/messages — newest first.
//
// Without page.CallID this is normal Chat: the canonical history, minus the
// session messages of calls that are still live. With page.CallID it is the
// in-call session chat of that call only: no earlier chat history and no
// other call's messages. Only the call's two participants may read it.
func (s *Service) ListMessages(ctx context.Context, p auth.Principal, conversationId string, page PageRequest) (Page[ChatMessage], error) {
	if !isUUID(conversationId) {
		return Page[ChatMessage]{}, apperr.NotFound("conversation")
	}
	if page.CallID != nil {
		if !isUUID(*page.CallID) {
			return Page[ChatMessage]{}, validationError(map[string]string{"call_id": "invalid_uuid"})
		}
		if !s.deps.MessageContext {
			// Without the metadata columns a session cannot be told apart.
			return Page[ChatMessage]{}, apperr.Unavailable("in_call_chat_disabled", "in-call chat is not enabled")
		}
	}
	after, err := DecodeCursor(page.Cursor)
	if err != nil {
		return Page[ChatMessage]{}, validationError(map[string]string{"cursor": "invalid"})
	}
	repo, err := s.repo()
	if err != nil {
		return Page[ChatMessage]{}, err
	}
	peerID, err := repo.ConversationPeer(ctx, conversationId, p.UserID)
	if errors.Is(err, ErrNotFound) {
		return Page[ChatMessage]{}, apperr.NotFound("conversation")
	} else if err != nil {
		return Page[ChatMessage]{}, internal(err)
	}
	if page.CallID != nil {
		// The session belongs to exactly this pair's call.
		if err := repo.CallBetween(ctx, *page.CallID, p.UserID, peerID); errors.Is(err, ErrNotFound) {
			return Page[ChatMessage]{}, apperr.NotFound("call")
		} else if err != nil {
			return Page[ChatMessage]{}, internal(err)
		}
	}
	msgs, err := repo.ListMessages(ctx, conversationId, p.UserID, page.CallID, after, page.Limit+1)
	if err != nil {
		return Page[ChatMessage]{}, internal(err)
	}
	out := Page[ChatMessage]{Items: []ChatMessage{}}
	if len(msgs) > page.Limit {
		msgs = msgs[:page.Limit]
		last := msgs[len(msgs)-1]
		next := Cursor{At: last.SentAt, ID: last.Id}.Encode()
		out.NextCursor = &next
	}
	out.Items = append(out.Items, msgs...)
	return out, nil
}

// SendMessage: POST /v1/conversations/{id}/messages. Enforces blocks,
// eligibility, the receiver's privacy and the contact-detail filter, then
// publishes chat.message to the recipient after commit.
//
// Messages sent from the in-call panel (context "call") are the same kind
// of message in the same conversation; the call is only validated and
// recorded. Messaging never touches calls, billing or the ledger.
func (s *Service) SendMessage(ctx context.Context, p auth.Principal, conversationId string, in SendMessageRequest) (ChatMessage, error) {
	if !isUUID(conversationId) {
		return ChatMessage{}, apperr.NotFound("conversation")
	}
	in.normalize()
	if errs := in.validate(); len(errs) > 0 {
		return ChatMessage{}, validationError(errs)
	}
	repo, err := s.repo()
	if err != nil {
		return ChatMessage{}, err
	}
	peerID, err := repo.ConversationPeer(ctx, conversationId, p.UserID)
	if errors.Is(err, ErrNotFound) {
		return ChatMessage{}, apperr.NotFound("conversation")
	}
	if err != nil {
		return ChatMessage{}, internal(err)
	}
	if err := s.canMessage(ctx, repo, p, peerID); err != nil {
		return ChatMessage{}, err
	}
	if textfilter.ContainsContactDetails(in.Body) {
		return ChatMessage{}, errMessageRejected()
	}
	nm := NewMessage{ConversationID: conversationId, SenderID: p.UserID, Body: in.Body, Context: in.context()}
	if s.deps.MessageContext {
		if nm.Context == ContextCall {
			if err := repo.CallBetween(ctx, *in.CallId, p.UserID, peerID); errors.Is(err, ErrNotFound) {
				return ChatMessage{}, validationError(map[string]string{"call_id": "not_found"})
			} else if err != nil {
				return ChatMessage{}, internal(err)
			}
			nm.CallID = in.CallId
		}
		nm.ClientMessageID = in.ClientMessageId
	} else {
		// Metadata disabled (migration not applied): stored as a plain message.
		nm.Context = ContextChat
	}
	msg, inserted, err := repo.InsertMessage(ctx, nm)
	if err != nil {
		return ChatMessage{}, internal(err)
	}
	if !inserted {
		return msg, nil // duplicate of a stored message: already announced
	}
	// After commit: hints only; failures never undo the message.
	if s.deps.Realtime != nil {
		if err := s.deps.Realtime.Publish(ctx, "user:"+peerID, EventChatMessage, map[string]string{"conversation_id": conversationId}); err != nil {
			slog.WarnContext(ctx, "chat realtime publish failed", "err", err)
		}
	}
	// No push for in-call messages: the recipient is on the call screen and
	// gets the realtime hint there.
	if s.deps.Push != nil && msg.Context != ContextCall {
		s.deps.Push(ctx, peerID, conversationId)
	}
	return msg, nil
}

// CallEnded is called after a call reaches a terminal phase. Its session
// messages are already in the canonical conversation and become part of
// normal Chat because the call is no longer live, so there is nothing to
// move, copy or retry. This only tells both participants' open Chat
// screens to re-fetch. Safe to call any number of times.
func (s *Service) CallEnded(ctx context.Context, callID string) {
	if !s.deps.MessageContext || s.deps.Repo == nil || s.deps.Realtime == nil || !isUUID(callID) {
		return
	}
	convID, users, err := s.deps.Repo.CallSession(ctx, callID)
	if errors.Is(err, ErrNotFound) {
		return // nobody chatted during this call
	}
	if err != nil {
		slog.WarnContext(ctx, "chat call session lookup failed", "call_id", callID, "err", err)
		return
	}
	for _, u := range users {
		if err := s.deps.Realtime.Publish(ctx, "user:"+u, EventChatMessage, map[string]string{"conversation_id": convID}); err != nil {
			slog.WarnContext(ctx, "chat realtime publish failed", "err", err)
		}
	}
}

// MarkRead: POST /v1/conversations/{id}/read — read up to now.
func (s *Service) MarkRead(ctx context.Context, p auth.Principal, conversationId string) error {
	if !isUUID(conversationId) {
		return apperr.NotFound("conversation")
	}
	repo, err := s.repo()
	if err != nil {
		return err
	}
	peerID, err := repo.ConversationPeer(ctx, conversationId, p.UserID)
	if errors.Is(err, ErrNotFound) {
		return apperr.NotFound("conversation")
	} else if err != nil {
		return internal(err)
	}
	advanced, err := repo.MarkRead(ctx, conversationId, p.UserID)
	if err != nil {
		return internal(err)
	}
	// Only when something new was read, so two open screens cannot ping-pong.
	if advanced && s.deps.Realtime != nil {
		if err := s.deps.Realtime.Publish(ctx, "user:"+peerID, EventChatRead, map[string]string{"conversation_id": conversationId}); err != nil {
			slog.WarnContext(ctx, "chat realtime publish failed", "err", err)
		}
	}
	return nil
}

// GetMessagingPrivacy: GET /v1/me/messaging-privacy.
func (s *Service) GetMessagingPrivacy(ctx context.Context, p auth.Principal) (MessagingPrivacy, error) {
	repo, err := s.repo()
	if err != nil {
		return MessagingPrivacy{}, err
	}
	v, err := repo.WhoCanMessage(ctx, p.UserID)
	if err != nil {
		return MessagingPrivacy{}, internal(err)
	}
	return MessagingPrivacy{WhoCanMessage: v}, nil
}

// UpdateMessagingPrivacy: PUT /v1/me/messaging-privacy.
func (s *Service) UpdateMessagingPrivacy(ctx context.Context, p auth.Principal, in MessagingPrivacy) (MessagingPrivacy, error) {
	if errs := in.validate(); len(errs) > 0 {
		return MessagingPrivacy{}, validationError(errs)
	}
	repo, err := s.repo()
	if err != nil {
		return MessagingPrivacy{}, err
	}
	if err := repo.SetWhoCanMessage(ctx, p.UserID, in.WhoCanMessage); err != nil {
		return MessagingPrivacy{}, internal(err)
	}
	return in, nil
}
