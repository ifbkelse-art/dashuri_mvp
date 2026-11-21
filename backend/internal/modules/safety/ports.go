package safety

import (
	"context"
	"errors"
	"time"

	"dashuri/backend/internal/modules/keyset"
)

// Sentinel errors returned by the Repository.
var (
	ErrNotFound      = errors.New("safety: not found")
	ErrNotAppealable = errors.New("safety: enforcement is not appealable")
	ErrAppealExists  = errors.New("safety: appeal already submitted")
)

// Cursor is the keyset position for newest-first lists.
type Cursor = keyset.Cursor

// CallInfo is what the report window check needs about a call.
type CallInfo struct {
	CallerID   string
	ReceiverID string
	Phase      string
	EndedAt    *time.Time
	CreatedAt  time.Time
}

// NewReport is a validated report to store.
type NewReport struct {
	ReporterID string
	TargetID   string
	Category   string
	CallID     *string
	Details    *string
	Priority   int
}

// Repository is the safety.* persistence port.
type Repository interface {
	UserExists(ctx context.Context, userID string) (bool, error)
	Call(ctx context.Context, callID string) (CallInfo, error)
	// CreateReport stores the report and an audit.events row atomically.
	CreateReport(ctx context.Context, r NewReport) (ReportReceipt, error)
	// Block is idempotent: an existing block is returned unchanged.
	Block(ctx context.Context, blockerID, blockedID string) (BlockedUser, error)
	Unblock(ctx context.Context, blockerID, blockedID string) error
	ListBlocks(ctx context.Context, blockerID string, after *Cursor, limit int) ([]BlockedUser, error)
	ListEnforcement(ctx context.Context, userID string, after *Cursor, limit int) ([]EnforcementNotice, error)
	// CreateAppeal: ErrNotFound (not the user's), ErrNotAppealable, ErrAppealExists.
	CreateAppeal(ctx context.Context, userID, enforcementID, statement string) (AppealReceipt, error)
}
