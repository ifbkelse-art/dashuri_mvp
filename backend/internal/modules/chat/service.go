package chat

import (
	"context"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
)

// Service implements the chat module's use cases. Every method is a
// scaffold that returns 501 until implemented; the documented steps are the
// required behaviour (see docs/architecture).
type Service struct {
	deps Deps
}

func NewService(d Deps) *Service { return &Service{deps: d} }

// ListConversations: GET /v1/conversations — Conversations for the signed-in user.
func (s *Service) ListConversations(ctx context.Context, p auth.Principal, page PageRequest) (Page[Conversation], error) {
	return Page[Conversation]{}, apperr.NotImplemented("chat.ListConversations")
}

// StartConversation: POST /v1/conversations — Open a conversation, if the peer's messaging privacy allows it.
func (s *Service) StartConversation(ctx context.Context, p auth.Principal, in StartConversationRequest) (Conversation, error) {
	return Conversation{}, apperr.NotImplemented("chat.StartConversation")
}

// ListMessages: GET /v1/conversations/{conversationId}/messages — Messages, newest first.
func (s *Service) ListMessages(ctx context.Context, p auth.Principal, conversationId string, page PageRequest) (Page[ChatMessage], error) {
	return Page[ChatMessage]{}, apperr.NotImplemented("chat.ListMessages")
}

// SendMessage: POST /v1/conversations/{conversationId}/messages — Send a message (privacy, blocks, rate limits, contact-detail filtering enforced).
func (s *Service) SendMessage(ctx context.Context, p auth.Principal, conversationId string, in SendMessageRequest) (ChatMessage, error) {
	return ChatMessage{}, apperr.NotImplemented("chat.SendMessage")
}

// GetMessagingPrivacy: GET /v1/me/messaging-privacy — Who can message me (C11).
func (s *Service) GetMessagingPrivacy(ctx context.Context, p auth.Principal) (MessagingPrivacy, error) {
	return MessagingPrivacy{}, apperr.NotImplemented("chat.GetMessagingPrivacy")
}

// UpdateMessagingPrivacy: PUT /v1/me/messaging-privacy — Change who can message me.
func (s *Service) UpdateMessagingPrivacy(ctx context.Context, p auth.Principal, in MessagingPrivacy) (MessagingPrivacy, error) {
	return MessagingPrivacy{}, apperr.NotImplemented("chat.UpdateMessagingPrivacy")
}
