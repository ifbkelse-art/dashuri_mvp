//go:build integration

package safety_test

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/safety"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/routing"
	"dashuri/backend/internal/testsupport/identitytest"
	"dashuri/backend/internal/testsupport/pgtest"
)

func code(err error) string {
	if e := apperr.As(err); e != nil {
		return e.Code
	}
	return ""
}

func TestReportIsIdempotentOverHTTP(t *testing.T) {
	api, admin := pgtest.Pools(t)
	ctx := context.Background()
	svc := safety.NewService(safety.Deps{Repo: postgres.SafetyRepo{Pool: api}})
	mux := http.NewServeMux()
	testUser := func(h http.HandlerFunc) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			h(w, r.WithContext(auth.WithPrincipal(r.Context(), identitytest.Principal(r.Header.Get("X-Test-User")))))
		})
	}
	safety.Routes(mux, svc, routing.Stack{
		User:                  testUser,
		UserAllowingSuspended: testUser,
		Idempotency:           postgres.IdempotencyStore{Pool: api},
	})
	reporter, target := pgtest.NewUser(t, admin, true), pgtest.NewUser(t, admin, true)
	callID := identitytest.Call(t, admin, reporter, target, "ended", 120, 2*time.Hour)

	post := func(key, body string) (*httptest.ResponseRecorder, map[string]any) {
		req := httptest.NewRequest(http.MethodPost, "/v1/reports", strings.NewReader(body))
		req.Header.Set("X-Test-User", reporter)
		req.Header.Set("Idempotency-Key", key)
		rr := httptest.NewRecorder()
		mux.ServeHTTP(rr, req)
		var out map[string]any
		_ = json.Unmarshal(rr.Body.Bytes(), &out)
		return rr, out
	}
	body := `{"target_user_id":"` + target + `","category":"nudity","call_id":"` + callID + `","details":"during the call"}`
	key := pgtest.UUID()
	r1, b1 := post(key, body)
	r2, b2 := post(key, body)
	if r1.Code != 201 || r2.Code != 201 || b1["report_id"] != b2["report_id"] || r2.Header().Get("Idempotent-Replayed") != "true" {
		t.Fatalf("replay: %d %v / %d %v", r1.Code, b1, r2.Code, b2)
	}
	var n, prio int
	_ = admin.QueryRow(ctx, `select count(*), max(priority) from safety.reports where reporter_id = $1`, reporter).Scan(&n, &prio)
	if n != 1 || prio != 1 {
		t.Fatalf("reports %d priority %d", n, prio)
	}
	var audits int
	_ = admin.QueryRow(ctx, `select count(*) from audit.events where action = 'safety.report_created' and target = $1`, b1["report_id"]).Scan(&audits)
	if audits != 1 {
		t.Fatalf("audit rows %d", audits)
	}
	if r3, _ := post(key, strings.Replace(body, "nudity", "harassment", 1)); r3.Code != 422 {
		t.Fatalf("same key different body: %d", r3.Code)
	}
	if r4, b4 := post(pgtest.UUID(), `{"target_user_id":"`+target+`","category":"other"}`); r4.Code != 201 || b4["report_id"] == b1["report_id"] {
		t.Fatalf("new key: %d %v", r4.Code, b4)
	}
}

func TestReportWindowAndParticipants(t *testing.T) {
	api, admin := pgtest.Pools(t)
	ctx := context.Background()
	s := safety.NewService(safety.Deps{Repo: postgres.SafetyRepo{Pool: api}})
	me, peer, stranger := pgtest.NewUser(t, admin, true), pgtest.NewUser(t, admin, true), pgtest.NewUser(t, admin, true)
	p := identitytest.Principal(me)
	report := func(target, callID string) error {
		_, err := s.ReportUser(ctx, p, safety.ReportRequest{TargetUserId: target, Category: "harassment", CallId: &callID})
		return err
	}
	old := identitytest.Call(t, admin, me, peer, "ended", 60, 25*time.Hour)
	if err := report(peer, old); code(err) != "report_window_closed" {
		t.Fatalf("old call: %v", err)
	}
	recent := identitytest.Call(t, admin, peer, me, "ended", 60, 23*time.Hour)
	if err := report(peer, recent); err != nil {
		t.Fatalf("recent: %v", err)
	}
	if err := report(stranger, recent); code(err) != "validation_failed" {
		t.Fatalf("target not in call: %v", err)
	}
	others := identitytest.Call(t, admin, peer, stranger, "ended", 60, time.Hour)
	if err := report(peer, others); apperr.As(err).Kind != apperr.KindNotFound {
		t.Fatalf("not a participant: %v", err)
	}
	live := identitytest.Call(t, admin, stranger, me, "active", 0, 0)
	if err := report(stranger, live); err != nil {
		t.Fatalf("live call: %v", err)
	}
	if _, err := s.ReportUser(ctx, p, safety.ReportRequest{TargetUserId: me, Category: "other"}); code(err) != "validation_failed" {
		t.Fatalf("self report: %v", err)
	}
	if _, err := s.ReportUser(ctx, p, safety.ReportRequest{TargetUserId: pgtest.UUID(), Category: "other"}); apperr.As(err).Kind != apperr.KindNotFound {
		t.Fatalf("unknown target: %v", err)
	}
}

