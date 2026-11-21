//go:build integration

package moderation_test

import (
	"context"
	"encoding/base64"
	"testing"
	"time"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/calls"
	"dashuri/backend/internal/modules/moderation"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/db"
	"dashuri/backend/internal/testsupport/callstest"
	"dashuri/backend/internal/testsupport/pgtest"
)

type fakeClassifier struct{ score moderation.NudityScore }

func (f fakeClassifier) Score(context.Context, []byte) (moderation.NudityScore, error) {
	return f.score, nil
}

var frame = base64.StdEncoding.EncodeToString([]byte{0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3})

func activeCall(t *testing.T, svc *calls.Service, cust, host string, at time.Time) string {
	t.Helper()
	ctx := context.Background()
	s, err := svc.RequestCall(ctx, callstest.Principal(cust), calls.CallRequestBody{HostUserId: host})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := svc.AcceptCall(ctx, callstest.Principal(host), s.CallId); err != nil {
		t.Fatal(err)
	}
	callstest.Joined(t, svc, s.CallId, at, cust, host)
	if got, _ := svc.GetCall(ctx, callstest.Principal(cust), s.CallId); got.Phase != "active" {
		t.Fatalf("phase %s", got.Phase)
	}
	return s.CallId
}

func TestModerationFlagEndsCallAndOpensReport(t *testing.T) {
	api, admin := pgtest.Pools(t)
	ctx := context.Background()
	video := &callstest.Video{}
	callSvc := callstest.Calls(api, video)
	repo := postgres.ModerationRepo{Pool: api, Tx: db.TxManager{Pool: api}}
	flagging := moderation.NewService(moderation.Deps{Enabled: true, Repo: repo, Calls: callSvc,
		Classifier: fakeClassifier{moderation.NudityScore{Vendor: "fake", SexualDisplay: 0.93}}})

	host := callstest.Host(t, admin, 1000)
	cust := pgtest.NewUser(t, admin, true)
	callstest.Fund(t, api, cust, 10000)
	callID := activeCall(t, callSvc, cust, host, time.Now().UTC())

	// Strangers cannot submit; bad images are rejected.
	if _, err := flagging.SubmitFrame(ctx, callstest.Principal(pgtest.UUID()), callID, moderation.ModerationFrameRequest{ImageBase64: frame, CapturedAt: time.Now()}); callstest.Rule(err) != "not_found" {
		t.Fatalf("stranger: %v", err)
	}
	// Not configured while enabled → 503.
	unconfigured := moderation.NewService(moderation.Deps{Enabled: true, Repo: repo, Calls: callSvc})
	if _, err := unconfigured.SubmitFrame(ctx, callstest.Principal(cust), callID, moderation.ModerationFrameRequest{ImageBase64: frame, CapturedAt: time.Now()}); callstest.Rule(err) != "moderation_not_configured" {
		t.Fatalf("unconfigured: %v", err)
	}

	out, err := flagging.SubmitFrame(ctx, callstest.Principal(cust), callID, moderation.ModerationFrameRequest{ImageBase64: frame, CapturedAt: time.Now()})
	if err != nil || !out.Accepted {
		t.Fatalf("%+v %v", out, err)
	}
	got, _ := callSvc.GetCall(ctx, callstest.Principal(host), callID)
	if got.Phase != "ended" || got.EndReason == nil || *got.EndReason != "moderation" {
		t.Fatalf("call not ended for moderation: %+v", got)
	}
	var reportID, source, category string
	var reporter *string
	var priority int
	if err := api.QueryRow(ctx, `select id, reporter_id, source, category, priority from safety.reports where call_id = $1 and target_user_id = $2`,
		callID, cust).Scan(&reportID, &reporter, &source, &category, &priority); err != nil {
		t.Fatal(err)
	}
	if reporter != nil || source != "automated" || category != "nudity" || priority != 1 {
		t.Fatalf("report %v %s %s %d", reporter, source, category, priority)
	}
	var flagged int
	_ = api.QueryRow(ctx, `select count(*) from moderation.frame_checks where call_id = $1 and flagged and action = 'end_call'`, callID).Scan(&flagged)
	if flagged != 1 {
		t.Fatalf("frame checks %d", flagged)
	}
	// After the end the window is closed.
	if _, err := flagging.SubmitFrame(ctx, callstest.Principal(host), callID, moderation.ModerationFrameRequest{ImageBase64: frame, CapturedAt: time.Now()}); callstest.Rule(err) != "moderation_window_closed" {
		t.Fatalf("closed window: %v", err)
	}

	// Queue → decision (ban) → appeal by a different reviewer.
	mod1 := pgtest.NewUser(t, admin, true, "customer", "moderator")
	mod2 := pgtest.NewUser(t, admin, true, "customer", "moderator")
	page, err := flagging.ListModerationQueue(ctx, callstest.Principal(mod1, auth.RoleModerator), moderation.PageRequest{Limit: 100})
	if err != nil {
		t.Fatal(err)
	}
	found := false
	for _, c := range page.Items {
		if c.ReportId == reportID {
			found = c.EvidenceCount == 1 && c.TargetUserId == cust
		}
	}
	if !found {
		t.Fatal("case missing from queue or without evidence")
	}
	d, err := flagging.DecideReport(ctx, callstest.Principal(mod1), reportID, moderation.ModerationDecisionRequest{Action: "ban", Reason: "explicit content"})
	if err != nil || d.Status != "decided" {
		t.Fatalf("%+v %v", d, err)
	}
	if _, err := flagging.DecideReport(ctx, callstest.Principal(mod2), reportID, moderation.ModerationDecisionRequest{Action: "warn", Reason: "x"}); callstest.Rule(err) != "already_decided" {
		t.Fatalf("second decision: %v", err)
	}
	var status string
	var enforcementID string
	_ = api.QueryRow(ctx, `select status from identity.accounts where id = $1`, cust).Scan(&status)
	_ = api.QueryRow(ctx, `select id from safety.enforcement_actions where report_id = $1`, reportID).Scan(&enforcementID)
	if status != "banned" || enforcementID == "" {
		t.Fatalf("status %s enforcement %q", status, enforcementID)
	}
	var audits int
	_ = admin.QueryRow(ctx, `select count(*) from audit.events where target = $1 and action = 'moderation.report_decided'`, reportID).Scan(&audits)
	if audits != 1 {
		t.Fatalf("audit events %d", audits)
	}
	var appealID string
	if err := admin.QueryRow(ctx, `insert into safety.appeals (enforcement_id, user_id, statement) values ($1, $2, 'not me') returning id`,
		enforcementID, cust).Scan(&appealID); err != nil {
		t.Fatal(err)
	}
	if _, err := flagging.DecideAppeal(ctx, callstest.Principal(mod1), appealID, moderation.AppealDecisionRequest{Outcome: "overturned", Reason: "x"}); callstest.Rule(err) != "different_reviewer_required" {
		t.Fatalf("same reviewer: %v", err)
	}
	if _, err := flagging.DecideAppeal(ctx, callstest.Principal(mod2), appealID, moderation.AppealDecisionRequest{Outcome: "overturned", Reason: "false positive"}); err != nil {
		t.Fatal(err)
	}
	_ = api.QueryRow(ctx, `select status from identity.accounts where id = $1`, cust).Scan(&status)
	if status != "active" {
		t.Fatalf("overturned appeal left status %s", status)
	}
}

