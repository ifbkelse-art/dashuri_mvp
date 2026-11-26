//go:build integration

package hosts_test

import (
	"context"
	"encoding/json"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/admin"
	"dashuri/backend/internal/modules/calls"
	"dashuri/backend/internal/modules/discovery"
	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/modules/hosts"
	"dashuri/backend/internal/modules/ledger"
	"dashuri/backend/internal/modules/purchases"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/db"
	"dashuri/backend/internal/testsupport/callstest"
	"dashuri/backend/internal/testsupport/identitytest"
	"dashuri/backend/internal/testsupport/pgtest"
)

// fakeEvidence is the private evidence bucket.
type fakeEvidence struct {
	mu      sync.Mutex
	uploads []string
	deleted []string
}

func (f *fakeEvidence) Configured() bool { return true }
func (f *fakeEvidence) SignUpload(_ context.Context, path string) (string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.uploads = append(f.uploads, path)
	return "https://storage.test/upload/" + path + "?token=u", nil
}
func (f *fakeEvidence) SignRead(_ context.Context, paths []string, ttl time.Duration) map[string]string {
	out := map[string]string{}
	for _, p := range paths {
		out[p] = "https://storage.test/read/" + p + "?ttl=" + ttl.String()
	}
	return out
}
func (f *fakeEvidence) Delete(_ context.Context, path string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.deleted = append(f.deleted, path)
	return nil
}

type vEnv struct {
	ctx      context.Context
	api      *pgxpool.Pool
	admin    *pgxpool.Pool
	svc      *hosts.Service
	evidence *fakeEvidence
	rules    economy.Rules
}

func newVEnv(t *testing.T) vEnv {
	api, adm := pgtest.Pools(t)
	ev := &fakeEvidence{}
	r := economy.Founder()
	return vEnv{ctx: context.Background(), api: api, admin: adm, evidence: ev, rules: r,
		svc: hosts.NewService(hosts.Deps{Rules: r, Evidence: ev, Repo: postgres.HostsRepo{Pool: api, Tx: db.TxManager{Pool: api}}})}
}

// host creates an approved, online host at `level` (XP fixture) and rate 500.
func (e vEnv) host(t *testing.T, level int) (string, auth.Principal) {
	t.Helper()
	id := pgtest.NewUser(t, e.admin, true, "customer", "host")
	identitytest.Profile(t, e.admin, id, "Host", []string{"hi"}, nil)
	identitytest.Host(t, e.admin, id, 500, true)
	if level > 1 {
		identitytest.XP(t, e.admin, id, e.rules.XPThresholds[level-1])
	}
	return id, callstest.Principal(id, auth.RoleCustomer, auth.RoleHost)
}

func (e vEnv) moderator(t *testing.T) auth.Principal {
	return callstest.Principal(pgtest.NewUser(t, e.admin, true, "customer", "moderator"), auth.RoleModerator)
}

// verify runs the full workflow to an active Verified Host.
func (e vEnv) verify(t *testing.T, hostID string, hp, mod auth.Principal) {
	t.Helper()
	face, _ := e.svc.CreateEvidenceUpload(e.ctx, hp, hosts.EvidenceUploadRequest{Kind: "face_video", ContentType: "video/mp4"})
	id, _ := e.svc.CreateEvidenceUpload(e.ctx, hp, hosts.EvidenceUploadRequest{Kind: "id_document_front", ContentType: "image/jpeg"})
	if _, err := e.svc.SubmitVerification(e.ctx, hp, hosts.SubmitVerificationRequest{EvidenceIds: []string{face.EvidenceId, id.EvidenceId}}); err != nil {
		t.Fatal(err)
	}
	for _, a := range []string{"start_review", "approve"} {
		if _, err := e.svc.ActOnVerification(e.ctx, mod, hostID, hosts.VerificationActionRequest{Action: a, Reason: "ok"}); err != nil {
			t.Fatalf("%s: %v", a, err)
		}
	}
}

