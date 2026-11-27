//go:build integration

package gifts_test

// Virtual gifts against real Postgres with every migration applied and the
// API connecting as api_service: money movement, idempotency, concurrency,
// rollback, chat lines, history, catalogue administration and holds.

import (
	"context"
	"encoding/json"
	"sync"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/chat"
	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/modules/gifts"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/db"
	"dashuri/backend/internal/testsupport/callstest"
	"dashuri/backend/internal/testsupport/identitytest"
	"dashuri/backend/internal/testsupport/pgtest"
)

type recorder struct {
	mu     sync.Mutex
	events []string
	gifts  []map[string]any
}

func (r *recorder) Publish(_ context.Context, ch, ev string, payload any) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.events = append(r.events, ch+" "+ev)
	if ev == gifts.EventGift {
		raw, _ := json.Marshal(payload)
		var m map[string]any
		_ = json.Unmarshal(raw, &m)
		r.gifts = append(r.gifts, m)
	}
	return nil
}

func (r *recorder) count(ev string) int {
	r.mu.Lock()
	defer r.mu.Unlock()
	n := 0
	for _, e := range r.events {
		if len(e) >= len(ev) && e[len(e)-len(ev):] == ev {
			n++
		}
	}
	return n
}

type env struct {
	t            *testing.T
	api, admin   *pgxpool.Pool
	svc          *gifts.Service
	rec          *recorder
	customer     string
	host         string
	call         string
	pc, ph       auth.Principal
	staff        auth.Principal
	ctx          context.Context
	rules        economy.Rules
	callsService interface{}
}

func setup(t *testing.T) *env {
	t.Helper()
	api, admin := pgtest.Pools(t)
	e := &env{t: t, api: api, admin: admin, rec: &recorder{}, ctx: context.Background(), rules: economy.Founder()}
	e.svc = gifts.NewService(gifts.Deps{Repo: postgres.GiftsRepo{Pool: api}, Realtime: e.rec, Rules: e.rules,
		Limits: gifts.DefaultLimits(), Enabled: true})
	e.customer = pgtest.NewUser(t, admin, true)
	identitytest.Profile(t, admin, e.customer, "Asha", []string{"en"}, nil)
	e.host = callstest.Host(t, admin, 500)
	identitytest.Profile(t, admin, e.host, "Meera", []string{"en"}, nil)
	callstest.Fund(t, api, e.customer, 100_000)
	e.call = identitytest.Call(t, admin, e.customer, e.host, "active", 0, 0)
	e.pc = identitytest.Principal(e.customer)
	e.ph = callstest.Principal(e.host, auth.RoleHost)
	staffID := pgtest.NewUser(t, admin, true, "customer", "admin")
	e.staff = callstest.Principal(staffID, auth.RoleAdmin)
	return e
}

func (e *env) send(p auth.Principal, call, gift, recipient, key string) (gifts.SendGiftResponse, error) {
	return e.svc.SendGift(e.ctx, p, call, key, gifts.SendGiftRequest{GiftId: gift, RecipientUserId: recipient})
}

func (e *env) balance(user, kind string) int64 {
	e.t.Helper()
	var b int64
	if err := e.admin.QueryRow(e.ctx, `select coalesce(sum(b.balance), 0)::bigint from ledger.accounts a
		left join ledger.balances b on b.account_id = a.id where a.owner_user_id = $1 and a.kind = $2`, user, kind).Scan(&b); err != nil {
		e.t.Fatal(err)
	}
	return b
}

func (e *env) count(sql string, args ...any) int {
	e.t.Helper()
	var n int
	if err := e.admin.QueryRow(e.ctx, sql, args...).Scan(&n); err != nil {
		e.t.Fatal(err)
	}
	return n
}

