//go:build integration

package accounts_test

import (
	"context"
	"encoding/json"
	"strings"
	"testing"
	"time"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/accounts"
	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/testsupport/identitytest"
	"dashuri/backend/internal/testsupport/pgtest"
)

type fakeStorage struct{ configured bool }

func (f fakeStorage) Configured() bool                                    { return f.configured }
func (f fakeStorage) List(context.Context, string, int) ([]string, error) { return nil, nil }
func (f fakeStorage) Delete(context.Context, string) error                { return nil }
func (f fakeStorage) SignUpload(_ context.Context, path string) (string, error) {
	return "https://storage.test/upload/" + path + "?token=t", nil
}
func (f fakeStorage) SignRead(_ context.Context, paths []string, _ time.Duration) map[string]string {
	out := map[string]string{}
	for _, p := range paths {
		out[p] = "https://storage.test/read/" + p
	}
	return out
}

func rule(err error) string {
	if e := apperr.As(err); e != nil {
		return e.Code
	}
	return ""
}

func decode[T any](t *testing.T, s string) T {
	var v T
	if err := json.Unmarshal([]byte(s), &v); err != nil {
		t.Fatal(err)
	}
	return v
}

func TestProfileLifecycleAndMe(t *testing.T) {
	api, admin := pgtest.Pools(t)
	s := accounts.NewService(accounts.Deps{Repo: postgres.AccountsRepo{Pool: api}, Storage: fakeStorage{true}, Rules: economy.Founder()})
	ctx := context.Background()
	u := pgtest.NewUser(t, admin, true)
	p := identitytest.Principal(u)

	me, err := s.GetMe(ctx, p)
	if err != nil || me.ProfileComplete || me.RulesAccepted || me.IsHost || me.HostState != nil {
		t.Fatalf("fresh me: %+v %v", me, err)
	}
	if _, err := s.GetMyProfile(ctx, p); apperr.As(err).Kind != apperr.KindNotFound {
		t.Fatalf("profile before create: %v", err)
	}
	// Creating needs a display name.
	if _, err := s.UpdateMyProfile(ctx, p, decode[accounts.UpdateProfileRequest](t, `{"bio":"hi"}`)); rule(err) != "validation_failed" {
		t.Fatalf("want validation: %v", err)
	}
	prof, err := s.UpdateMyProfile(ctx, p, decode[accounts.UpdateProfileRequest](t,
		`{"display_name":"  Priya ","gender":"woman","city_id":"pune","languages":["HI","en","hi"],"bio":"Love music"}`))
	if err != nil {
		t.Fatal(err)
	}
	if prof.DisplayName != "Priya" || prof.Gender == nil || *prof.Gender != "woman" || prof.City == nil || prof.City.Name != "Pune" ||
		strings.Join(prof.Languages, ",") != "hi,en" || prof.Level != 1 {
		t.Fatalf("profile: %+v", prof)
	}
	// Clear city with null, keep the rest.
	prof, err = s.UpdateMyProfile(ctx, p, decode[accounts.UpdateProfileRequest](t, `{"city_id":null}`))
	if err != nil || prof.City != nil || prof.Bio == nil || *prof.Bio != "Love music" {
		t.Fatalf("clear city: %+v %v", prof, err)
	}
	if _, err := s.UpdateMyProfile(ctx, p, decode[accounts.UpdateProfileRequest](t, `{"city_id":"atlantis"}`)); rule(err) != "validation_failed" {
		t.Fatalf("unknown city: %v", err)
	}
	for _, body := range []string{`{"bio":"call me 98765 43210"}`, `{"display_name":"priya@okaxis"}`, `{"bio":"insta: instagram.com/priya"}`} {
		if _, err := s.UpdateMyProfile(ctx, p, decode[accounts.UpdateProfileRequest](t, body)); rule(err) != "profile_text_rejected" {
			t.Fatalf("%s: want profile_text_rejected, got %v", body, err)
		}
	}
	// Rules.
	if _, err := s.AcceptRules(ctx, p, accounts.RulesAcceptanceRequest{Version: "2020-01"}); rule(err) != "rules_version_outdated" {
		t.Fatal(err)
	}
	me, err = s.AcceptRules(ctx, p, accounts.RulesAcceptanceRequest{Version: accounts.CurrentRulesVersion})
	if err != nil || !me.RulesAccepted || !me.ProfileComplete || !me.AgeEligible {
		t.Fatalf("me after: %+v %v", me, err)
	}
	identitytest.Host(t, admin, u, 800, true)
	if me, _ = s.GetMe(ctx, p); !me.IsHost || *me.HostState != "approved" {
		t.Fatalf("host me: %+v", me)
	}
	identitytest.XP(t, admin, u, 40000)
	if prof, _ = s.GetMyProfile(ctx, p); prof.Level != 2 {
		t.Fatalf("level %d", prof.Level)
	}
}

