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
	ID        string
	PeerID    string
	PeerName  string
	PeerPhoto *string // storage path of the peer's first approved photo
	// PeerVerified: the peer is an ACTIVE Verified Host (badge only).
	PeerVerified bool
	LastMessage  *ChatMessage
	Unread       int
	UpdatedAt    time.Time
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
	// InLiveCall: the pair is in a call whose billing has started (active
	// or paused). In-call chat counts the current call partner as a call
	// partner for the "past_call_partners" privacy setting.
	InLiveCall(ctx context.Context, a, b string) (bool, error)
	// CallBetween reports whether callID is a call between a and b;
	// ErrNotFound otherwise.
	CallBetween(ctx context.Context, callID, a, b string) error
	// ListMessages is newest first; ReadByPeer is computed for viewerID.
	// With callID nil it is the normal Chat view: messages of a call
	// session whose call is still live are left out (they appear, in place,
	// once the call ends). With callID set it is that call's session only.
	ListMessages(ctx context.Context, conversationID, viewerID string, callID *string, after *Cursor, limit int) ([]ChatMessage, error)
	// CallSession returns the conversation holding callID's session
	// messages and the two participants; ErrNotFound when the call has no
	// session messages.
	CallSession(ctx context.Context, callID string) (conversationID string, participants [2]string, err error)
	// InsertMessage stores the message, bumps the conversation and marks it
	// read for the sender, in one transaction. With a ClientMessageID that
	// was already stored for this sender and conversation it returns the
	// stored message and inserted=false (no second row).
	InsertMessage(ctx context.Context, m NewMessage) (msg ChatMessage, inserted bool, err error)
	// MarkRead moves the user's read marker to now. advanced=true when it
	// passed at least one message from the peer (worth telling the peer).
	MarkRead(ctx context.Context, conversationID, userID string) (advanced bool, err error)
	WhoCanMessage(ctx context.Context, userID string) (string, error)
	SetWhoCanMessage(ctx context.Context, userID, value string) error
}

// NewMessage is a message to store.
type NewMessage struct {
	ConversationID  string
	SenderID        string
	Body            string
	Context         string  // ContextChat or ContextCall
	CallID          *string // only with ContextCall
	ClientMessageID *string
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
