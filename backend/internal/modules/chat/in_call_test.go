package chat

// EXPERIMENT — unified chat + in-call messaging: service rules against an
// in-memory repository. The same flows run against Postgres in
// chat_integration_test.go (TestInCall*).

import (
	"context"
	"sort"
	"strings"
	"testing"
	"time"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
)

const (
	userA  = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
	userB  = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
	convID = "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
	callID = "dddddddd-dddd-4ddd-8ddd-dddddddddddd"
	other  = "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee"
)

type fakeRepo struct {
	privacy  string
	live     bool
	blocked  bool
	msgs     []ChatMessage
	clientID map[string]string // client id -> message id
	readAt   map[string]time.Time
	clock    time.Time
}

func newFake() *fakeRepo {
	return &fakeRepo{privacy: "everyone", clientID: map[string]string{}, readAt: map[string]time.Time{},
		clock: time.Date(2026, 11, 22, 10, 0, 0, 0, time.UTC)}
}

func (f *fakeRepo) tick() time.Time { f.clock = f.clock.Add(time.Second); return f.clock }

func (f *fakeRepo) Peer(_ context.Context, id string) (PeerAccount, error) {
	return PeerAccount{UserID: id, Status: "active", AgeEligible: true, WhoCanMessage: f.privacy}, nil
}
func (f *fakeRepo) BlockedEither(context.Context, string, string) (bool, error) {
	return f.blocked, nil
}
func (f *fakeRepo) HadBilledCall(context.Context, string, string) (bool, error) { return false, nil }
func (f *fakeRepo) InLiveCall(context.Context, string, string) (bool, error)    { return f.live, nil }
func (f *fakeRepo) CallBetween(_ context.Context, id, _, _ string) error {
	if id != callID {
		return ErrNotFound
	}
	return nil
}
func (f *fakeRepo) EnsureConversation(context.Context, string, string) (string, error) {
	return convID, nil
}
func (f *fakeRepo) ConversationPeer(_ context.Context, c, u string) (string, error) {
	switch {
	case c != convID:
		return "", ErrNotFound
	case u == userA:
		return userB, nil
	case u == userB:
		return userA, nil
	}
	return "", ErrNotFound
}
func (f *fakeRepo) Conversation(context.Context, string, string) (ConversationRow, error) {
	return ConversationRow{ID: convID}, nil
}
func (f *fakeRepo) ListConversations(context.Context, string, *Cursor, int) ([]ConversationRow, error) {
	return nil, nil
}
func (f *fakeRepo) ListMessages(_ context.Context, _, viewer string, _ *Cursor, limit int) ([]ChatMessage, error) {
	out := []ChatMessage{}
	for _, m := range f.msgs {
		if m.SenderId == viewer {
			for u, at := range f.readAt {
				m.ReadByPeer = m.ReadByPeer || (u != viewer && !at.Before(m.SentAt))
			}
		}
		out = append(out, m)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].SentAt.After(out[j].SentAt) })
	if len(out) > limit {
		out = out[:limit]
	}
	return out, nil
}
func (f *fakeRepo) InsertMessage(_ context.Context, nm NewMessage) (ChatMessage, bool, error) {
	if nm.ClientMessageID != nil {
		if id, ok := f.clientID[nm.SenderID+*nm.ClientMessageID]; ok {
			for _, m := range f.msgs {
				if m.Id == id {
					return m, false, nil
				}
			}
		}
	}
	m := ChatMessage{Id: time.Now().Format("150405.000000000") + nm.Body, ConversationId: nm.ConversationID,
		SenderId: nm.SenderID, Body: nm.Body, SentAt: f.tick(), Context: nm.Context}
	f.msgs = append(f.msgs, m)
	f.readAt[nm.SenderID] = m.SentAt
	if nm.ClientMessageID != nil {
		f.clientID[nm.SenderID+*nm.ClientMessageID] = m.Id
	}
	return m, true, nil
}
func (f *fakeRepo) MarkRead(_ context.Context, _, u string) (bool, error) {
	prev := f.readAt[u]
	f.readAt[u] = f.tick()
	for _, m := range f.msgs {
		if m.SenderId != u && m.SentAt.After(prev) {
			return true, nil
		}
	}
	return false, nil
}
func (f *fakeRepo) WhoCanMessage(context.Context, string) (string, error)  { return f.privacy, nil }
func (f *fakeRepo) SetWhoCanMessage(context.Context, string, string) error { return nil }

type events struct{ got []string }

func (e *events) Publish(_ context.Context, ch, ev string, _ any) error {
	e.got = append(e.got, ch+" "+ev)
	return nil
}

func principalOf(id string) auth.Principal {
	return auth.Principal{UserID: id, AgeEligible: true, Status: "active"}
}

func ptr(s string) *string { return &s }

func setup(contextOn bool) (*Service, *fakeRepo, *events, *[]string) {
	repo, ev, pushed := newFake(), &events{}, &[]string{}
	s := NewService(Deps{Repo: repo, Realtime: ev, MessageContext: contextOn,
		Push: func(_ context.Context, to, _ string) { *pushed = append(*pushed, to) }})
	return s, repo, ev, pushed
}

