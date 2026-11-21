package moderation

import (
	"context"
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
	Nudity    float64 // 0–1
	Sexual    float64
	MinorRisk float64 // if the vendor offers it
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
