//go:build integration

package notifications_test

import (
	"context"
	"testing"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/notifications"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/testsupport/identitytest"
	"dashuri/backend/internal/testsupport/pgtest"
)

type pushes struct{ to []string }

func (p *pushes) Send(_ context.Context, token string, _ notifications.Push) error {
	p.to = append(p.to, token)
	if token == "stale-token" {
		return notifications.ErrTokenUnregistered
	}
	return nil
}

func TestDevicesInboxAndNotifier(t *testing.T) {
	api, admin := pgtest.Pools(t)
	ctx := context.Background()
	repo := postgres.NotificationsRepo{Pool: api}
	s := notifications.NewService(notifications.Deps{Repo: repo})
	u, other := pgtest.NewUser(t, admin, true), pgtest.NewUser(t, admin, true)
	p := identitytest.Principal(u)

	tok := "fcm-" + pgtest.UUID()
	for _, d := range []notifications.DeviceRegistration{{Token: tok, Platform: "android"}, {Token: "stale-token", Platform: "android"}} {
		if err := s.RegisterDevice(ctx, identitytest.Principal(other), d); err != nil {
			t.Fatal(err)
		}
	}
	// Re-registering the token as u moves it to u.
	if err := s.RegisterDevice(ctx, p, notifications.DeviceRegistration{Token: tok, Platform: "android"}); err != nil {
		t.Fatal(err)
	}
	if err := s.RegisterDevice(ctx, p, notifications.DeviceRegistration{Token: "stale-token", Platform: "android"}); err != nil {
		t.Fatal(err)
	}

	push := &pushes{}
	n := notifications.Notifier{Repo: repo, Push: push}
	item, err := n.Notify(ctx, u, notifications.Notification{Kind: "payout", Title: "Withdrawal update", Body: "Your request was received"})
	if err != nil || len(push.to) != 2 {
		t.Fatalf("notify: %+v %v pushes %v", item, err, push.to)
	}
	tokens, _ := repo.DeviceTokens(ctx, u)
	if len(tokens) != 1 || tokens[0] != tok {
		t.Fatalf("stale token not forgotten: %v", tokens)
	}
	if _, err := n.Notify(ctx, u, notifications.Notification{Kind: "moderation", Title: "T2", Body: "B2"}); err != nil {
		t.Fatal(err)
	}

	pg1, err := s.ListInbox(ctx, p, notifications.PageRequest{Limit: 1})
	if err != nil || len(pg1.Items) != 1 || pg1.Items[0].Title != "T2" || pg1.NextCursor == nil {
		t.Fatalf("inbox page1 %+v %v", pg1, err)
	}
	pg2, _ := s.ListInbox(ctx, p, notifications.PageRequest{Limit: 1, Cursor: *pg1.NextCursor})
	if len(pg2.Items) != 1 || pg2.Items[0].Id != item.Id || pg2.Items[0].ReadAt != nil {
		t.Fatalf("inbox page2 %+v", pg2)
	}
	if err := s.MarkRead(ctx, p, item.Id); err != nil {
		t.Fatal(err)
	}
	if err := s.MarkRead(ctx, identitytest.Principal(other), item.Id); apperr.As(err).Kind != apperr.KindNotFound {
		t.Fatalf("other user's item: %v", err)
	}
	pg2, _ = s.ListInbox(ctx, p, notifications.PageRequest{Limit: 1, Cursor: *pg1.NextCursor})
	if pg2.Items[0].ReadAt == nil {
		t.Fatal("not marked read")
	}
	if err := s.UnregisterDevice(ctx, p, tok); err != nil {
		t.Fatal(err)
	}
	if tokens, _ := repo.DeviceTokens(ctx, u); len(tokens) != 0 {
		t.Fatalf("after unregister: %v", tokens)
	}
}
