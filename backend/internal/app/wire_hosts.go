package app

import (
	"context"
	"errors"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/adapters/sightengine"
	"dashuri/backend/internal/adapters/supabase"
	"dashuri/backend/internal/modules/hosts"
	"dashuri/backend/internal/modules/moderation"
	"dashuri/backend/internal/wiring"
)

// wireHosts builds the hosts module from shared infrastructure. KYC uses the
// manual provider (a moderator decides) until a vendor is chosen.
func wireHosts(env wiring.Env) *hosts.Service {
	d := hosts.Deps{Rules: env.Rules, KYC: hosts.ManualKYC{}, Clock: env.Clock, Evidence: verificationEvidenceStorage(env)}
	if env.Pool != nil {
		repo := postgres.HostsRepo{Pool: env.Pool, Tx: env.Tx, Sessions: env.Config.ArrivalPhotosEnabled}
		d.Repo = repo
		d.Arrival = hosts.ArrivalConfig{
			Enabled: env.Config.ArrivalPhotosEnabled, Repo: repo,
			Store:                arrivalStore{arrivalPhotoStorage(env)},
			Scanner:              arrivalScanner(env),
			FlagThreshold:        moderation.DefaultFlagThreshold,
			AutoApproveUnscanned: env.Config.ArrivalPhotoAutoApproveUnscanned,
		}
	}
	return hosts.NewService(d)
}

// verificationEvidenceStorage signs URLs for the PRIVATE Verified Host
// evidence bucket (face video, ID images). Same server-held key as profile
// photos; objects are never public and never returned by public APIs.
func verificationEvidenceStorage(env wiring.Env) supabase.PhotoStorage {
	return supabase.PhotoStorage{
		BaseURL: env.Config.SupabaseURL, APIKey: env.Config.StorageServiceKey,
		Bucket: hosts.EvidenceBucket, Client: env.HTTP,
	}
}

// arrivalPhotoStorage is the PRIVATE host-arrival-photos bucket.
func arrivalPhotoStorage(env wiring.Env) supabase.PhotoStorage {
	return supabase.PhotoStorage{
		BaseURL: env.Config.SupabaseURL, APIKey: env.Config.StorageServiceKey,
		Bucket: hosts.ArrivalBucket, Client: env.HTTP,
	}
}

// arrivalStore maps the Storage adapter's errors to the hosts module's.
type arrivalStore struct{ supabase.PhotoStorage }

func (s arrivalStore) Download(ctx context.Context, path string, maxBytes int64) ([]byte, error) {
	b, err := s.PhotoStorage.Download(ctx, path, maxBytes)
	switch {
	case errors.Is(err, supabase.ErrObjectNotFound):
		return nil, hosts.ErrObjectNotFound
	case errors.Is(err, supabase.ErrObjectTooLarge):
		return nil, hosts.ErrObjectTooLarge
	}
	return b, err
}

// arrivalScanner scores arrival photos with the call-moderation classifier
// when MODERATION_ENABLED and Sightengine credentials are set (paid per
// image; nil otherwise → photos wait for a moderator unless
// ARRIVAL_PHOTO_AUTO_APPROVE_UNSCANNED).
func arrivalScanner(env wiring.Env) hosts.ImageScanner {
	if !env.Config.ModerationEnabled || env.Config.SightengineUser == "" || env.Config.SightengineSecret == "" {
		return nil
	}
	return classifierScanner{sightengine.New(env.Config.SightengineUser, env.Config.SightengineSecret, env.HTTP)}
}

type classifierScanner struct{ c moderation.NudityClassifier }

func (s classifierScanner) ExplicitScore(ctx context.Context, image []byte) (float64, error) {
	sc, err := s.c.Score(ctx, image)
	if err != nil {
		return 0, err
	}
	return sc.Explicit(), nil
}

// WireHostsForJobs exposes the hosts service to scheduled jobs.
func WireHostsForJobs(env wiring.Env) *hosts.Service { return wireHosts(env) }
