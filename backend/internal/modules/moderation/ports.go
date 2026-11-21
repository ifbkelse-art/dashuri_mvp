package moderation

import (
	"context"
	"errors"
	"time"
)

// NudityClassifier scores still frames. Vendor not chosen (Sightengine,
// Cloud Vision SafeSearch or an on-device model are candidates; prices
// UNVERIFIED). Founder model (S7): automated checks only during the first
// three minutes of each call; afterwards action is report-based.
// This architecture does NOT by itself establish legal or Play compliance.
type NudityClassifier interface {
	Score(ctx context.Context, frame []byte) (NudityScore, error)
}

type NudityScore struct {
	Vendor         string
	SexualActivity float64 // 0–1
	SexualDisplay  float64
	Erotica        float64
	VerySuggestive float64
	Suggestive     float64
}

// Explicit is the highest explicit-content probability.
func (s NudityScore) Explicit() float64 { return max(s.SexualActivity, s.SexualDisplay, s.Erotica) }

// Flagged reports explicit content at or above the threshold.
func (s NudityScore) Flagged(threshold float64) bool { return s.Explicit() >= threshold }

// DefaultFlagThreshold: sexual_activity, sexual_display or erotica ≥ 0.6.
const DefaultFlagThreshold = 0.6

// CallEnder ends a call for moderation (implemented by calls.Service; an
// interface keeps the modules free of import cycles).
type CallEnder interface {
	EndCallForModeration(ctx context.Context, callID string) error
}

// CallInfo is what moderation needs to know about a call.
type CallInfo struct {
	ID, CallerID, ReceiverID string
	Phase                    string
	ConnectedAt              *time.Time
	ModerationWindowEndsAt   *time.Time
	EndedAt                  *time.Time
}

// FrameCheck is a moderation.frame_checks row.
type FrameCheck struct {
	CallID, UserID string
	At             time.Time
	Score          NudityScore
	Flagged        bool
	Action         string // none | end_call | queue_review
}

// AutomatedCase opens a system-reported safety.reports row (source
// automated, no reporter) plus evidence metadata.
type AutomatedCase struct {
	CallID, TargetUserID string
	Category             string // nudity | other
	Reason               string // nudity_classifier | missing_frames
	Details              string
	Priority             int
	EvidenceRef          string
	RetainUntil          time.Time
}

// ReportDecision is a moderator decision on a report.
type ReportDecision struct {
	ReportID, ModeratorID, Action, Reason string
	At                                    time.Time
	// ModeratorIsAdmin allows enforcement against staff accounts.
	ModeratorIsAdmin bool
}

// AppealDecision is a moderator decision on an appeal.
type AppealDecision struct {
	AppealID, ModeratorID, Outcome, Reason string
	At                                     time.Time
}

// CallFrames is a call inside (or just after) its moderation window with the
// frame times received per participant.
type CallFrames struct {
	CallID, CallerID, ReceiverID string
	ConnectedAt, WindowEndsAt    time.Time
	EndedAt                      *time.Time
	Frames                       map[string][]time.Time
}

// Domain errors returned by Repository implementations.
var (
	ErrNotFound        = errors.New("moderation: not found")
	ErrAlreadyDecided  = errors.New("moderation: already decided")
	ErrSameReviewer    = errors.New("moderation: different reviewer required")
	ErrSelfDecision    = errors.New("moderation: cannot decide own case")
	ErrStaffTarget     = errors.New("moderation: only an admin may act against staff")
	ErrInvalidDecision = errors.New("moderation: invalid decision")
)

// Repository persists moderation.* and the enforcement side of safety.*.
type Repository interface {
	CallInfo(ctx context.Context, callID string) (CallInfo, error)
	RecordFrameCheck(ctx context.Context, f FrameCheck) (int64, error)
	OpenAutomatedCase(ctx context.Context, c AutomatedCase) (reportID string, created bool, err error)
	Queue(ctx context.Context, after *QueueCursor, limit int) ([]ModerationCase, []QueueCursor, error)
	DecideReport(ctx context.Context, d ReportDecision) (ModerationDecision, error)
	DecideAppeal(ctx context.Context, d AppealDecision) (ModerationDecision, error)
	FrameWindowCalls(ctx context.Context, now time.Time) ([]CallFrames, error)
	// LiveCallIDs lists the user's calls that are still live (enforcement ends them).
	LiveCallIDs(ctx context.Context, userID string) ([]string, error)
	// LastFrameAt is when the user last submitted a frame for the call.
	LastFrameAt(ctx context.Context, callID, userID string) (*time.Time, error)
}

// QueueCursor is the keyset position (priority asc, created_at asc, id asc).
type QueueCursor struct {
	Priority  int
	CreatedAt time.Time
	ID        string
}

// FrameSource supplies frames for a call's first three minutes. Which side
// captures frames is UNRESOLVED (server-side via the provider if supported;
// otherwise client capture with server-side checks that frames arrived).
type FrameSource interface {
	Frames(ctx context.Context, callID string, from, to time.Time) (<-chan Frame, error)
}

type Frame struct {
	CallID string
	UserID string
	At     time.Time
	JPEG   []byte // never persisted unless flagged as evidence
}

// EvidenceStore keeps flagged frames encrypted, access-logged, with
// retention set by legal advice. Child sexual abuse material must follow the
// mandatory reporting path, never ordinary moderation storage.
type EvidenceStore interface {
	Put(ctx context.Context, caseID string, kind string, data []byte) (ref string, err error)
}
