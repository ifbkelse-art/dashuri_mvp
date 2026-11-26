// Package config loads settings from environment variables. Secrets come
// from Google Secret Manager mounted as env vars on Cloud Run; nothing secret
// has a default value.
package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	Env             string // development | staging | production
	Port            string
	DatabaseURL     string // Supabase Postgres via the pooler; dedicated `api_service` role (not the service-role key)
	SupabaseURL     string
	SupabaseJWKSURL string
	SupabaseIssuer  string
	// SupabaseDevJWTSecret verifies HS256 tokens from a local `supabase start`
	// stack. Refused outside development.
	SupabaseDevJWTSecret string
	ShutdownTimeout      time.Duration
	PayoutsEnabled       bool // false until incorporation + payout provider (R3-7)
	FreeCallEnabled      bool // Android-only feature (S4)
	SupportEmail         string

	// Google Play Billing (default rail, ADR-010).
	PlayPackageName string
	// GoogleCredentialsFile is a service-account JSON file with the Android
	// Publisher scope (mounted from Secret Manager). Empty disables Play verification.
	GoogleCredentialsFile string
	// PlayRTDNAudience is the OIDC audience configured on the Pub/Sub push subscription.
	PlayRTDNAudience string
	// PlayRTDNServiceAccount is the push subscription's service-account email.
	PlayRTDNServiceAccount string

	// Cashfree PG (second rail behind a flag, founder decision F1 / ADR-011).
	CashfreeEnabled      bool
	CashfreeEnv          string // sandbox | production
	CashfreeClientID     string // secret
	CashfreeClientSecret string // secret
	CashfreeAPIVersion   string
	CashfreeReturnURL    string // https deep link the PG redirects to after payment (optional)

	// Stream Video (ADR-005, founder decision F2).
	StreamAPIKey    string // public key (also given to clients with call tokens)
	StreamAPISecret string // secret: signs user tokens and verifies webhooks

	// Supabase Realtime broadcast from the server (ADR-006).
	RealtimeAPIKey string // secret

	// Nudity moderation during the first 3 minutes of each call (S7).
	ModerationEnabled bool
	SightengineUser   string // secret
	SightengineSecret string // secret

	// Push (FCM HTTP v1). Uses GoogleCredentialsFile for auth.
	FCMProjectID string

	// DiscoveryVerifiedBoostXP is the Verified Host ranking signal in the
	// "recommended" discovery sort, as an XP-equivalent bonus (0 = off).
	// Non-verified hosts are never excluded by it.
	DiscoveryVerifiedBoostXP int64

	// Supabase Storage signing key (BE-identity): issues signed upload and
	// read URLs for the private profile-photos bucket. Server only; empty
	// makes photo uploads return 503 storage_not_configured.
	StorageServiceKey string // secret

	// EXPERIMENT — Dashuri Reels (docs/reels). Off by default: every Reels
	// endpoint answers 503 reels_disabled and nothing else changes.
	ReelsEnabled bool
	// ReelsVideoProvider receives new uploads: "r2" (target, default) or
	// "mux" (transition only). Reels stored with the other provider keep
	// being served while its credentials are set.
	ReelsVideoProvider string
	R2AccountID        string
	R2AccessKeyID      string // secret
	R2SecretAccessKey  string // secret
	R2Bucket           string
	R2Endpoint         string // optional override (S3-compatible fake for local testing)
	R2KeepOriginals    bool   // keep reels/<id>/original after processing (default off)

	MuxTokenID               string // secret
	MuxTokenSecret           string // secret
	MuxSigningKeyID          string
	MuxSigningKeyBase64      string // secret (base64 PEM RSA key for signed playback)
	MuxWebhookSecret         string // secret
	ReelsModerationModels    string // Sightengine models per frame
	ReelsModerationFrameSecs int    // seconds between moderation frames

	// EXPERIMENT — unified chat + in-call messaging (docs/chat). Stores the
	// in-call metadata columns (context, call_id, client_message_id). Needs
	// migration 20261123000200 applied FIRST. Off: in-call messages are
	// still delivered, stored as plain chat messages.
	ChatMessageContextEnabled bool

	// Virtual gifts during calls (docs/gifts/VIRTUAL_GIFTS.md). Needs
	// migrations 20261123000200 and 20261126000200 applied FIRST, and
	// CHAT_MESSAGE_CONTEXT_ENABLED (gift lines live in the call's session
	// chat). Default off.
	GiftsEnabled bool
	// Host arrival photos (docs/host/HOST_HOME_SESSION_AND_ARRIVAL_PHOTO.md).
	// Needs migration 20261126000100. Default off.
	ArrivalPhotosEnabled bool
	// ArrivalPhotoAutoApproveUnscanned publishes a validated arrival photo
	// without an automated nudity scan when no classifier is configured.
	// Default false: such photos wait for a moderator. FOUNDER DECISION.
	ArrivalPhotoAutoApproveUnscanned bool

	// AdminOrigins are the browser origins of the admin web console allowed
	// by CORS (ADMIN_ORIGINS, comma-separated). Empty: CORS off.
	AdminOrigins []string
}

