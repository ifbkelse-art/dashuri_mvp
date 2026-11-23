//go:build integration

package reels_test

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"sync"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/reels"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/db"
	"dashuri/backend/internal/testsupport/identitytest"
	"dashuri/backend/internal/testsupport/pgtest"
)

// ---------------------------------------------------------------- fakes

// fakeProvider records calls; webhooks are JSON-encoded WebhookEvents (the
// real signature check is tested in adapters/mux).
type fakeProvider struct {
	mu      sync.Mutex
	n       int
	deleted []string
}

func (p *fakeProvider) Name() string     { return "fake" }
func (p *fakeProvider) Configured() bool { return true }
func (p *fakeProvider) CreateUpload(_ context.Context, pass string) (reels.UploadSession, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.n++
	return reels.UploadSession{UploadID: fmt.Sprintf("up-%s", pass), URL: "https://upload.example/" + pass, ExpiresAt: time.Now().Add(time.Hour)}, nil
}
func (p *fakeProvider) UploadStatus(context.Context, string) (reels.UploadState, error) {
	return reels.UploadState{State: "waiting"}, nil
}
func (p *fakeProvider) Asset(context.Context, string) (reels.AssetInfo, error) {
	return reels.AssetInfo{}, reels.ErrAssetNotFound
}
func (p *fakeProvider) Playback(id string, ttl time.Duration) (reels.Playback, error) {
	return reels.Playback{HLSURL: "https://play.example/" + id + ".m3u8", ThumbnailURL: "https://img.example/" + id, ExpiresAt: time.Now().Add(ttl)}, nil
}
func (p *fakeProvider) FrameURLs(id string, ms int, iv, _ time.Duration) ([]string, error) {
	return []string{"https://img.example/" + id + "?t=0", "https://img.example/" + id + "?t=2"}, nil
}
func (p *fakeProvider) DeleteAsset(_ context.Context, id string) error {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.deleted = append(p.deleted, id)
	return nil
}
func (p *fakeProvider) ParseWebhook(_ map[string]string, body []byte, _ time.Time) (reels.WebhookEvent, error) {
	var ev reels.WebhookEvent
	err := json.Unmarshal(body, &ev)
	return ev, err
}

type fakeClassifier struct {
	scores reels.FrameScores
	err    error
}

func (c fakeClassifier) ClassifyURL(context.Context, string) (reels.FrameScores, error) {
	return c.scores, c.err
}

// ---------------------------------------------------------------- fixture helpers

type env struct {
	t        *testing.T
	api, adm *pgxpool.Pool
	prov     *fakeProvider
	svc      *reels.Service
	ctx      context.Context
}

func setup(t *testing.T, cls reels.FrameClassifier) *env {
	api, adm := pgtest.Pools(t)
	prov := &fakeProvider{}
	svc := reels.NewService(reels.Deps{Enabled: true, Repo: postgres.ReelsRepo{Pool: api, Tx: db.TxManager{Pool: api}},
		Provider: prov, Classifier: cls})
	return &env{t: t, api: api, adm: adm, prov: prov, svc: svc, ctx: context.Background()}
}

func (e *env) user(name string, roles ...string) (string, auth.Principal) {
	id := pgtest.NewUser(e.t, e.adm, true, roles...)
	identitytest.Profile(e.t, e.adm, id, name, []string{"hi"}, nil)
	p := identitytest.Principal(id)
	for _, r := range roles {
		p.Roles = append(p.Roles, auth.Role(r))
	}
	return id, p
}

func (e *env) webhook(ev reels.WebhookEvent) {
	e.t.Helper()
	b, _ := json.Marshal(ev)
	if err := e.svc.HandleWebhook(e.ctx, "fake", nil, b); err != nil {
		e.t.Fatalf("webhook %s: %v", ev.Type, err)
	}
}

