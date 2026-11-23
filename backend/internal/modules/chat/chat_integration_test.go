//go:build integration

package chat_test

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/chat"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/testsupport/identitytest"
	"dashuri/backend/internal/testsupport/pgtest"
)

type recorder struct {
	mu     sync.Mutex
	events []string
}

func (r *recorder) Publish(_ context.Context, ch, ev string, payload any) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.events = append(r.events, ch+" "+ev+" "+payload.(map[string]string)["conversation_id"])
	return nil
}

func code(err error) string {
	if e := apperr.As(err); e != nil {
		return e.Code
	}
	return ""
}

func TestChatFlowPrivacyAndBlocks(t *testing.T) {
	api, admin := pgtest.Pools(t)
	ctx := context.Background()
	rec := &recorder{}
	var pushed []string
	s := chat.NewService(chat.Deps{Repo: postgres.ChatRepo{Pool: api}, Realtime: rec,
		Push: func(_ context.Context, to, conv string) { pushed = append(pushed, to) }})

	a, b := pgtest.NewUser(t, admin, true), pgtest.NewUser(t, admin, true)
	identitytest.Profile(t, admin, a, "Arjun", nil, nil)
	identitytest.Profile(t, admin, b, "Bina", nil, nil)
	pa, pb := identitytest.Principal(a), identitytest.Principal(b)

	conv, err := s.StartConversation(ctx, pa, chat.StartConversationRequest{PeerUserId: b})
	if err != nil || conv.Peer.DisplayName != "Bina" || conv.LastMessage != nil {
		t.Fatalf("start: %+v %v", conv, err)
	}
	again, _ := s.StartConversation(ctx, pb, chat.StartConversationRequest{PeerUserId: a})
	if again.Id != conv.Id || again.Peer.UserId != a {
		t.Fatalf("canonical pair: %+v", again)
	}
	var ua, ub string
	_ = admin.QueryRow(ctx, `select user_a, user_b from chat.conversations where id = $1`, conv.Id).Scan(&ua, &ub)
	if !(ua < ub) {
		t.Fatalf("not canonical: %s %s", ua, ub)
	}

	for i, body := range []string{"hello", "how are you?", "  third  "} {
		m, err := s.SendMessage(ctx, pa, conv.Id, chat.SendMessageRequest{Body: body})
		if err != nil {
			t.Fatalf("send %d: %v", i, err)
		}
		if i == 2 && m.Body != "third" {
			t.Fatalf("not trimmed: %q", m.Body)
		}
	}
	if len(rec.events) != 3 || rec.events[0] != "user:"+b+" chat.message "+conv.Id || len(pushed) != 3 {
		t.Fatalf("events %v pushed %v", rec.events, pushed)
	}
	_, err = s.SendMessage(ctx, pa, conv.Id, chat.SendMessageRequest{Body: "pay me at arjun@okicici"})
	if code(err) != "message_rejected" || apperr.As(err).Fields["body"] != "contact_details" {
		t.Fatalf("filter: %v", err)
	}

	list, err := s.ListConversations(ctx, pb, chat.PageRequest{Limit: 20})
	if err != nil || len(list.Items) != 1 || list.Items[0].UnreadCount != 3 || list.Items[0].LastMessage.Body != "third" ||
		*list.Items[0].LastMessagePreview != "third" {
		t.Fatalf("list b: %+v %v", list, err)
	}
	if la, _ := s.ListConversations(ctx, pa, chat.PageRequest{Limit: 20}); la.Items[0].UnreadCount != 0 {
		t.Fatalf("sender sees own messages as unread: %+v", la.Items[0])
	}
	if err := s.MarkRead(ctx, pb, conv.Id); err != nil {
		t.Fatal(err)
	}
	if list, _ = s.ListConversations(ctx, pb, chat.PageRequest{Limit: 20}); list.Items[0].UnreadCount != 0 {
		t.Fatalf("after read: %+v", list.Items[0])
	}

	// Message pagination, newest first.
	p1, _ := s.ListMessages(ctx, pb, conv.Id, chat.PageRequest{Limit: 2})
	if len(p1.Items) != 2 || p1.Items[0].Body != "third" || p1.NextCursor == nil {
		t.Fatalf("page1 %+v", p1)
	}
	p2, _ := s.ListMessages(ctx, pb, conv.Id, chat.PageRequest{Limit: 2, Cursor: *p1.NextCursor})
	if len(p2.Items) != 1 || p2.Items[0].Body != "hello" || p2.NextCursor != nil {
		t.Fatalf("page2 %+v", p2)
	}
	outsider := identitytest.Principal(pgtest.NewUser(t, admin, true))
	if _, err := s.ListMessages(ctx, outsider, conv.Id, chat.PageRequest{Limit: 2}); apperr.As(err).Kind != apperr.KindNotFound {
		t.Fatalf("outsider read: %v", err)
	}
	if _, err := s.SendMessage(ctx, outsider, conv.Id, chat.SendMessageRequest{Body: "hi"}); apperr.As(err).Kind != apperr.KindNotFound {
		t.Fatalf("outsider send: %v", err)
	}

	// Blocks either way stop messaging and hide the conversation.
	identitytest.Block(t, admin, b, a)
	if _, err := s.SendMessage(ctx, pa, conv.Id, chat.SendMessageRequest{Body: "hi"}); code(err) != "blocked" {
		t.Fatalf("blocked send: %v", err)
	}
	if _, err := s.StartConversation(ctx, pb, chat.StartConversationRequest{PeerUserId: a}); code(err) != "blocked" {
		t.Fatalf("blocked start: %v", err)
	}
	if la, _ := s.ListConversations(ctx, pa, chat.PageRequest{Limit: 20}); len(la.Items) != 0 {
		t.Fatalf("blocked conversation listed: %+v", la)
	}
}

