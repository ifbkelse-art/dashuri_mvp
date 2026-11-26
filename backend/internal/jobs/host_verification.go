package jobs

import (
	"context"
	"log/slog"

	"dashuri/backend/internal/app"
	"dashuri/backend/internal/wiring"
)

// Verified Host jobs (2026-11-23).

func init() {
	Register(Job{
		Name: "purge-verification-evidence", Schedule: "daily 03:30",
		Doc: "Delete private Verified Host evidence (face video, ID images) 90 days after a final decision, uploads never submitted after 48 h, and evidence of deleted accounts. Metadata and audit rows stay.",
		Run: PurgeVerificationEvidence,
	})
}

// PurgeVerificationEvidence applies the evidence retention policy.
func PurgeVerificationEvidence(ctx context.Context, env wiring.Env) error {
	n, err := app.WireHostsForJobs(env).PurgeEvidence(ctx, 500)
	if err == nil && n > 0 {
		slog.Info("verification evidence purged", "objects", n)
	}
	return err
}
