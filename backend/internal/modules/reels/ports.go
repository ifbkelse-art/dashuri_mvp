package reels

import (
	"context"
	"errors"
	"time"

	"dashuri/backend/internal/modules/reelsrank"
)

// ---------------------------------------------------------------- video provider

// VideoProvider hides the hosting vendor. The target is Cloudflare R2 plus
// our own ffmpeg processing (adapters/r2, adapters/ffmpeg; see
// docs/reels/DASHURI_REELS_R2_MIGRATION.md); Mux (adapters/mux) stays only
// for the transition. Secrets stay in the adapter; the app only ever
// receives a one-time upload URL and short-lived signed playback URLs.
type VideoProvider interface {
	Name() string
	// Configured is false without credentials; uploads then return 503
	// video_provider_not_configured (never a fake success).
	Configured() bool
	// CreateUpload opens a direct upload for one video. Passthrough is our
	// video id (echoed back in Mux webhooks; the object key for R2).
	CreateUpload(ctx context.Context, req UploadRequest) (UploadSession, error)
	UploadStatus(ctx context.Context, uploadID string) (UploadState, error)
	Asset(ctx context.Context, assetID string) (AssetInfo, error)
	// Playback signs HLS and poster URLs valid for ttl.
	Playback(playbackID string, ttl time.Duration) (Playback, error)
	// FrameURLs returns signed still-frame URLs every interval for moderation.
	FrameURLs(playbackID string, durationMs int, interval, ttl time.Duration) ([]string, error)
	DeleteAsset(ctx context.Context, assetID string) error
	// ParseWebhook verifies the signature over the raw body and decodes it.
	ParseWebhook(headers map[string]string, body []byte, now time.Time) (WebhookEvent, error)
}

// ErrProviderNotConfigured is returned by adapters without credentials.
var ErrProviderNotConfigured = errors.New("video provider not configured")

// ErrWebhookSignature means the webhook signature is missing, wrong or stale.
var ErrWebhookSignature = errors.New("webhook signature invalid")

// ErrProcessorUnavailable means this process cannot transcode (no ffmpeg:
// the API image). Reels wait for the media worker; they are never failed
// for it.
var ErrProcessorUnavailable = errors.New("media processor unavailable")

// ErrAssetNotFound means the provider has no such asset (already deleted).
var ErrAssetNotFound = errors.New("asset not found")

// UploadRequest describes the file the app is about to send. SizeBytes and
// ContentType are signed into the R2 upload URL, so the storage rejects a
// different (e.g. much larger) file; Mux ignores them.
type UploadRequest struct {
	Passthrough string
	SizeBytes   int64  // 0 = not declared
	ContentType string // "" = not declared
}

type UploadSession struct {
	UploadID string
	URL      string // PUT the file here (no auth header; the URL is the grant)
	// Headers the client must send unchanged with the PUT (signed for R2).
	Headers   map[string]string
	ExpiresAt time.Time
}

type UploadState struct {
	State   string // waiting | asset_created | errored | cancelled | timed_out
	AssetID string
}

type AssetInfo struct {
	ID          string
	State       string // preparing | ready | errored
	DurationMs  int
	AspectRatio string
	PlaybackID  string
	Passthrough string
	// Media facts recorded in reels.videos (filled by self-processing
	// providers; zero/empty for Mux).
	Width        int
	Height       int
	SizeBytes    int64 // playback file
	VideoKey     string
	ThumbnailKey string
}

// Playback formats.
const (
	FormatHLS = "hls"
	FormatMP4 = "mp4"
)

type Playback struct {
	URL          string // what the player opens
	Format       string // FormatHLS | FormatMP4
	ThumbnailURL string
	ExpiresAt    time.Time
}

// SelfProcessing is implemented by providers that only store files (R2):
// our own worker validates and transcodes the upload and extracts the
// thumbnail and moderation frames (job reels-process-media). Vendors that
// process themselves (Mux) don't implement it.
type SelfProcessing interface {
	// Process is idempotent: a finished asset returns its stored result.
	// Invalid media returns *MediaError (permanent); other errors are
	// transient and retried.
	Process(ctx context.Context, assetID string, limits MediaLimits) (AssetInfo, error)
}

// MediaLimits are the server-side rules Process enforces.
type MediaLimits struct {
	MaxBytes      int64
	MinDurationMs int
	MaxDurationMs int
	FrameInterval time.Duration
	// MinShortSide rejects tiny videos (pixels on the shorter side; 0 = off).
	MinShortSide int
}

