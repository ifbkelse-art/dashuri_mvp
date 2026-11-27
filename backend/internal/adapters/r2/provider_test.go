package r2

import (
	"bytes"
	"context"
	"errors"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"

	"dashuri/backend/internal/adapters/ffmpeg"
	"dashuri/backend/internal/modules/reels"
)

const testID = "0b5e8a1e-1111-4a2b-8c3d-123456789abc"

var testSigner = Signer{AccessKeyID: "test-key", SecretAccessKey: "test-secret", Region: "auto", Service: "s3"}

var limits = reels.MediaLimits{MaxBytes: 50 << 20, MinDurationMs: 14100, MaxDurationMs: 60900, FrameInterval: 2 * time.Second}

func newTestProvider(t *testing.T, keepOriginals bool) (*Provider, *fakeS3) {
	t.Helper()
	f := newFakeS3(t, testSigner, "media")
	p := New(Config{AccessKeyID: testSigner.AccessKeyID, SecretAccessKey: testSigner.SecretAccessKey,
		Bucket: "media", Endpoint: f.srv.URL, KeepOriginals: keepOriginals}, ffmpeg.New(), f.srv.Client())
	return p, f
}

func needFFmpeg(t *testing.T) {
	t.Helper()
	if !ffmpeg.New().Available() {
		t.Skip("ffmpeg/ffprobe not installed")
	}
}

// makeVideo renders a test clip: portrait 1080x1920 H.264 + AAC with a GPS
// location tag (must not survive processing).
func makeVideo(t *testing.T, seconds int, size string) []byte {
	t.Helper()
	out := filepath.Join(t.TempDir(), "in.mp4")
	cmd := exec.Command("ffmpeg", "-v", "error", "-y",
		"-f", "lavfi", "-i", "testsrc=size="+size+":rate=24",
		"-f", "lavfi", "-i", "sine=frequency=440",
		"-t", strconv.Itoa(seconds), "-c:v", "libx264", "-preset", "ultrafast", "-pix_fmt", "yuv420p", "-c:a", "aac",
		"-metadata", "location=+12.9716+077.5946/", "-movflags", "+use_metadata_tags", out)
	if b, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("ffmpeg: %v %s", err, b)
	}
	b, err := os.ReadFile(out)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