// Load reads and validates configuration. In production every required
// value must be present; development tolerates gaps so the API can boot.
func Load() (Config, error) {
	c := Config{
		Env:                    get("DASHURI_ENV", "production"), // fail safe: dev relaxations need an explicit DASHURI_ENV=development
		Port:                   get("PORT", "8080"),
		DatabaseURL:            os.Getenv("DATABASE_URL"),
		SupabaseURL:            os.Getenv("SUPABASE_URL"),
		SupabaseJWKSURL:        os.Getenv("SUPABASE_JWKS_URL"),
		SupabaseIssuer:         os.Getenv("SUPABASE_JWT_ISSUER"),
		SupabaseDevJWTSecret:   os.Getenv("SUPABASE_DEV_JWT_SECRET"),
		ShutdownTimeout:        20 * time.Second,
		PayoutsEnabled:         getBool("PAYOUTS_ENABLED", false),
		FreeCallEnabled:        getBool("FREE_CALL_ENABLED", true),
		SupportEmail:           get("SUPPORT_EMAIL", "support@dashuri.app"),
		PlayPackageName:        os.Getenv("PLAY_PACKAGE_NAME"),
		GoogleCredentialsFile:  os.Getenv("GOOGLE_APPLICATION_CREDENTIALS"),
		PlayRTDNAudience:       os.Getenv("PLAY_RTDN_AUDIENCE"),
		PlayRTDNServiceAccount: os.Getenv("PLAY_RTDN_SERVICE_ACCOUNT"),
		CashfreeEnabled:        getBool("CASHFREE_ENABLED", false),
		CashfreeEnv:            get("CASHFREE_ENV", "sandbox"),
		CashfreeClientID:       os.Getenv("CASHFREE_CLIENT_ID"),
		CashfreeClientSecret:   os.Getenv("CASHFREE_CLIENT_SECRET"),
		CashfreeAPIVersion:     get("CASHFREE_API_VERSION", "2025-01-01"),
		CashfreeReturnURL:      os.Getenv("CASHFREE_RETURN_URL"),
		StreamAPIKey:           os.Getenv("STREAM_API_KEY"),
		StreamAPISecret:        os.Getenv("STREAM_API_SECRET"),
		RealtimeAPIKey:         os.Getenv("SUPABASE_REALTIME_SERVICE_KEY"),
		ModerationEnabled:      getBool("MODERATION_ENABLED", true),
		SightengineUser:        os.Getenv("SIGHTENGINE_API_USER"),
		SightengineSecret:      os.Getenv("SIGHTENGINE_API_SECRET"),
		FCMProjectID:           os.Getenv("FCM_PROJECT_ID"),
		StorageServiceKey:      os.Getenv("SUPABASE_STORAGE_SERVICE_KEY"),

		ReelsEnabled:             getBool("REELS_ENABLED", false),
		ReelsVideoProvider:       get("REELS_VIDEO_PROVIDER", "r2"),
		R2AccountID:              os.Getenv("R2_ACCOUNT_ID"),
		R2AccessKeyID:            os.Getenv("R2_ACCESS_KEY_ID"),
		R2SecretAccessKey:        os.Getenv("R2_SECRET_ACCESS_KEY"),
		R2Bucket:                 os.Getenv("R2_BUCKET"),
		R2Endpoint:               os.Getenv("R2_ENDPOINT"),
		R2KeepOriginals:          getBool("R2_KEEP_ORIGINALS", false),
		MuxTokenID:               os.Getenv("MUX_TOKEN_ID"),
		MuxTokenSecret:           os.Getenv("MUX_TOKEN_SECRET"),
		MuxSigningKeyID:          os.Getenv("MUX_SIGNING_KEY_ID"),
		MuxSigningKeyBase64:      os.Getenv("MUX_SIGNING_KEY_PRIVATE"),
		MuxWebhookSecret:         os.Getenv("MUX_WEBHOOK_SECRET"),
		ReelsModerationModels:    os.Getenv("REELS_MODERATION_MODELS"),
		ReelsModerationFrameSecs: getInt("REELS_MODERATION_FRAME_SECONDS", 2),

		ChatMessageContextEnabled: getBool("CHAT_MESSAGE_CONTEXT_ENABLED", false),

		GiftsEnabled:                     getBool("GIFTS_ENABLED", false),
		ArrivalPhotosEnabled:             getBool("ARRIVAL_PHOTOS_ENABLED", false),
		ArrivalPhotoAutoApproveUnscanned: getBool("ARRIVAL_PHOTO_AUTO_APPROVE_UNSCANNED", false),

		AdminOrigins: getList("ADMIN_ORIGINS"),

		DiscoveryVerifiedBoostXP: getNonNegativeInt64("DISCOVERY_VERIFIED_BOOST_XP", DefaultDiscoveryVerifiedBoostXP),
	}
	return c, c.Validate()
}

