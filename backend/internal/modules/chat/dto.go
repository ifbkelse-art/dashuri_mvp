package chat

import "time"

// Wire types for this module. Generated from the API registry; keep in sync
// with api/openapi/dashuri.v1.yaml (the contract).

type Conversation struct {
	Id                 string    `json:"id"`
	PeerUserId         string    `json:"peer_user_id"`
	PeerDisplayName    string    `json:"peer_display_name"`
	LastMessagePreview *string   `json:"last_message_preview,omitempty"`
	UnreadCount        int       `json:"unread_count"`
	UpdatedAt          time.Time `json:"updated_at"`
}

type StartConversationRequest struct {
	PeerUserId string `json:"peer_user_id"`
}

func (r StartConversationRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.PeerUserId == "" {
		errs["peer_user_id"] = "required"
	}
	if r.PeerUserId != "" && !isUUID(r.PeerUserId) {
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

type SendMessageRequest struct {
	Body string `json:"body"`
}

func (r SendMessageRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.Body == "" {
		errs["body"] = "required"
	}
	if len(r.Body) > 1000 {
		errs["body"] = "too_long"
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
	}
	if r.WhoCanMessage != "everyone" && r.WhoCanMessage != "past_call_partners" {
		errs["who_can_message"] = "invalid_value"
	}
	return errs
}