// uploadReady creates an upload and drives it to pending_moderation.
func (e *env) uploadReady(p auth.Principal, ms int) string {
	e.t.Helper()
	d := 30000
	tk, err := e.svc.CreateUpload(e.ctx, p, reels.CreateUploadRequest{DeclaredDurationMs: &d, Caption: ptr("hello")})
	if err != nil {
		e.t.Fatal(err)
	}
	id := tk.Reel.Id
	e.webhook(reels.WebhookEvent{DeliveryID: "c-" + id, Type: "upload_asset_created", UploadID: "up-" + id, Asset: reels.AssetInfo{ID: "as-" + id}})
	e.webhook(reels.WebhookEvent{DeliveryID: "r-" + id, Type: "asset_ready", Asset: reels.AssetInfo{ID: "as-" + id, DurationMs: ms, PlaybackID: "pb-" + id, Passthrough: id}})
	return id
}

// published inserts a published reel directly (with an approving decision).
func (e *env) published(creator string, age time.Duration) string {
	e.t.Helper()
	var id string
	err := e.adm.QueryRow(e.ctx, `insert into reels.videos (creator_id, declared_duration_ms, provider, provider_asset_id, playback_id, duration_ms, caption)
	   values ($1, 20000, 'fake', gen_random_uuid()::text, 'pb', 20000, 'x') returning id`, creator).Scan(&id)
	if err != nil {
		e.t.Fatal(err)
	}
	mod := pgtest.NewUser(e.t, e.adm, true, "moderator")
	if _, err := e.adm.Exec(e.ctx, `insert into reels.moderation_decisions (video_id, decision, reason_code, source, decided_by) values ($1, 'approve', 'fixture', 'moderator', $2)`, id, mod); err != nil {
		e.t.Fatal(err)
	}
	if _, err := e.adm.Exec(e.ctx, `update reels.videos set status = 'published', published_at = now() - make_interval(secs => $2) where id = $1`, id, age.Seconds()); err != nil {
		e.t.Fatal(err)
	}
	return id
}

func (e *env) status(id string) string {
	var s string
	if err := e.adm.QueryRow(e.ctx, `select status from reels.videos where id = $1`, id).Scan(&s); err != nil {
		e.t.Fatal(err)
	}
	return s
}

func code(err error) string {
	if a := apperr.As(err); a != nil {
		return a.Code
	}
	if err != nil {
		return err.Error()
	}
	return ""
}

func ptr[T any](v T) *T { return &v }

// ---------------------------------------------------------------- tests

func TestLifecycleFirstReelNeedsHumanThenAutomated(t *testing.T) {
	e := setup(t, fakeClassifier{scores: reels.FrameScores{Sexual: 0.01}})
	_, creator := e.user("Asha", "host")
	_, viewer := e.user("Ravi")
	modID, mod := e.user("Mod", "moderator")
	_ = modID

	id := e.uploadReady(creator, 21000)
	if s := e.status(id); s != "pending_moderation" {
		t.Fatalf("after ready: %s", s)
	}
	// Not public while pending.
	if _, err := e.svc.GetReel(e.ctx, viewer, id); code(err) != "not_found" {
		t.Fatalf("pending reel visible to others: %v", err)
	}
	if own, err := e.svc.GetReel(e.ctx, creator, id); err != nil || own.Status != "pending_moderation" || own.Playback == nil {
		t.Fatalf("creator preview: %+v %v", own, err)
	}
	if n, err := e.svc.ModeratePending(e.ctx, 10); err != nil || n != 1 {
		t.Fatalf("moderate: %d %v", n, err)
	}
	if s := e.status(id); s != "in_review" {
		t.Fatalf("first reel must go to human review, got %s", s)
	}
	feed, _ := e.svc.Feed(e.ctx, viewer, "for_you", "", 10)
	if len(feed.Items) != 0 {
		t.Fatal("in-review reel leaked into the feed")
	}
	q, err := e.svc.Queue(e.ctx, mod, "", 10)
	if err != nil || len(q.Items) == 0 || q.Items[0].Reel.Playback == nil {
		t.Fatalf("queue: %+v %v", q, err)
	}
	if _, err := e.svc.Decide(e.ctx, creator, id, reels.DecisionRequest{Decision: ptr("approve"), ReasonCode: ptr("ok")}); code(err) != "role_required" {
		t.Fatalf("creator approving own reel: %v", err)
	}
	if res, err := e.svc.Decide(e.ctx, mod, id, reels.DecisionRequest{Decision: ptr("approve"), ReasonCode: ptr("ok")}); err != nil || res.Status != "published" {
		t.Fatalf("approve: %+v %v", res, err)
	}
	feed, _ = e.svc.Feed(e.ctx, viewer, "for_you", "", 10)
	if len(feed.Items) != 1 || feed.Items[0].Id != id || feed.Items[0].Playback == nil {
		t.Fatalf("published reel missing from feed: %+v", feed)
	}
	// Second reel from the now-established creator is approved automatically.
	id2 := e.uploadReady(creator, 30000)
	if _, err := e.svc.ModeratePending(e.ctx, 10); err != nil {
		t.Fatal(err)
	}
	if s := e.status(id2); s != "published" {
		t.Fatalf("second reel: %s", s)
	}
	// Duplicate webhook deliveries are ignored.
	e.webhook(reels.WebhookEvent{DeliveryID: "r-" + id2, Type: "asset_ready", Asset: reels.AssetInfo{ID: "as-" + id2, DurationMs: 30000, PlaybackID: "pb-" + id2}})
	if s := e.status(id2); s != "published" {
		t.Fatalf("redelivery changed state: %s", s)
	}
	var decisions int
	_ = e.adm.QueryRow(e.ctx, `select count(*) from reels.moderation_decisions where video_id = any($1)`, []string{id, id2}).Scan(&decisions)
	if decisions != 2 {
		t.Fatalf("audit trail: %d decisions", decisions)
	}
}

