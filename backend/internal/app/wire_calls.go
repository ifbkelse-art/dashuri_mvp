package app

import (
	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/adapters/stream"
	"dashuri/backend/internal/modules/calls"
	"dashuri/backend/internal/wiring"
)

// wireCalls builds the calls module from shared infrastructure.
func wireCalls(env wiring.Env) *calls.Service { return BuildCalls(env) }

// BuildCalls builds the calls service; jobs reuse it (settle-stale-calls).
// Without STREAM_API_KEY / STREAM_API_SECRET the provider refuses with 503
// video_not_configured; without a database the service returns 503.
func BuildCalls(env wiring.Env) *calls.Service {
	d := calls.Deps{
		Rules:        env.Rules,
		Video:        stream.New(env.Config.StreamAPIKey, env.Config.StreamAPISecret, env.HTTP),
		Clock:        env.Clock,
		ProviderName: "stream",
		APIKey:       env.Config.StreamAPIKey,
	}
	if env.Realtime != nil {
		d.Realtime = env.Realtime
	}
	if env.Pool != nil {
		d.Repo = postgres.CallsRepo{Pool: env.Pool, Tx: env.Tx}
		// BE-identity: peer.photo_url from the first approved profile photo.
		d.Photos = postgres.ProfilePhotoURLs{Pool: env.Pool, Signer: profilePhotoStorage(env)}
	}
	return calls.NewService(d)
}