func (e vEnv) storedRate(t *testing.T, hostID string) int64 {
	t.Helper()
	var r int64
	if err := e.admin.QueryRow(e.ctx, `select rate_per_minute from hosting.hosts where user_id = $1`, hostID).Scan(&r); err != nil {
		t.Fatal(err)
	}
	return r
}

func (e vEnv) audits(t *testing.T, hostID, action string) int {
	t.Helper()
	var n int
	_ = e.admin.QueryRow(e.ctx, `select count(*) from audit.events where target = $1 and action = $2`, hostID, action).Scan(&n)
	return n
}

// Every level 1–10, verified and not: 499/500, max, max+1, 3,000/3,001.
func TestPricingEveryLevelAgainstDatabase(t *testing.T) {
	e := newVEnv(t)
	mod := e.moderator(t)
	for level := 1; level <= 10; level++ {
		for _, verified := range []bool{false, true} {
			hid, hp := e.host(t, level)
			if verified {
				e.verify(t, hid, hp, mod)
			}
			st, err := e.svc.GetHostStatus(e.ctx, hp)
			levelMax := int64(level) * 1000
			eligible := levelMax
			if !verified {
				eligible = min(levelMax, 3000)
			}
			if err != nil || st.Level != level || st.IsVerified != verified || st.MaxRatePerMinute != eligible ||
				st.LevelMaxRatePerMinute != levelMax || st.MinRatePerMinute != 500 || st.VerifiedRateThreshold != 3000 {
				t.Fatalf("L%d v=%v status %+v %v", level, verified, st, err)
			}
			if _, err := e.svc.SetRate(e.ctx, hp, hosts.SetRateRequest{RatePerMinute: 499}); callstest.Rule(err) != "rate_below_minimum" {
				t.Fatalf("L%d 499: %v", level, err)
			}
			for _, ok := range []int64{500, eligible} {
				if st, err := e.svc.SetRate(e.ctx, hp, hosts.SetRateRequest{RatePerMinute: ok}); err != nil || st.RatePerMinute != ok {
					t.Fatalf("L%d v=%v %d: %+v %v", level, verified, ok, st, err)
				}
			}
			want := "rate_outside_level_limits"
			if !verified && levelMax > 3000 {
				want = "verification_required_for_rate"
			}
			if _, err := e.svc.SetRate(e.ctx, hp, hosts.SetRateRequest{RatePerMinute: eligible + 1}); callstest.Rule(err) != want {
				t.Fatalf("L%d v=%v max+1: %v want %s", level, verified, err, want)
			}
			if e.storedRate(t, hid) != eligible {
				t.Fatalf("L%d rejected update changed the price", level)
			}
			if level >= 4 {
				_, err3000 := e.svc.SetRate(e.ctx, hp, hosts.SetRateRequest{RatePerMinute: 3000})
				_, err3001 := e.svc.SetRate(e.ctx, hp, hosts.SetRateRequest{RatePerMinute: 3001})
				if err3000 != nil || (verified != (err3001 == nil)) {
					t.Fatalf("L%d v=%v 3000=%v 3001=%v", level, verified, err3000, err3001)
				}
			}
		}
	}
}

// A client can never smuggle a higher price in: even a direct write is
// refused by the database for a non-verified host.
func TestDatabaseRefusesUnverifiedPremiumPrice(t *testing.T) {
	e := newVEnv(t)
	hid, _ := e.host(t, 10)
	if _, err := e.api.Exec(e.ctx, `update hosting.hosts set rate_per_minute = 3001 where user_id = $1`, hid); err == nil ||
		!strings.Contains(err.Error(), "rate_above_threshold_requires_verified") {
		t.Fatalf("db accepted 3,001 for a non-verified host: %v", err)
	}
}