// MediaError is a permanent rejection of an uploaded file. Code becomes the
// reel's rejection_code (file_too_large, invalid_media, no_video_stream,
// duration_out_of_range, unsupported_format, resolution_too_low,
// upload_missing).
type MediaError struct{ Code string }

func (e *MediaError) Error() string { return "media rejected: " + e.Code }

// WebhookEvent is the provider-neutral subset of a webhook.
type WebhookEvent struct {
	DeliveryID string // provider event id (dedupe)
	Type       string // upload_asset_created | asset_ready | asset_errored | upload_failed | ignored
	RawType    string
	UploadID   string
	Asset      AssetInfo
}

// ---------------------------------------------------------------- moderation classifier

// FrameScores are the classifier's probabilities for one frame (0..1).
type FrameScores struct {
	Sexual     float64 // max(sexual_activity, sexual_display, erotica)
	Suggestive float64 // very_suggestive
	Other      float64 // max of the other configured models (gore, offensive, …)
}

// FrameClassifier scores a still frame reachable at a (signed) URL.
// Nil when not configured: moderation then fails closed to human review.
type FrameClassifier interface {
	ClassifyURL(ctx context.Context, url string) (FrameScores, error)
}

// PhotoSigner signs profile-photo read URLs (Supabase Storage).
type PhotoSigner interface {
	SignRead(ctx context.Context, paths []string, ttl time.Duration) map[string]string
}

// ---------------------------------------------------------------- repository

// Viewer-independent creator facts joined from identity and hosting.
type CreatorRow struct {
	UserID       string
	DisplayName  string
	PhotoPath    *string
	Bio          *string
	IsHost       bool // hosting.hosts.state = approved
	KYCVerified  bool
	Availability string // online | busy | offline ("" when not a host)
	RatePerMin   int64
	FollowedByMe bool
}

type VideoRow struct {
	ID               string
	CreatorID        string
	Caption          string
	Language         *string
	DeclaredMs       int
	DurationMs       *int
	Status           string
	RejectionCode    *string
	Provider         string
	ProviderUploadID *string
	ProviderAssetID  *string
	PlaybackID       *string
	LikeCount        int
	ViewCount        int
	CompletedCount   int
	ShareCount       int
	LikedByMe        bool
	PublishedAt      *time.Time
	CreatedAt        time.Time
	UpdatedAt        time.Time
	Creator          CreatorRow
}

// ProcessingClaim is a reel leased to this worker for media processing.
type ProcessingClaim struct {
	Video     VideoRow
	Attempts  int       // including this one
	StartedAt time.Time // first claim
}

type NewVideo struct {
	ID          string
	CreatorID   string
	Caption     string
	Language    *string
	DeclaredMs  int
	Provider    string
	UploadID    string
	DailyLimit  int
	DayStartUTC time.Time
}

// ModerationOutcome is what the automated pipeline decided.
type ModerationOutcome struct {
	Decision     string // approve | reject | review
	ReasonCode   string
	Priority     int
	Scores       map[string]float64
	CaseSource   string // automated | provider_unavailable
	EvidenceHold *time.Time
}

type QueueItem struct {
	CaseID    string
	Source    string
	Priority  int
	Scores    map[string]float64
	CreatedAt time.Time
	Reports   int
	Video     VideoRow
	Appeal    *string
}

type CreatorCounts struct {
	Followers, Following, Reels int
}

type AnalyticsSummary struct {
	From, To             time.Time
	Published            int
	ActiveCreators       int
	Impressions          int
	PlaysStarted         int
	PlaysCompleted       int
	WatchMs              int64
	Likes                int
	Follows              int
	Shares               int
	Reports              int
	ProfileOpens         int
	CTAClicks            int
	AttributedCalls      int
	AttributedCompleted  int
	AttributedPaidSecs   int64
	AttributedDiamonds   int64
	AttributionWindowMin int
}