func TestDatabaseRefusesPublicationWithoutDecision(t *testing.T) {
	e := setup(t, nil)
	cid, _ := e.user("Asha")
	var id string
	if err := e.api.QueryRow(e.ctx, `insert into reels.videos (creator_id, declared_duration_ms, provider) values ($1, 20000, 'fake') returning id`, cid).Scan(&id); err != nil {
		t.Fatal(err)
	}
	_, err := e.api.Exec(e.ctx, `update reels.videos set status = 'published', published_at = now() where id = $1`, id)
	if !postgres.IsCheckViolation(err) {
		t.Fatalf("publication without decision must fail, got %v", err)
	}
	if _, err := e.api.Exec(e.ctx, `insert into reels.videos (creator_id, declared_duration_ms, provider, status, published_at) values ($1, 20000, 'fake', 'published', now())`, cid); !postgres.IsCheckViolation(err) {
		t.Fatalf("insert as published must fail, got %v", err)
	}
	if _, err := e.api.Exec(e.ctx, `insert into reels.moderation_decisions (video_id, decision, reason_code, source) values ($1, 'reject', 'x', 'automated')`, id); err != nil {
		t.Fatal(err)
	}
	if _, err := e.api.Exec(e.ctx, `update reels.moderation_decisions set decision = 'approve' where video_id = $1`, id); err == nil {
		t.Fatal("decisions must be append-only")
	}
	if _, err := e.api.Exec(e.ctx, `update reels.videos set status = 'published', published_at = now() where id = $1`, id); !postgres.IsCheckViolation(err) {
		t.Fatalf("latest decision is reject: must fail, got %v", err)
	}
}

func TestFailClosedWithoutClassifierOrOnOutage(t *testing.T) {
	e := setup(t, nil) // no classifier configured
	_, creator := e.user("Asha", "host")
	id := e.uploadReady(creator, 20000)
	if _, err := e.svc.ModeratePending(e.ctx, 10); err != nil {
		t.Fatal(err)
	}
	var src string
	_ = e.adm.QueryRow(e.ctx, `select source from reels.moderation_cases where video_id = $1 and status = 'open'`, id).Scan(&src)
	if e.status(id) != "in_review" || src != "provider_unavailable" {
		t.Fatalf("no classifier → human review, got %s/%s", e.status(id), src)
	}

	out := setup(t, fakeClassifier{err: errors.New("503")})
	_, c2 := out.user("Bina", "host")
	id2 := out.uploadReady(c2, 20000)
	if _, err := out.svc.ModeratePending(out.ctx, 10); err != nil {
		t.Fatal(err)
	}
	if s := out.status(id2); s != "pending_moderation" {
		t.Fatalf("outage: stay pending and retry, got %s", s)
	}
	// After the give-up window the reel goes to humans, never to the public.
	if _, err := out.adm.Exec(out.ctx, `update reels.videos set updated_at = now() - interval '31 minutes' where id = $1`, id2); err != nil {
		t.Fatal(err)
	}
	if _, err := out.adm.Exec(out.ctx, `alter table reels.videos disable trigger videos_touch`); err == nil {
		defer out.adm.Exec(out.ctx, `alter table reels.videos enable trigger videos_touch`)
	}
	if _, err := out.adm.Exec(out.ctx, `update reels.videos set updated_at = now() - interval '31 minutes' where id = $1`, id2); err != nil {
		t.Fatal(err)
	}
	if _, err := out.svc.ModeratePending(out.ctx, 10); err != nil {
		t.Fatal(err)
	}
	if s := out.status(id2); s != "in_review" {
		t.Fatalf("after give-up: %s", s)
	}
}