func TestVerificationWorkflowAuditAndPriceCaps(t *testing.T) {
	e := newVEnv(t)
	hid, hp := e.host(t, 5)
	mod := e.moderator(t)
	adm := callstest.Principal(pgtest.NewUser(t, e.admin, true, "customer", "admin"), auth.RoleAdmin)
	customer := callstest.Principal(pgtest.NewUser(t, e.admin, true))

	v, err := e.svc.GetVerification(e.ctx, hp)
	if err != nil || v.Status != "not_applied" || !v.CanSubmit || len(v.RequiredEvidence) != 2 {
		t.Fatalf("%+v %v", v, err)
	}
	// Non-hosts cannot apply.
	if _, err := e.svc.GetVerification(e.ctx, customer); callstest.Rule(err) != "host_not_approved" {
		t.Fatalf("customer view: %v", err)
	}
	// Evidence is required.
	if _, err := e.svc.SubmitVerification(e.ctx, hp, hosts.SubmitVerificationRequest{}); callstest.Rule(err) != "validation_failed" {
		t.Fatalf("empty submit: %v", err)
	}
	face, err := e.svc.CreateEvidenceUpload(e.ctx, hp, hosts.EvidenceUploadRequest{Kind: "face_video", ContentType: "video/mp4"})
	if err != nil || face.UploadUrl == "" {
		t.Fatalf("%+v %v", face, err)
	}
	if _, err := e.svc.SubmitVerification(e.ctx, hp, hosts.SubmitVerificationRequest{EvidenceIds: []string{face.EvidenceId}}); callstest.Rule(err) != "validation_failed" {
		t.Fatalf("submit without ID document: %v", err)
	}
	idDoc, _ := e.svc.CreateEvidenceUpload(e.ctx, hp, hosts.EvidenceUploadRequest{Kind: "id_document_front", ContentType: "image/jpeg"})
	// Another host's evidence cannot be attached.
	otherID, otherP := e.host(t, 1)
	other, _ := e.svc.CreateEvidenceUpload(e.ctx, otherP, hosts.EvidenceUploadRequest{Kind: "face_video", ContentType: "video/mp4"})
	if _, err := e.svc.SubmitVerification(e.ctx, hp, hosts.SubmitVerificationRequest{EvidenceIds: []string{face.EvidenceId, idDoc.EvidenceId, other.EvidenceId}}); callstest.Rule(err) != "validation_failed" {
		t.Fatalf("foreign evidence: %v", err)
	}
	v, err = e.svc.SubmitVerification(e.ctx, hp, hosts.SubmitVerificationRequest{EvidenceIds: []string{face.EvidenceId, idDoc.EvidenceId}})
	if err != nil || v.Status != "submitted" || v.CanSubmit || v.ApplicationId == nil || len(v.Evidence) != 2 {
		t.Fatalf("%+v %v", v, err)
	}
	appID := *v.ApplicationId
	if _, err := e.svc.SubmitVerification(e.ctx, hp, hosts.SubmitVerificationRequest{EvidenceIds: []string{face.EvidenceId, idDoc.EvidenceId}}); callstest.Rule(err) != "verification_not_allowed" {
		t.Fatalf("double submit: %v", err)
	}
	// The host's own view never exposes storage paths or URLs.
	raw, _ := json.Marshal(v)
	if strings.Contains(string(raw), hid+"/") || strings.Contains(string(raw), "http") {
		t.Fatalf("host view leaks evidence location: %s", raw)
	}

	// Unauthorised transitions.
	if _, err := e.svc.ActOnVerification(e.ctx, customer, hid, hosts.VerificationActionRequest{Action: "approve"}); callstest.Rule(err) != "forbidden" {
		t.Fatalf("customer approve: %v", err)
	}
	if _, err := e.svc.ActOnVerification(e.ctx, hp, hid, hosts.VerificationActionRequest{Action: "approve"}); callstest.Rule(err) != "forbidden" {
		t.Fatalf("host self-approve without staff role: %v", err)
	}
	selfMod := callstest.Principal(hid, auth.RoleHost, auth.RoleModerator)
	if _, err := e.svc.ActOnVerification(e.ctx, selfMod, hid, hosts.VerificationActionRequest{Action: "start_review"}); callstest.Rule(err) != "self_review" {
		t.Fatalf("self review: %v", err)
	}
	if _, err := e.svc.EvidenceAccessURL(e.ctx, selfMod, hid, face.EvidenceId); callstest.Rule(err) != "self_review" {
		t.Fatalf("self evidence access: %v", err)
	}
	if _, err := e.svc.ActOnVerification(e.ctx, mod, hid, hosts.VerificationActionRequest{Action: "approve"}); callstest.Rule(err) != "invalid_transition" {
		t.Fatalf("approve before review: %v", err)
	}
	if _, err := e.svc.ActOnVerification(e.ctx, mod, hid, hosts.VerificationActionRequest{Action: "reject"}); callstest.Rule(err) != "validation_failed" {
		t.Fatalf("reject without reason: %v", err)
	}
	if _, err := e.svc.ActOnVerification(e.ctx, mod, otherID, hosts.VerificationActionRequest{Action: "start_review"}); callstest.Rule(err) != "verification_not_applied" {
		t.Fatalf("review without application: %v", err)
	}

	// Review → info required → resubmit → review → approve.
	steps := []hosts.VerificationActionRequest{{Action: "start_review"}, {Action: "request_info", InfoRequest: "ID photo is blurred"}}
	for _, s := range steps {
		if _, err := e.svc.ActOnVerification(e.ctx, mod, hid, s); err != nil {
			t.Fatalf("%s: %v", s.Action, err)
		}
	}
	if st, _ := e.svc.GetHostStatus(e.ctx, hp); st.VerificationStatus != "info_required" || st.VerificationNote == nil || *st.VerificationNote != "ID photo is blurred" {
		t.Fatalf("%+v", st)
	}
	back, _ := e.svc.CreateEvidenceUpload(e.ctx, hp, hosts.EvidenceUploadRequest{Kind: "id_document_back", ContentType: "image/png"})
	if v, err := e.svc.SubmitVerification(e.ctx, hp, hosts.SubmitVerificationRequest{EvidenceIds: []string{back.EvidenceId}}); err != nil || v.Status != "submitted" || *v.ApplicationId != appID {
		t.Fatalf("resubmit %+v %v", v, err)
	}
	// Staff evidence access: short-lived, audited.
	acc, err := e.svc.EvidenceAccessURL(e.ctx, mod, hid, face.EvidenceId)
	if err != nil || !strings.Contains(acc.Url, "ttl=5m0s") || acc.ExpiresAt.After(time.Now().Add(6*time.Minute)) {
		t.Fatalf("%+v %v", acc, err)
	}
	if e.audits(t, hid, "host.verification.evidence_accessed") != 1 {
		t.Fatal("evidence access not audited")
	}
	if _, err := e.svc.EvidenceAccessURL(e.ctx, mod, otherID, face.EvidenceId); err == nil {
		t.Fatal("evidence readable through another host id")
	}
	for _, a := range []string{"start_review", "approve"} {
		if _, err := e.svc.ActOnVerification(e.ctx, adm, hid, hosts.VerificationActionRequest{Action: a, Reason: "face matches ID"}); err != nil {
			t.Fatalf("%s: %v", a, err)
		}
	}
	st, _ := e.svc.GetHostStatus(e.ctx, hp)
	if !st.IsVerified || st.VerificationStatus != "verified" || st.MaxRatePerMinute != 5000 || st.RatePerMinute != 500 {
		t.Fatalf("approval must not change the price: %+v", st)
	}
	if _, err := e.svc.SetRate(e.ctx, hp, hosts.SetRateRequest{RatePerMinute: 5000}); err != nil {
		t.Fatal(err)
	}

	// Suspend → capped to 3,000; reinstate keeps 3,000; revoke caps again.
	d, err := e.svc.ActOnVerification(e.ctx, mod, hid, hosts.VerificationActionRequest{Action: "suspend", Reason: "report under review"})
	if err != nil || d.Status != "suspended" || e.storedRate(t, hid) != 3000 || d.RatePerMinute != 3000 {
		t.Fatalf("suspend %+v %v rate=%d", d, err, e.storedRate(t, hid))
	}
	if _, err := e.svc.SetRate(e.ctx, hp, hosts.SetRateRequest{RatePerMinute: 3001}); callstest.Rule(err) != "verification_required_for_rate" {
		t.Fatalf("suspended host raised price: %v", err)
	}
	if _, err := e.svc.ActOnVerification(e.ctx, mod, hid, hosts.VerificationActionRequest{Action: "reinstate", Reason: "cleared"}); err != nil || e.storedRate(t, hid) != 3000 {
		t.Fatalf("reinstate %v rate=%d", err, e.storedRate(t, hid))
	}
	if _, err := e.svc.SetRate(e.ctx, hp, hosts.SetRateRequest{RatePerMinute: 4500}); err != nil {
		t.Fatal(err)
	}
	if _, err := e.svc.ActOnVerification(e.ctx, adm, hid, hosts.VerificationActionRequest{Action: "revoke", Reason: "ID was forged"}); err != nil {
		t.Fatal(err)
	}
	st, _ = e.svc.GetHostStatus(e.ctx, hp)
	if st.IsVerified || st.VerificationStatus != "revoked" || st.RatePerMinute != 3000 || *st.VerificationNote != "ID was forged" {
		t.Fatalf("after revoke %+v", st)
	}
	if _, err := e.svc.ActOnVerification(e.ctx, mod, hid, hosts.VerificationActionRequest{Action: "reinstate", Reason: "x"}); callstest.Rule(err) != "invalid_transition" {
		t.Fatalf("reinstate after revoke: %v", err)
	}

	// Audit trail: every action with actor, time, reason and application id.
	d, err = e.svc.GetAdminVerification(e.ctx, mod, hid)
	if err != nil {
		t.Fatal(err)
	}
	actions := map[string]int{}
	for _, h := range d.History {
		actions[h.Action]++
		if strings.HasPrefix(h.Action, "host.verification.") && h.Action != "host.verification.evidence_accessed" {
			if h.Details["application_id"] != appID || h.Actor == "" || h.At.IsZero() {
				t.Fatalf("incomplete audit row %+v", h)
			}
		}
	}
	for _, a := range []string{"submitted", "review_started", "info_requested", "resubmitted", "approved", "suspended", "reinstated", "revoked"} {
		if actions["host.verification."+a] == 0 {
			t.Fatalf("missing audit %s in %v", a, actions)
		}
	}
	if actions["host.rate_capped"] != 2 {
		t.Fatalf("rate caps audited %d", actions["host.rate_capped"])
	}
	var reason string
	_ = e.admin.QueryRow(e.ctx, `select details->>'reason' from audit.events where target = $1 and action = 'host.verification.revoked'`, hid).Scan(&reason)
	if reason != "ID was forged" {
		t.Fatalf("revoke reason %q", reason)
	}

	// Revoked hosts may apply again (a new application).
	if v, _ := e.svc.GetVerification(e.ctx, hp); !v.CanSubmit {
		t.Fatal("revoked host cannot reapply")
	}

	// Retention: evidence of final decisions is purged after the period.
	if _, err := e.admin.Exec(e.ctx, `update hosting.verification_applications set decided_at = now() - interval '91 days' where id = $1`, appID); err != nil {
		t.Fatal(err)
	}
	if n, err := e.svc.PurgeEvidence(e.ctx, 500); err != nil || n < 3 {
		t.Fatalf("purged %d %v", n, err)
	}
	if _, err := e.svc.EvidenceAccessURL(e.ctx, mod, hid, face.EvidenceId); callstest.Rule(err) != "evidence_purged" {
		t.Fatalf("purged evidence still readable: %v", err)
	}
}