// Repository is the Postgres port for the reels schema. Implemented in
// internal/adapters/postgres/reels_repo.go.
type Repository interface {
	Creator(ctx context.Context, viewerID, creatorID string) (CreatorRow, error)
	CreatorCounts(ctx context.Context, creatorID string) (CreatorCounts, error)
	UpsertCreatorBio(ctx context.Context, userID string, bio *string) error
	ViewerLanguages(ctx context.Context, userID string) ([]string, error)
	AnalyticsConsent(ctx context.Context, userID string) (bool, error)
	Blocked(ctx context.Context, a, b string) (bool, error)

	CreateVideo(ctx context.Context, v NewVideo) error
	Video(ctx context.Context, viewerID, videoID string) (VideoRow, error)
	VideoByUpload(ctx context.Context, uploadID string) (VideoRow, error)
	VideoByAsset(ctx context.Context, assetID string) (VideoRow, error)
	MarkProcessing(ctx context.Context, videoID, assetID string) error
	MarkReady(ctx context.Context, videoID string, a AssetInfo, minMs, maxMs int) (string, error)
	MarkFailed(ctx context.Context, videoID, code string) error
	DeleteVideo(ctx context.Context, creatorID, videoID string, hold time.Time) error
	StaleVideos(ctx context.Context, status string, olderThan time.Time, limit int) ([]VideoRow, error)
	// ClaimProcessing atomically claims up to limit 'processing' reels of the
	// given providers that are not leased and are due, leases them until
	// now+lease and counts one attempt each. Concurrent callers never get the
	// same reel (FOR UPDATE SKIP LOCKED).
	ClaimProcessing(ctx context.Context, providers []string, now time.Time, lease time.Duration, limit int) ([]ProcessingClaim, error)
	// ReleaseProcessing drops the lease of a reel still 'processing' and
	// schedules its next attempt (nil = now). uncount undoes the attempt
	// (the work never ran, e.g. no ffmpeg on this instance).
	ReleaseProcessing(ctx context.Context, videoID string, nextAttempt *time.Time, uncount bool) error
	PurgeCandidates(ctx context.Context, now time.Time, limit int) ([]VideoRow, error)
	MarkPurged(ctx context.Context, videoID string) error
	CleanupDeletedAccounts(ctx context.Context, limit int) (int, error)
	HasApprovedReel(ctx context.Context, creatorID string) (bool, error)

	FeedCandidates(ctx context.Context, viewerID string, asOf time.Time, limit int) ([]reelsrank.Candidate, error)
	FollowingFeed(ctx context.Context, viewerID string, after *Keyset, limit int) ([]VideoRow, error)
	CreatorVideos(ctx context.Context, viewerID, creatorID string, includeUnpublished bool, after *Keyset, limit int) ([]VideoRow, error)
	VideosByIDs(ctx context.Context, viewerID string, ids []string) ([]VideoRow, error)

	Like(ctx context.Context, userID, videoID string) (int, error)
	Unlike(ctx context.Context, userID, videoID string) (int, error)
	Follow(ctx context.Context, followerID, creatorID string) error
	Unfollow(ctx context.Context, followerID, creatorID string) error
	CountShare(ctx context.Context, videoID string) error
	RecordView(ctx context.Context, viewerID, videoID string, day time.Time, watchedMs int, completed bool) error
	InsertEvents(ctx context.Context, userID string, evs []Event) error

	ApplyAutomated(ctx context.Context, videoID string, o ModerationOutcome) (string, error)
	Report(ctx context.Context, reporterID, videoID, category string, details *string, hideThreshold int) (bool, error)
	Appeal(ctx context.Context, creatorID, videoID, statement string) error
	Queue(ctx context.Context, after *Keyset, limit int) ([]QueueItem, error)
	Decide(ctx context.Context, moderatorID, videoID, decision, reasonCode string, note *string, now time.Time) (string, error)
	Analytics(ctx context.Context, from, to time.Time, windowMin int) (AnalyticsSummary, error)
	// RecordWebhook stores a delivery hash; false when already seen.
	RecordWebhook(ctx context.Context, provider, hash, eventType string) (bool, error)
}

// Keyset is a (time, id) position for newest-first lists.
type Keyset struct {
	At time.Time
	ID string
}

// Event is one client analytics event (validated).
type Event struct {
	Name      string
	VideoID   *string
	CreatorID *string
	ValueMs   *int
	SessionID *string
}

// Repository errors mapped to API errors by the service.
var (
	ErrNotFound         = errors.New("not found")
	ErrUploadLimit      = errors.New("daily upload limit")
	ErrNotOwner         = errors.New("not owner")
	ErrAlreadyReported  = errors.New("already reported")
	ErrAppealNotAllowed = errors.New("appeal not allowed")
	ErrAlreadyAppealed  = errors.New("already appealed")
	ErrIllegalDecision  = errors.New("illegal decision")
	ErrSelfFollow       = errors.New("self follow")
)
