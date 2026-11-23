package app

import (
	"log/slog"
	"time"

	"dashuri/backend/internal/adapters/mux"
	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/adapters/sightengine"
	"dashuri/backend/internal/adapters/supabase"
	"dashuri/backend/internal/modules/reels"
	"dashuri/backend/internal/wiring"
)

// BuildReels builds the EXPERIMENTAL Reels module (also used by jobs).
// Missing Mux credentials → uploads 503 video_provider_not_configured;
// missing Sightengine credentials → every reel goes to human review.
func BuildReels(env wiring.Env) *reels.Service {
	c := env.Config
	provider, err := mux.New(c.MuxTokenID, c.MuxTokenSecret, c.MuxSigningKeyID, c.MuxSigningKeyBase64, c.MuxWebhookSecret, env.HTTP)
	if err != nil {
		slog.Warn("reels: mux signing key invalid; uploads disabled", "err", err)
	}
	d := reels.Deps{
		Enabled:       c.ReelsEnabled,
		Provider:      provider,
		Classifier:    sightengine.NewFrameClassifier(c.SightengineUser, c.SightengineSecret, c.ReelsModerationModels, env.HTTP),
		Photos:        supabase.PhotoStorage{BaseURL: c.SupabaseURL, APIKey: c.StorageServiceKey, Bucket: "profile-photos", Client: env.HTTP},
		Clock:         env.Clock,
		FrameInterval: time.Duration(c.ReelsModerationFrameSecs) * time.Second,
	}
	if env.Pool != nil {
		d.Repo = postgres.ReelsRepo{Pool: env.Pool, Tx: env.Tx}
	}
	return reels.NewService(d)
}