// Revocation while a call is live: the live call keeps its rate and is
// billed at it; the next call uses the capped price.
func TestRevocationNeverChangesALiveCall(t *testing.T) {
	e := newVEnv(t)
	hid, hp := e.host(t, 4)
	mod := e.moderator(t)
	e.verify(t, hid, hp, mod)
	if _, err := e.svc.SetRate(e.ctx, hp, hosts.SetRateRequest{RatePerMinute: 4000}); err != nil {
		t.Fatal(err)
	}
	video := &callstest.Video{}
	csvc := callstest.Calls(e.api, video)
	cust := pgtest.NewUser(t, e.admin, true)
	callstest.Fund(t, e.api, cust, 100000)
	cs, err := csvc.RequestCall(e.ctx, callstest.Principal(cust), calls.CallRequestBody{HostUserId: hid})
	if err != nil || cs.RatePerMinute != 4000 {
		t.Fatalf("%+v %v", cs, err)
	}
	if _, err := e.svc.ActOnVerification(e.ctx, mod, hid, hosts.VerificationActionRequest{Action: "revoke", Reason: "policy"}); err != nil {
		t.Fatal(err)
	}
	var live int64
	_ = e.admin.QueryRow(e.ctx, `select rate_per_minute from calls.calls where id = $1`, cs.CallId).Scan(&live)
	if live != 4000 || e.storedRate(t, hid) != 3000 {
		t.Fatalf("live call rate %d, stored %d", live, e.storedRate(t, hid))
	}
}

