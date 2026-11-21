// Package jobs holds scheduled, idempotent batch jobs run by `worker <job>`
// as Cloud Run Jobs. Each area registers its jobs from its own file with
// Register in an init function.
package jobs

import (
	"context"
	"sort"

	"dashuri/backend/internal/wiring"
)

// Job is one scheduled batch job. Run must be idempotent and bounded.
type Job struct {
	Name     string
	Schedule string // documentation for Cloud Scheduler (IST)
	Doc      string
	Run      func(ctx context.Context, env wiring.Env) error
}

var registry = map[string]Job{}

// Register adds a job; duplicate names panic at startup.
func Register(j Job) {
	if _, dup := registry[j.Name]; dup {
		panic("jobs: duplicate job " + j.Name)
	}
	registry[j.Name] = j
}

// Get returns a registered job.
func Get(name string) (Job, bool) { j, ok := registry[name]; return j, ok }

// All returns jobs sorted by name.
func All() []Job {
	out := make([]Job, 0, len(registry))
	for _, j := range registry {
		out = append(out, j)
	}
	sort.Slice(out, func(i, k int) bool { return out[i].Name < out[k].Name })
	return out
}