func TestBlocksEnforcementAndAppeals(t *testing.T) {
	api, admin := pgtest.Pools(t)
	ctx := context.Background()
	s := safety.NewService(safety.Deps{Repo: postgres.SafetyRepo{Pool: api}})
	me := pgtest.NewUser(t, admin, true)
	p := identitytest.Principal(me)
	var others []string
	for i := 0; i < 3; i++ {
		o := pgtest.NewUser(t, admin, true)
		identitytest.Profile(t, admin, o, "U"+string(rune('a'+i)), nil, nil)
		others = append(others, o)
		b, err := s.BlockUser(ctx, p, safety.BlockRequest{UserId: o})
		if err != nil || b.UserId != o {
			t.Fatalf("block: %+v %v", b, err)
		}
	}
	if b, err := s.BlockUser(ctx, p, safety.BlockRequest{UserId: others[0]}); err != nil || b.DisplayName != "Ua" {
		t.Fatalf("re-block is idempotent: %+v %v", b, err)
	}
	if _, err := s.BlockUser(ctx, p, safety.BlockRequest{UserId: pgtest.UUID()}); apperr.As(err).Kind != apperr.KindNotFound {
		t.Fatalf("unknown user: %v", err)
	}
	if _, err := s.BlockUser(ctx, p, safety.BlockRequest{UserId: me}); code(err) != "validation_failed" {
		t.Fatalf("self block: %v", err)
	}
	pg1, _ := s.ListBlockedUsers(ctx, p, safety.PageRequest{Limit: 2})
	pg2, _ := s.ListBlockedUsers(ctx, p, safety.PageRequest{Limit: 2, Cursor: *pg1.NextCursor})
	if len(pg1.Items) != 2 || len(pg2.Items) != 1 || pg2.NextCursor != nil {
		t.Fatalf("pages %+v %+v", pg1, pg2)
	}
	if err := s.UnblockUser(ctx, p, others[1]); err != nil {
		t.Fatal(err)
	}
	if err := s.UnblockUser(ctx, p, others[1]); err != nil {
		t.Fatal("unblock must be idempotent")
	}
	if all, _ := s.ListBlockedUsers(ctx, p, safety.PageRequest{Limit: 10}); len(all.Items) != 2 {
		t.Fatalf("after unblock: %+v", all)
	}

	var appealable, final, foreign string
	_ = admin.QueryRow(ctx, `insert into safety.enforcement_actions (user_id, action, reason) values ($1, 'warn', 'spam') returning id`, me).Scan(&appealable)
	_ = admin.QueryRow(ctx, `insert into safety.enforcement_actions (user_id, action, reason, appealable) values ($1, 'restrict_calls', 'nudity', false) returning id`, me).Scan(&final)
	_ = admin.QueryRow(ctx, `insert into safety.enforcement_actions (user_id, action, reason) values ($1, 'warn', 'x') returning id`, others[0]).Scan(&foreign)

	notices, err := s.ListEnforcementNotices(ctx, p, safety.PageRequest{Limit: 10})
	if err != nil || len(notices.Items) != 2 {
		t.Fatalf("notices %+v %v", notices, err)
	}
	rec, err := s.SubmitAppeal(ctx, p, safety.AppealRequest{EnforcementId: appealable, Statement: "I did not spam"})
	if err != nil || rec.Status != "open" {
		t.Fatalf("appeal: %+v %v", rec, err)
	}
	if _, err := s.SubmitAppeal(ctx, p, safety.AppealRequest{EnforcementId: appealable, Statement: "again"}); code(err) != "appeal_exists" {
		t.Fatalf("second appeal: %v", err)
	}
	if _, err := s.SubmitAppeal(ctx, p, safety.AppealRequest{EnforcementId: final, Statement: "please"}); code(err) != "not_appealable" {
		t.Fatalf("not appealable: %v", err)
	}
	if _, err := s.SubmitAppeal(ctx, p, safety.AppealRequest{EnforcementId: foreign, Statement: "x"}); apperr.As(err).Kind != apperr.KindNotFound {
		t.Fatalf("foreign: %v", err)
	}
	notices, _ = s.ListEnforcementNotices(ctx, p, safety.PageRequest{Limit: 10})
	for _, n := range notices.Items {
		if n.Id == appealable && (n.AppealStatus == nil || *n.AppealStatus != "open") {
			t.Fatalf("appeal status not shown: %+v", n)
		}
	}
}

// Grievances (D-22): a complaint about no other user is stored without a
// target; other self-reports stay invalid.
func TestGrievanceWithoutTarget(t *testing.T) {
	api, admin := pgtest.Pools(t)
	ctx := context.Background()
	s := safety.NewService(safety.Deps{Repo: postgres.SafetyRepo{Pool: api}})
	u := pgtest.NewUser(t, admin, true)
	p := auth.Principal{UserID: u, Roles: []auth.Role{auth.RoleCustomer}, Status: "active", AgeEligible: true}
	details := "Payment issue with order dsh_123"
	rec, err := s.ReportUser(ctx, p, safety.ReportRequest{TargetUserId: u, Category: "other", Details: &details})
	if err != nil {
		t.Fatalf("grievance: %v", err)
	}
	var target *string
	_ = admin.QueryRow(ctx, `select target_user_id::text from safety.reports where id = $1`, rec.ReportId).Scan(&target)
	if target != nil {
		t.Fatalf("grievance stored with target %v", *target)
	}
	if _, err := s.ReportUser(ctx, p, safety.ReportRequest{TargetUserId: u, Category: "harassment", Details: &details}); err == nil {
		t.Fatal("self-report with a user category must be refused")
	}
}