func TestMessagingPrivacyAndEligibility(t *testing.T) {
	api, admin := pgtest.Pools(t)
	ctx := context.Background()
	s := chat.NewService(chat.Deps{Repo: postgres.ChatRepo{Pool: api}})
	a, c := pgtest.NewUser(t, admin, true), pgtest.NewUser(t, admin, true)
	identitytest.Profile(t, admin, c, "Chitra", nil, nil)
	pa, pc := identitytest.Principal(a), identitytest.Principal(c)

	if mp, err := s.GetMessagingPrivacy(ctx, pc); err != nil || mp.WhoCanMessage != "everyone" {
		t.Fatalf("default: %+v %v", mp, err)
	}
	if _, err := s.UpdateMessagingPrivacy(ctx, pc, chat.MessagingPrivacy{WhoCanMessage: "past_call_partners"}); err != nil {
		t.Fatal(err)
	}
	if _, err := s.StartConversation(ctx, pa, chat.StartConversationRequest{PeerUserId: c}); code(err) != "messaging_not_allowed" {
		t.Fatalf("no call: %v", err)
	}
	identitytest.Call(t, admin, a, c, "ended", 0, time.Hour) // unbilled call does not count
	if _, err := s.StartConversation(ctx, pa, chat.StartConversationRequest{PeerUserId: c}); code(err) != "messaging_not_allowed" {
		t.Fatalf("unbilled call: %v", err)
	}
	identitytest.Call(t, admin, c, a, "ended", 45, time.Hour)
	conv, err := s.StartConversation(ctx, pa, chat.StartConversationRequest{PeerUserId: c})
	if err != nil {
		t.Fatalf("past partner: %v", err)
	}
	if _, err := s.SendMessage(ctx, pa, conv.Id, chat.SendMessageRequest{Body: "thanks for the call"}); err != nil {
		t.Fatal(err)
	}

	minor := identitytest.Principal(pgtest.NewUser(t, admin, false))
	minor.AgeEligible = false
	if _, err := s.StartConversation(ctx, minor, chat.StartConversationRequest{PeerUserId: a}); code(err) != "not_age_eligible" {
		t.Fatalf("minor: %v", err)
	}
	restricted := identitytest.Principal(pgtest.NewUser(t, admin, true))
	restricted.Status = "restricted"
	if _, err := s.StartConversation(ctx, restricted, chat.StartConversationRequest{PeerUserId: a}); code(err) != "account_restricted" {
		t.Fatalf("restricted: %v", err)
	}
	ineligiblePeer := pgtest.NewUser(t, admin, false)
	if _, err := s.StartConversation(ctx, pa, chat.StartConversationRequest{PeerUserId: ineligiblePeer}); code(err) != "messaging_not_allowed" {
		t.Fatalf("ineligible peer: %v", err)
	}
	if _, err := s.StartConversation(ctx, pa, chat.StartConversationRequest{PeerUserId: a}); code(err) != "validation_failed" {
		t.Fatalf("self: %v", err)
	}
}

