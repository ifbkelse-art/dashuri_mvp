//go:build integration

package chat_test

// Video-call session chat against real Postgres (migration 20261123000200,
// CHAT_MESSAGE_CONTEXT_ENABLED on): isolation while the call is live,
// joining normal Chat when the call ends (by /end or the stale-call job),
// multiple calls, ordering, duplicates, access and billing.

import (
	"context"
	"strings"
	"testing"
	"time"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/chat"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/testsupport/identitytest"
	"dashuri/backend/internal/testsupport/pgtest"
)

func TestCallSessionChat(t *testing.T) {
	api, admin := pgtest.Pools(t)
	ctx := context.Background()
	rec := &recorder{}
	s := chat.NewService(chat.Deps{Repo: postgres.ChatRepo{Pool: api, MessageContext: true}, Realtime: rec, MessageContext: true})

	a, b := pgtest.NewUser(t, admin, true), pgtest.NewUser(t, admin, true)
	pa, pb := identitytest.Principal(a), identitytest.Principal(b)
	conv, err := s.StartConversation(ctx, pa, chat.StartConversationRequest{PeerUserId: b})
	if err != nil {
		t.Fatal(err)
	}
	send := func(p string, call *string, body string) chat.ChatMessage {
		t.Helper()
		req := chat.SendMessageRequest{Body: body}
		if call != nil {
			req.Context, req.CallId = strp(chat.ContextCall), call
		}
		m, err := s.SendMessage(ctx, identitytest.Principal(p), conv.Id, req)
		if err != nil {
			t.Fatalf("send %q: %v", body, err)
		}
		return m
	}
	list := func(p string, call *string) []chat.ChatMessage {
		t.Helper()
		page, err := s.ListMessages(ctx, identitytest.Principal(p), conv.Id, chat.PageRequest{Limit: 100, CallID: call})
		if err != nil {
			t.Fatal(err)
		}
		return page.Items
	}
	joined := func(ms []chat.ChatMessage) string {
		var out []string
		for i := len(ms) - 1; i >= 0; i-- {
			out = append(out, ms[i].Body)
		}
		return strings.Join(out, ",")
	}
	end := func(call string) {
		t.Helper()
		if _, err := admin.Exec(ctx, `update calls.calls set phase = 'ended', ended_at = now() where id = $1`, call); err != nil {
			t.Fatal(err)
		}
	}

	send(a, nil, "hello")
	send(b, nil, "hi there")

	// 1. A new call's session does not show normal-chat history.
	c1 := identitytest.Call(t, admin, a, b, "active", 0, 0)
	before := moneySnapshot(t, admin, c1)
	if got := joined(list(a, &c1)); got != "" {
		t.Fatalf("session must start empty: %q", got)
	}
	m1 := send(a, &c1, "c1: can you hear me")
	send(b, &c1, "c1: yes")
	// 3/4. Both participants see the same session.
	if ga, gb := joined(list(a, &c1)), joined(list(b, &c1)); ga != "c1: can you hear me,c1: yes" || ga != gb {
		t.Fatalf("session views: %q / %q", ga, gb)
	}
	// Isolated while live: normal Chat, the inbox preview and unread count
	// do not include it yet.
	if got := joined(list(b, nil)); got != "hello,hi there" {
		t.Fatalf("normal Chat during call: %q", got)
	}
	inbox, _ := s.ListConversations(ctx, pb, chat.PageRequest{Limit: 10})
	if len(inbox.Items) != 1 || inbox.Items[0].LastMessage.Body != "hi there" || inbox.Items[0].UnreadCount != 0 { // b read up to "hi there"; c1 messages not counted
		t.Fatalf("inbox during call: %+v", inbox.Items)
	}

	// 9/10. Reconnect retry of a sent message: one row, no new hint.
	rec.events = nil
	clientID := pgtest.UUID()
	r1 := chat.SendMessageRequest{Body: "c1: retry me", Context: strp(chat.ContextCall), CallId: &c1, ClientMessageId: &clientID}
	first, err := s.SendMessage(ctx, pa, conv.Id, r1)
	if err != nil {
		t.Fatal(err)
	}
	again, err := s.SendMessage(ctx, pa, conv.Id, r1)
	if err != nil || again.Id != first.Id || len(rec.events) != 1 {
		t.Fatalf("retry: %v %v events=%v", again.Id, err, rec.events)
	}

	// 11. Unauthorized: an outsider, and a participant naming someone else's call.
	x := pgtest.NewUser(t, admin, true)
	if _, err := s.ListMessages(ctx, identitytest.Principal(x), conv.Id, chat.PageRequest{Limit: 5, CallID: &c1}); apperr.As(err) == nil || apperr.As(err).Kind != apperr.KindNotFound {
		t.Fatalf("outsider session read: %v", err)
	}
	foreign := identitytest.Call(t, admin, x, pgtest.NewUser(t, admin, true), "active", 0, 0)
	if _, err := s.ListMessages(ctx, pa, conv.Id, chat.PageRequest{Limit: 5, CallID: &foreign}); apperr.As(err) == nil || apperr.As(err).Kind != apperr.KindNotFound {
		t.Fatalf("foreign call session read: %v", err)
	}

	// 12. Chat moved no money and did not touch the call.
	if after := moneySnapshot(t, admin, c1); after != before {
		t.Fatalf("billing changed by chat:\n %s\n %s", before, after)
	}

	// 5/6/8. The call ends: the session is now in normal Chat, in place,
	// with original senders and timestamps; earlier history is intact.
	end(c1)
	rec.events = nil
	for range 3 { // repeated / delayed call-end events
		s.CallEnded(ctx, c1)
	}
	if len(rec.events) != 6 || !strings.Contains(strings.Join(rec.events, ","), "user:"+a+" chat.message "+conv.Id) {
		t.Fatalf("call-end hints: %v", rec.events)
	}
	after := list(b, nil)
	if got := joined(after); got != "hello,hi there,c1: can you hear me,c1: yes,c1: retry me" {
		t.Fatalf("normal Chat after call 1: %q", got)
	}
	for _, m := range after {
		if m.Id == m1.Id && (!m.SentAt.Equal(m1.SentAt) || m.SenderId != a || m.Context != chat.ContextCall) {
			t.Fatalf("session message changed: %+v vs %+v", m, m1)
		}
	}
	send(b, nil, "nice talking")

	// 2/7. A second call: nothing from call 1 or normal Chat leaks in; it
	// joins the same conversation when it ends.
	c2 := identitytest.Call(t, admin, a, b, "active", 0, 0)
	if got := joined(list(b, &c2)); got != "" {
		t.Fatalf("call 2 session must start empty: %q", got)
	}
	send(b, &c2, "c2: again")
	if got := joined(list(a, &c1)); got != "c1: can you hear me,c1: yes,c1: retry me" {
		t.Fatalf("call 1 session changed: %q", got)
	}
	// App killed / network lost: nobody calls /end. The stale-call job ends
	// the call server-side (phase), and the session appears without any
	// client action.
	end(c2)
	if got := joined(list(a, nil)); got != "hello,hi there,c1: can you hear me,c1: yes,c1: retry me,nice talking,c2: again" {
		t.Fatalf("one canonical history: %q", got)
	}
	var convs int
	_ = admin.QueryRow(ctx, `select count(*) from chat.conversations where least(user_a,user_b) = least($1::uuid,$2::uuid) and greatest(user_a,user_b) = greatest($1::uuid,$2::uuid)`, a, b).Scan(&convs)
	if convs != 1 {
		t.Fatalf("conversations for the pair: %d", convs)
	}

	// Safety net: a call row stuck "live" (no job running) still releases
	// its session after SessionRevealAfter.
	c3 := identitytest.Call(t, admin, a, b, "active", 0, 0)
	stuck := send(a, &c3, "c3: stuck")
	if strings.Contains(joined(list(b, nil)), "c3: stuck") {
		t.Fatal("live call leaked")
	}
	if _, err := admin.Exec(ctx, `update chat.messages set sent_at = now() - $2::interval where id = $1`, stuck.Id,
		(postgres.SessionRevealAfter + time.Minute).String()); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(joined(list(b, nil)), "c3: stuck") {
		t.Fatal("stuck call never released its session")
	}
}
