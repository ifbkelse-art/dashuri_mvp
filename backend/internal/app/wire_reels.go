package app

import (
	"log/slog"
	"time"

	"dashuri/backend/internal/adapters/ffmpeg"
	"dashuri/backend/internal/adapters/mux"
	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/adapters/r2"
	"dashuri/backend/internal/adapters/sightengine"
	"dashuri/backend/internal/adapters/supabase"
	"dashuri/backend/internal/modules/reels"
	"dashuri/backend/internal/wiring"
)

// BuildReels builds the EXPERIMENTAL Reels module (also used by jobs).
//
// New uploads go to REELS_VIDEO_PROVIDER (default r2: Cloudflare R2 + our
// own ffmpeg processing). The other provider stays wired as "legacy" so
// reels already stored there keep playing, moderating and purging while
// its credentials are set (the Mux → R2 transition; see
// docs/reels/DASHURI_REELS_R2_MIGRATION.md). Missing credentials →
// uploads 503 video_provider_not_configured; missing Sightengine
// credentials → every reel goes to human review.
func BuildReels(env wiring.Env) *reels.Service {
	c := env.Config
	r2p := r2.New(r2.Config{AccountID: c.R2AccountID, AccessKeyID: c.R2AccessKeyID, SecretAccessKey: c.R2SecretAccessKey,
		Bucket: c.R2Bucket, Endpoint: c.R2Endpoint, KeepOriginals: c.R2KeepOriginals}, ffmpeg.New(), env.HTTP)
	muxp, err := mux.New(c.MuxTokenID, c.MuxTokenSecret, c.MuxSigningKeyID, c.MuxSigningKeyBase64, c.MuxWebhookSecret, env.HTTP)
	if err != nil {
		slog.Warn("reels: mux signing key invalid; mux disabled", "err", err)
	}
	var upload reels.VideoProvider = r2p
	legacy := []reels.VideoProvider{muxp}
	switch c.ReelsVideoProvider {
	case "mux":
		upload, legacy = muxp, []reels.VideoProvider{r2p}
	case "r2", "":
	default:
		slog.Warn("reels: unknown REELS_VIDEO_PROVIDER; using r2", "value", c.ReelsVideoProvider)
	}
	d := reels.Deps{
		Enabled:       c.ReelsEnabled,
		Provider:      upload,
		Legacy:        legacy,
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