// A level drop that bypassed the reversal path (e.g. thresholds changed) is
// still caught at call creation, under the host row lock, before the rate
// is snapshotted; the cap is persisted and audited.
func TestCallCreationCapsPriceAfterLevelDrop(t *testing.T) {
	e := newVEnv(t)
	hid, hp := e.host(t, 6)
	e.verify(t, hid, hp, e.moderator(t))
	if _, err := e.svc.SetRate(e.ctx, hp, hosts.SetRateRequest{RatePerMinute: 6000}); err != nil {
		t.Fatal(err)
	}
	// Level 6 → level 2 behind the API's back.
	if _, err := e.admin.Exec(e.ctx, `insert into ledger.xp_events (user_id, source_type, source_id, xp_delta) values ($1, 'reversal', gen_random_uuid()::text, $2)`,
		hid, -(e.rules.XPThresholds[5] - e.rules.XPThresholds[1])); err != nil {
		t.Fatal(err)
	}
	// Discovery already shows the eligible price.
	d := discovery.NewService(discovery.Deps{Repo: postgres.DiscoveryRepo{Pool: e.api}, Rules: e.rules})
	viewer := pgtest.NewUser(t, e.admin, true)
	if card, err := d.GetHost(e.ctx, callstest.Principal(viewer), hid); err != nil || card.RatePerMinute != 2000 || !card.IsVerified || card.Level != 2 {
		t.Fatalf("discovery %+v %v", card, err)
	}
	csvc := callstest.Calls(e.api, &callstest.Video{})
	cust := pgtest.NewUser(t, e.admin, true)
	callstest.Fund(t, e.api, cust, 100000)
	cs, err := csvc.RequestCall(e.ctx, callstest.Principal(cust), calls.CallRequestBody{HostUserId: hid})
	if err != nil || cs.RatePerMinute != 2000 || e.storedRate(t, hid) != 2000 || e.audits(t, hid, "host.rate_capped") != 1 {
		t.Fatalf("%+v %v stored=%d", cs, err, e.storedRate(t, hid))
	}
}

