//go:build integration

package reels_test

import (
	"context"
	"sync"
	"testing"
	"time"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/reels"
	"dashuri/backend/internal/platform/db"
)

// selfProvider behaves like the R2 provider at the service boundary: it
// stores files only (no webhooks) and implements SelfProcessing. The real
// R2 + ffmpeg pipeline is tested in adapters/r2 against a signing S3 fake.
type selfProvider struct {
	mu       sync.Mutex
	uploaded map[string]bool
	result   map[string]error // per asset: nil = success
	calls    int
	deleted  []string
}

func newSelfProvider() *selfProvider {
	return &selfProvider{uploaded: map[string]bool{}, result: map[string]error{}}
}

func (p *selfProvider) Name() string     { return "r2" }
func (p *selfProvider) Configured() bool { return true }
func (p *selfProvider) CreateUpload(_ context.Context, req reels.UploadRequest) (reels.UploadSession, error) {
	if req.SizeBytes <= 0 {
		return reels.UploadSession{}, &reels.MediaError{Code: "size_bytes"}
	}
	return reels.UploadSession{UploadID: req.Passthrough, URL: "https://r2.example/" + req.Passthrough,
		Headers: map[string]string{"Content-Type": req.ContentType}, ExpiresAt: time.Now().Add(time.Hour)}, nil
}
func (p *selfProvider) UploadStatus(_ context.Context, id string) (reels.UploadState, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.uploaded[id] {
		return reels.UploadState{State: "asset_created", AssetID: id}, nil
	}
	return reels.UploadState{State: "waiting"}, nil
}
func (p *selfProvider) Asset(context.Context, string) (reels.AssetInfo, error) {
	return reels.AssetInfo{}, reels.ErrAssetNotFound
}
func (p *selfProvider) Process(_ context.Context, id string, lim reels.MediaLimits) (reels.AssetInfo, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.calls++
	if err := p.result[id]; err != nil {
		return reels.AssetInfo{}, err
	}
	return reels.AssetInfo{ID: id, DurationMs: 20000, PlaybackID: id, AspectRatio: "9:16", Width: 720, Height: 1280,
		SizeBytes: 4_200_000, VideoKey: "reels/" + id + "/playback.mp4", ThumbnailKey: "reels/" + id + "/thumbnail.jpg"}, nil
}
func (p *selfProvider) Playback(id string, ttl time.Duration) (reels.Playback, error) {
	return reels.Playback{URL: "https://r2.example/" + id + "/playback.mp4?sig", Format: reels.FormatMP4,
		ThumbnailURL: "https://r2.example/" + id + "/thumbnail.jpg?sig", ExpiresAt: time.Now().Add(ttl)}, nil
}
func (p *selfProvider) FrameURLs(id string, _ int, _, _ time.Duration) ([]string, error) {
	return []string{"https://r2.example/" + id + "/frames/0000000.jpg?sig"}, nil
}
func (p *selfProvider) DeleteAsset(_ context.Context, id string) error {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.deleted = append(p.deleted, id)
	return nil
}
func (p *selfProvider) ParseWebhook(map[string]string, []byte, time.Time) (reels.WebhookEvent, error) {
	return reels.WebhookEvent{}, reels.ErrWebhookSignature
}

// setupR2 wires R2-like uploads with the Mux-like fake as the legacy provider.
func setupR2(t *testing.T, cls reels.FrameClassifier) (*env, *selfProvider) {
	e := setup(t, cls)
	self := newSelfProvider()
	e.svc = reels.NewService(reels.Deps{Enabled: true, Repo: postgres.ReelsRepo{Pool: e.api, Tx: db.TxManager{Pool: e.api}},
		Provider: self, Legacy: []reels.VideoProvider{e.prov}, Classifier: cls})
	return e, self
}