func TestMissingFramesQueueReviewOnce(t *testing.T) {
	api, admin := pgtest.Pools(t)
	ctx := context.Background()
	callSvc := callstest.Calls(api, &callstest.Video{})
	svc := moderation.NewService(moderation.Deps{Enabled: true, Calls: callSvc,
		Repo:       postgres.ModerationRepo{Pool: api, Tx: db.TxManager{Pool: api}},
		Classifier: fakeClassifier{moderation.NudityScore{Vendor: "fake"}}})
	host := callstest.Host(t, admin, 1000)
	cust := pgtest.NewUser(t, admin, true)
	callstest.Fund(t, api, cust, 100000)
	now := time.Now().UTC()
	callID := activeCall(t, callSvc, cust, host, now.Add(-70*time.Second))
	// The host keeps sending frames; the customer sends none.
	for _, ago := range []int{65, 45, 25, 5} {
		if _, err := api.Exec(ctx, `insert into moderation.frame_checks (call_id, user_id, checked_at, vendor, flagged, action)
			values ($1, $2, $3, 'fake', false, 'none')`, callID, host, now.Add(-time.Duration(ago)*time.Second)); err != nil {
			t.Fatal(err)
		}
	}
	n, err := svc.CheckMissingFrames(ctx, now)
	if err != nil {
		t.Fatal(err)
	}
	var cases int
	_ = api.QueryRow(ctx, `select count(*) from safety.reports where call_id = $1 and automated_reason = 'missing_frames' and target_user_id = $2`, callID, cust).Scan(&cases)
	var hostCases int
	_ = api.QueryRow(ctx, `select count(*) from safety.reports where call_id = $1 and target_user_id = $2`, callID, host).Scan(&hostCases)
	if n < 1 || cases != 1 || hostCases != 0 {
		t.Fatalf("opened=%d cases=%d hostCases=%d", n, cases, hostCases)
	}
	if n2, _ := svc.CheckMissingFrames(ctx, now); n2 != 0 {
		t.Fatalf("rerun opened %d", n2)
	}
	if got, _ := callSvc.GetCall(ctx, callstest.Principal(cust), callID); got.Phase != "active" {
		t.Fatalf("missing frames must not end the call: %s", got.Phase)
	}
}

