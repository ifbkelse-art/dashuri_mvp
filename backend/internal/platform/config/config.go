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
	ShutdownTimeout time.Duration
	PayoutsEnabled  bool // false until incorporation + payout provider (R3-7)
	FreeCallEnabled bool // Android-only feature (S4)
	PlayPackageName string
	StreamAPIKey    string // secret; empty disables video credential issuance
	StreamAPISecret string // secret
	RealtimeAPIKey  string // secret used to publish Supabase Realtime broadcasts
}

// Load reads and validates configuration. In production every required
// value must be present; development tolerates gaps so the API can boot.
func Load() (Config, error) {
	c := Config{
		Env:             get("DASHURI_ENV", "development"),
		Port:            get("PORT", "8080"),
		DatabaseURL:     os.Getenv("DATABASE_URL"),
		SupabaseURL:     os.Getenv("SUPABASE_URL"),
		SupabaseJWKSURL: os.Getenv("SUPABASE_JWKS_URL"),
		SupabaseIssuer:  os.Getenv("SUPABASE_JWT_ISSUER"),
		ShutdownTimeout: 20 * time.Second,
		PayoutsEnabled:  getBool("PAYOUTS_ENABLED", false),
		FreeCallEnabled: getBool("FREE_CALL_ENABLED", true),
		PlayPackageName: os.Getenv("PLAY_PACKAGE_NAME"),
		StreamAPIKey:    os.Getenv("STREAM_API_KEY"),
		StreamAPISecret: os.Getenv("STREAM_API_SECRET"),
		RealtimeAPIKey:  os.Getenv("SUPABASE_REALTIME_SERVICE_KEY"),
	}
	if c.Env == "production" || c.Env == "staging" {
		for name, v := range map[string]string{
			"DATABASE_URL": c.DatabaseURL, "SUPABASE_URL": c.SupabaseURL,
			"SUPABASE_JWKS_URL": c.SupabaseJWKSURL, "SUPABASE_JWT_ISSUER": c.SupabaseIssuer,
			"PLAY_PACKAGE_NAME": c.PlayPackageName,
		} {
			if v == "" {
				return c, fmt.Errorf("config: %s is required in %s", name, c.Env)
			}
		}
	}
	return c, nil
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