// ledgerBalanced: every currency's postings sum to zero across the ledger.
func (e *env) ledgerBalanced() {
	e.t.Helper()
	if n := e.count(`select count(*) from (select currency, sum(amount) s from ledger.postings group by currency having sum(amount) <> 0) x`); n != 0 {
		e.t.Fatal("ledger out of balance")
	}
	if n := e.count(`select count(*) from ledger.balances b join (select account_id, sum(amount) s from ledger.postings group by account_id) p
		on p.account_id = b.account_id where p.s <> b.balance`); n != 0 {
		e.t.Fatal("balance projection differs from postings")
	}
}

func rule(err error) string {
	if a := apperr.As(err); a != nil {
		if a.Kind == apperr.KindValidation {
			for k, v := range a.Fields {
				return k + ":" + v
			}
		}
		return a.Code
	}
	if err != nil {
		return err.Error()
	}
	return ""
}

func TestSendGiftMovesMoneyOnceAndAppendsChat(t *testing.T) {
	e := setup(t)
	key := pgtest.UUID()
	out, err := e.send(e.pc, e.call, "rose", e.host, key)
	if err != nil {
		t.Fatal(err)
	}
	wantBeans, _ := e.rules.BeansForDiamonds(1500)
	if out.Replayed || out.Gift.DiamondValue != 1500 || out.Gift.GiftName != "Rose" || out.AvailableDiamonds != 98_500 {
		t.Fatalf("receipt %+v", out)
	}
	if out.Gift.Sender.DisplayName != "Asha" || out.Gift.Recipient.DisplayName != "Meera" || out.Gift.ChatMessageId == nil {
		t.Fatalf("parties %+v", out.Gift)
	}
	if got := e.balance(e.customer, "diamond_purchased"); got != 98_500 {
		t.Fatalf("customer diamonds %d", got)
	}
	if got := e.balance(e.host, "bean_held"); got != wantBeans {
		t.Fatalf("host beans %d, want %d", got, wantBeans)
	}
	if n := e.count(`select count(*) from ledger.journal_entries where entry_type = 'gift_send' and idempotency_key = 'gift_send:' || $1
		and rule_set_version = $2`, out.Gift.GiftTransactionId, e.rules.Version); n != 1 {
		t.Fatal("ledger entry missing")
	}
	if n := e.count(`select count(*) from chat.messages where kind = 'gift' and call_id = $1 and context = 'call'
		and body = '🌹 Asha sent Rose to Meera.' and sender_id = $2`, e.call, e.customer); n != 1 {
		t.Fatal("gift chat line missing")
	}
	if n := e.count(`select count(*) from ledger.xp_events where source_id = 'gift:' || $1 and user_id = $2`, out.Gift.GiftTransactionId, e.host); n != 1 {
		t.Fatal("host XP for gift Beans missing")
	}
	if e.rec.count(gifts.EventGift) != 1 || e.rec.count(gifts.EventChatMessage) != 2 {
		t.Fatalf("realtime %v", e.rec.events)
	}
	// Regression (2026-11-27): both wallets changed; both get a hint.
	if e.rec.count("user:"+e.customer+" "+gifts.EventWalletUpdated) != 1 || e.rec.count("user:"+e.host+" "+gifts.EventWalletUpdated) != 1 {
		t.Fatalf("wallet hints %v", e.rec.events)
	}
	// The realtime payload is public: no balances or ledger data.
	for _, k := range []string{"available_diamonds", "ledger_entry_id", "from_purchased", "host_beans", "rule_set_version"} {
		if _, ok := e.rec.gifts[0][k]; ok {
			t.Fatalf("realtime payload leaks %s", k)
		}
	}
	e.ledgerBalanced()

	// Retry with the same key and body: same gift, nothing charged again.
	again, err := e.send(e.pc, e.call, "rose", e.host, key)
	if err != nil || !again.Replayed || again.Gift.GiftTransactionId != out.Gift.GiftTransactionId {
		t.Fatalf("replay %+v %v", again, err)
	}
	if e.balance(e.customer, "diamond_purchased") != 98_500 || e.balance(e.host, "bean_held") != wantBeans {
		t.Fatal("replay moved money")
	}
	if e.count(`select count(*) from chat.messages where call_id = $1 and kind = 'gift'`, e.call) != 1 || e.rec.count(gifts.EventGift) != 1 {
		t.Fatal("replay duplicated chat line or realtime event")
	}
	// Same key, different gift: refused.
	if _, err := e.send(e.pc, e.call, "teddy", e.host, key); rule(err) != "Idempotency-Key:reused_with_different_request" {
		t.Fatalf("key reuse: %v", err)
	}
}