func TestRejectAppealRestoreAndDuration(t *testing.T) {
	e := setup(t, fakeClassifier{scores: reels.FrameScores{Sexual: 0.97}})
	_, creator := e.user("Asha", "host")
	_, mod := e.user("Mod", "moderator")
	id := e.uploadReady(creator, 20000)
	_, _ = e.svc.ModeratePending(e.ctx, 10)
	r, _ := e.svc.GetReel(e.ctx, creator, id)
	if r.Status != "rejected" || r.RejectionCode == nil || *r.RejectionCode != "sexual_content" {
		t.Fatalf("reject: %+v", r)
	}
	if err := e.svc.Appeal(e.ctx, creator, id, reels.AppealRequest{Statement: ptr("It is a swimming lesson")}); err != nil {
		t.Fatal(err)
	}
	if err := e.svc.Appeal(e.ctx, creator, id, reels.AppealRequest{Statement: ptr("again")}); code(err) != "already_appealed" {
		t.Fatalf("second appeal: %v", err)
	}
	q, _ := e.svc.Queue(e.ctx, mod, "", 10)
	found := false
	for _, it := range q.Items {
		found = found || (it.Reel.Id == id && it.Source == "appeal" && it.Appeal != nil)
	}
	if !found {
		t.Fatal("appeal not in queue")
	}
	if _, err := e.svc.Decide(e.ctx, mod, id, reels.DecisionRequest{Decision: ptr("remove"), ReasonCode: ptr("x")}); code(err) != "illegal_moderation_transition" {
		t.Fatalf("remove a rejected reel: %v", err)
	}
	if res, err := e.svc.Decide(e.ctx, mod, id, reels.DecisionRequest{Decision: ptr("restore"), ReasonCode: ptr("appeal_overturned")}); err != nil || res.Status != "published" {
		t.Fatalf("restore: %+v %v", res, err)
	}
	var ap string
	_ = e.adm.QueryRow(e.ctx, `select status from reels.appeals where video_id = $1`, id).Scan(&ap)
	if ap != "overturned" {
		t.Fatalf("appeal status %s", ap)
	}
	long := e.uploadReady(creator, 75000)
	if r, _ := e.svc.GetReel(e.ctx, creator, long); r.Status != "failed" || *r.RejectionCode != "duration_out_of_range" {
		t.Fatalf("75 s video: %+v", r)
	}
}