func TestInCallMessageSharesConversationAndSkipsPush(t *testing.T) {
	s, _, ev, pushed := setup(true)
	ctx := context.Background()
	inCall := SendMessageRequest{Body: "can you hear me?", Context: ptr(ContextCall), CallId: ptr(callID), ClientMessageId: ptr(other)}
	m, err := s.SendMessage(ctx, principalOf(userA), convID, inCall)
	if err != nil || m.Context != ContextCall || m.ConversationId != convID {
		t.Fatalf("in-call send: %+v %v", m, err)
	}
	if strings.Join(ev.got, ",") != "user:"+userB+" chat.message" || len(*pushed) != 0 {
		t.Fatalf("hint must go to the peer, push must not: %v %v", ev.got, *pushed)
	}
	// Reply from the inbox lands in the same conversation, gets a push.
	if _, err := s.SendMessage(ctx, principalOf(userB), convID, SendMessageRequest{Body: "yes!"}); err != nil {
		t.Fatal(err)
	}
	if len(*pushed) != 1 || (*pushed)[0] != userA {
		t.Fatalf("normal chat push: %v", *pushed)
	}
	page, _ := s.ListMessages(ctx, principalOf(userB), convID, PageRequest{Limit: 20})
	if len(page.Items) != 2 || page.Items[0].Body != "yes!" || page.Items[1].Context != ContextCall {
		t.Fatalf("one history, newest first: %+v", page.Items)
	}
}

func TestInCallDuplicateIsNotStoredOrAnnouncedTwice(t *testing.T) {
	s, repo, ev, _ := setup(true)
	ctx := context.Background()
	req := SendMessageRequest{Body: "hello", Context: ptr(ContextCall), CallId: ptr(callID), ClientMessageId: ptr(other)}
	first, _ := s.SendMessage(ctx, principalOf(userA), convID, req)
	again, err := s.SendMessage(ctx, principalOf(userA), convID, req) // reconnect retry
	if err != nil || again.Id != first.Id || len(repo.msgs) != 1 || len(ev.got) != 1 {
		t.Fatalf("dup: %+v %+v msgs=%d events=%v err=%v", first, again, len(repo.msgs), ev.got, err)
	}
}

func TestInCallRejectsForeignCallAndInvalidContext(t *testing.T) {
	s, repo, _, _ := setup(true)
	ctx := context.Background()
	_, err := s.SendMessage(ctx, principalOf(userA), convID, SendMessageRequest{Body: "x", Context: ptr(ContextCall), CallId: ptr(other)})
	if e := apperr.As(err); e == nil || e.Fields["call_id"] != "not_found" {
		t.Fatalf("foreign call: %v", err)
	}
	for req, field := range map[*SendMessageRequest]string{
		{Body: "x", Context: ptr(ContextCall)}:                      "call_id",
		{Body: "x", Context: ptr("video")}:                          "context",
		{Body: "x", CallId: ptr(callID)}:                            "call_id",
		{Body: "x", Context: ptr(ContextCall), CallId: ptr("nope")}: "call_id",
		{Body: "x", ClientMessageId: ptr("nope")}:                   "client_message_id",
	} {
		_, err := s.SendMessage(ctx, principalOf(userA), convID, *req)
		if e := apperr.As(err); e == nil || e.Fields[field] == "" {
			t.Errorf("%+v: want %s error, got %v", req, field, err)
		}
	}
	if _, err := s.SendMessage(ctx, principalOf(other), convID, SendMessageRequest{Body: "x"}); apperr.As(err).Kind != apperr.KindNotFound {
		t.Fatalf("non-participant: %v", err)
	}
	if len(repo.msgs) != 0 {
		t.Fatalf("nothing may be stored: %+v", repo.msgs)
	}
}

func TestInCallWithContextDisabledStoresPlainMessage(t *testing.T) {
	s, _, _, _ := setup(false)
	// Even an unknown call is not looked up: metadata is not stored at all.
	m, err := s.SendMessage(context.Background(), principalOf(userA), convID,
		SendMessageRequest{Body: "hi", Context: ptr(ContextCall), CallId: ptr(other)})
	if err != nil || m.Context != ContextChat {
		t.Fatalf("%+v %v", m, err)
	}
}

func TestPastCallPartnersAllowsTheLiveCallPartner(t *testing.T) {
	s, repo, _, _ := setup(true)
	repo.privacy = "past_call_partners"
	ctx := context.Background()
	if _, err := s.SendMessage(ctx, principalOf(userA), convID, SendMessageRequest{Body: "hi"}); apperr.As(err).Code != "messaging_not_allowed" {
		t.Fatalf("no call: %v", err)
	}
	repo.live = true
	if _, err := s.SendMessage(ctx, principalOf(userA), convID, SendMessageRequest{Body: "hi"}); err != nil {
		t.Fatalf("live call partner: %v", err)
	}
	repo.blocked = true // a block always wins, also mid-call
	if _, err := s.SendMessage(ctx, principalOf(userA), convID, SendMessageRequest{Body: "hi"}); apperr.As(err).Code != "blocked" {
		t.Fatalf("blocked mid-call: %v", err)
	}
}

func TestReadEventOnlyWhenSomethingNewWasRead(t *testing.T) {
	s, _, ev, _ := setup(true)
	ctx := context.Background()
	m, _ := s.SendMessage(ctx, principalOf(userA), convID, SendMessageRequest{Body: "hi"})
	if m.ReadByPeer {
		t.Fatal("new message cannot be read yet")
	}
	ev.got = nil
	if err := s.MarkRead(ctx, principalOf(userB), convID); err != nil {
		t.Fatal(err)
	}
	if err := s.MarkRead(ctx, principalOf(userB), convID); err != nil { // nothing new
		t.Fatal(err)
	}
	if strings.Join(ev.got, ",") != "user:"+userA+" chat.read" {
		t.Fatalf("read events: %v", ev.got)
	}
	page, _ := s.ListMessages(ctx, principalOf(userA), convID, PageRequest{Limit: 5})
	if !page.Items[0].ReadByPeer {
		t.Fatalf("sender should see Read: %+v", page.Items[0])
	}
	if page, _ = s.ListMessages(ctx, principalOf(userB), convID, PageRequest{Limit: 5}); page.Items[0].ReadByPeer {
		t.Fatal("read_by_peer is only for the viewer's own messages")
	}
}