func TestConcurrentSameKeyChargesOnce(t *testing.T) {
	e := setup(t)
	key := pgtest.UUID()
	var wg sync.WaitGroup
	ids := make([]string, 8)
	errs := make([]error, 8)
	for i := range ids {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			out, err := e.send(e.pc, e.call, "teddy", e.host, key)
			ids[i], errs[i] = out.Gift.GiftTransactionId, err
		}(i)
	}
	wg.Wait()
	for i, err := range errs {
		if err != nil {
			t.Fatalf("attempt %d: %v", i, err)
		}
		if ids[i] != ids[0] {
			t.Fatal("concurrent retries produced different gifts")
		}
	}
	if e.count(`select count(*) from gifts.transactions where sender_id = $1`, e.customer) != 1 {
		t.Fatal("more than one gift recorded")
	}
	if got := e.balance(e.customer, "diamond_purchased"); got != 95_000 {
		t.Fatalf("charged %d", 100_000-got)
	}
	e.ledgerBalanced()
}

func TestConcurrentDifferentKeysNeverOverspend(t *testing.T) {
	e := setup(t)
	poor := pgtest.NewUser(t, e.admin, true)
	callstest.Fund(t, e.api, poor, 4000) // covers two roses, not three
	host2 := callstest.Host(t, e.admin, 500)
	call := identitytest.Call(t, e.admin, poor, host2, "active", 0, 0)
	pp := identitytest.Principal(poor)
	var wg sync.WaitGroup
	var mu sync.Mutex
	ok, insufficient := 0, 0
	for range 3 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			_, err := e.send(pp, call, "rose", host2, pgtest.UUID())
			mu.Lock()
			defer mu.Unlock()
			switch rule(err) {
			case "":
				ok++
			case "insufficient_diamonds":
				insufficient++
			default:
				t.Errorf("unexpected %v", err)
			}
		}()
	}
	wg.Wait()
	if ok != 2 || insufficient != 1 || e.balance(poor, "diamond_purchased") != 1000 {
		t.Fatalf("ok %d insufficient %d balance %d", ok, insufficient, e.balance(poor, "diamond_purchased"))
	}
	e.ledgerBalanced()
}

func TestReservedDiamondsCannotBeGifted(t *testing.T) {
	e := setup(t)
	if _, err := e.admin.Exec(e.ctx, `insert into ledger.diamond_reservations (user_id, call_id, amount, status)
		values ($1, $2, 99000, 'active')`, e.customer, e.call); err != nil {
		t.Fatal(err)
	}
	if _, err := e.send(e.pc, e.call, "rose", e.host, pgtest.UUID()); rule(err) != "insufficient_diamonds" {
		t.Fatalf("gift ate into the call reservation: %v", err)
	}
	if e.count(`select count(*) from gifts.transactions where sender_id = $1`, e.customer) != 0 {
		t.Fatal("entry posted")
	}
}