func TestFeedPaginationBlocksReportsFollowing(t *testing.T) {
	e := setup(t, nil)
	viewerID, viewer := e.user("Viewer")
	var creators []string
	mine := map[string]bool{}
	for i := range 5 {
		c, _ := e.user(fmt.Sprintf("C%d", i))
		creators = append(creators, c)
		for j := range 5 {
			mine[e.published(c, time.Duration(i*5+j)*time.Hour)] = true
		}
	}
	seen := map[string]bool{}
	cursor := ""
	pages := 0
	for {
		page, err := e.svc.Feed(e.ctx, viewer, "for_you", cursor, 10)
		if err != nil {
			t.Fatal(err)
		}
		pages++
		for _, it := range page.Items {
			if seen[it.Id] {
				t.Fatalf("duplicate %s on page %d", it.Id, pages)
			}
			seen[it.Id] = true
		}
		if page.NextCursor == nil {
			break
		}
		cursor = *page.NextCursor
	}
	got := 0
	for id := range mine {
		if seen[id] {
			got++
		}
	}
	// The shared test database may hold reels from other tests; all 25 of
	// ours must appear exactly once across at least 3 pages of 10.
	if got != 25 || pages < 3 {
		t.Fatalf("got %d of 25 reels in %d pages", got, pages)
	}
	if _, err := e.svc.Feed(e.ctx, viewer, "for_you", "garbage", 10); code(err) != "validation_failed" {
		t.Fatal("bad cursor")
	}
	// Block (either direction) hides the creator everywhere.
	identitytest.Block(t, e.adm, creators[0], viewerID)
	page, _ := e.svc.Feed(e.ctx, viewer, "for_you", "", 20)
	for _, it := range page.Items {
		if it.Creator.UserId == creators[0] {
			t.Fatal("blocked creator in feed")
		}
	}
	if _, err := e.svc.GetCreator(e.ctx, viewer, creators[0]); code(err) != "not_found" {
		t.Fatal("blocked creator profile visible")
	}
	// Following feed.
	if _, err := e.svc.SetFollow(e.ctx, viewer, creators[1], true); err != nil {
		t.Fatal(err)
	}
	if _, err := e.svc.SetFollow(e.ctx, viewer, creators[1], true); err != nil {
		t.Fatal("follow must be idempotent")
	}
	if _, err := e.svc.SetFollow(e.ctx, viewer, viewerID, true); code(err) != "self_follow" {
		t.Fatal("self follow")
	}
	fol, _ := e.svc.Feed(e.ctx, viewer, "following", "", 3)
	if len(fol.Items) != 3 || fol.NextCursor == nil {
		t.Fatalf("following page 1: %d", len(fol.Items))
	}
	fol2, _ := e.svc.Feed(e.ctx, viewer, "following", *fol.NextCursor, 3)
	if len(fol2.Items) != 2 || fol2.NextCursor != nil {
		t.Fatalf("following page 2: %d", len(fol2.Items))
	}
	for _, it := range append(fol.Items, fol2.Items...) {
		if it.Creator.UserId != creators[1] || !it.Creator.FollowedByMe {
			t.Fatal("following feed has an unfollowed creator")
		}
	}
	prof, _ := e.svc.GetCreator(e.ctx, viewer, creators[1])
	if prof.FollowerCount != 1 || prof.ReelCount != 5 || !prof.FollowedByMe {
		t.Fatalf("profile counts %+v", prof)
	}
	// A reel the viewer reported disappears from their feed.
	target := fol.Items[0].Id
	if err := e.svc.Report(e.ctx, viewer, target, reels.ReportRequest{Category: ptr("spam_or_scam")}); err != nil {
		t.Fatal(err)
	}
	if err := e.svc.Report(e.ctx, viewer, target, reels.ReportRequest{Category: ptr("spam_or_scam")}); err != nil {
		t.Fatal("repeat report must be idempotent")
	}
	page, _ = e.svc.Feed(e.ctx, viewer, "for_you", "", 20)
	for _, it := range page.Items {
		if it.Id == target {
			t.Fatal("reported reel still in reporter's feed")
		}
	}
}

