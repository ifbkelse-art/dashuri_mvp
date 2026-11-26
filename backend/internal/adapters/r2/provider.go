// Package r2 implements reels.VideoProvider with Cloudflare R2 object
// storage plus our own ffmpeg processing (reels.SelfProcessing). It is the
// replacement for Mux (docs/reels/DASHURI_REELS_R2_MIGRATION.md).
//
// Flow:
//  1. CreateUpload presigns a PUT of reels/<id>/original with the declared
//     size and type signed in (R2 rejects any other file). 1 h validity.
//  2. The app PUTs, then calls POST /v1/reels/{id}/upload-complete;
//     UploadStatus HEADs the object (the server never trusts the call).
//  3. Job reels-process-media (media worker image, has ffmpeg) calls
//     Process: size check, probe, container/stream/duration validation,
//     720p H.264 faststart MP4, poster JPEG, one moderation still every
//     FrameInterval, all metadata stripped; manifest.json is written last
//     (the commit point) and the original is deleted (KeepOriginals=false).
//  4. Moderation reads FrameURLs (presigned stills) exactly as with Mux.
//  5. Playback presigns GETs of playback.mp4 and thumbnail.jpg.
//  6. DeleteAsset removes every object under reels/<id>/.
//
// Bucket stays private; nothing is public. Credentials never leave the
// server: the app only sees presigned URLs.
package r2

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"dashuri/backend/internal/adapters/ffmpeg"
	"dashuri/backend/internal/modules/reels"
)

const (
	ProviderName  = "r2"
	UploadTTL     = time.Hour
	MaxFrames     = 31 // 60 s at one still every 2 s
	manifestName  = "manifest.json"
	originalName  = "original"
	playbackName  = "playback.mp4"
	thumbnailName = "thumbnail.jpg"
)

// Config comes from the environment (R2_* variables). Secrets: the keys.
type Config struct {
	AccountID       string
	AccessKeyID     string
	SecretAccessKey string
	Bucket          string
	Endpoint        string // optional override (tests, S3-compatible fakes)
	KeepOriginals   bool   // keep reels/<id>/original after processing
}

// Provider is the R2 video provider.
type Provider struct {
	store         *Store
	tool          *ffmpeg.Tool
	keepOriginals bool
	configured    bool
}

var (
	_ reels.VideoProvider  = (*Provider)(nil)
	_ reels.SelfProcessing = (*Provider)(nil)
)

// New builds the provider. Without account/keys/bucket, Configured() is
// false and Reels answers 503 video_provider_not_configured for uploads.
// tool may be nil or lack binaries (API image): Process then fails
// transiently and only the media worker processes.
func New(c Config, tool *ffmpeg.Tool, hc *http.Client) *Provider {
	endpoint := c.Endpoint
	if endpoint == "" && c.AccountID != "" {
		endpoint = "https://" + c.AccountID + ".r2.cloudflarestorage.com"
	}
	return &Provider{
		store: &Store{Endpoint: endpoint, Bucket: c.Bucket, HTTP: hc,
			Signer: Signer{AccessKeyID: c.AccessKeyID, SecretAccessKey: c.SecretAccessKey, Region: "auto", Service: "s3"}},
		tool:          tool,
		keepOriginals: c.KeepOriginals,
		configured:    endpoint != "" && c.Bucket != "" && c.AccessKeyID != "" && c.SecretAccessKey != "",
	}
}

// Store exposes the object client (tests, ops tooling).
func (p *Provider) Store() *Store { return p.store }

func (p *Provider) Name() string     { return ProviderName }
func (p *Provider) Configured() bool { return p != nil && p.configured }

// Key builds the stable object key for one file of one reel.
func Key(reelID, name string) string { return "reels/" + reelID + "/" + name }

// FrameKey is the moderation still at atMs.
func FrameKey(reelID string, atMs int) string {
	return Key(reelID, fmt.Sprintf("frames/%07d.jpg", atMs))
}

