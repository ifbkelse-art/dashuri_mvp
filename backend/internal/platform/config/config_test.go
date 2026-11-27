package config

import (
	"strings"
	"testing"
)

func validProduction() Config {
	return Config{
		Env: "production", CashfreeEnv: "sandbox",
		DatabaseURL: "postgres://x", SupabaseURL: "https://x.supabase.co", SupabaseJWKSURL: "https://x/jwks",
		SupabaseIssuer: "https://x/auth/v1", PlayPackageName: "app.dashuri", GoogleCredentialsFile: "/creds.json",
		StreamAPIKey: "k", StreamAPISecret: "s", RealtimeAPIKey: "r",
	}
}

func TestValidProductionConfigPasses(t *testing.T) {
	if err := validProduction().Validate(); err != nil {
		t.Fatal(err)
	}
}

// Regression (2026-11-27): ARRIVAL_PHOTO_AUTO_APPROVE_UNSCANNED could be
// switched on in production, publishing arrival photos that no classifier or
// moderator had checked.
func TestUnscannedArrivalPhotosRefusedInProduction(t *testing.T) {
	c := validProduction()
	c.ArrivalPhotoAutoApproveUnscanned = true
	if err := c.Validate(); err == nil || !strings.Contains(err.Error(), "ARRIVAL_PHOTO_AUTO_APPROVE_UNSCANNED") {
		t.Fatalf("want refusal, got %v", err)
	}
	for _, env := range []string{"development", "staging"} {
		c.Env = env
		if err := c.Validate(); err != nil {
			t.Fatalf("%s should allow it: %v", env, err)
		}
	}
}

func TestDevJWTSecretRefusedOutsideDevelopment(t *testing.T) {
	c := validProduction()
	c.SupabaseDevJWTSecret = "dev"
	if err := c.Validate(); err == nil {
		t.Fatal("production accepted a dev JWT secret")
	}
}

func TestIssuerRequiredOutsideDevelopment(t *testing.T) {
	c := validProduction()
	c.SupabaseIssuer = ""
	if err := c.Validate(); err == nil || !strings.Contains(err.Error(), "SUPABASE_JWT_ISSUER") {
		t.Fatalf("want issuer required, got %v", err)
	}
}