func TestSendRefusals(t *testing.T) {
	e := setup(t)
	ended := identitytest.Call(t, e.admin, e.customer, e.host, "ended", 30, time.Minute)
	ringing := pgtest.NewUser(t, e.admin, true)
	ringHost := callstest.Host(t, e.admin, 500)
	ringingCall := identitytest.Call(t, e.admin, ringing, ringHost, "ringing", 0, 0)
	other := callstest.Host(t, e.admin, 500)
	suspended := pgtest.NewUser(t, e.admin, true)
	callstest.Fund(t, e.api, suspended, 10_000)
	suspCall := identitytest.Call(t, e.admin, suspended, other, "active", 0, 0)
	if _, err := e.admin.Exec(e.ctx, `update identity.accounts set status = 'suspended' where id = $1`, suspended); err != nil {
		t.Fatal(err)
	}
	for _, c := range []struct {
		name            string
		p               auth.Principal
		call, gift, rcp string
		want            string
	}{
		{"ended call", e.pc, ended, "rose", e.host, "call_not_giftable"},
		{"ringing call", identitytest.Principal(ringing), ringingCall, "rose", ringHost, "call_not_giftable"},
		{"host sends", e.ph, e.call, "rose", e.host, "hosts_cannot_send_gifts"},
		{"wrong recipient", e.pc, e.call, "rose", other, "recipient_user_id:not_call_host"},
		{"not my call", e.pc, suspCall, "rose", other, "not_found"},
		{"suspended account", identitytest.Principal(suspended), suspCall, "rose", other, "account_restricted"},
		{"unknown gift", e.pc, e.call, "unicorn", e.host, "not_found"},
		{"insufficient", e.pc, e.call, "elite_gift", e.host, "insufficient_diamonds"},
	} {
		t.Run(c.name, func(t *testing.T) {
			if _, err := e.send(c.p, c.call, c.gift, c.rcp, pgtest.UUID()); rule(err) != c.want {
				t.Fatalf("want %s, got %v", c.want, err)
			}
		})
	}
	// Disabled gift.
	off, on := false, true
	if _, err := e.svc.AdminUpdateGift(e.ctx, e.staff, "rose", gifts.UpdateGiftRequest{Active: &off}); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_, _ = e.svc.AdminUpdateGift(context.Background(), e.staff, "rose", gifts.UpdateGiftRequest{Active: &on})
	})
	if _, err := e.send(e.pc, e.call, "rose", e.host, pgtest.UUID()); rule(err) != "gift_unavailable" {
		t.Fatalf("disabled gift: %v", err)
	}
	cat, err := e.svc.GetCatalogue(e.ctx, e.pc)
	if err != nil {
		t.Fatal(err)
	}
	for _, g := range cat.Items {
		if g.Id == "rose" {
			t.Fatal("disabled gift still in the catalogue")
		}
	}
	if len(cat.Items) != 9 {
		t.Fatalf("catalogue has %d gifts", len(cat.Items))
	}
	// Blocked pair.
	identitytest.Block(t, e.admin, e.host, e.customer)
	if _, err := e.send(e.pc, e.call, "teddy", e.host, pgtest.UUID()); rule(err) != "blocked" {
		t.Fatalf("blocked: %v", err)
	}
	if e.count(`select count(*) from gifts.transactions where sender_id in ($1, $2, $3)`, e.customer, ringing, suspended) != 0 ||
		e.count(`select count(*) from ledger.journal_entries where entry_type = 'gift_send' and metadata->>'customer_id' in ($1, $2, $3)`,
			e.customer, ringing, suspended) != 0 {
		t.Fatal("a refused gift left rows behind")
	}
}

func TestHostAccountCannotSendEvenAsCaller(t *testing.T) {
	e := setup(t)
	hostCaller := callstest.Host(t, e.admin, 500)
	callee := callstest.Host(t, e.admin, 500)
	callstest.Fund(t, e.api, hostCaller, 10_000)
	call := identitytest.Call(t, e.admin, hostCaller, callee, "active", 0, 0)
	if _, err := e.send(callstest.Principal(hostCaller, auth.RoleHost), call, "rose", callee, pgtest.UUID()); rule(err) != "hosts_cannot_send_gifts" {
		t.Fatalf("host-to-host gift: %v", err)
	}
}