// FrameTimes are the still positions for a video: 0, interval, … strictly
// before the end, at most MaxFrames. Process and FrameURLs both use it, so
// the URLs never need a storage round trip.
func FrameTimes(durationMs int, interval time.Duration) []int {
	step := int(interval / time.Millisecond)
	if step <= 0 {
		step = 2000
	}
	end := durationMs - 250 // last decodable frame margin
	out := []int{0}
	for t := step; t < end && len(out) < MaxFrames; t += step {
		out = append(out, t)
	}
	return out
}

func (p *Provider) CreateUpload(_ context.Context, req reels.UploadRequest) (reels.UploadSession, error) {
	if !p.Configured() {
		return reels.UploadSession{}, reels.ErrProviderNotConfigured
	}
	switch {
	case req.SizeBytes <= 0:
		return reels.UploadSession{}, &reels.MediaError{Code: "size_bytes"}
	case req.ContentType == "":
		return reels.UploadSession{}, &reels.MediaError{Code: "content_type"}
	}
	u, h := p.store.PresignPut(Key(req.Passthrough, originalName), req.ContentType, req.SizeBytes, UploadTTL)
	return reels.UploadSession{UploadID: req.Passthrough, URL: u, Headers: h, ExpiresAt: p.store.now().Add(UploadTTL)}, nil
}

// UploadStatus: asset_created once the original (or a finished manifest)
// exists. The asset id is the reel id.
func (p *Provider) UploadStatus(ctx context.Context, uploadID string) (reels.UploadState, error) {
	if !p.Configured() {
		return reels.UploadState{}, reels.ErrProviderNotConfigured
	}
	for _, name := range []string{originalName, manifestName} {
		_, _, err := p.store.Head(ctx, Key(uploadID, name))
		if err == nil {
			return reels.UploadState{State: "asset_created", AssetID: uploadID}, nil
		}
		if !errors.Is(err, ErrNoSuchKey) {
			return reels.UploadState{}, err
		}
	}
	return reels.UploadState{State: "waiting"}, nil
}

// manifest is the processing result, written last (commit point).
type manifest struct {
	Version    int    `json:"version"`
	DurationMs int    `json:"duration_ms"`
	Width      int    `json:"width"`
	Height     int    `json:"height"`
	SizeBytes  int64  `json:"size_bytes"`
	Video      string `json:"video_key"`
	Thumbnail  string `json:"thumbnail_key"`
	Frames     []int  `json:"frame_ms"`
	Remuxed    bool   `json:"remuxed"`
}

func (m manifest) asset(id string) reels.AssetInfo {
	g := gcd(m.Width, m.Height)
	return reels.AssetInfo{ID: id, State: "ready", DurationMs: m.DurationMs, PlaybackID: id, Passthrough: id,
		AspectRatio: strconv.Itoa(m.Width/g) + ":" + strconv.Itoa(m.Height/g),
		Width:       m.Width, Height: m.Height, SizeBytes: m.SizeBytes, VideoKey: m.Video, ThumbnailKey: m.Thumbnail}
}

func gcd(a, b int) int {
	for b != 0 {
		a, b = b, a%b
	}
	if a == 0 {
		return 1
	}
	return a
}

func (p *Provider) readManifest(ctx context.Context, id string) (manifest, error) {
	var buf bytes.Buffer
	if _, err := p.store.Get(ctx, Key(id, manifestName), &buf, 1<<20); err != nil {
		return manifest{}, err
	}
	var m manifest
	if err := json.Unmarshal(buf.Bytes(), &m); err != nil {
		return manifest{}, fmt.Errorf("r2 manifest: %w", err)
	}
	return m, nil
}

// Asset reports ready once processing committed its manifest.
func (p *Provider) Asset(ctx context.Context, assetID string) (reels.AssetInfo, error) {
	if !p.Configured() {
		return reels.AssetInfo{}, reels.ErrProviderNotConfigured
	}
	m, err := p.readManifest(ctx, assetID)
	if errors.Is(err, ErrNoSuchKey) {
		if _, _, herr := p.store.Head(ctx, Key(assetID, originalName)); errors.Is(herr, ErrNoSuchKey) {
			return reels.AssetInfo{}, reels.ErrAssetNotFound
		}
		return reels.AssetInfo{ID: assetID, State: "preparing", Passthrough: assetID}, nil
	}
	if err != nil {
		return reels.AssetInfo{}, err
	}
	return m.asset(assetID), nil
}