// A purchase reversal that lowers a host's level caps the stored price in
// the same transaction.
func TestPurchaseReversalLevelDropCapsPrice(t *testing.T) {
	e := newVEnv(t)
	hid, hp := e.host(t, 1)
	e.verify(t, hid, hp, e.moderator(t))
	repo := postgres.PurchasesRepo{Pool: e.api, Tx: db.TxManager{Pool: e.api}, Rules: e.rules}
	var product string
	if err := e.admin.QueryRow(e.ctx, `select product_id from economy.diamond_packages order by diamonds limit 1`).Scan(&product); err != nil {
		t.Fatal(err)
	}
	diamonds := e.rules.XPThresholds[5] / e.rules.XPDiamondWeight // exactly level 6
	token := "rev-" + pgtest.UUID()
	if _, _, err := repo.CreditPurchase(e.ctx, purchases.Credit{UserID: hid, ProductID: product, TokenHash: token, OrderID: "GPA." + token,
		Diamonds: diamonds, Rail: "google_play", XP: diamonds * e.rules.XPDiamondWeight,
		Entry: func(pid string) ledger.Entry {
			return ledger.PurchaseCredit(hid, pid, token, diamonds, e.rules.Version, time.Now())
		}}); err != nil {
		t.Fatal(err)
	}
	if st, err := e.svc.SetRate(e.ctx, hp, hosts.SetRateRequest{RatePerMinute: 6000}); err != nil || st.Level != 6 {
		t.Fatalf("%+v %v", st, err)
	}
	if _, err := repo.ReversePurchase(e.ctx, token, "refund", time.Now(),
		func(p purchases.PurchaseRecord, purchased, promo, reserved int64) int64 {
			return min(purchased, p.Diamonds)
		},
		e.rules.XPDiamondWeight); err != nil {
		t.Fatal(err)
	}
	if r := e.storedRate(t, hid); r != 1000 {
		t.Fatalf("after level drop to 1 the stored price is %d, want 1,000", r)
	}
	var reason string
	_ = e.admin.QueryRow(e.ctx, `select details->>'reason' from audit.events where target = $1 and action = 'host.rate_capped'`, hid).Scan(&reason)
	if reason != "level_decreased" {
		t.Fatalf("cap reason %q", reason)
	}
}