func TestFailureAfterChargeRollsEverythingBack(t *testing.T) {
	e := setup(t)
	// Make the chat insert (after the ledger entry) fail inside the send.
	if _, err := e.admin.Exec(e.ctx, `
		create function public.fail_gift_line() returns trigger language plpgsql as $$
		begin raise exception 'forced failure'; end $$;
		create trigger fail_gift_line before insert on chat.messages for each row
		  when (new.kind = 'gift') execute function public.fail_gift_line();`); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_, _ = e.admin.Exec(context.Background(), `drop trigger if exists fail_gift_line on chat.messages; drop function if exists public.fail_gift_line();`)
	})
	if _, err := e.send(e.pc, e.call, "rose", e.host, pgtest.UUID()); err == nil {
		t.Fatal("expected failure")
	}
	if e.balance(e.customer, "diamond_purchased") != 100_000 || e.balance(e.host, "bean_held") != 0 {
		t.Fatal("money moved on a failed gift")
	}
	if e.count(`select count(*) from gifts.transactions where sender_id = $1`, e.customer) != 0 ||
		e.count(`select count(*) from ledger.journal_entries where entry_type = 'gift_send' and metadata->>'customer_id' = $1`, e.customer) != 0 {
		t.Fatal("partial gift left behind")
	}
	if e.rec.count(gifts.EventGift) != 0 {
		t.Fatal("no celebration may be announced for a failed gift")
	}
	e.ledgerBalanced()
}

func TestRateLimitPerCall(t *testing.T) {
	e := setup(t)
	for i := range 6 {
		if _, err := e.send(e.pc, e.call, "rose", e.host, pgtest.UUID()); err != nil {
			t.Fatalf("gift %d: %v", i, err)
		}
	}
	if _, err := e.send(e.pc, e.call, "rose", e.host, pgtest.UUID()); rule(err) != "gift_rate_limited" {
		t.Fatalf("7th gift in a minute: %v", err)
	}
}

func TestPriceChangeNeverRepricesHistory(t *testing.T) {
	e := setup(t)
	first, err := e.send(e.pc, e.call, "rose", e.host, pgtest.UUID())
	if err != nil {
		t.Fatal(err)
	}
	if _, err := e.svc.AdminChangePrice(e.ctx, e.staff, "rose", gifts.ChangePriceRequest{DiamondPrice: 2000, Reason: "test reprice"}); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_, _ = e.svc.AdminChangePrice(context.Background(), e.staff, "rose", gifts.ChangePriceRequest{DiamondPrice: 1500, Reason: "test restore"})
	})
	if e.count(`select count(*) from audit.events where action = 'gift.price_changed' and target = 'rose' and actor = $1`, e.staff.UserID) != 1 {
		t.Fatal("price change not audited")
	}
	hist, err := e.svc.AdminPriceHistory(e.ctx, "rose")
	if err != nil || len(hist) < 2 || hist[0].NewPrice != 2000 || *hist[0].OldPrice != 1500 || hist[len(hist)-1].OldPrice != nil {
		t.Fatalf("history %+v %v", hist, err)
	}
	second, err := e.send(e.pc, e.call, "rose", e.host, pgtest.UUID())
	if err != nil || second.Gift.DiamondValue != 2000 {
		t.Fatalf("new price not applied: %+v %v", second, err)
	}
	calls, err := e.svc.ListCallGifts(e.ctx, e.ph, e.call)
	if err != nil || len(calls.Items) != 2 {
		t.Fatalf("call gifts %+v %v", calls, err)
	}
	if calls.Items[0].GiftTransactionId != first.Gift.GiftTransactionId || calls.Items[0].DiamondValue != 1500 || calls.Items[1].DiamondValue != 2000 {
		t.Fatalf("history repriced or out of order: %+v", calls.Items)
	}
	if e.balance(e.customer, "diamond_purchased") != 100_000-3500 {
		t.Fatal("wrong total charge")
	}
	// Transactions are immutable even for the service role.
	if _, err := e.api.Exec(e.ctx, `update gifts.transactions set diamond_price = 1 where id = $1`, first.Gift.GiftTransactionId); err == nil {
		t.Fatal("gift transaction was mutable")
	}
	// Only admins change prices; validation on the reason.
	if _, err := e.svc.AdminChangePrice(e.ctx, e.staff, "rose", gifts.ChangePriceRequest{DiamondPrice: 0, Reason: "x"}); err == nil {
		t.Fatal("invalid price accepted")
	}
}

