package chat

import (
	"strings"
	"time"
	"unicode"
	"unicode/utf8"
)

// Wire types. Keep in sync with api/openapi/dashuri.v1.yaml and
// docs/mvp/MVP_DECISIONS_AND_CONTRACT.md §2.6.

// Peer is the other participant of a conversation.
type Peer struct {
	UserId      string  `json:"user_id"`
	DisplayName string  `json:"display_name"`
	PhotoUrl    *string `json:"photo_url"`
	// IsVerified: the peer is an ACTIVE Verified Host.
	IsVerified bool `json:"is_verified"`
}

type Conversation struct {
	Id                 string       `json:"id"`
	PeerUserId         string       `json:"peer_user_id"`
	PeerDisplayName    string       `json:"peer_display_name"`
	Peer               Peer         `json:"peer"`
	LastMessage        *ChatMessage `json:"last_message"`
	LastMessagePreview *string      `json:"last_message_preview"`
	UnreadCount        int          `json:"unread_count"`
	UpdatedAt          time.Time    `json:"updated_at"`
}

type StartConversationRequest struct {
	PeerUserId string `json:"peer_user_id"`
}

func (r StartConversationRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.PeerUserId == "" {
		errs["peer_user_id"] = "required"
	} else if !isUUID(r.PeerUserId) {
		errs["peer_user_id"] = "invalid_uuid"
	}
	return errs
}

type ChatMessage struct {
	Id             string    `json:"id"`
	ConversationId string    `json:"conversation_id"`
	SenderId       string    `json:"sender_id"`
	Body           string    `json:"body"`
	SentAt         time.Time `json:"sent_at"`
	// Context is where the message was sent from: "chat" (inbox) or "call"
	// (the in-call panel). Metadata only; same conversation, same store.
	Context string `json:"context"`
	// ReadByPeer: for the viewer's own messages, the other participant has
	// read up to (or past) this message. Always false for received ones.
	ReadByPeer bool `json:"read_by_peer"`
	// Kind is "text" or "gift" (2026-11-26). A gift message is written by
	// the server when a gift commits (never by POST .../messages); Gift
	// carries its public details.
	Kind string           `json:"kind"`
	Gift *GiftMessageInfo `json:"gift,omitempty"`
}

// GiftMessageInfo is the public part of a gift shown in chat.
type GiftMessageInfo struct {
	GiftTransactionId string `json:"gift_transaction_id"`
	GiftId            string `json:"gift_id"`
	GiftName          string `json:"gift_name"`
	Emoji             string `json:"emoji"`
	Tier              string `json:"tier"`
	DiamondValue      int64  `json:"diamond_value"`
}

// ChatMessageHint is the chat.message realtime payload on user:<recipient>.
// Message is the new message (absent in hints that only announce a
// conversation); older clients read only conversation_id.
type ChatMessageHint struct {
	ConversationId string       `json:"conversation_id"`
	Message        *ChatMessage `json:"message,omitempty"`
	// CallId: the call an in-call message was sent during (sent only to the
	// other participant of that call), so clients keep each call's session
	// apart from the inbox exactly as the list endpoints do.
	CallId *string `json:"call_id,omitempty"`
}

// Message contexts.
const (
	ContextChat = "chat"
	ContextCall = "call"
)

// MaxMessageChars is the message length limit in characters (D-15).
const MaxMessageChars = 1000

type SendMessageRequest struct {
	Body string `json:"body"`
	// Optional (unified chat). Omitted = "chat". "call" requires CallId: a
	// call between the two participants.
	Context *string `json:"context,omitempty"`
	CallId  *string `json:"call_id,omitempty"`
	// ClientMessageId is the sender's id for this message (the client sends
	// its Idempotency-Key). A repeat returns the stored message.
	ClientMessageId *string `json:"client_message_id,omitempty"`
}

// normalize trims surrounding whitespace.
func (r *SendMessageRequest) normalize() { r.Body = strings.TrimSpace(r.Body) }

// context returns the effective message context.
func (r SendMessageRequest) context() string {
	if r.Context == nil {
		return ContextChat
	}
	return *r.Context
}

func (r SendMessageRequest) validate() map[string]string {
	errs := map[string]string{}
	switch {
	case r.Body == "":
		errs["body"] = "required"
	case !utf8.ValidString(r.Body):
		errs["body"] = "invalid_encoding"
	case utf8.RuneCountInString(r.Body) > MaxMessageChars:
		errs["body"] = "too_long"
	default:
		for _, c := range r.Body {
			if unicode.IsControl(c) && c != '\n' && c != '\r' && c != '\t' {
				errs["body"] = "invalid_characters"
				break
			}
		}
	}
	switch ctx := r.context(); {
	case ctx != ContextChat && ctx != ContextCall:
		errs["context"] = "invalid_value"
	case ctx == ContextCall && (r.CallId == nil || *r.CallId == ""):
		errs["call_id"] = "required"
	case r.CallId != nil && ctx != ContextCall:
		errs["call_id"] = "only_for_call_context"
	case r.CallId != nil && !isUUID(*r.CallId):
		errs["call_id"] = "invalid_uuid"
	}
	if r.ClientMessageId != nil && !isUUID(*r.ClientMessageId) {
		errs["client_message_id"] = "invalid_uuid"
	}
	return errs
}

type MessagingPrivacy struct {
	WhoCanMessage string `json:"who_can_message"`
}

func (r MessagingPrivacy) validate() map[string]string {
	errs := map[string]string{}
	if r.WhoCanMessage == "" {
		errs["who_can_message"] = "required"
	} else if r.WhoCanMessage != "everyone" && r.WhoCanMessage != "past_call_partners" {
		errs["who_can_message"] = "invalid_value"
	}
	return errs
}

// previewChars bounds last_message_preview.
const previewChars = 80

func preview(body string) string {
	if utf8.RuneCountInString(body) <= previewChars {
		return body
	}
	return string([]rune(body)[:previewChars]) + "…"
}