func TestReportsHideLikesViewsAndShare(t *testing.T) {
	e := setup(t, nil)
	cid, creator := e.user("Asha", "host")
	_, a := e.user("A")
	_, b := e.user("B")
	id := e.published(cid, time.Hour)

	l1, _ := e.svc.SetLike(e.ctx, a, id, true)
	l2, _ := e.svc.SetLike(e.ctx, a, id, true)
	l3, _ := e.svc.SetLike(e.ctx, b, id, true)
	if l1.LikeCount != 1 || l2.LikeCount != 1 || l3.LikeCount != 2 {
		t.Fatalf("likes %d %d %d", l1.LikeCount, l2.LikeCount, l3.LikeCount)
	}
	if u, _ := e.svc.SetLike(e.ctx, a, id, false); u.LikeCount != 1 {
		t.Fatalf("unlike %d", u.LikeCount)
	}
	ev := func(p auth.Principal, name string, ms int) {
		if err := e.svc.RecordEvents(e.ctx, p, reels.EventsRequest{Events: []reels.EventIn{{Event: name, ReelId: &id, ValueMs: &ms}}}); err != nil {
			t.Fatal(err)
		}
	}
	ev(a, "reel_play_started", 0)
	ev(a, "reel_play_started", 0)
	ev(a, "reel_play_completed", 20000)
	ev(a, "reel_play_completed", 20000)
	ev(creator, "reel_play_started", 0) // own views do not count
	r, _ := e.svc.GetReel(e.ctx, b, id)
	var completed int
	_ = e.adm.QueryRow(e.ctx, `select completed_count from reels.videos where id = $1`, id).Scan(&completed)
	if r.ViewCount != 1 || completed != 1 {
		t.Fatalf("views %d completed %d", r.ViewCount, completed)
	}
	var stored int
	_ = e.adm.QueryRow(e.ctx, `select count(*) from reels.feed_events where video_id = $1`, id).Scan(&stored)
	if stored != 0 {
		t.Fatal("events stored without analytics consent")
	}
	if s, err := e.svc.Share(e.ctx, b, id); err != nil || s.Url == "" {
		t.Fatalf("share %v", err)
	}
	if err := e.svc.Report(e.ctx, creator, id, reels.ReportRequest{Category: ptr("other")}); code(err) != "self_report" {
		t.Fatal("self report")
	}
	// minor_safety hides immediately (fail safe) and opens a priority-1 case.
	if err := e.svc.Report(e.ctx, b, id, reels.ReportRequest{Category: ptr("minor_safety")}); err != nil {
		t.Fatal(err)
	}
	var prio int
	_ = e.adm.QueryRow(e.ctx, `select priority from reels.moderation_cases where video_id = $1 and status = 'open'`, id).Scan(&prio)
	if e.status(id) != "in_review" || prio != 1 {
		t.Fatalf("minor safety report: %s prio %d", e.status(id), prio)
	}
	if _, err := e.svc.GetReel(e.ctx, a, id); code(err) != "not_found" {
		t.Fatal("hidden reel still visible")
	}
}

func TestDeletionPurgeAndAccountCleanup(t *testing.T) {
	e := setup(t, nil)
	cid, creator := e.user("Asha", "host")
	fid, fan := e.user("Fan")
	id := e.published(cid, time.Hour)
	other := e.published(cid, 2*time.Hour)
	_, _ = e.svc.SetLike(e.ctx, fan, other, true)
	_, _ = e.svc.SetFollow(e.ctx, fan, cid, true)

	if err := e.svc.DeleteReel(e.ctx, fan, id); code(err) != "not_found" {
		t.Fatal("only the creator can delete")
	}
	if err := e.svc.DeleteReel(e.ctx, creator, id); err != nil {
		t.Fatal(err)
	}
	if _, err := e.svc.GetReel(e.ctx, creator, id); code(err) != "not_found" {
		t.Fatal("deleted reel still readable")
	}
	if n, err := e.svc.PurgeMedia(e.ctx, 50); err != nil || n < 1 {
		t.Fatalf("purge: %d %v", n, err)
	}
	var purged bool
	_ = e.adm.QueryRow(e.ctx, `select media_purged_at is not null from reels.videos where id = $1`, id).Scan(&purged)
	if !purged || len(e.prov.deleted) == 0 {
		t.Fatal("provider asset not deleted")
	}
	// Account deletion (as done by execute-account-deletions) → cleanup job.
	if _, err := e.adm.Exec(e.ctx, `update identity.accounts set status = 'deleted', deleted_at = now() where id = $1`, fid); err != nil {
		t.Fatal(err)
	}
	if _, err := e.adm.Exec(e.ctx, `update identity.accounts set status = 'deleted', deleted_at = now() where id = $1`, cid); err != nil {
		t.Fatal(err)
	}
	if n, err := e.svc.CleanupDeletedAccounts(e.ctx, 50); err != nil || n < 2 {
		t.Fatalf("cleanup: %d %v", n, err)
	}
	var likes, follows int
	var st string
	_ = e.adm.QueryRow(e.ctx, `select (select count(*) from reels.likes where user_id = $1), (select count(*) from reels.follows where follower_id = $1)`, fid).Scan(&likes, &follows)
	_ = e.adm.QueryRow(e.ctx, `select status from reels.videos where id = $1`, other).Scan(&st)
	if likes != 0 || follows != 0 || st != "deleted" {
		t.Fatalf("after cleanup likes=%d follows=%d status=%s", likes, follows, st)
	}
	if n, _ := e.svc.CleanupDeletedAccounts(e.ctx, 50); n != 0 {
		t.Fatal("cleanup must be idempotent")
	}
}

