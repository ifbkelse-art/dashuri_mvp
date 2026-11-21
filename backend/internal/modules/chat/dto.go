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
}

// MaxMessageChars is the message length limit in characters (D-15).
const MaxMessageChars = 1000

type SendMessageRequest struct {
	Body string `json:"body"`
}

// normalize trims surrounding whitespace.
func (r *SendMessageRequest) normalize() { r.Body = strings.TrimSpace(r.Body) }

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