// Process validates and transcodes one upload (see package doc).
func (p *Provider) Process(ctx context.Context, assetID string, lim reels.MediaLimits) (reels.AssetInfo, error) {
	if !p.Configured() {
		return reels.AssetInfo{}, reels.ErrProviderNotConfigured
	}
	if m, err := p.readManifest(ctx, assetID); err == nil {
		return m.asset(assetID), nil // already done (idempotent)
	} else if !errors.Is(err, ErrNoSuchKey) {
		return reels.AssetInfo{}, err
	}
	if !p.tool.Available() {
		return reels.AssetInfo{}, reels.ErrProcessorUnavailable
	}
	origKey := Key(assetID, originalName)
	size, _, err := p.store.Head(ctx, origKey)
	if errors.Is(err, ErrNoSuchKey) {
		return reels.AssetInfo{}, &reels.MediaError{Code: "upload_missing"}
	}
	if err != nil {
		return reels.AssetInfo{}, err
	}
	if size > lim.MaxBytes {
		_ = p.store.Delete(ctx, origKey) // never keep oversized uploads
		return reels.AssetInfo{}, &reels.MediaError{Code: "file_too_large"}
	}

	dir, err := os.MkdirTemp("", "reel-*")
	if err != nil {
		return reels.AssetInfo{}, err
	}
	defer os.RemoveAll(dir)
	src := filepath.Join(dir, "original")
	if err := p.download(ctx, origKey, src, lim.MaxBytes); err != nil {
		if errors.Is(err, errTooLarge) {
			_ = p.store.Delete(ctx, origKey)
			return reels.AssetInfo{}, &reels.MediaError{Code: "file_too_large"}
		}
		return reels.AssetInfo{}, err
	}

	in, err := p.tool.Probe(ctx, src)
	switch {
	case errors.Is(err, ffmpeg.ErrUnreadable):
		return reels.AssetInfo{}, &reels.MediaError{Code: "invalid_media"}
	case err != nil:
		return reels.AssetInfo{}, err
	case !in.FormatAllowed():
		return reels.AssetInfo{}, &reels.MediaError{Code: "unsupported_format"}
	case !in.HasVideo || in.Width <= 0 || in.Height <= 0:
		return reels.AssetInfo{}, &reels.MediaError{Code: "no_video_stream"}
	case in.Width > 4096 || in.Height > 4096:
		return reels.AssetInfo{}, &reels.MediaError{Code: "unsupported_format"}
	case in.DurationMs < lim.MinDurationMs || in.DurationMs > lim.MaxDurationMs:
		return reels.AssetInfo{}, &reels.MediaError{Code: "duration_out_of_range"}
	}

	out := filepath.Join(dir, playbackName)
	if err := p.tool.Transcode(ctx, in, src, out, lim.MaxDurationMs); err != nil {
		if errors.Is(err, ffmpeg.ErrTimeout) || ctx.Err() != nil {
			return reels.AssetInfo{}, err // transient: retried, then processing_failed
		}
		return reels.AssetInfo{}, &reels.MediaError{Code: "invalid_media"} // decoder refused the stream
	}
	res, err := p.tool.Probe(ctx, out)
	if err != nil || !res.HasVideo {
		return reels.AssetInfo{}, fmt.Errorf("r2: probing transcoded output: %v", err)
	}
	thumb := filepath.Join(dir, thumbnailName)
	if err := p.tool.Still(ctx, out, thumb, min(1000, res.DurationMs/2), ffmpeg.PosterMaxSide); err != nil {
		return reels.AssetInfo{}, err
	}
	times := FrameTimes(res.DurationMs, lim.FrameInterval)
	frames := make([]string, len(times))
	for i, t := range times {
		frames[i] = filepath.Join(dir, fmt.Sprintf("f%07d.jpg", t))
		if err := p.tool.Still(ctx, out, frames[i], t, ffmpeg.FrameMaxSide); err != nil {
			return reels.AssetInfo{}, err
		}
	}

	outSize, err := p.upload(ctx, out, Key(assetID, playbackName), "video/mp4")
	if err != nil {
		return reels.AssetInfo{}, err
	}
	if _, err := p.upload(ctx, thumb, Key(assetID, thumbnailName), "image/jpeg"); err != nil {
		return reels.AssetInfo{}, err
	}
	for i, t := range times {
		if _, err := p.upload(ctx, frames[i], FrameKey(assetID, t), "image/jpeg"); err != nil {
			return reels.AssetInfo{}, err
		}
	}
	m := manifest{Version: 1, DurationMs: res.DurationMs, Width: res.Width, Height: res.Height, SizeBytes: outSize,
		Video: Key(assetID, playbackName), Thumbnail: Key(assetID, thumbnailName), Frames: times, Remuxed: in.CanRemux()}
	mb, _ := json.Marshal(m)
	if err := p.store.Put(ctx, Key(assetID, manifestName), bytes.NewReader(mb), int64(len(mb)), "application/json"); err != nil {
		return reels.AssetInfo{}, err
	}
	if !p.keepOriginals {
		_ = p.store.Delete(ctx, origKey) // best effort; purge removes it later anyway
	}
	return m.asset(assetID), nil
}