// Concurrent price updates and a revocation never leave a non-verified
// host above 3,000 (serialised on the host row; CHECK as a backstop).
func TestConcurrentRateUpdatesAndRevocation(t *testing.T) {
	e := newVEnv(t)
	hid, hp := e.host(t, 10)
	mod := e.moderator(t)
	e.verify(t, hid, hp, mod)
	var wg sync.WaitGroup
	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			_, _ = e.svc.SetRate(e.ctx, hp, hosts.SetRateRequest{RatePerMinute: 9000 + int64(i)})
		}(i)
	}
	wg.Add(1)
	go func() {
		defer wg.Done()
		if _, err := e.svc.ActOnVerification(e.ctx, mod, hid, hosts.VerificationActionRequest{Action: "revoke", Reason: "race"}); err != nil {
			t.Error(err)
		}
	}()
	wg.Wait()
	var rate int64
	var status string
	_ = e.admin.QueryRow(e.ctx, `select rate_per_minute, verification_status from hosting.hosts where user_id = $1`, hid).Scan(&rate, &status)
	if status != "revoked" || rate > 3000 {
		t.Fatalf("status %s rate %d", status, rate)
	}
}

// Discovery: All / Verified / Non-Verified filters; verification is a
// ranking signal (boost) and never excludes non-verified hosts.
func TestDiscoveryVerificationFilterAndRanking(t *testing.T) {
	e := newVEnv(t)
	mod := e.moderator(t)
	city := "pune"
	viewer := pgtest.NewUser(t, e.admin, true)
	mk := func(verified bool) string {
		id, p := e.host(t, 2)
		if _, err := e.admin.Exec(e.ctx, `update identity.profiles set city_id = $2 where user_id = $1`, id, city); err != nil {
			t.Fatal(err)
		}
		if verified {
			e.verify(t, id, p, mod)
		}
		return id
	}
	plainHigherXP := mk(false)
	identitytest.XP(t, e.admin, plainHigherXP, 1000) // more XP than the verified host
	ver := mk(true)
	plain := mk(false)
	list := func(verification string, boost int64) []string {
		s := discovery.NewService(discovery.Deps{Repo: postgres.DiscoveryRepo{Pool: e.api}, Rules: e.rules, VerifiedBoostXP: boost})
		var out []string
		page, err := s.ListAvailableHosts(e.ctx, callstest.Principal(viewer), discovery.ListRequest{CityID: city, Verification: verification, Limit: 100})
		if err != nil {
			t.Fatal(err)
		}
		for _, c := range page.Items {
			switch c.UserId {
			case ver, plain, plainHigherXP:
				if c.IsVerified != (c.UserId == ver) {
					t.Fatalf("is_verified wrong for %s", c.UserId)
				}
				out = append(out, c.UserId)
			}
		}
		return out
	}
	if got := list("verified", 0); len(got) != 1 || got[0] != ver {
		t.Fatalf("verified filter %v", got)
	}
	if got := list("non_verified", 0); len(got) != 2 {
		t.Fatalf("non-verified filter %v", got)
	}
	if got := list("", 0); len(got) != 3 || got[0] != plainHigherXP {
		t.Fatalf("no boost: %v", got)
	}
	if got := list("all", 100000); len(got) != 3 || got[0] != ver {
		t.Fatalf("boost must rank the verified host first without excluding others: %v", got)
	}
	s := discovery.NewService(discovery.Deps{Repo: postgres.DiscoveryRepo{Pool: e.api}, Rules: e.rules})
	if _, err := s.ListAvailableHosts(e.ctx, callstest.Principal(viewer), discovery.ListRequest{Verification: "gold", Limit: 10}); callstest.Rule(err) != "validation_failed" {
		t.Fatalf("bad filter: %v", err)
	}
	// Public card JSON never carries verification evidence.
	card, _ := s.GetHost(e.ctx, callstest.Principal(viewer), ver)
	raw, _ := json.Marshal(card)
	for _, leak := range []string{"evidence", "face_video", "id_document", "verification_status"} {
		if strings.Contains(string(raw), leak) {
			t.Fatalf("public card leaks %s: %s", leak, raw)
		}
	}
}

