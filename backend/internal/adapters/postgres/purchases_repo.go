package postgres

import (
	"context"
	"dashuri/backend/internal/modules/economy"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/modules/ledger"
	"dashuri/backend/internal/modules/purchases"
	"dashuri/backend/internal/platform/db"
)

// PurchasesRepo implements purchases.Repository.
type PurchasesRepo struct {
	Pool *pgxpool.Pool
	Tx   db.TxManager
	// Rules caps a host's price after a reversal lowers their level. Zero
	// value: economy.Founder().
	Rules economy.Rules
}

func (r PurchasesRepo) rules() economy.Rules {
	if r.Rules.LevelRateStep == 0 {
		return economy.Founder()
	}
	return r.Rules
}

var _ purchases.Repository = PurchasesRepo{}

func (r PurchasesRepo) Packages(ctx context.Context) ([]purchases.Package, error) {
	rows, err := r.Pool.Query(ctx, `
		select product_id, diamonds, coalesce(price_paise, 0), coalesce(label, ''), badge, provisional
		  from economy.diamond_packages where active order by sort_order, diamonds`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []purchases.Package
	for rows.Next() {
		var p purchases.Package
		if err := rows.Scan(&p.ProductID, &p.Diamonds, &p.PricePaise, &p.Label, &p.Badge, &p.Provisional); err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

func (r PurchasesRepo) Package(ctx context.Context, productID string) (purchases.Package, bool, error) {
	var p purchases.Package
	err := r.Pool.QueryRow(ctx, `
		select product_id, diamonds, coalesce(price_paise, 0), coalesce(label, ''), badge, provisional
		  from economy.diamond_packages where active and product_id = $1`, productID).
		Scan(&p.ProductID, &p.Diamonds, &p.PricePaise, &p.Label, &p.Badge, &p.Provisional)
	if errors.Is(err, pgx.ErrNoRows) {
		return p, false, nil
	}
	return p, err == nil, err
}

const purchaseCols = `id::text, user_id::text, product_id, purchase_token_hash, coalesce(order_id, ''), state, diamonds, rail`

func scanPurchase(row pgx.Row) (purchases.PurchaseRecord, error) {
	var p purchases.PurchaseRecord
	err := row.Scan(&p.ID, &p.UserID, &p.ProductID, &p.TokenHash, &p.OrderID, &p.State, &p.Diamonds, &p.Rail)
	return p, err
}

func (r PurchasesRepo) PurchaseByTokenHash(ctx context.Context, hash string) (purchases.PurchaseRecord, bool, error) {
	p, err := scanPurchase(r.Pool.QueryRow(ctx, `select `+purchaseCols+` from commerce.purchases where purchase_token_hash = $1`, hash))
	if errors.Is(err, pgx.ErrNoRows) {
		return p, false, nil
	}
	return p, err == nil, err
}

func (r PurchasesRepo) PurchaseByOrderID(ctx context.Context, orderID string) (purchases.PurchaseRecord, bool, error) {
	if orderID == "" {
		return purchases.PurchaseRecord{}, false, nil
	}
	p, err := scanPurchase(r.Pool.QueryRow(ctx, `select `+purchaseCols+` from commerce.purchases where order_id = $1`, orderID))
	if errors.Is(err, pgx.ErrNoRows) {
		return p, false, nil
	}
	return p, err == nil, err
}

func nullIfEmpty(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func (r PurchasesRepo) SavePlayPurchaseState(ctx context.Context, rec purchases.PurchaseRecord) (purchases.PurchaseRecord, error) {
	var out purchases.PurchaseRecord
	err := r.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, `
			insert into commerce.purchases (user_id, product_id, purchase_token_hash, order_id, state, diamonds, rail)
			values ($1, $2, $3, $4, $5, $6, 'google_play')
			on conflict (purchase_token_hash) do update set state = excluded.state
			 where commerce.purchases.state in ('pending','rejected') and commerce.purchases.user_id = excluded.user_id`,
			rec.UserID, rec.ProductID, rec.TokenHash, nullIfEmpty(rec.OrderID), rec.State, rec.Diamonds); err != nil {
			return err
		}
		var err error
		out, err = scanPurchase(tx.QueryRow(ctx, `select `+purchaseCols+` from commerce.purchases where purchase_token_hash = $1`, rec.TokenHash))
		if err != nil {
			return err
		}
		if out.UserID != rec.UserID {
			return purchases.ErrOtherAccount
		}
		return nil
	})
	return out, err
}

func (r PurchasesRepo) CreditPurchase(ctx context.Context, c purchases.Credit) (purchases.PurchaseRecord, bool, error) {
	var out purchases.PurchaseRecord
	var replayed bool
	err := r.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
		replayed = false
		if c.CashfreeOrderID != "" {
			var state, reason string
			err := tx.QueryRow(ctx, `select state, coalesce(failure_reason, '') from commerce.cashfree_orders where order_id = $1 for update`,
				c.CashfreeOrderID).Scan(&state, &reason)
			if err != nil {
				return err
			}
			if state == "failed" && reason == "amount_mismatch" {
				return purchases.ErrNotCreditable
			}
		}
		if _, err := tx.Exec(ctx, `
			insert into commerce.purchases (user_id, product_id, purchase_token_hash, order_id, state, diamonds, rail)
			values ($1, $2, $3, $4, 'pending', $5, $6)
			on conflict do nothing`,
			c.UserID, c.ProductID, c.TokenHash, nullIfEmpty(c.OrderID), c.Diamonds, c.Rail); err != nil {
			return err
		}
		p, err := scanPurchase(tx.QueryRow(ctx, `select `+purchaseCols+` from commerce.purchases where purchase_token_hash = $1 for update`, c.TokenHash))
		if errors.Is(err, pgx.ErrNoRows) {
			return errors.New("purchases: order id already recorded for a different token")
		}
		if err != nil {
			return err
		}
		if p.UserID != c.UserID {
			return purchases.ErrOtherAccount
		}
		if p.State == "credited" || p.State == "reversed" {
			out, replayed = p, true
			return r.markCashfreeCredited(ctx, tx, c.CashfreeOrderID, p.ID, p.State)
		}
		entryID, _, err := PostEntry(ctx, tx, c.Entry(p.ID))
		if err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `
			update commerce.purchases set state = 'credited', credit_entry_id = $2, diamonds = $3, verified_at = now(),
			       order_id = coalesce(order_id, $4)
			 where id = $1`, p.ID, entryID, c.Diamonds, nullIfEmpty(c.OrderID)); err != nil {
			return err
		}
		if c.XP > 0 {
			if _, err := tx.Exec(ctx, `
				insert into ledger.xp_events (user_id, source_type, source_id, xp_delta) values ($1, 'purchase', $2, $3)
				on conflict (source_type, source_id) do nothing`, c.UserID, p.ID, c.XP); err != nil {
				return err
			}
		}
		p.State, p.Diamonds = "credited", c.Diamonds
		out = p
		return r.markCashfreeCredited(ctx, tx, c.CashfreeOrderID, p.ID, "credited")
	})
	return out, replayed, err
}