func TestR2UploadProcessModerateFlow(t *testing.T) {
	e, self := setupR2(t, fakeClassifier{})
	_, host := e.user("Asha", "host")
	_, other := e.user("Ravi", "host")

	if cfg := e.svc.Config(); cfg.VideoProvider != "r2" || !cfg.UploadsAvailable || len(cfg.UploadContentTypes) == 0 {
		t.Fatalf("config: %+v", cfg)
	}

	d := 20000
	// R2 needs the declared size (signed into the URL).
	if _, err := e.svc.CreateUpload(e.ctx, host, reels.CreateUploadRequest{DeclaredDurationMs: &d}); code(err) != "validation_failed" {
		t.Fatalf("no size: %v", err)
	}
	if _, err := e.svc.CreateUpload(e.ctx, host, reels.CreateUploadRequest{DeclaredDurationMs: &d, SizeBytes: ptr(int64(reels.MaxUploadBytes + 1))}); code(err) != "validation_failed" {
		t.Fatalf("oversized declared: %v", err)
	}
	if _, err := e.svc.CreateUpload(e.ctx, host, reels.CreateUploadRequest{DeclaredDurationMs: &d, SizeBytes: ptr(int64(10)), ContentType: ptr("text/html")}); code(err) != "validation_failed" {
		t.Fatalf("bad type: %v", err)
	}
	tk, err := e.svc.CreateUpload(e.ctx, host, reels.CreateUploadRequest{DeclaredDurationMs: &d, SizeBytes: ptr(int64(9_000_000)), ContentType: ptr("video/mp4")})
	if err != nil {
		t.Fatal(err)
	}
	id := tk.Reel.Id
	if tk.UploadHeaders["Content-Type"] != "video/mp4" || tk.Reel.Status != "awaiting_upload" || tk.Reel.Playback != nil {
		t.Fatalf("ticket: %+v", tk)
	}

	// upload-complete: only the creator; the server checks the storage itself.
	if _, err := e.svc.CompleteUpload(e.ctx, other, id); code(err) != "not_found" {
		t.Fatalf("other creator: %v", err)
	}
	if _, err := e.svc.CompleteUpload(e.ctx, host, id); code(err) != "upload_not_received" {
		t.Fatalf("before PUT: %v", err)
	}
	self.mu.Lock()
	self.uploaded[id] = true
	self.mu.Unlock()
	r, err := e.svc.CompleteUpload(e.ctx, host, id)
	if err != nil || r.Status != "processing" {
		t.Fatalf("complete: %+v %v", r, err)
	}
	if r2, err := e.svc.CompleteUpload(e.ctx, host, id); err != nil || r2.Status != "processing" {
		t.Fatalf("complete again (idempotent): %+v %v", r2, err)
	}

	// Reconcile leaves self-processed reels to the processing job.
	if _, err := e.svc.ReconcileUploads(e.ctx, 10); err != nil || e.status(id) != "processing" {
		t.Fatalf("reconcile touched it: %s %v", e.status(id), err)
	}

	// Processing records the media facts and hands over to moderation.
	if n, err := e.svc.ProcessMedia(e.ctx, 10); err != nil || n != 1 {
		t.Fatalf("process: %d %v", n, err)
	}
	if e.status(id) != "pending_moderation" {
		t.Fatalf("status = %s", e.status(id))
	}
	var w, h int
	var size int64
	var vkey, tkey, prov string
	if err := e.adm.QueryRow(e.ctx, `select width, height, size_bytes, video_storage_key, thumbnail_storage_key, provider
	   from reels.videos where id = $1`, id).Scan(&w, &h, &size, &vkey, &tkey, &prov); err != nil {
		t.Fatal(err)
	}
	if w != 720 || h != 1280 || size != 4_200_000 || vkey != "reels/"+id+"/playback.mp4" || tkey != "reels/"+id+"/thumbnail.jpg" || prov != "r2" {
		t.Fatalf("row: %d %d %d %s %s %s", w, h, size, vkey, tkey, prov)
	}

	// Not visible to others before moderation; the creator sees MP4 playback.
	if _, err := e.svc.GetReel(e.ctx, other, id); code(err) != "not_found" {
		t.Fatalf("visible before moderation: %v", err)
	}
	own, err := e.svc.GetReel(e.ctx, host, id)
	if err != nil || own.Playback == nil || own.Playback.Format != "mp4" || own.Playback.Url == "" || own.Playback.HlsUrl != "" {
		t.Fatalf("own playback: %+v %v", own.Playback, err)
	}

	// Moderation is unchanged: a creator's first reel goes to human review.
	if _, err := e.svc.ModeratePending(e.ctx, 10); err != nil || e.status(id) != "in_review" {
		t.Fatalf("moderation: %s %v", e.status(id), err)
	}
}

