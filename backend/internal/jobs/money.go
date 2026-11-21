package jobs

import (
	"context"
	"errors"
	"fmt"
	"log/slog"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/app"
	"dashuri/backend/internal/modules/purchases"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/wiring"
)

// Money jobs (BE-money). Each is idempotent and bounded.

// ErrLedgerDrift makes `worker reconcile-ledger` exit non-zero.
var ErrLedgerDrift = errors.New("ledger reconciliation found discrepancies")

func init() {
	Register(Job{
		Name: "reconcile-ledger", Schedule: "daily 02:30",
		Doc: "Recompute balances from postings, check entry balance, audit drift (non-zero exit on drift).",
		Run: ReconcileLedger,
	})
	Register(Job{
		Name: "expire-promo-diamonds", Schedule: "daily 01:00",
		Doc: "Expire promotional Diamond grants older than 30 days (PromoExpiry).",
		Run: ExpirePromoDiamonds,
	})
	Register(Job{
		Name: "poll-cashfree-orders", Schedule: "every 10 min",
		Doc: "Re-check open Cashfree orders (<24 h) server-to-server; expire older ones.",
		Run: PollCashfreeOrders,
	})
	Register(Job{
		Name: "poll-voided-purchases", Schedule: "daily 04:00",
		Doc: "Play Voided Purchases API (30 days) → reversal of the unspent amount.",
		Run: PollVoidedPurchases,
	})
}

// ReconcileLedger logs the totals and audits any drift.
func ReconcileLedger(ctx context.Context, env wiring.Env) error {
	rep, err := app.NewAdminService(env).Reconcile(ctx)
	if err != nil {
		return err
	}
	slog.Info("ledger reconciliation", "customer_diamond_liability", rep.CustomerDiamondLiability,
		"promotional_diamond_liability", rep.PromotionalDiamondLiability, "host_bean_liability", rep.HostBeanLiability,
		"host_bean_liability_paise", rep.HostBeanLiabilityPaise, "discrepancies", rep.Discrepancies)
	if rep.Discrepancies == 0 {
		return nil
	}
	for _, d := range rep.DriftedAccounts {
		slog.Error("ledger drift", "account_id", d.AccountID, "kind", d.Kind, "owner", d.Owner,
			"projected", d.ProjectedValue, "posted", d.PostedValue)
	}
	if err := postgres.InsertAudit(ctx, env.Pool, "system:reconcile-ledger", "ledger.drift_detected", "", map[string]any{
		"drifted_accounts": rep.DriftedAccounts, "unbalanced_entries": rep.UnbalancedEntries}); err != nil {
		return err
	}
	return fmt.Errorf("%w: %d", ErrLedgerDrift, rep.Discrepancies)
}

// ExpirePromoDiamonds is a no-op while no promotional grants exist.
func ExpirePromoDiamonds(ctx context.Context, env wiring.Env) error {
	now := env.Clock.Now()
	grants, expired, err := postgres.ExpirePromoGrants(ctx, env.Pool, env.Tx, now.Add(-env.Rules.PromoDiamondTTL), now, 1000)
	if err != nil {
		return err
	}
	slog.Info("promo expiry", "grants_processed", grants, "diamonds_expired", expired)
	return nil
}

func skipUnavailable(job string, err error) error {
	if e := apperr.As(err); e != nil && e.Kind == apperr.KindUnavailable {
		slog.Warn("job skipped", "job", job, "reason", e.Code)
		return nil
	}
	return err
}

// PollCashfreeOrders re-checks open orders so a lost webhook still credits.
func PollCashfreeOrders(ctx context.Context, env wiring.Env) error {
	checked, expired, err := app.NewPurchasesService(env).PollCashfreeOrders(ctx)
	if err != nil {
		return skipUnavailable("poll-cashfree-orders", err)
	}
	slog.Info("cashfree orders polled", "checked", checked, "expired", expired)
	return nil
}

// PollVoidedPurchases uses the same reversal path as RTDN.
func PollVoidedPurchases(ctx context.Context, env wiring.Env) error {
	n, err := app.NewPurchasesService(env).PollVoidedPurchases(ctx)
	if errors.Is(err, purchases.ErrPlayNotConfigured) {
		slog.Warn("job skipped", "job", "poll-voided-purchases", "reason", "play_not_configured")
		return nil
	}
	if err != nil {
		return skipUnavailable("poll-voided-purchases", err)
	}
	slog.Info("voided purchases processed", "reversed", n)
	return nil
}