func TestUploadLimitConcurrent(t *testing.T) {
	e := setup(t, nil)
	_, creator := e.user("Asha", "host")
	var wg sync.WaitGroup
	var mu sync.Mutex
	ok, limited := 0, 0
	for range 14 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			d := 20000
			_, err := e.svc.CreateUpload(e.ctx, creator, reels.CreateUploadRequest{DeclaredDurationMs: &d})
			mu.Lock()
			defer mu.Unlock()
			switch code(err) {
			case "":
				ok++
			case "reel_upload_limit":
				limited++
			default:
				t.Errorf("upload: %v", err)
			}
		}()
	}
	wg.Wait()
	if ok != reels.DailyUploadLimit || limited != 4 {
		t.Fatalf("ok=%d limited=%d", ok, limited)
	}
}

func TestAttributionCountsOnlyNewCTACalls(t *testing.T) {
	e := setup(t, nil)
	hid, _ := e.user("Host")
	identitytest.Host(t, e.adm, hid, 1500, true)
	vid, viewer := e.user("Viewer")
	regularID, regular := e.user("Regular")
	_, admin := e.user("Admin", "admin")
	for _, u := range []string{vid, regularID} {
		if _, err := e.adm.Exec(e.ctx, `insert into identity.consents (user_id, analytics) values ($1, true)`, u); err != nil {
			t.Fatal(err)
		}
	}
	reel := e.published(hid, time.Hour)
	r, _ := e.svc.GetReel(e.ctx, viewer, reel)
	if r.Creator.Host == nil || r.Creator.Host.Availability != "online" || r.Creator.Host.RatePerMinute != 1500 {
		t.Fatalf("host info on reel: %+v", r.Creator.Host)
	}
	// The regular already had a paid call with this host 3 days ago.
	identitytest.Call(t, e.adm, regularID, hid, "ended", 120, 72*time.Hour)
	for _, p := range []auth.Principal{viewer, regular} {
		if err := e.svc.RecordEvents(e.ctx, p, reels.EventsRequest{Events: []reels.EventIn{{Event: "host_call_cta_clicked", ReelId: &reel}}}); err != nil {
			t.Fatal(err)
		}
	}
	// Both call within the window.
	for _, caller := range []string{vid, regularID} {
		if _, err := e.adm.Exec(e.ctx, `insert into calls.calls (caller_id, receiver_id, phase, rate_per_minute, rule_set_version, billed_seconds, diamonds_charged, created_at, ended_at)
		   values ($1, $2, 'ended', 1500, (select version from economy.rule_sets order by effective_from limit 1), 90, 2250, clock_timestamp(), clock_timestamp())`, caller, hid); err != nil {
			t.Fatal(err)
		}
	}
	a, err := e.svc.GetAnalytics(e.ctx, admin, 1)
	if err != nil {
		t.Fatal(err)
	}
	if a.CTAClicks != 2 || a.AttributedCalls != 1 || a.AttributedCompleted != 1 || a.AttributedDiamonds != 2250 {
		t.Fatalf("attribution %+v", a)
	}
	if _, err := e.svc.GetAnalytics(e.ctx, viewer, 1); code(err) != "role_required" {
		t.Fatal("analytics is staff-only")
	}
}

func TestClientRolesCannotReadReels(t *testing.T) {
	e := setup(t, nil)
	for _, role := range []string{"authenticated", "anon"} {
		err := pgx.BeginFunc(e.ctx, e.adm, func(tx pgx.Tx) error {
			if _, err := tx.Exec(e.ctx, "set local role "+role); err != nil {
				return err
			}
			_, err := tx.Exec(e.ctx, `select count(*) from reels.videos`)
			return err
		})
		if err == nil {
			t.Fatalf("%s can read reels.videos", role)
		}
	}
}
