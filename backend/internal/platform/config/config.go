// Package config loads settings from environment variables. Secrets come
// from Google Secret Manager mounted as env vars on Cloud Run; nothing secret
// has a default value.
package config

import (
	"fmt"
	"os"
	"strconv"
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

	// Supabase Storage signing key (BE-identity): issues signed upload and
	// read URLs for the private profile-photos bucket. Server only; empty
	// makes photo uploads return 503 storage_not_configured.
	StorageServiceKey string // secret
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

func getBool(k string, def bool) bool {
	if b, err := strconv.ParseBool(os.Getenv(k)); err == nil {
		return b
	}
	return def
}