func TestHistoriesAndChatAfterCall(t *testing.T) {
	e := setup(t)
	out, err := e.send(e.pc, e.call, "diamond_ring", e.host, pgtest.UUID())
	if err != nil {
		t.Fatal(err)
	}
	sent, err := e.svc.ListSentGifts(e.ctx, e.pc, gifts.PageRequest{Limit: 20})
	if err != nil || len(sent.Items) != 1 || sent.Items[0].DiamondCost != 25_000 || sent.Items[0].Recipient.UserId != e.host {
		t.Fatalf("sent %+v %v", sent, err)
	}
	got, err := e.svc.ListReceivedGifts(e.ctx, e.ph, gifts.PageRequest{Limit: 20})
	wantBeans, _ := e.rules.BeansForDiamonds(25_000)
	if err != nil || len(got.Items) != 1 || got.Items[0].BeansEarned != wantBeans || got.Items[0].SettlementStatus != "on_hold" ||
		got.Items[0].Sender.DisplayName != "Asha" {
		t.Fatalf("received %+v %v", got, err)
	}
	sum, err := e.svc.GetReceivedSummary(e.ctx, e.ph)
	if err != nil || sum.TotalGifts != 1 || sum.TotalBeans != wantBeans || sum.TodayGifts != 1 {
		t.Fatalf("summary %+v %v", sum, err)
	}
	// Strangers cannot read a call's gifts.
	stranger := pgtest.NewUser(t, e.admin, true)
	if _, err := e.svc.ListCallGifts(e.ctx, identitytest.Principal(stranger), e.call); rule(err) != "not_found" {
		t.Fatalf("stranger read call gifts: %v", err)
	}

	cs := chat.NewService(chat.Deps{Repo: postgres.ChatRepo{Pool: e.api, MessageContext: true, Gifts: true}, MessageContext: true})
	convs, err := cs.ListConversations(e.ctx, e.ph, chat.PageRequest{Limit: 10})
	if err != nil || len(convs.Items) != 1 {
		t.Fatalf("conversations %+v %v", convs, err)
	}
	conv := convs.Items[0].Id
	session, err := cs.ListMessages(e.ctx, e.ph, conv, chat.PageRequest{Limit: 10, CallID: &e.call})
	if err != nil || len(session.Items) != 1 || session.Items[0].Kind != "gift" || session.Items[0].Gift == nil ||
		session.Items[0].Gift.GiftTransactionId != out.Gift.GiftTransactionId || session.Items[0].Id != *out.Gift.ChatMessageId {
		t.Fatalf("in-call chat %+v %v", session.Items, err)
	}
	inbox, _ := cs.ListMessages(e.ctx, e.ph, conv, chat.PageRequest{Limit: 10})
	if len(inbox.Items) != 0 {
		t.Fatal("a live call's gift line must stay in the session until the call ends")
	}
	if _, err := e.admin.Exec(e.ctx, `update calls.calls set phase = 'ended', ended_at = now() where id = $1`, e.call); err != nil {
		t.Fatal(err)
	}
	for _, p := range []auth.Principal{e.pc, e.ph} {
		inbox, err = cs.ListMessages(e.ctx, p, conv, chat.PageRequest{Limit: 10})
		if err != nil || len(inbox.Items) != 1 || inbox.Items[0].Kind != "gift" || inbox.Items[0].Body != "💎 Asha sent Diamond Ring to Meera." {
			t.Fatalf("main chat after call %+v %v", inbox.Items, err)
		}
	}
	// No more gifts once the call has ended.
	if _, err := e.send(e.pc, e.call, "rose", e.host, pgtest.UUID()); rule(err) != "call_not_giftable" {
		t.Fatalf("gift after end: %v", err)
	}
}

