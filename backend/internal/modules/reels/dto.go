package reels

import (
	"strings"
	"time"
	"unicode/utf8"
)

// ---------------------------------------------------------------- responses

type HostInfo struct {
	Availability  string `json:"availability"` // online | busy | offline
	RatePerMinute int64  `json:"rate_per_minute"`
	IsVerified    bool   `json:"is_verified"`
}

type CreatorSummary struct {
	UserId       string    `json:"user_id"`
	DisplayName  string    `json:"display_name"`
	PhotoUrl     *string   `json:"photo_url"`
	FollowedByMe bool      `json:"followed_by_me"`
	Host         *HostInfo `json:"host"` // null unless an approved host (paid calls)
}

type PlaybackInfo struct {
	HlsUrl       string    `json:"hls_url"`
	ThumbnailUrl string    `json:"thumbnail_url"`
	ExpiresAt    time.Time `json:"expires_at"`
}

type Reel struct {
	Id            string         `json:"id"`
	Creator       CreatorSummary `json:"creator"`
	Caption       string         `json:"caption"`
	Language      *string        `json:"language"`
	DurationMs    *int           `json:"duration_ms"`
	Status        string         `json:"status"`
	RejectionCode *string        `json:"rejection_code"`
	LikeCount     int            `json:"like_count"`
	ViewCount     int            `json:"view_count"`
	ShareCount    int            `json:"share_count"`
	LikedByMe     bool           `json:"liked_by_me"`
	IsMine        bool           `json:"is_mine"`
	Playback      *PlaybackInfo  `json:"playback"`
	PublishedAt   *time.Time     `json:"published_at"`
	CreatedAt     time.Time      `json:"created_at"`
}

type Page[T any] struct {
	Items      []T     `json:"items"`
	NextCursor *string `json:"next_cursor"`
}

type CreatorProfile struct {
	CreatorSummary
	Bio            *string `json:"bio"`
	FollowerCount  int     `json:"follower_count"`
	FollowingCount int     `json:"following_count"`
	ReelCount      int     `json:"reel_count"`
	IsSelf         bool    `json:"is_self"`
}

type UploadTicket struct {
	Reel      Reel      `json:"reel"`
	UploadUrl string    `json:"upload_url"`
	ExpiresAt time.Time `json:"expires_at"`
}

type LikeState struct {
	Liked     bool `json:"liked"`
	LikeCount int  `json:"like_count"`
}

type FollowState struct {
	Following bool `json:"following"`
}

type ShareLink struct {
	Url  string `json:"url"`
	Text string `json:"text"`
}

type ReelsConfig struct {
	Enabled          bool  `json:"enabled"`
	UploadsAvailable bool  `json:"uploads_available"`
	MinDurationMs    int   `json:"min_duration_ms"`
	MaxDurationMs    int   `json:"max_duration_ms"`
	MaxCaption       int   `json:"max_caption_length"`
	DailyUploadLimit int   `json:"daily_upload_limit"`
	MaxUploadBytes   int64 `json:"max_upload_bytes"`
}

// MaxUploadBytes bounds the client-side file (a 60 s 1080p phone clip is
// typically 20–80 MB).
const MaxUploadBytes = 150 << 20

type QueueEntry struct {
	CaseId    string             `json:"case_id"`
	Source    string             `json:"source"`
	Priority  int                `json:"priority"`
	Scores    map[string]float64 `json:"scores"`
	Reports   int                `json:"report_count"`
	Appeal    *string            `json:"appeal_statement"`
	CreatedAt time.Time          `json:"created_at"`
	Reel      Reel               `json:"reel"`
}

type DecisionResult struct {
	ReelId string `json:"reel_id"`
	Status string `json:"status"`
}