// Security review findings 3, 6 and 8.
func TestEnforcementEndsLiveCallsAndConflictRules(t *testing.T) {
	api, admin := pgtest.Pools(t)
	ctx := context.Background()
	callSvc := callstest.Calls(api, &callstest.Video{})
	svc := moderation.NewService(moderation.Deps{Enabled: true, Calls: callSvc,
		Repo:       postgres.ModerationRepo{Pool: api, Tx: db.TxManager{Pool: api}},
		Classifier: fakeClassifier{moderation.NudityScore{Vendor: "fake"}}})
	host := callstest.Host(t, admin, 1000)
	cust := pgtest.NewUser(t, admin, true)
	mod := pgtest.NewUser(t, admin, true, "customer", "moderator")
	otherMod := pgtest.NewUser(t, admin, true, "customer", "moderator")
	callstest.Fund(t, api, cust, 100000)
	callID := activeCall(t, callSvc, cust, host, time.Now().UTC().Add(-30*time.Second))

	// 8: a second frame within 8 s is rate limited.
	req := moderation.ModerationFrameRequest{ImageBase64: frame, CapturedAt: time.Now().UTC()}
	if _, err := svc.SubmitFrame(ctx, callstest.Principal(cust), callID, req); err != nil {
		t.Fatalf("first frame: %v", err)
	}
	if _, err := svc.SubmitFrame(ctx, callstest.Principal(cust), callID, req); callstest.Rule(err) != "frame_rate_limited" {
		t.Fatalf("second frame: %v", err)
	}

	report := func(reporter, target string) string {
		var id string
		if err := admin.QueryRow(ctx, `insert into safety.reports (reporter_id, target_user_id, category, priority) values ($1, $2, 'harassment', 2) returning id`, reporter, target).Scan(&id); err != nil {
			t.Fatal(err)
		}
		return id
	}
	// 6: a moderator cannot decide a report they filed.
	own := report(mod, cust)
	if _, err := svc.DecideReport(ctx, callstest.Principal(mod, auth.RoleModerator), own, moderation.ModerationDecisionRequest{Action: "ban", Reason: "x"}); callstest.Rule(err) != "self_review" {
		t.Fatalf("own report: %v", err)
	}
	// 6: a moderator cannot ban another staff member; only an admin can.
	staff := report(cust, otherMod)
	if _, err := svc.DecideReport(ctx, callstest.Principal(mod, auth.RoleModerator), staff, moderation.ModerationDecisionRequest{Action: "ban", Reason: "x"}); callstest.Rule(err) != "admin_required" {
		t.Fatalf("staff target: %v", err)
	}
	// 3: banning the customer ends their live call.
	r := report(host, cust)
	if _, err := svc.DecideReport(ctx, callstest.Principal(otherMod, auth.RoleModerator), r, moderation.ModerationDecisionRequest{Action: "ban", Reason: "abuse"}); err != nil {
		t.Fatal(err)
	}
	var phase string
	_ = api.QueryRow(ctx, `select phase from calls.calls where id = $1`, callID).Scan(&phase)
	if phase != "ended" {
		t.Fatalf("ban left the live call in phase %s", phase)
	}
}
