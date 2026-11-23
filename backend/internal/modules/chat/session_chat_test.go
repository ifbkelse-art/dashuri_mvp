package chat

// Video-call session chat: each call has its own session (keyed by the call
// id) inside the pair's one canonical conversation. The session is isolated
// while the call is live and is part of normal Chat once the call ends.
// The same flows run against Postgres in chat_integration_test.go
// (TestCallSessionChat*), which checks the real SQL.

import (
	"context"
	"strings"
	"testing"

	"dashuri/backend/internal/platform/apperr"
)

func bodies(p Page[ChatMessage]) string {
	var out []string
	for i := len(p.Items) - 1; i >= 0; i-- { // oldest first
		out = append(out, p.Items[i].Body)
	}
	return strings.Join(out, ",")
}

func sendIn(t *testing.T, s *Service, from, call, body string) ChatMessage {
	t.Helper()
	req := SendMessageRequest{Body: body}
	if call != "" {
		req.Context, req.CallId = ptr(ContextCall), ptr(call)
	}
	m, err := s.SendMessage(context.Background(), principalOf(from), convID, req)
	if err != nil {
		t.Fatalf("send %q: %v", body, err)
	}
	return m
}

func TestCallSessionIsIsolatedThenJoinsNormalChat(t *testing.T) {
	s, repo, _, _ := setup(true)
	ctx := context.Background()
	page := func(who string, call *string) Page[ChatMessage] {
		t.Helper()
		p, err := s.ListMessages(ctx, principalOf(who), convID, PageRequest{Limit: 50, CallID: call})
		if err != nil {
			t.Fatal(err)
		}
		return p
	}

	sendIn(t, s, userA, "", "old chat")
	// Call 1 is live.
	repo.liveCall[callID] = true
	if got := bodies(page(userA, ptr(callID))); got != "" {
		t.Fatalf("new session must start empty, got %q", got)
	}
	sendIn(t, s, userA, callID, "c1 hello")
	sendIn(t, s, userB, callID, "c1 hi")
	for _, who := range []string{userA, userB} {
		if got := bodies(page(who, ptr(callID))); got != "c1 hello,c1 hi" {
			t.Fatalf("%s session view: %q", who, got)
		}
	}
	if got := bodies(page(userB, nil)); got != "old chat" {
		t.Fatalf("normal Chat must not show a live call's session: %q", got)
	}

	// Call 1 ends: its session is now part of normal Chat, in order.
	repo.liveCall[callID] = false
	if got := bodies(page(userA, nil)); got != "old chat,c1 hello,c1 hi" {
		t.Fatalf("after call 1: %q", got)
	}
	sendIn(t, s, userB, "", "after call 1")

	// Call 2: nothing from call 1 or normal Chat leaks in.
	repo.liveCall[callID2] = true
	if got := bodies(page(userA, ptr(callID2))); got != "" {
		t.Fatalf("call 2 session must start empty, got %q", got)
	}
	sendIn(t, s, userB, callID2, "c2 again")
	if got := bodies(page(userA, ptr(callID))); got != "c1 hello,c1 hi" {
		t.Fatalf("call 1 session changed: %q", got)
	}
	repo.liveCall[callID2] = false
	if got := bodies(page(userB, nil)); got != "old chat,c1 hello,c1 hi,after call 1,c2 again" {
		t.Fatalf("one canonical history: %q", got)
	}
}

func TestCallSessionAccessRules(t *testing.T) {
	ctx := context.Background()
	s, _, _, _ := setup(true)
	// Not a call of this pair.
	if _, err := s.ListMessages(ctx, principalOf(userA), convID, PageRequest{Limit: 5, CallID: ptr(other)}); apperr.As(err) == nil ||
		apperr.As(err).Kind != apperr.KindNotFound {
		t.Fatalf("foreign call: %v", err)
	}
	// Not a participant of the conversation.
	if _, err := s.ListMessages(ctx, principalOf(other), convID, PageRequest{Limit: 5, CallID: ptr(callID)}); apperr.As(err) == nil ||
		apperr.As(err).Kind != apperr.KindNotFound {
		t.Fatalf("outsider: %v", err)
	}
	if _, err := s.ListMessages(ctx, principalOf(userA), convID, PageRequest{Limit: 5, CallID: ptr("nope")}); apperr.As(err) == nil ||
		apperr.As(err).Fields["call_id"] != "invalid_uuid" {
		t.Fatalf("bad id: %v", err)
	}
	// Without the metadata columns a session cannot be isolated: refuse
	// rather than show the whole history in the call.
	off, _, _, _ := setup(false)
	if _, err := off.ListMessages(ctx, principalOf(userA), convID, PageRequest{Limit: 5, CallID: ptr(callID)}); apperr.As(err) == nil ||
		apperr.As(err).Code != "in_call_chat_disabled" {
		t.Fatalf("flag off: %v", err)
	}
}

func TestCallEndedRefreshesBothChatsIdempotently(t *testing.T) {
	s, repo, ev, _ := setup(true)
	ctx := context.Background()
	repo.liveCall[callID] = true
	s.CallEnded(ctx, callID) // no session messages: nothing to announce
	if len(ev.got) != 0 {
		t.Fatalf("empty session announced: %v", ev.got)
	}
	sendIn(t, s, userA, callID, "hello")
	repo.liveCall[callID] = false
	for range 3 { // repeated call-end events
		ev.got = nil
		s.CallEnded(ctx, callID)
		if got := strings.Join(ev.got, ","); got != "user:"+userA+" chat.message,user:"+userB+" chat.message" {
			t.Fatalf("hints: %q", got)
		}
	}
	p, _ := s.ListMessages(ctx, principalOf(userB), convID, PageRequest{Limit: 50})
	if len(p.Items) != 1 {
		t.Fatalf("repeated finalization must not duplicate: %d", len(p.Items))
	}
}