// clientPut does what the app does: PUT with the ticket's headers.
func clientPut(t *testing.T, s reels.UploadSession, body []byte, override map[string]string) int {
	t.Helper()
	req, _ := http.NewRequest(http.MethodPut, s.URL, bytes.NewReader(body))
	req.ContentLength = int64(len(body))
	for k, v := range s.Headers {
		if k != "Content-Length" {
			req.Header.Set(k, v)
		}
	}
	for k, v := range override {
		req.Header.Set(k, v)
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	res.Body.Close()
	return res.StatusCode
}

func upload(t *testing.T, p *Provider, body []byte) reels.UploadSession {
	t.Helper()
	s, err := p.CreateUpload(t.Context(), reels.UploadRequest{Passthrough: testID, SizeBytes: int64(len(body)), ContentType: "video/mp4"})
	if err != nil {
		t.Fatal(err)
	}
	if code := clientPut(t, s, body, nil); code != http.StatusOK {
		t.Fatalf("upload PUT: HTTP %d", code)
	}
	return s
}

func TestNotConfiguredWithoutCredentials(t *testing.T) {
	p := New(Config{Bucket: "media"}, nil, nil)
	if p.Configured() {
		t.Fatal("configured without keys")
	}
	if _, err := p.CreateUpload(context.Background(), reels.UploadRequest{Passthrough: testID, SizeBytes: 1, ContentType: "video/mp4"}); !errors.Is(err, reels.ErrProviderNotConfigured) {
		t.Fatalf("err = %v", err)
	}
	if _, err := p.Playback(testID, time.Hour); !errors.Is(err, reels.ErrProviderNotConfigured) {
		t.Fatalf("err = %v", err)
	}
	if New(Config{AccountID: "acct", AccessKeyID: "k", SecretAccessKey: "s", Bucket: "b"}, nil, nil).store.Endpoint != "https://acct.r2.cloudflarestorage.com" {
		t.Fatal("R2 endpoint not derived from account id")
	}
}

func TestCreateUploadRequiresDeclaredFile(t *testing.T) {
	p, _ := newTestProvider(t, false)
	var me *reels.MediaError
	if _, err := p.CreateUpload(t.Context(), reels.UploadRequest{Passthrough: testID, ContentType: "video/mp4"}); !errors.As(err, &me) || me.Code != "size_bytes" {
		t.Fatalf("missing size: %v", err)
	}
	if _, err := p.CreateUpload(t.Context(), reels.UploadRequest{Passthrough: testID, SizeBytes: 10}); !errors.As(err, &me) || me.Code != "content_type" {
		t.Fatalf("missing type: %v", err)
	}
}

func TestPresignedUploadEnforcesDeclaredSizeAndType(t *testing.T) {
	p, f := newTestProvider(t, false)
	s, err := p.CreateUpload(t.Context(), reels.UploadRequest{Passthrough: testID, SizeBytes: 5, ContentType: "video/mp4"})
	if err != nil {
		t.Fatal(err)
	}
	if s.UploadID != testID || s.Headers["Content-Type"] != "video/mp4" || s.Headers["Content-Length"] != "5" {
		t.Fatalf("session: %+v", s)
	}
	if strings.Contains(s.URL, testSigner.SecretAccessKey) {
		t.Fatal("secret leaked into URL")
	}
	if code := clientPut(t, s, []byte("0123456789"), nil); code != http.StatusForbidden {
		t.Fatalf("larger body accepted: HTTP %d", code)
	}
	if code := clientPut(t, s, []byte("01234"), map[string]string{"Content-Type": "text/html"}); code != http.StatusForbidden {
		t.Fatalf("other type accepted: HTTP %d", code)
	}
	if len(f.keys()) != 0 {
		t.Fatalf("rejected uploads stored: %v", f.keys())
	}
	if st, _ := p.UploadStatus(t.Context(), testID); st.State != "waiting" {
		t.Fatalf("status before upload: %+v", st)
	}
	if code := clientPut(t, s, []byte("01234"), nil); code != http.StatusOK {
		t.Fatalf("declared file rejected: HTTP %d", code)
	}
	if st, _ := p.UploadStatus(t.Context(), testID); st.State != "asset_created" || st.AssetID != testID {
		t.Fatalf("status after upload: %+v", st)
	}
	if _, ok := f.get("reels/" + testID + "/original"); !ok {
		t.Fatalf("keys: %v", f.keys())
	}
}

func TestUnsignedRequestsAreRefused(t *testing.T) {
	_, f := newTestProvider(t, false)
	res, err := http.Get(f.srv.URL + "/media/reels/" + testID + "/playback.mp4")
	if err != nil {
		t.Fatal(err)
	}
	res.Body.Close()
	if res.StatusCode != http.StatusForbidden {
		t.Fatalf("anonymous read: HTTP %d", res.StatusCode)
	}
}

func TestProcessProducesPlaybackPosterFramesAndManifest(t *testing.T) {
	needFFmpeg(t)
	p, f := newTestProvider(t, false)
	upload(t, p, makeVideo(t, 16, "1080x1920"))

	a, err := p.Process(t.Context(), testID, limits)
	if err != nil {
		t.Fatal(err)
	}
	if a.State != "ready" || a.PlaybackID != testID || a.Width != 720 || a.Height != 1280 || a.AspectRatio != "9:16" {
		t.Fatalf("asset: %+v", a)
	}
	if a.DurationMs < 15500 || a.DurationMs > 16500 || a.SizeBytes <= 0 {
		t.Fatalf("duration/size: %+v", a)
	}
	if a.VideoKey != "reels/"+testID+"/playback.mp4" || a.ThumbnailKey != "reels/"+testID+"/thumbnail.jpg" {
		t.Fatalf("keys: %+v", a)
	}
	if _, ok := f.get("reels/" + testID + "/original"); ok {
		t.Fatal("original kept although KeepOriginals=false")
	}
	if o, _ := f.get(a.ThumbnailKey); o.contentType != "image/jpeg" || len(o.body) == 0 {
		t.Fatalf("thumbnail: %q %d", o.contentType, len(o.body))
	}

	// Metadata (GPS) stripped from the playback file.
	pb, _ := f.get(a.VideoKey)
	if bytes.Contains(pb.body, []byte("+12.9716")) {
		t.Fatal("location metadata survived processing")
	}
	// faststart: moov before mdat.
	if m, d := bytes.Index(pb.body, []byte("moov")), bytes.Index(pb.body, []byte("mdat")); m < 0 || m > d {
		t.Fatalf("not faststart: moov=%d mdat=%d", m, d)
	}

	// The frame URLs the moderation job will use point at stills that exist.
	urls, err := p.FrameURLs(testID, a.DurationMs, limits.FrameInterval, time.Minute)
	if err != nil || len(urls) != 8 {
		t.Fatalf("frames: %d %v", len(urls), err)
	}
	for _, u := range urls {
		res, err := http.Get(u)
		if err != nil {
			t.Fatal(err)
		}
		res.Body.Close()
		if res.StatusCode != http.StatusOK {
			t.Fatalf("frame %s: HTTP %d", u, res.StatusCode)
		}
	}

	// Playback URLs are presigned and work; tampering breaks them.
	play, err := p.Playback(testID, time.Hour)
	if err != nil || play.Format != reels.FormatMP4 {
		t.Fatalf("playback: %+v %v", play, err)
	}
	for _, u := range []string{play.URL, play.ThumbnailURL} {
		res, _ := http.Get(u)
		res.Body.Close()
		if res.StatusCode != http.StatusOK {
			t.Fatalf("%s: HTTP %d", u, res.StatusCode)
		}
	}
	res, _ := http.Get(strings.Replace(play.URL, "playback.mp4", "manifest.json", 1))
	res.Body.Close()
	if res.StatusCode != http.StatusForbidden {
		t.Fatalf("re-pointed signed URL worked: HTTP %d", res.StatusCode)
	}

	// Idempotent: a second run returns the same result without the original.
	again, err := p.Process(t.Context(), testID, limits)
	if err != nil || again != a {
		t.Fatalf("second run: %+v %v", again, err)
	}
	if st, _ := p.UploadStatus(t.Context(), testID); st.State != "asset_created" {
		t.Fatalf("status after processing: %+v", st)
	}
	if got, err := p.Asset(t.Context(), testID); err != nil || got != a {
		t.Fatalf("asset: %+v %v", got, err)
	}

	// Delete removes every object of the reel.
	if err := p.DeleteAsset(t.Context(), testID); err != nil {
		t.Fatal(err)
	}
	if k := f.keys(); len(k) != 0 {
		t.Fatalf("left after delete: %v", k)
	}
	if _, err := p.Asset(t.Context(), testID); !errors.Is(err, reels.ErrAssetNotFound) {
		t.Fatalf("asset after delete: %v", err)
	}
}

func TestProcessKeepsOriginalWhenConfigured(t *testing.T) {
	needFFmpeg(t)
	p, f := newTestProvider(t, true)
	upload(t, p, makeVideo(t, 15, "640x360"))
	a, err := p.Process(t.Context(), testID, limits)
	if err != nil {
		t.Fatal(err)
	}
	if a.Width != 640 || a.Height != 360 { // never upscaled
		t.Fatalf("asset: %+v", a)
	}
	if _, ok := f.get("reels/" + testID + "/original"); !ok {
		t.Fatal("original deleted although KeepOriginals=true")
	}
}

func TestProcessRejectsBadMedia(t *testing.T) {
	needFFmpeg(t)
	cases := []struct {
		name string
		body func(t *testing.T) []byte
		lim  reels.MediaLimits
		code string
		gone bool // original deleted
	}{
		{"not a video", func(*testing.T) []byte { return []byte("hello, definitely not an mp4 file") }, limits, "invalid_media", false},
		{"hls playlist", func(*testing.T) []byte { return []byte("#EXTM3U\n#EXTINF:1,\nfile:///etc/hosts\n") }, limits, "invalid_media", false},
		{"too short", func(t *testing.T) []byte { return makeVideo(t, 5, "320x568") }, limits, "duration_out_of_range", false},
		{"too large", func(t *testing.T) []byte { return makeVideo(t, 15, "320x568") },
			reels.MediaLimits{MaxBytes: 1000, MinDurationMs: 1, MaxDurationMs: 60900, FrameInterval: 2 * time.Second}, "file_too_large", true},
		// Regression (2026-11-27): there was a maximum resolution but no minimum.
		{"tiny resolution", func(t *testing.T) []byte { return makeVideo(t, 15, "128x228") },
			reels.MediaLimits{MaxBytes: 50 << 20, MinDurationMs: 14100, MaxDurationMs: 60900, FrameInterval: 2 * time.Second,
				MinShortSide: reels.MinShortSidePx}, "resolution_too_low", false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			p, f := newTestProvider(t, false)
			upload(t, p, c.body(t))
			_, err := p.Process(t.Context(), testID, c.lim)
			var me *reels.MediaError
			if !errors.As(err, &me) || me.Code != c.code {
				t.Fatalf("err = %v, want %s", err, c.code)
			}
			if _, ok := f.get("reels/" + testID + "/manifest.json"); ok {
				t.Fatal("manifest written for rejected media")
			}
			if _, ok := f.get("reels/" + testID + "/original"); ok == c.gone {
				t.Fatalf("original present=%v", ok)
			}
		})
	}
}

func TestProcessMissingUpload(t *testing.T) {
	needFFmpeg(t)
	p, _ := newTestProvider(t, false)
	var me *reels.MediaError
	if _, err := p.Process(t.Context(), testID, limits); !errors.As(err, &me) || me.Code != "upload_missing" {
		t.Fatalf("err = %v", err)
	}
}

func TestFrameTimes(t *testing.T) {
	if got := FrameTimes(16000, 2*time.Second); len(got) != 8 || got[7] != 14000 {
		t.Fatalf("16 s: %v", got)
	}
	if got := FrameTimes(60900, 2*time.Second); len(got) != MaxFrames {
		t.Fatalf("60.9 s: %d frames", len(got))
	}
	if got := FrameTimes(100, 0); len(got) != 1 || got[0] != 0 {
		t.Fatalf("tiny: %v", got)
	}
}