func (PurchasesRepo) markCashfreeCredited(ctx context.Context, tx pgx.Tx, orderID, purchaseID, purchaseState string) error {
	if orderID == "" || purchaseState != "credited" {
		return nil
	}
	_, err := tx.Exec(ctx, `
		update commerce.cashfree_orders set state = 'credited', purchase_id = $2, failure_reason = null
		 where order_id = $1 and state <> 'credited'`, orderID, purchaseID)
	return err
}

func (r PurchasesRepo) ReversePurchase(ctx context.Context, hash, reason string, voidedAt time.Time, plan purchases.ReversalPlan, xpWeight int64) (purchases.ReversalResult, error) {
	var res purchases.ReversalResult
	err := r.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
		res = purchases.ReversalResult{}
		p, err := scanPurchase(tx.QueryRow(ctx, `select `+purchaseCols+` from commerce.purchases where purchase_token_hash = $1 for update`, hash))
		if errors.Is(err, pgx.ErrNoRows) {
			return nil
		}
		if err != nil {
			return err
		}
		res.Found, res.PurchaseID, res.UserID = true, p.ID, p.UserID
		switch p.State {
		case "reversed":
			res.Replayed = true
			return nil
		case "pending", "rejected":
			_, err := tx.Exec(ctx, `update commerce.purchases set state = 'reversed', voided_at = $2, void_reason = $3,
				reversed_diamonds = 0, unrecovered_diamonds = 0 where id = $1`, p.ID, voidedAt, reason)
			return err
		}
		bal, err := LockUserBalances(ctx, tx, p.UserID, ledger.UserDiamondPurchased, ledger.UserDiamondPromotional)
		if err != nil {
			return err
		}
		reserved, err := ActiveReservations(ctx, tx, p.UserID)
		if err != nil {
			return err
		}
		remove := plan(p, bal[ledger.UserDiamondPurchased], bal[ledger.UserDiamondPromotional], reserved)
		var entryID *string
		if remove > 0 {
			id, _, err := PostEntry(ctx, tx, ledger.PurchaseReversal(p.UserID, p.ID, remove, voidedAt))
			if err != nil {
				return err
			}
			entryID = &id
		}
		res.Removed, res.Unrecovered = remove, p.Diamonds-remove
		if _, err := tx.Exec(ctx, `
			update commerce.purchases set state = 'reversed', voided_at = $2, void_reason = $3,
			       reversed_diamonds = $4, unrecovered_diamonds = $5, reversal_entry_id = $6
			 where id = $1`, p.ID, voidedAt, reason, res.Removed, res.Unrecovered, entryID); err != nil {
			return err
		}
		if xp := xpWeight * p.Diamonds; xp > 0 {
			if _, err := tx.Exec(ctx, `
				insert into ledger.xp_events (user_id, source_type, source_id, xp_delta) values ($1, 'reversal', $2, $3)
				on conflict (source_type, source_id) do nothing`, p.UserID, p.ID, -xp); err != nil {
				return err
			}
			// A lower level lowers the price ceiling: cap the stored price in
			// the same transaction, before any new call (live calls keep
			// their snapshotted rate). No-op for non-hosts.
			if _, err := capHostRateToEligibility(ctx, tx, r.rules(), p.UserID, "system:purchase_reversal", "level_decreased"); err != nil {
				return err
			}
		}
		return nil
	})
	return res, err
}