func TestPublicProfileHidesGenderAndRespectsBlocks(t *testing.T) {
	api, admin := pgtest.Pools(t)
	s := accounts.NewService(accounts.Deps{Repo: postgres.AccountsRepo{Pool: api}, Storage: fakeStorage{true}, Rules: economy.Founder()})
	ctx := context.Background()
	viewer, target, blocker, blocked := pgtest.NewUser(t, admin, true), pgtest.NewUser(t, admin, true), pgtest.NewUser(t, admin, true), pgtest.NewUser(t, admin, true)
	pune := "pune"
	identitytest.Profile(t, admin, target, "Asha", []string{"hi"}, &pune)
	identitytest.Profile(t, admin, blocker, "B1", nil, nil)
	identitytest.Profile(t, admin, blocked, "B2", nil, nil)
	if _, err := admin.Exec(ctx, `insert into identity.profile_photos (user_id, storage_path, status, position) values
		($1::uuid, $1::text || '/a.jpg', 'approved', 0), ($1::uuid, $1::text || '/b.jpg', 'pending_review', 1)`, target); err != nil {
		t.Fatal(err)
	}
	identitytest.Block(t, admin, blocker, viewer) // they blocked me
	identitytest.Block(t, admin, viewer, blocked) // I blocked them

	prof, err := s.GetProfile(ctx, identitytest.Principal(viewer), target)
	if err != nil {
		t.Fatal(err)
	}
	if prof.Gender != nil || prof.City == nil || prof.City.Id != "pune" || len(prof.PhotoUrls) != 1 || !strings.HasSuffix(prof.PhotoUrls[0], "/a.jpg") {
		t.Fatalf("public profile: %+v", prof)
	}
	b, _ := json.Marshal(prof)
	if strings.Contains(string(b), "gender") {
		t.Fatalf("gender leaked: %s", b)
	}
	for _, id := range []string{blocker, blocked, pgtest.UUID(), "not-a-uuid"} {
		if _, err := s.GetProfile(ctx, identitytest.Principal(viewer), id); apperr.As(err).Kind != apperr.KindNotFound {
			t.Errorf("%s: want 404, got %v", id, err)
		}
	}
	// Own profile shows pending photos too.
	own, _ := s.GetMyProfile(ctx, identitytest.Principal(target))
	if len(own.PhotoUrls) != 2 || own.Gender == nil {
		t.Fatalf("own: %+v", own)
	}
}

func TestAgeDeclaration(t *testing.T) {
	api, admin := pgtest.Pools(t)
	now := time.Date(2026, 11, 21, 6, 0, 0, 0, time.UTC)
	s := accounts.NewService(accounts.Deps{Repo: postgres.AccountsRepo{Pool: api}, Rules: economy.Founder(), Clock: fixedClock{now}})
	ctx := context.Background()

	minor := pgtest.NewUser(t, admin, false)
	p := identitytest.Principal(minor)
	p.AgeEligible = false
	if st, _ := s.GetAgeStatus(ctx, p); st.Eligible || st.Declared {
		t.Fatalf("before: %+v", st)
	}
	// Turns 18 tomorrow (IST): still under 18.
	if _, err := s.SubmitAgeDeclaration(ctx, p, accounts.AgeDeclarationRequest{DateOfBirth: "2008-11-22"}); rule(err) != "under_18" {
		t.Fatalf("want under_18, got %v", err)
	}
	var status string
	var eligible bool
	if err := admin.QueryRow(ctx, `select status, age_eligible from identity.accounts where id = $1`, minor).Scan(&status, &eligible); err != nil {
		t.Fatal(err)
	}
	if status != "restricted" || eligible {
		t.Fatalf("minor account: %s %v", status, eligible)
	}
	me, _ := s.GetMe(ctx, p)
	if me.Restriction == nil || *me.Restriction != "under_18" {
		t.Fatalf("me restriction: %+v", me)
	}
	if _, err := s.SubmitAgeDeclaration(ctx, p, accounts.AgeDeclarationRequest{DateOfBirth: "1990-01-01"}); rule(err) != "declaration_locked" {
		t.Fatalf("want declaration_locked, got %v", err)
	}
	var audits int
	_ = admin.QueryRow(ctx, `select count(*) from audit.events where actor = $1 and action = 'account.restricted_under_18'`, minor).Scan(&audits)
	if audits != 1 {
		t.Fatalf("audit rows %d", audits)
	}

	adult := pgtest.NewUser(t, admin, false)
	st, err := s.SubmitAgeDeclaration(ctx, identitytest.Principal(adult), accounts.AgeDeclarationRequest{DateOfBirth: "2008-11-21"})
	if err != nil || !st.Eligible || *st.Method != "self_declared" {
		t.Fatalf("18 today: %+v %v", st, err)
	}
	for _, bad := range []string{"", "21-11-2000", "2030-01-01", "1850-01-01", "2000-02-30"} {
		if _, err := s.SubmitAgeDeclaration(ctx, identitytest.Principal(adult), accounts.AgeDeclarationRequest{DateOfBirth: bad}); rule(err) != "validation_failed" {
			t.Errorf("%q: %v", bad, err)
		}
	}
}

