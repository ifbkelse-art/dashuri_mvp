package chat

import (
	"context"
	"errors"
	"time"
)

// ErrNotFound: missing user or conversation (or not a participant).
var ErrNotFound = errors.New("chat: not found")

// PeerAccount is what the messaging rules need about the other user.
type PeerAccount struct {
	UserID        string
	Status        string
	AgeEligible   bool
	WhoCanMessage string
}

// ConversationRow is a conversation as seen by one participant.
type ConversationRow struct {
	ID          string
	PeerID      string
	PeerName    string
	PeerPhoto   *string // storage path of the peer's first approved photo
	LastMessage *ChatMessage
	Unread      int
	UpdatedAt   time.Time
}

// Repository is the chat.* persistence port.
type Repository interface {
	Peer(ctx context.Context, userID string) (PeerAccount, error)
	BlockedEither(ctx context.Context, a, b string) (bool, error)
	// HadBilledCall: the pair had an ended call with billed_seconds > 0.
	HadBilledCall(ctx context.Context, a, b string) (bool, error)
	// EnsureConversation returns the pair's conversation, creating it once.
	EnsureConversation(ctx context.Context, a, b string) (string, error)
	// ConversationPeer returns the other participant; ErrNotFound if the
	// user is not a participant.
	ConversationPeer(ctx context.Context, conversationID, userID string) (string, error)
	Conversation(ctx context.Context, conversationID, userID string) (ConversationRow, error)
	// ListConversations excludes conversations with a block either way.
	ListConversations(ctx context.Context, userID string, after *Cursor, limit int) ([]ConversationRow, error)
	ListMessages(ctx context.Context, conversationID string, after *Cursor, limit int) ([]ChatMessage, error)
	// InsertMessage stores the message, bumps the conversation and marks it
	// read for the sender, in one transaction.
	InsertMessage(ctx context.Context, conversationID, senderID, body string) (ChatMessage, error)
	MarkRead(ctx context.Context, conversationID, userID string) error
	WhoCanMessage(ctx context.Context, userID string) (string, error)
	SetWhoCanMessage(ctx context.Context, userID, value string) error
}

// Publisher pushes Realtime hints (wiring.Publisher).
type Publisher interface {
	Publish(ctx context.Context, channel, event string, payload any) error
}

// PhotoSigner signs read URLs for the private profile-photos bucket.
type PhotoSigner interface {
	SignRead(ctx context.Context, paths []string, ttl time.Duration) map[string]string
}

// MessagePusher sends a push notification for a new message (optional).
type MessagePusher func(ctx context.Context, recipientID, conversationID string)