func (p *Provider) download(ctx context.Context, key, dst string, maxBytes int64) error {
	f, err := os.Create(dst)
	if err != nil {
		return err
	}
	_, err = p.store.Get(ctx, key, f, maxBytes)
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	return err
}

func (p *Provider) upload(ctx context.Context, path, key, contentType string) (int64, error) {
	f, err := os.Open(path)
	if err != nil {
		return 0, err
	}
	defer f.Close()
	st, err := f.Stat()
	if err != nil {
		return 0, err
	}
	return st.Size(), p.store.Put(ctx, key, io.Reader(f), st.Size(), contentType)
}

// Playback presigns the MP4 and poster (no network call).
func (p *Provider) Playback(playbackID string, ttl time.Duration) (reels.Playback, error) {
	if !p.Configured() {
		return reels.Playback{}, reels.ErrProviderNotConfigured
	}
	return reels.Playback{
		URL:          p.store.PresignGet(Key(playbackID, playbackName), ttl),
		Format:       reels.FormatMP4,
		ThumbnailURL: p.store.PresignGet(Key(playbackID, thumbnailName), ttl),
		ExpiresAt:    p.store.now().Add(ttl),
	}, nil
}

// FrameURLs presigns the moderation stills written by Process.
func (p *Provider) FrameURLs(playbackID string, durationMs int, interval, ttl time.Duration) ([]string, error) {
	if !p.Configured() {
		return nil, reels.ErrProviderNotConfigured
	}
	times := FrameTimes(durationMs, interval)
	out := make([]string, len(times))
	for i, t := range times {
		out[i] = p.store.PresignGet(FrameKey(playbackID, t), ttl)
	}
	return out, nil
}

// DeleteAsset removes every object of the reel.
func (p *Provider) DeleteAsset(ctx context.Context, assetID string) error {
	if !p.Configured() {
		return reels.ErrProviderNotConfigured
	}
	keys, err := p.store.List(ctx, "reels/"+assetID+"/")
	if err != nil {
		return err
	}
	for _, k := range keys {
		if err := p.store.Delete(ctx, k); err != nil {
			return err
		}
	}
	return nil
}

// ParseWebhook: R2 sends no webhooks to us; completion comes from
// upload-complete and the reconcile job.
func (p *Provider) ParseWebhook(map[string]string, []byte, time.Time) (reels.WebhookEvent, error) {
	return reels.WebhookEvent{}, reels.ErrWebhookSignature
}