// Validate checks environment-specific requirements.
func (c Config) Validate() error {
	if c.Env != "development" && c.Env != "staging" && c.Env != "production" {
		return fmt.Errorf("config: DASHURI_ENV must be development, staging or production, got %q", c.Env)
	}
	if c.CashfreeEnv != "sandbox" && c.CashfreeEnv != "production" {
		return fmt.Errorf("config: CASHFREE_ENV must be sandbox or production")
	}
	if c.GiftsEnabled && !c.ChatMessageContextEnabled {
		return fmt.Errorf("config: GIFTS_ENABLED requires CHAT_MESSAGE_CONTEXT_ENABLED (gift lines are call-session chat messages)")
	}
	if c.Env == "development" {
		return nil
	}
	if c.SupabaseDevJWTSecret != "" {
		return fmt.Errorf("config: SUPABASE_DEV_JWT_SECRET is only allowed in development")
	}
	required := map[string]string{
		"DATABASE_URL": c.DatabaseURL, "SUPABASE_URL": c.SupabaseURL,
		"SUPABASE_JWKS_URL": c.SupabaseJWKSURL, "SUPABASE_JWT_ISSUER": c.SupabaseIssuer,
		"PLAY_PACKAGE_NAME": c.PlayPackageName, "GOOGLE_APPLICATION_CREDENTIALS": c.GoogleCredentialsFile,
		"STREAM_API_KEY": c.StreamAPIKey, "STREAM_API_SECRET": c.StreamAPISecret,
		"SUPABASE_REALTIME_SERVICE_KEY": c.RealtimeAPIKey,
	}
	if c.CashfreeEnabled {
		required["CASHFREE_CLIENT_ID"] = c.CashfreeClientID
		required["CASHFREE_CLIENT_SECRET"] = c.CashfreeClientSecret
	}
	if c.ModerationEnabled {
		required["SIGHTENGINE_API_USER"] = c.SightengineUser
		required["SIGHTENGINE_API_SECRET"] = c.SightengineSecret
	}
	for name, v := range required {
		if v == "" {
			return fmt.Errorf("config: %s is required in %s", name, c.Env)
		}
	}
	if c.Env == "production" && c.CashfreeEnabled && c.CashfreeEnv != "production" {
		return fmt.Errorf("config: CASHFREE_ENV must be production in production")
	}
	return nil
}

func get(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func getInt(k string, def int) int {
	if n, err := strconv.Atoi(os.Getenv(k)); err == nil && n > 0 {
		return n
	}
	return def
}

// DefaultDiscoveryVerifiedBoostXP ranks a verified host like one with
// 100,000 more lifetime XP (about one level band at levels 2–3).
const DefaultDiscoveryVerifiedBoostXP = 100000

func getNonNegativeInt64(k string, def int64) int64 {
	if n, err := strconv.ParseInt(os.Getenv(k), 10, 64); err == nil && n >= 0 {
		return n
	}
	return def
}

func getBool(k string, def bool) bool {
	if b, err := strconv.ParseBool(os.Getenv(k)); err == nil {
		return b
	}
	return def
}

func getList(k string) []string {
	var out []string
	for _, v := range strings.Split(os.Getenv(k), ",") {
		if v = strings.TrimSpace(v); v != "" {
			out = append(out, v)
		}
	}
	return out
}
