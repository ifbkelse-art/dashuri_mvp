// Command worker runs scheduled jobs as Cloud Run Jobs, triggered by Cloud
// Scheduler: `worker <job>`. Every job is idempotent (safe to re-run) and
// processes work in bounded batches.
package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"sort"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/logging"
)

type job struct {
	schedule string
	doc      string
}

// Jobs and their intended schedules (IST). None is implemented yet.
var jobs = map[string]job{
	"release-bean-holds":        {"every 15 min", "Post BeanRelease for Beans whose 7-day hold has ended (skip hosts under fraud review)."},
	"expire-promo-diamonds":     {"hourly", "Post PromoExpiry for promotional grants older than 30 days."},
	"build-payout-cycle":        {"weekly", "Collect requested withdrawals into a cycle, compute TDS, await finance approval. No-op while PAYOUTS_ENABLED=false."},
	"sync-payout-status":        {"every 30 min", "Fetch provider outcomes; post PayoutSettled (paid or failed → Beans back to available)."},
	"reconcile-ledger":          {"daily", "Rebuild balances from postings and compare with the projection; compare purchases with Google Play earnings reports; alert on any difference."},
	"poll-voided-purchases":     {"daily", "Google Play Voided Purchases API → purchase reversals, fraud cases, Bean clawback."},
	"settle-stale-calls":        {"every minute", "End and settle calls with no provider events past the timeout; release orphaned reservations."},
	"mark-offline-hosts":        {"every minute", "Hosts without a heartbeat for 90 s become unavailable."},
	"purge-expired-idempotency": {"daily", "Delete idempotency keys past their 24 h expiry."},
	"retention-enforcement":     {"daily", "Delete or anonymise data past its retention period (periods need legal review)."},
}

func main() {
	slog.SetDefault(logging.New(os.Getenv("DASHURI_ENV")))
	if len(os.Args) < 2 {
		names := make([]string, 0, len(jobs))
		for n := range jobs {
			names = append(names, n)
		}
		sort.Strings(names)
		fmt.Println("usage: worker <job>")
		for _, n := range names {
			fmt.Printf("  %-27s %-14s %s\n", n, jobs[n].schedule, jobs[n].doc)
		}
		os.Exit(2)
	}
	name := os.Args[1]
	if _, ok := jobs[name]; !ok {
		slog.Error("unknown job", "job", name)
		os.Exit(2)
	}
	if err := run(context.Background(), name); err != nil {
		slog.Error("job failed", "job", name, "err", err)
		os.Exit(1)
	}
}

func run(_ context.Context, name string) error {
	return apperr.NotImplemented("job " + name)
}