type fixedClock struct{ t time.Time }

func (f fixedClock) Now() time.Time { return f.t }

func TestDeletionRefusedWithBeansOrLiveCall(t *testing.T) {
	api, admin := pgtest.Pools(t)
	s := accounts.NewService(accounts.Deps{Repo: postgres.AccountsRepo{Pool: api}, Rules: economy.Founder()})
	ctx := context.Background()

	host := pgtest.NewUser(t, admin, true, "customer", "host")
	identitytest.Beans(t, admin, host, 1)
	if _, err := s.RequestAccountDeletion(ctx, identitytest.Principal(host)); rule(err) != "pending_balance_or_payout" {
		t.Fatalf("beans: %v", err)
	}
	caller, other := pgtest.NewUser(t, admin, true), pgtest.NewUser(t, admin, true)
	identitytest.Call(t, admin, caller, other, "active", 0, 0)
	if _, err := s.RequestAccountDeletion(ctx, identitytest.Principal(caller)); rule(err) != "pending_balance_or_payout" {
		t.Fatalf("live call: %v", err)
	}

	free := pgtest.NewUser(t, admin, true)
	d, err := s.RequestAccountDeletion(ctx, identitytest.Principal(free))
	if err != nil || d.ScheduledFor == nil || d.Status != "received" {
		t.Fatalf("%+v %v", d, err)
	}
	if delta := time.Until(*d.ScheduledFor); delta < 6*24*time.Hour+23*time.Hour || delta > 7*24*time.Hour+time.Minute {
		t.Fatalf("scheduled in %v", delta)
	}
	again, err := s.RequestAccountDeletion(ctx, identitytest.Principal(free))
	if err != nil || again.RequestId != d.RequestId {
		t.Fatalf("repeat: %+v %v", again, err)
	}
	ex, err := s.RequestDataExport(ctx, identitytest.Principal(free))
	ex2, _ := s.RequestDataExport(ctx, identitytest.Principal(free))
	if err != nil || ex.RequestId == "" || ex2.RequestId != ex.RequestId {
		t.Fatalf("export %+v %+v %v", ex, ex2, err)
	}
}

func TestConsentsAndPhotoTickets(t *testing.T) {
	api, admin := pgtest.Pools(t)
	ctx := context.Background()
	repo := postgres.AccountsRepo{Pool: api}
	u := pgtest.NewUser(t, admin, true)
	p := identitytest.Principal(u)

	s := accounts.NewService(accounts.Deps{Repo: repo, Storage: fakeStorage{false}, Rules: economy.Founder()})
	if _, err := s.RequestPhotoUpload(ctx, p, accounts.PhotoUploadTicketRequest{ContentType: "image/jpeg"}); rule(err) != "storage_not_configured" {
		t.Fatalf("want storage_not_configured, got %v", err)
	}
	c, err := s.GetConsents(ctx, p)
	if err != nil || c.Analytics || c.Marketing {
		t.Fatalf("%+v %v", c, err)
	}
	yes, no := true, false
	if c, err = s.UpdateConsents(ctx, p, accounts.UpdateConsentsRequest{Analytics: &yes, Marketing: &no}); err != nil || !c.Analytics || c.Marketing {
		t.Fatalf("%+v %v", c, err)
	}

	s = accounts.NewService(accounts.Deps{Repo: repo, Storage: fakeStorage{true}, Rules: economy.Founder()})
	for i := 0; i < accounts.MaxPhotos; i++ {
		tk, err := s.RequestPhotoUpload(ctx, p, accounts.PhotoUploadTicketRequest{ContentType: "image/webp"})
		if err != nil || tk.Status != "pending_review" || !strings.Contains(tk.UploadUrl, u+"/"+tk.PhotoId+".webp") {
			t.Fatalf("ticket %d: %+v %v", i, tk, err)
		}
	}
	_, err = s.RequestPhotoUpload(ctx, p, accounts.PhotoUploadTicketRequest{ContentType: "image/png"})
	if rule(err) != "photo_limit_reached" {
		t.Fatalf("7th photo: %v", err)
	}
}
