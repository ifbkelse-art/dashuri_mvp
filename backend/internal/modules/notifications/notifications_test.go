package notifications

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"
)

type memRepo struct {
	tokens    []string
	forgotten []string
	inbox     []InboxItem
}

func (m *memRepo) UpsertDevice(context.Context, string, string, string) error { return nil }
func (m *memRepo) DeleteDevice(context.Context, string, string) error         { return nil }
func (m *memRepo) DeviceTokens(context.Context, string) ([]string, error)     { return m.tokens, nil }
func (m *memRepo) ForgetToken(_ context.Context, t string) error {
	m.forgotten = append(m.forgotten, t)
	return nil
}
func (m *memRepo) InsertInbox(_ context.Context, _, kind, title, body string) (InboxItem, error) {
	it := InboxItem{Id: "11111111-1111-4111-8111-111111111111", Kind: kind, Title: title, Body: body, CreatedAt: time.Now()}
	m.inbox = append(m.inbox, it)
	return it, nil
}
func (m *memRepo) ListInbox(context.Context, string, *Cursor, int) ([]InboxItem, error) {
	return m.inbox, nil
}
func (m *memRepo) MarkRead(context.Context, string, string) error { return nil }

type fakePush struct{ sent []string }

func (f *fakePush) Send(_ context.Context, token string, msg Push) error {
	f.sent = append(f.sent, token+":"+msg.Data["kind"]+":"+msg.Data["notification_id"])
	if token == "dead" {
		return ErrTokenUnregistered
	}
	if token == "flaky" {
		return errors.New("timeout")
	}
	return nil
}

type fakePub struct{ events []string }

func (f *fakePub) Publish(_ context.Context, ch, ev string, _ any) error {
	f.events = append(f.events, ch+" "+ev)
	return nil
}

func TestNotifierStoresPublishesAndPushes(t *testing.T) {
	repo := &memRepo{tokens: []string{"good", "dead", "flaky"}}
	push, pub := &fakePush{}, &fakePub{}
	n := Notifier{Repo: repo, Push: push, Realtime: pub}
	item, err := n.Notify(context.Background(), "u1", Notification{Kind: "payout", Title: "T", Body: "B"})
	if err != nil || item.Kind != "payout" || len(repo.inbox) != 1 {
		t.Fatalf("%+v %v", item, err)
	}
	if len(pub.events) != 1 || pub.events[0] != "user:u1 notification.created" {
		t.Fatalf("events %v", pub.events)
	}
	if len(push.sent) != 3 || !strings.HasPrefix(push.sent[0], "good:payout:"+item.Id) {
		t.Fatalf("pushes %v", push.sent)
	}
	if len(repo.forgotten) != 1 || repo.forgotten[0] != "dead" {
		t.Fatalf("forgotten %v", repo.forgotten)
	}
	// No push sender configured: inbox still works.
	if _, err := (Notifier{Repo: repo}).Notify(context.Background(), "u1", Notification{Kind: "x"}); err != nil {
		t.Fatal(err)
	}
}

func TestDeviceRegistrationValidate(t *testing.T) {
	if errs := (DeviceRegistration{Token: "t", Platform: "android"}).validate(); len(errs) != 0 {
		t.Fatal(errs)
	}
	for _, d := range []DeviceRegistration{{Platform: "android"}, {Token: "t", Platform: "web"}, {Token: strings.Repeat("a", 4097), Platform: "ios"}} {
		if errs := d.validate(); len(errs) == 0 {
			t.Errorf("accepted %+v", d)
		}
	}
}