func (r PurchasesRepo) NotificationSeen(ctx context.Context, messageID string) (bool, error) {
	var ok bool
	err := r.Pool.QueryRow(ctx, `select exists (select 1 from commerce.play_notifications where message_id = $1)`, messageID).Scan(&ok)
	return ok, err
}

func (r PurchasesRepo) RecordNotification(ctx context.Context, messageID, kind string, payload []byte) error {
	if len(payload) == 0 || !jsonValid(payload) {
		payload = []byte(`{}`)
	}
	_, err := r.Pool.Exec(ctx, `insert into commerce.play_notifications (message_id, kind, payload) values ($1, $2, $3)
		on conflict (message_id) do nothing`, messageID, kind, payload)
	return err
}

func (r PurchasesRepo) CustomerPhone(ctx context.Context, userID string) (string, error) {
	var phone *string
	if err := r.Pool.QueryRow(ctx, `select commerce.customer_phone($1)`, userID).Scan(&phone); err != nil {
		return "", err
	}
	if phone == nil {
		return "", nil
	}
	return *phone, nil
}

func (r PurchasesRepo) InsertCashfreeOrder(ctx context.Context, o purchases.CashfreeOrderRecord) error {
	_, err := r.Pool.Exec(ctx, `
		insert into commerce.cashfree_orders (order_id, user_id, product_id, amount_paise, diamonds, environment, state, created_at, expires_at)
		values ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
		o.OrderID, o.UserID, o.ProductID, o.AmountPaise, o.Diamonds, o.Environment, o.State, o.CreatedAt, o.ExpiresAt)
	return err
}

const cashfreeCols = `order_id, user_id::text, product_id, amount_paise, diamonds, coalesce(payment_session_id, ''), coalesce(cf_order_id, ''),
	environment, state, coalesce(purchase_id::text, ''), coalesce(failure_reason, ''), created_at, expires_at`

func scanCashfree(row pgx.Row) (purchases.CashfreeOrderRecord, error) {
	var o purchases.CashfreeOrderRecord
	err := row.Scan(&o.OrderID, &o.UserID, &o.ProductID, &o.AmountPaise, &o.Diamonds, &o.PaymentSessionID, &o.CFOrderID,
		&o.Environment, &o.State, &o.PurchaseID, &o.FailureReason, &o.CreatedAt, &o.ExpiresAt)
	return o, err
}

func (r PurchasesRepo) CashfreeOrder(ctx context.Context, orderID string) (purchases.CashfreeOrderRecord, bool, error) {
	o, err := scanCashfree(r.Pool.QueryRow(ctx, `select `+cashfreeCols+` from commerce.cashfree_orders where order_id = $1`, orderID))
	if errors.Is(err, pgx.ErrNoRows) {
		return o, false, nil
	}
	return o, err == nil, err
}

func (r PurchasesRepo) SetCashfreeSession(ctx context.Context, orderID, sessionID, cfOrderID string) error {
	_, err := r.Pool.Exec(ctx, `update commerce.cashfree_orders set payment_session_id = $2, cf_order_id = $3 where order_id = $1`,
		orderID, sessionID, nullIfEmpty(cfOrderID))
	return err
}

func (r PurchasesRepo) SetCashfreeOrderState(ctx context.Context, orderID, state, reason string) error {
	_, err := r.Pool.Exec(ctx, `
		update commerce.cashfree_orders set state = $2, failure_reason = $3
		 where order_id = $1 and state in ('created','pending')`, orderID, state, nullIfEmpty(reason))
	return err
}

func (r PurchasesRepo) OpenCashfreeOrders(ctx context.Context, limit int) ([]purchases.CashfreeOrderRecord, error) {
	rows, err := r.Pool.Query(ctx, `select `+cashfreeCols+` from commerce.cashfree_orders
		where state in ('created','pending') order by created_at limit $1`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []purchases.CashfreeOrderRecord
	for rows.Next() {
		o, err := scanCashfree(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, o)
	}
	return out, rows.Err()
}

func (r PurchasesRepo) WebhookSeen(ctx context.Context, hash string) (bool, error) {
	var ok bool
	err := r.Pool.QueryRow(ctx, `select exists (select 1 from commerce.cashfree_webhooks where delivery_hash = $1)`, hash).Scan(&ok)
	return ok, err
}

func (r PurchasesRepo) RecordWebhook(ctx context.Context, hash, orderID, eventType string, payload []byte) error {
	if !jsonValid(payload) {
		payload = []byte(`{}`)
	}
	if eventType == "" {
		eventType = "unknown"
	}
	_, err := r.Pool.Exec(ctx, `insert into commerce.cashfree_webhooks (delivery_hash, order_id, event_type, payload)
		values ($1, $2, $3, $4) on conflict (delivery_hash) do nothing`, hash, nullIfEmpty(orderID), eventType, payload)
	return err
}

func (r PurchasesRepo) Audit(ctx context.Context, actor, action, target string, details map[string]any) error {
	return InsertAudit(ctx, r.Pool, actor, action, target, details)
}
