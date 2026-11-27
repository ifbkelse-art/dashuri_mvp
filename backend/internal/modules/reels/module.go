// Package reels is the EXPERIMENTAL Dashuri Reels module: short vertical
// videos, creator profiles, follows, likes, a ranked feed, a pre-publication
// moderation lifecycle and product analytics.
//
// It is self-contained: it reads identity, hosting and safety tables through
// its own repository port, never imports another module, and never touches
// calls, wallets or the ledger. Switching REELS_ENABLED off makes every
// endpoint return 503 reels_disabled while the rest of Dashuri is unchanged.
package reels

import (
	"crypto/rand"
	"fmt"
	"regexp"
	"time"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/clock"
)

// Product limits (PRD §4). Changing them is a config/code change only.
const (
	MinDurationMs       = 15000
	MaxDurationMs       = 60000
	DurationToleranceMs = 900 // encoders round; 14.1 s–60.9 s is accepted
	MaxCaptionRunes     = 300
	MaxBioRunes         = 300
	DailyUploadLimit    = 10
	PlaybackTTL         = 6 * time.Hour
	ReviewPlaybackTTL   = 15 * time.Minute
	PhotoTTL            = time.Hour
	FeedCandidateLimit  = 400
	FeedPageMax         = 20
	ReportHideThreshold = 3 // distinct reporters hide a video pending review
	EvidenceHold        = 90 * 24 * time.Hour
	AttributionWindow   = 30 // minutes from a reel CTA click to a call start
	ModerationGiveUp    = 30 * time.Minute
	ProcessingGiveUp    = 2 * time.Hour // transient processing errors, then failed
	// MaxProcessingAttempts also ends retries (whichever comes first).
	MaxProcessingAttempts = 6
	// UploadExpiry: an upload URL lives 1 h; a reel still waiting for its
	// file after this is failed as upload_expired.
	UploadExpiry = 3 * time.Hour
	// UploadExpiryUnconfirmed is used when the storage cannot be asked.
	UploadExpiryUnconfirmed = 24 * time.Hour
	// MinShortSidePx: below this the video is unwatchable full screen.
	MinShortSidePx = 240
	// ProcessingLease must exceed one reel's worst-case processing time
	// (ffmpeg timeouts) so a live worker never loses its claim.
	ProcessingLease = 20 * time.Minute
	// ProcessingDeadline bounds one reel's processing (all ffmpeg runs and
	// transfers); it must stay below ProcessingLease.
	ProcessingDeadline = 15 * time.Minute
)

// ProcessingBackoff is the wait before retrying after the n-th transient
// failure: 2, 4, 8, 16, 32 min, capped at 32.
func ProcessingBackoff(attempt int) time.Duration {
	d := 2 * time.Minute
	for i := 1; i < attempt && d < 32*time.Minute; i++ {
		d *= 2
	}
	return min(d, 32*time.Minute)
}

// Moderation thresholds on frame maxima (docs/reels/DASHURI_REELS_SAFETY_AND_MODERATION.md).
type Thresholds struct {
	RejectSexual  float64
	ReviewSexual  float64
	ReviewSuggest float64
	RejectOther   float64
	ReviewOther   float64
}

var DefaultThresholds = Thresholds{RejectSexual: 0.80, ReviewSexual: 0.20, ReviewSuggest: 0.50, RejectOther: 0.85, ReviewOther: 0.30}

// Deps are the module's ports. Repo is nil without a database; Provider and
// Classifier may be unconfigured (explicit 503 / fail-closed review).
type Deps struct {
	Enabled bool
	Repo    Repository
	// Provider receives new uploads (REELS_VIDEO_PROVIDER, default r2).
	Provider VideoProvider
	// Legacy providers still serve, moderate and purge reels stored with
	// them (reels.videos.provider) while uploads go to Provider. This is
	// how Mux stays available during the move to R2.
	Legacy        []VideoProvider
	Classifier    FrameClassifier
	Photos        PhotoSigner
	Clock         clock.Clock
	Thresholds    Thresholds
	FrameInterval time.Duration // seconds between moderation frames (default 2 s)
}

func validationError(errs map[string]string) error { return apperr.Validation(errs) }

func internal(err error) error { return apperr.Internal(err) }

var uuidRE = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

func isUUID(s string) bool { return uuidRE.MatchString(s) }

func newUUID() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:])
}

var langRE = regexp.MustCompile(`^[a-z]{2}$`)