func TestGiftBeansFollowTheHold(t *testing.T) {
	e := setup(t)
	if _, err := e.send(e.pc, e.call, "watch", e.host, pgtest.UUID()); err != nil {
		t.Fatal(err)
	}
	held := e.balance(e.host, "bean_held")
	repo := postgres.HostsRepo{Pool: e.api, Tx: db.TxManager{Pool: e.api}}
	n, err := repo.ReleaseDueBeanHolds(e.ctx, time.Now().Add(time.Minute), time.Now(), 100)
	if err != nil || n < 1 {
		t.Fatalf("released %d %v", n, err)
	}
	if e.balance(e.host, "bean_held") != 0 || e.balance(e.host, "bean_available") != held {
		t.Fatal("gift Beans not released after the hold")
	}
	e.ledgerBalanced()
}

func TestDisabledFlagRefuses(t *testing.T) {
	e := setup(t)
	off := gifts.NewService(gifts.Deps{Repo: postgres.GiftsRepo{Pool: e.api}, Rules: e.rules})
	if _, err := off.SendGift(e.ctx, e.pc, e.call, pgtest.UUID(), gifts.SendGiftRequest{GiftId: "rose", RecipientUserId: e.host}); rule(err) != "gifts_disabled" {
		t.Fatalf("flag off: %v", err)
	}
	// Admin catalogue tools work while gifting is off.
	if items, err := off.AdminListGifts(e.ctx); err != nil || len(items) != 10 {
		t.Fatalf("admin list %d %v", len(items), err)
	}
}

func TestAdminCreateUpdateRetire(t *testing.T) {
	e := setup(t)
	g, err := e.svc.AdminCreateGift(e.ctx, e.staff, gifts.CreateGiftRequest{Id: "star", Name: "Star", Emoji: "⭐", IconAsset: "gift/star",
		AnimationAsset: "celebration/star", Tier: "rare", SortOrder: 15, DiamondPrice: 3000, Active: true, Reason: "festival"})
	if err != nil || g.DiamondPrice != 3000 || g.AnimationDurationMs != 5000 {
		t.Fatalf("create %+v %v", g, err)
	}
	if _, err := e.svc.AdminCreateGift(e.ctx, e.staff, gifts.CreateGiftRequest{Id: "star", Name: "Star", Emoji: "⭐", IconAsset: "a",
		AnimationAsset: "b", Tier: "rare", DiamondPrice: 3000, Reason: "dup"}); rule(err) != "gift_exists" {
		t.Fatalf("duplicate: %v", err)
	}
	from := time.Now().Add(time.Hour)
	if _, err := e.svc.AdminUpdateGift(e.ctx, e.staff, "star", gifts.UpdateGiftRequest{AvailableFrom: &from}); err != nil {
		t.Fatal(err)
	}
	if _, err := e.send(e.pc, e.call, "star", e.host, pgtest.UUID()); rule(err) != "gift_unavailable" {
		t.Fatalf("scheduled gift sold early: %v", err)
	}
	if _, err := e.svc.AdminUpdateGift(e.ctx, e.staff, "star", gifts.UpdateGiftRequest{Retire: true}); err != nil {
		t.Fatal(err)
	}
	on := true
	if _, err := e.svc.AdminUpdateGift(e.ctx, e.staff, "star", gifts.UpdateGiftRequest{Active: &on}); rule(err) != "gift_retired" {
		t.Fatalf("retired gift reactivated: %v", err)
	}
	perf, err := e.svc.AdminPerformance(e.ctx, 30)
	if err != nil || len(perf) != 11 {
		t.Fatalf("performance %d %v", len(perf), err)
	}
	if e.count(`select count(*) from audit.events where target = 'star' and action in ('gift.created','gift.updated')`) != 3 {
		t.Fatal("catalogue changes not audited")
	}
}
