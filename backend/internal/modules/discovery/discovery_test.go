package discovery

import (
	"context"
	"testing"

	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
)

const id1 = "11111111-1111-4111-8111-111111111111"

func TestCursorRoundTrip(t *testing.T) {
	for _, sort := range []string{SortRecommended, SortRateLow, SortRateHigh} {
		c := Cursor{Sort: sort, K1: -4000, K2: -123456789, ID: id1}
		got, err := DecodeCursor(c.Encode(), sort)
		if err != nil || *got != c {
			t.Fatalf("%s: %+v, %v", sort, got, err)
		}
	}
	if c, err := DecodeCursor("", SortRateLow); c != nil || err != nil {
		t.Fatal("empty cursor must mean first page")
	}
}

func TestCursorRejectsTampering(t *testing.T) {
	good := Cursor{Sort: SortRateLow, K1: 500, ID: id1}.Encode()
	bad := []struct{ tok, sort string }{
		{good, SortRateHigh}, // different sort
		{"not base64!!", SortRateLow},
		{Cursor{Sort: SortRateLow, K1: 1, ID: "x'; drop table"}.Encode(), SortRateLow},
		{"aDF8cmF0ZV9sb3d8YWJjfDB8MTExMTExMTEtMTExMS00MTExLTgxMTEtMTExMTExMTExMTEx", SortRateLow}, // non-numeric key
		{string(make([]byte, 300)), SortRateLow},
	}
	for _, b := range bad {
		if _, err := DecodeCursor(b.tok, b.sort); err == nil {
			t.Errorf("accepted %q for %s", b.tok, b.sort)
		}
	}
}

func TestSortKeys(t *testing.T) {
	avail := HostRow{RatePerMinute: 800, LifetimeXP: 100, Online: true}
	busy := HostRow{RatePerMinute: 600, LifetimeXP: 900, Busy: true}
	if k1, k2 := SortKeys(SortRecommended, avail); k1 != 0 || k2 != -100 {
		t.Fatal(k1, k2)
	}
	if k1, _ := SortKeys(SortRecommended, busy); k1 != 1 {
		t.Fatal("busy must sort after available")
	}
	if k1, _ := SortKeys(SortRateLow, avail); k1 != 800 {
		t.Fatal(k1)
	}
	if k1, _ := SortKeys(SortRateHigh, avail); k1 != -800 {
		t.Fatal(k1)
	}
}

func TestListRequestValidate(t *testing.T) {
	r := ListRequest{Limit: 20}
	if errs := r.validate(); len(errs) != 0 || r.Sort != SortRecommended {
		t.Fatalf("defaults: %v %q", errs, r.Sort)
	}
	for _, bad := range []ListRequest{
		{Limit: 20, Language: "hin"}, {Limit: 20, Language: "HI"}, {Limit: 20, CityID: "Pune!"},
		{Limit: 20, Sort: "price"}, {Limit: 0}, {Limit: 101},
	} {
		if errs := bad.validate(); len(errs) == 0 {
			t.Errorf("accepted %+v", bad)
		}
	}
}

type fakeRepo struct{ rows []HostRow }

func (f fakeRepo) ListHosts(_ context.Context, q ListQuery) ([]HostRow, error) {
	if len(f.rows) > q.Limit {
		return f.rows[:q.Limit], nil
	}
	return f.rows, nil
}
func (f fakeRepo) Host(context.Context, string, string) (HostRow, error) {
	return HostRow{}, ErrNotFound
}
func (f fakeRepo) OnlineCount(context.Context, string) (int, error) { return len(f.rows), nil }

func TestListPagination(t *testing.T) {
	rows := []HostRow{
		{UserID: id1, DisplayName: "A", RatePerMinute: 500, Online: true},
		{UserID: "22222222-2222-4222-8222-222222222222", DisplayName: "B", RatePerMinute: 600, Online: true},
		{UserID: "33333333-3333-4333-8333-333333333333", DisplayName: "C", RatePerMinute: 700, Busy: true},
	}
	s := NewService(Deps{Repo: fakeRepo{rows}, Rules: economy.Founder()})
	page, err := s.ListAvailableHosts(context.Background(), auth.Principal{UserID: id1}, ListRequest{Limit: 2, Sort: SortRateLow})
	if err != nil || len(page.Items) != 2 || page.NextCursor == nil {
		t.Fatalf("%+v %v", page, err)
	}
	c, err := DecodeCursor(*page.NextCursor, SortRateLow)
	if err != nil || c.K1 != 600 || c.ID != rows[1].UserID {
		t.Fatalf("cursor %+v %v", c, err)
	}
	page, _ = s.ListAvailableHosts(context.Background(), auth.Principal{UserID: id1}, ListRequest{Limit: 3})
	if page.NextCursor != nil || page.Items[2].Availability != "busy" || page.Items[0].Languages == nil {
		t.Fatalf("%+v", page)
	}
	if _, err := s.GetHost(context.Background(), auth.Principal{}, "nope"); apperr.As(err).Kind != apperr.KindNotFound {
		t.Fatal(err)
	}
	if _, err := NewService(Deps{}).GetSummary(context.Background(), auth.Principal{}); apperr.As(err).Kind != apperr.KindUnavailable {
		t.Fatal(err)
	}
}