// The verification and pricing changes post nothing to the ledger:
// reconciliation stays clean.
func TestLedgerUnaffectedByVerificationAndPricing(t *testing.T) {
	e := newVEnv(t)
	hid, hp := e.host(t, 4)
	mod := e.moderator(t)
	e.verify(t, hid, hp, mod)
	_, _ = e.svc.SetRate(e.ctx, hp, hosts.SetRateRequest{RatePerMinute: 4000})
	_, _ = e.svc.ActOnVerification(e.ctx, mod, hid, hosts.VerificationActionRequest{Action: "revoke", Reason: "x"})
	rc, err := (postgres.AdminRepo{Pool: e.api, Tx: db.TxManager{Pool: e.api}}).Reconcile(e.ctx)
	if err != nil {
		t.Fatal(err)
	}
	rep := admin.NewService(admin.Deps{Rules: e.rules}).Report(rc)
	if rep.UnbalancedEntries != 0 || len(rep.DriftedAccounts) != 0 {
		t.Fatalf("ledger affected: %+v", rep)
	}
	var entriesForHost int
	_ = e.admin.QueryRow(e.ctx, `select count(*) from ledger.postings p join ledger.accounts a on a.id = p.account_id where a.owner_user_id = $1`, hid).Scan(&entriesForHost)
	if entriesForHost != 0 {
		t.Fatalf("verification/pricing posted %d ledger rows for the host", entriesForHost)
	}
}