// ---------------------------------------------------------------------------
// EXPERIMENT — unified chat + in-call messaging (docs/chat). Real Postgres,
// migration 20261123000200 applied, CHAT_MESSAGE_CONTEXT_ENABLED on.

func strp(s string) *string { return &s }

// moneySnapshot is everything a message must never change: ledger rows,
// balances, reservations and the call's billing columns.
func moneySnapshot(t *testing.T, admin *pgxpool.Pool, callID string) string {
	t.Helper()
	var s string
	err := admin.QueryRow(context.Background(), `
		select concat_ws('|',
		  (select count(*) from ledger.journal_entries),
		  (select count(*) from ledger.postings),
		  (select coalesce(sum(balance), 0) from ledger.balances),
		  (select count(*) from ledger.diamond_reservations),
		  (select concat_ws(',', phase, billed_seconds, diamonds_charged) from calls.calls where id = $1))`, callID).Scan(&s)
	if err != nil {
		t.Fatal(err)
	}
	return s
}

func TestInCallChatIsTheSameConversation(t *testing.T) {
	api, admin := pgtest.Pools(t)
	ctx := context.Background()
	rec := &recorder{}
	var pushed []string
	s := chat.NewService(chat.Deps{Repo: postgres.ChatRepo{Pool: api, MessageContext: true}, Realtime: rec, MessageContext: true,
		Push: func(_ context.Context, to, _ string) { pushed = append(pushed, to) }})

	cust, host := pgtest.NewUser(t, admin, true), pgtest.NewUser(t, admin, true, "customer", "host")
	identitytest.Profile(t, admin, cust, "Arjun", nil, nil)
	identitytest.Profile(t, admin, host, "Bina", nil, nil)
	pc, ph := identitytest.Principal(cust), identitytest.Principal(host)

	// Normal chat first (host accepts everyone for now).
	conv, err := s.StartConversation(ctx, pc, chat.StartConversationRequest{PeerUserId: host})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := s.SendMessage(ctx, pc, conv.Id, chat.SendMessageRequest{Body: "before the call"}); err != nil {
		t.Fatal(err)
	}
	// Host restricts to past call partners, then they start a call.
	if _, err := s.UpdateMessagingPrivacy(ctx, ph, chat.MessagingPrivacy{WhoCanMessage: "past_call_partners"}); err != nil {
		t.Fatal(err)
	}
	if _, err := s.SendMessage(ctx, pc, conv.Id, chat.SendMessageRequest{Body: "no call yet"}); code(err) != "messaging_not_allowed" {
		t.Fatalf("restricted before call: %v", err)
	}
	callID := identitytest.Call(t, admin, cust, host, "active", 0, 0)
	before := moneySnapshot(t, admin, callID)

	// The in-call panel opens the pair's conversation: same id, no new one.
	again, err := s.StartConversation(ctx, pc, chat.StartConversationRequest{PeerUserId: host})
	if err != nil || again.Id != conv.Id {
		t.Fatalf("in-call start must reuse the conversation: %+v %v", again, err)
	}
	clientID := pgtest.UUID()
	inCall := chat.SendMessageRequest{Body: "can you hear me?", Context: strp(chat.ContextCall), CallId: &callID, ClientMessageId: &clientID}
	m1, err := s.SendMessage(ctx, pc, conv.Id, inCall)
	if err != nil || m1.Context != chat.ContextCall {
		t.Fatalf("in-call send: %+v %v", m1, err)
	}
	// Reconnect: the same message again stores nothing and announces nothing.
	rec.events, pushed = nil, nil
	dup, err := s.SendMessage(ctx, pc, conv.Id, inCall)
	if err != nil || dup.Id != m1.Id || len(rec.events) != 0 {
		t.Fatalf("duplicate: %+v %v events=%v", dup, err, rec.events)
	}
	var n int
	_ = admin.QueryRow(ctx, `select count(*) from chat.messages where client_message_id = $1`, clientID).Scan(&n)
	if n != 1 {
		t.Fatalf("rows for client id: %d", n)
	}
	// The host replies from the in-call panel, the customer from the inbox.
	m2, err := s.SendMessage(ctx, ph, conv.Id, chat.SendMessageRequest{Body: "yes, loud and clear", Context: strp(chat.ContextCall), CallId: &callID})
	if err != nil {
		t.Fatal(err)
	}
	m3, err := s.SendMessage(ctx, pc, conv.Id, chat.SendMessageRequest{Body: "typed in the inbox"})
	if err != nil || m3.Context != chat.ContextChat {
		t.Fatal(err)
	}
	if len(pushed) != 1 || pushed[0] != host {
		t.Fatalf("push only for the inbox message: %v", pushed)
	}

	// A call between other people cannot be used as context.
	stranger := pgtest.NewUser(t, admin, true)
	foreign := identitytest.Call(t, admin, stranger, host, "ended", 60, time.Minute)
	if _, err := s.SendMessage(ctx, pc, conv.Id, chat.SendMessageRequest{Body: "x", Context: strp(chat.ContextCall), CallId: &foreign}); apperr.As(err) == nil ||
		apperr.As(err).Fields["call_id"] != "not_found" {
		t.Fatalf("foreign call: %v", err)
	}

	// Messaging moved no money and did not touch the call.
	if after := moneySnapshot(t, admin, callID); after != before {
		t.Fatalf("money/call changed by messaging:\n before %s\n after  %s", before, after)
	}

	// The call ends (billed). History survives; both keep chatting.
	if _, err := admin.Exec(ctx, `update calls.calls set phase = 'ended', billed_seconds = 120, ended_at = now() where id = $1`, callID); err != nil {
		t.Fatal(err)
	}
	page, err := s.ListMessages(ctx, ph, conv.Id, chat.PageRequest{Limit: 20})
	if err != nil {
		t.Fatal(err)
	}
	var bodies []string
	for _, m := range page.Items {
		bodies = append(bodies, m.Body+"/"+m.Context)
	}
	want := "typed in the inbox/chat,yes, loud and clear/call,can you hear me?/call,before the call/chat"
	if got := strings.Join(bodies, ","); got != want {
		t.Fatalf("history after call end:\n got  %s\n want %s", got, want)
	}
	if _, err := s.SendMessage(ctx, pc, conv.Id, chat.SendMessageRequest{Body: "thanks for the call"}); err != nil {
		t.Fatalf("past partner after call: %v", err)
	}
	if list, _ := s.ListConversations(ctx, ph, chat.PageRequest{Limit: 20}); len(list.Items) != 1 || list.Items[0].Id != conv.Id {
		t.Fatalf("one conversation per pair: %+v", list.Items)
	}

	// Read state: the host reads; the customer's messages show as read.
	rec.events = nil
	if err := s.MarkRead(ctx, ph, conv.Id); err != nil {
		t.Fatal(err)
	}
	if err := s.MarkRead(ctx, ph, conv.Id); err != nil {
		t.Fatal(err)
	}
	if len(rec.events) != 1 || rec.events[0] != "user:"+cust+" chat.read "+conv.Id {
		t.Fatalf("read events: %v", rec.events)
	}
	mine, _ := s.ListMessages(ctx, pc, conv.Id, chat.PageRequest{Limit: 20})
	for _, m := range mine.Items {
		if (m.SenderId == cust) != m.ReadByPeer {
			t.Fatalf("read_by_peer for %q: %v", m.Body, m.ReadByPeer)
		}
	}
	_ = m2

	// Outsiders see nothing; a block mid-conversation stops both panels.
	outsider := identitytest.Principal(stranger)
	if _, err := s.ListMessages(ctx, outsider, conv.Id, chat.PageRequest{Limit: 5}); apperr.As(err).Kind != apperr.KindNotFound {
		t.Fatalf("outsider read: %v", err)
	}
	if _, err := s.SendMessage(ctx, outsider, conv.Id, chat.SendMessageRequest{Body: "hi", Context: strp(chat.ContextCall), CallId: &callID}); apperr.As(err).Kind != apperr.KindNotFound {
		t.Fatalf("outsider in-call send: %v", err)
	}
	live := identitytest.Call(t, admin, cust, host, "active", 0, 0)
	identitytest.Block(t, admin, host, cust)
	if _, err := s.SendMessage(ctx, pc, conv.Id, chat.SendMessageRequest{Body: "hi", Context: strp(chat.ContextCall), CallId: &live}); code(err) != "blocked" {
		t.Fatalf("blocked in-call send: %v", err)
	}
	if _, err := s.SendMessage(ctx, ph, conv.Id, chat.SendMessageRequest{Body: "hi"}); code(err) != "blocked" {
		t.Fatalf("blocker cannot message either: %v", err)
	}
}

