// Package gifts implements customer-to-host virtual gifts during an active
// one-to-one video call (docs/gifts/VIRTUAL_GIFTS.md).
//
// The server is authoritative: the price comes from gifts.catalogue, the
// Diamond split and the host's Beans are computed here from the versioned
// economy rule set (the same conversion as calls; no gift commission), and
// one database transaction posts the ledger entry, records the immutable
// gift transaction and appends the gift's chat message. The client never
// sends an amount.
package gifts

import (
	"context"
	"errors"
	"time"
)

// Domain errors returned by Repository implementations.
var (
	ErrNotFound     = errors.New("gifts: not found")
	ErrInsufficient = errors.New("gifts: insufficient balance")
	ErrExists       = errors.New("gifts: already exists")
)

// Item is one catalogue row.
type Item struct {
	ID                  string
	Name                string
	Description         string
	Emoji               string
	IconAsset           string
	AnimationAsset      string
	AnimationDurationMs int
	SoundAsset          *string
	Tier                string
	SortOrder           int
	DiamondPrice        int64
	Active              bool
	AvailableFrom       *time.Time
	AvailableUntil      *time.Time
	EarningRule         string
	RetiredAt           *time.Time
	CreatedAt           time.Time
	UpdatedAt           time.Time
}

// SellableAt reports whether the gift may be sent at t.
func (i Item) SellableAt(t time.Time) bool {
	if !i.Active || i.RetiredAt != nil {
		return false
	}
	if i.AvailableFrom != nil && t.Before(*i.AvailableFrom) {
		return false
	}
	if i.AvailableUntil != nil && !t.Before(*i.AvailableUntil) {
		return false
	}
	return true
}

// Transaction is one gifts.transactions row (immutable).
type Transaction struct {
	ID               string
	SenderID         string
	RecipientID      string
	CallID           string
	GiftID           string
	GiftName         string
	Tier             string
	Emoji            string
	AnimationAsset   string
	DiamondPrice     int64
	FromPromotional  int64
	FromPurchased    int64
	HostBeans        int64
	RuleSetVersion   string
	LedgerEntryID    string
	ClientRequestID  string
	RequestHash      string
	RiskFlags        []string
	CreatedAt        time.Time
	SenderName       string // display names (joined; not stored)
	RecipientName    string
	ChatMessageID    *string
	AnimationDurMs   int // from the catalogue (current), for the event
	ConversationID   *string
	SenderRoleIsHost bool
}

// CallInfo is the call as read (share-locked) inside the send transaction.
type CallInfo struct {
	ID, CallerID, ReceiverID, Phase string
	IsFreeCall                      bool
}

// Party is what the rules need about the sender or the recipient.
type Party struct {
	Exists        bool
	Status        string // identity.accounts.status
	AgeEligible   bool
	DisplayName   string
	HostState     string // hosting.hosts.state ("" when never applied)
	AccountAgeDur time.Duration
}

// SendState is everything the send rules need, read inside ONE database
// transaction after the sender's Diamond balances are locked (so two
// requests from the same sender serialise and see each other's result).
type SendState struct {
	Existing  *Transaction // a gift already stored for (sender, client request id)
	Call      CallInfo     // zero when the call does not exist
	CallFound bool
	Gift      Item
	GiftFound bool
	Sender    Party
	Recipient Party
	Blocked   bool // a block either way
	// Diamond buckets (locked) and the Diamonds reserved for live calls.
	Promotional, Purchased, Reserved int64
	// Velocity and spend over recent windows (this sender).
	SentInCallLastMinute int
	SpentLast24h         int64
	PairSpentLast24h     int64 // this sender -> this recipient
}

// SendPlan is what the service decided: either replay Existing, or write
// the new gift. Built only by Service.decide.
type SendPlan struct {
	Replay      bool
	Transaction Transaction // to insert (ID, split, beans, snapshots)
	ChatBody    string
	XPDelta     int64
}

// SendRequest is the validated input to one send.
type SendRequest struct {
	SenderID        string
	CallID          string
	RecipientID     string
	GiftID          string
	ClientRequestID string
	RequestHash     string
	Now             time.Time
}

// PricePatch is an audited price change.
type PricePatch struct {
	GiftID   string
	NewPrice int64
	ActorID  string
	Reason   string
}

// Performance is one gift's sales over a window (admin).
type Performance struct {
	GiftID        string
	GiftName      string
	Count         int64
	Diamonds      int64
	HostBeans     int64
	UniqueSenders int64
	UniqueHosts   int64
}

// HostSummary is the host's gift totals.
type HostSummary struct {
	Count    int64
	Diamonds int64
	Beans    int64
}

// HistoryQuery pages a user's gift history (newest first).
type HistoryQuery struct {
	UserID   string // sender or recipient, per As
	As       string // "sender" | "recipient" | "any" (admin)
	CallID   string // optional filter
	Flagged  bool   // admin: only risk-flagged
	BeforeAt *time.Time
	BeforeID string
	Limit    int
}

// Repository persists gifts.* and runs the send transaction.
type Repository interface {
	Catalogue(ctx context.Context, includeInactive bool) ([]Item, error)
	Item(ctx context.Context, id string) (Item, error)
	// Send runs the whole send in ONE transaction: lock the sender's
	// Diamond buckets, read SendState, call decide, then (unless the plan
	// is a replay) post the ledger entry, insert the transaction, append
	// the chat message and grant XP. Any error rolls everything back.
	Send(ctx context.Context, req SendRequest, decide func(SendState) (SendPlan, error)) (tx Transaction, replayed bool, err error)
	// CallGifts lists a call's gifts in order (oldest first).
	CallGifts(ctx context.Context, callID string) ([]Transaction, error)
	// Call returns the two participants of a call.
	Call(ctx context.Context, callID string) (CallInfo, error)
	History(ctx context.Context, q HistoryQuery) ([]Transaction, error)
	HostSummary(ctx context.Context, hostID string, since *time.Time) (HostSummary, error)
	// Admin.
	CreateItem(ctx context.Context, it Item, actorID, reason string) error
	UpdateItem(ctx context.Context, it Item, actorID string) error
	ChangePrice(ctx context.Context, p PricePatch) (old int64, err error)
	PriceHistory(ctx context.Context, giftID string, limit int) ([]PriceChange, error)
	Performance(ctx context.Context, since time.Time) ([]Performance, error)
}

// PriceChange is one gifts.price_changes row.
type PriceChange struct {
	OldPrice  *int64
	NewPrice  int64
	ChangedBy string
	Reason    string
	ChangedAt time.Time
}

// Publisher pushes Realtime hints (`call:<id>`, `user:<id>`).
type Publisher interface {
	Publish(ctx context.Context, channel, event string, payload any) error
}