func TestR2ProcessingFailuresAndWaiting(t *testing.T) {
	e, self := setupR2(t, fakeClassifier{})
	_, host := e.user("Asha", "host")
	d := 20000
	mk := func() string {
		tk, err := e.svc.CreateUpload(e.ctx, host, reels.CreateUploadRequest{DeclaredDurationMs: &d, SizeBytes: ptr(int64(1000)), ContentType: ptr("video/mp4")})
		if err != nil {
			t.Fatal(err)
		}
		self.mu.Lock()
		self.uploaded[tk.Reel.Id] = true
		self.mu.Unlock()
		if _, err := e.svc.CompleteUpload(e.ctx, host, tk.Reel.Id); err != nil {
			t.Fatal(err)
		}
		return tk.Reel.Id
	}

	// No ffmpeg here (API image): reels wait, nothing fails.
	waiting := mk()
	self.result[waiting] = reels.ErrProcessorUnavailable
	if _, err := e.svc.ProcessMedia(e.ctx, 10); err != nil || e.status(waiting) != "processing" {
		t.Fatalf("processor unavailable: %s %v", e.status(waiting), err)
	}
	delete(self.result, waiting)
	if _, err := e.svc.ProcessMedia(e.ctx, 10); err != nil || e.status(waiting) != "pending_moderation" {
		t.Fatalf("after worker: %s %v", e.status(waiting), err)
	}
	if _, err := e.svc.ModeratePending(e.ctx, 10); err != nil { // leave no pending reel for other tests
		t.Fatal(err)
	}

	// Invalid media fails with its reason; the creator sees why.
	bad := mk()
	self.result[bad] = &reels.MediaError{Code: "no_video_stream"}
	if _, err := e.svc.ProcessMedia(e.ctx, 10); err != nil {
		t.Fatal(err)
	}
	r, _ := e.svc.GetReel(e.ctx, host, bad)
	if r.Status != "failed" || r.RejectionCode == nil || *r.RejectionCode != "no_video_stream" {
		t.Fatalf("bad media: %+v", r)
	}

	// Transient errors retry (status unchanged) until ProcessingGiveUp.
	flaky := mk()
	self.result[flaky] = context.DeadlineExceeded
	if _, err := e.svc.ProcessMedia(e.ctx, 10); err != nil || e.status(flaky) != "processing" {
		t.Fatalf("transient: %s %v", e.status(flaky), err)
	}
	// Backdate past ProcessingGiveUp (bypassing the touch_updated_at trigger).
	tx, err := e.adm.Begin(e.ctx)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := tx.Exec(e.ctx, `set local session_replication_role = replica`); err != nil {
		t.Fatal(err)
	}
	if _, err := tx.Exec(e.ctx, `update reels.videos set updated_at = now() - interval '3 hours' where id = $1`, flaky); err != nil {
		t.Fatal(err)
	}
	if err := tx.Commit(e.ctx); err != nil {
		t.Fatal(err)
	}
	if _, err := e.svc.ProcessMedia(e.ctx, 10); err != nil || e.status(flaky) != "failed" {
		t.Fatalf("give up: %s %v", e.status(flaky), err)
	}

	// Failed reels' media is purged from R2 (nothing orphaned).
	if _, err := e.svc.PurgeMedia(e.ctx, 50); err != nil {
		t.Fatal(err)
	}
	self.mu.Lock()
	defer self.mu.Unlock()
	if len(self.deleted) < 2 {
		t.Fatalf("purged: %v", self.deleted)
	}
}

func TestLegacyMuxReelsStillServedDuringTransition(t *testing.T) {
	e, _ := setupR2(t, fakeClassifier{})
	creator, _ := e.user("Asha", "host")
	_, viewer := e.user("Ravi")
	id := e.published(creator, time.Hour) // provider 'fake' = the legacy (Mux-like) provider
	t.Cleanup(func() {                    // keep the shared test database's feeds empty for other tests
		_, _ = e.adm.Exec(context.Background(), `update reels.videos set status = 'deleted', deleted_at = now() where id = $1`, id)
	})
	r, err := e.svc.GetReel(e.ctx, viewer, id)
	if err != nil || r.Playback == nil || r.Playback.Format != "hls" || r.Playback.HlsUrl == "" || r.Playback.HlsUrl != r.Playback.Url {
		t.Fatalf("legacy playback: %+v %v", r.Playback, err)
	}
}