func TestInCallChatOrderingAndPagination(t *testing.T) {
	api, admin := pgtest.Pools(t)
	ctx := context.Background()
	s := chat.NewService(chat.Deps{Repo: postgres.ChatRepo{Pool: api, MessageContext: true}, MessageContext: true})
	a, b := pgtest.NewUser(t, admin, true), pgtest.NewUser(t, admin, true)
	pa, pb := identitytest.Principal(a), identitytest.Principal(b)
	callID := identitytest.Call(t, admin, a, b, "active", 0, 0)
	conv, err := s.StartConversation(ctx, pa, chat.StartConversationRequest{PeerUserId: b})
	if err != nil {
		t.Fatal(err)
	}
	const total = 25
	for i := range total {
		p, req := pa, chat.SendMessageRequest{Body: fmt.Sprintf("m%02d", i)}
		if i%2 == 1 {
			p, req.Context, req.CallId = pb, strp(chat.ContextCall), &callID
		}
		if _, err := s.SendMessage(ctx, p, conv.Id, req); err != nil {
			t.Fatal(err)
		}
	}
	walk := func(call *string) []string {
		var seen []string
		cursor := ""
		for range 10 {
			page, err := s.ListMessages(ctx, pb, conv.Id, chat.PageRequest{Limit: 7, Cursor: cursor, CallID: call})
			if err != nil {
				t.Fatal(err)
			}
			for _, m := range page.Items {
				seen = append(seen, m.Body)
			}
			if page.NextCursor == nil {
				break
			}
			cursor = *page.NextCursor
		}
		return seen
	}
	check := func(seen []string, want func(i int) bool) {
		t.Helper()
		var exp []string
		for i := total - 1; i >= 0; i-- {
			if want(i) {
				exp = append(exp, fmt.Sprintf("m%02d", i))
			}
		}
		if strings.Join(seen, ",") != strings.Join(exp, ",") {
			t.Fatalf("got  %v\nwant %v", seen, exp)
		}
	}
	// Call live: the session holds the odd messages, normal Chat the even.
	check(walk(&callID), func(i int) bool { return i%2 == 1 })
	check(walk(nil), func(i int) bool { return i%2 == 0 })
	// Call ended: every message exactly once, strictly newest first.
	if _, err := admin.Exec(ctx, `update calls.calls set phase = 'ended', ended_at = now() where id = $1`, callID); err != nil {
		t.Fatal(err)
	}
	check(walk(nil), func(int) bool { return true })
}

func TestChatWithContextDisabledUsesTheOldColumns(t *testing.T) {
	api, admin := pgtest.Pools(t)
	ctx := context.Background()
	s := chat.NewService(chat.Deps{Repo: postgres.ChatRepo{Pool: api}})
	a, b := pgtest.NewUser(t, admin, true), pgtest.NewUser(t, admin, true)
	callID := identitytest.Call(t, admin, a, b, "active", 0, 0)
	conv, _ := s.StartConversation(ctx, identitytest.Principal(a), chat.StartConversationRequest{PeerUserId: b})
	m, err := s.SendMessage(ctx, identitytest.Principal(a), conv.Id,
		chat.SendMessageRequest{Body: "from the call", Context: strp(chat.ContextCall), CallId: &callID})
	if err != nil || m.Context != chat.ContextChat {
		t.Fatalf("%+v %v", m, err)
	}
	var stored *string
	_ = admin.QueryRow(ctx, `select context from chat.messages where id = $1`, m.Id).Scan(&stored)
	if stored != nil {
		t.Fatalf("metadata written with the flag off: %v", *stored)
	}
}