type Analytics struct {
	From                 time.Time `json:"from"`
	To                   time.Time `json:"to"`
	Published            int       `json:"published_reels"`
	ActiveCreators       int       `json:"active_creators"`
	Impressions          int       `json:"impressions"`
	PlaysStarted         int       `json:"plays_started"`
	PlaysCompleted       int       `json:"plays_completed"`
	WatchSeconds         int64     `json:"watch_seconds"`
	Likes                int       `json:"likes"`
	Follows              int       `json:"follows"`
	Shares               int       `json:"shares"`
	Reports              int       `json:"reports"`
	ProfileOpens         int       `json:"creator_profile_opens"`
	CTAClicks            int       `json:"host_call_cta_clicks"`
	AttributedCalls      int       `json:"reel_attributed_calls_started"`
	AttributedCompleted  int       `json:"reel_attributed_calls_completed"`
	AttributedPaidSecs   int64     `json:"reel_attributed_billed_seconds"`
	AttributedDiamonds   int64     `json:"reel_attributed_diamonds_charged"`
	AttributionWindowMin int       `json:"attribution_window_minutes"`
}

// ---------------------------------------------------------------- requests

type CreateUploadRequest struct {
	Caption            *string `json:"caption"`
	Language           *string `json:"language"`
	DeclaredDurationMs *int    `json:"duration_ms"`
}

func (r CreateUploadRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.Caption != nil && utf8.RuneCountInString(*r.Caption) > MaxCaptionRunes {
		errs["caption"] = "too_long"
	}
	if r.Language != nil && !langRE.MatchString(*r.Language) {
		errs["language"] = "invalid"
	}
	switch {
	case r.DeclaredDurationMs == nil:
		errs["duration_ms"] = "required"
	case *r.DeclaredDurationMs < MinDurationMs || *r.DeclaredDurationMs > MaxDurationMs:
		errs["duration_ms"] = "out_of_range"
	}
	return errs
}

type UpdateCreatorRequest struct {
	Bio *string `json:"bio"`
}

type ReportRequest struct {
	Category *string `json:"category"`
	Details  *string `json:"details"`
}

var reportCategories = map[string]int{ // category → case priority
	"minor_safety": 1, "nudity": 1, "sexual_content": 2, "violence": 2, "hate": 2,
	"harassment": 3, "privacy": 3, "copyright": 3, "spam_or_scam": 4, "other": 4,
}

func (r ReportRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.Category == nil {
		errs["category"] = "required"
	} else if _, ok := reportCategories[*r.Category]; !ok {
		errs["category"] = "invalid"
	}
	if r.Details != nil && utf8.RuneCountInString(*r.Details) > 1000 {
		errs["details"] = "too_long"
	}
	return errs
}

type AppealRequest struct {
	Statement *string `json:"statement"`
}

type DecisionRequest struct {
	Decision   *string `json:"decision"` // approve | reject | remove | restore
	ReasonCode *string `json:"reason_code"`
	Note       *string `json:"note"`
}

func (r DecisionRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.Decision == nil {
		errs["decision"] = "required"
	} else {
		switch *r.Decision {
		case "approve", "reject", "remove", "restore":
		default:
			errs["decision"] = "invalid"
		}
	}
	if r.ReasonCode == nil || strings.TrimSpace(*r.ReasonCode) == "" {
		errs["reason_code"] = "required"
	} else if len(*r.ReasonCode) > 60 {
		errs["reason_code"] = "too_long"
	}
	if r.Note != nil && utf8.RuneCountInString(*r.Note) > 2000 {
		errs["note"] = "too_long"
	}
	return errs
}

type EventIn struct {
	Event     string  `json:"event"`
	ReelId    *string `json:"reel_id"`
	CreatorId *string `json:"creator_id"`
	ValueMs   *int    `json:"value_ms"`
	SessionId *string `json:"session_id"`
}

type EventsRequest struct {
	Events []EventIn `json:"events"`
}

// ClientEvents are the events the app may send. Likes, follows, shares and
// reports are recorded by their own endpoints (never trusted from the client).
var ClientEvents = map[string]bool{
	"reel_impression": true, "reel_play_started": true, "reel_play_completed": true,
	"reel_watch_duration": true, "creator_profile_opened": true, "host_call_cta_clicked": true,
}

const MaxEventsPerBatch = 50
