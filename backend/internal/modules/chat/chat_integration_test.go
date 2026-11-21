//go:build integration

package chat_test

import (
	"context"
	"sync"
	"testing"
	"time"

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
