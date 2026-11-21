package app

import (
	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/adapters/supabase"
	"dashuri/backend/internal/modules/accounts"
	"dashuri/backend/internal/wiring"
)

// profilePhotoStorage signs URLs for the private profile-photos bucket.
// Unconfigured (no SUPABASE_URL or SUPABASE_STORAGE_SERVICE_KEY) it signs
// nothing: uploads return 503 storage_not_configured, photos are omitted.
func profilePhotoStorage(env wiring.Env) supabase.PhotoStorage {
	return supabase.PhotoStorage{
		BaseURL: env.Config.SupabaseURL, APIKey: env.Config.StorageServiceKey,
		Bucket: "profile-photos", Client: env.HTTP,
	}
}

// wireAccounts builds the accounts module from shared infrastructure.
func wireAccounts(env wiring.Env) *accounts.Service {
	d := accounts.Deps{Storage: profilePhotoStorage(env), Rules: env.Rules, Clock: env.Clock}
	if env.Pool != nil {
		d.Repo = postgres.AccountsRepo{Pool: env.Pool}
	}
	return accounts.NewService(d)
}
