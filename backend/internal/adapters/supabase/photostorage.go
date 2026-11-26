package supabase

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// ErrStorageNotConfigured means SUPABASE_URL or the storage key is missing.
var ErrStorageNotConfigured = errors.New("supabase storage: not configured")

// PhotoStorage issues signed URLs for a private Storage bucket (profile
// photos) through the Storage REST API with a server-held key. The app never
// holds the key; it only receives short-lived signed URLs.
type PhotoStorage struct {
	BaseURL string // SUPABASE_URL
	APIKey  string // SUPABASE_STORAGE_SERVICE_KEY (server only)
	Bucket  string // e.g. profile-photos
	Client  *http.Client
}

// Configured reports whether URLs can be signed.
func (s PhotoStorage) Configured() bool { return s.BaseURL != "" && s.APIKey != "" && s.Bucket != "" }

// UploadURLTTL is how long Supabase keeps a signed upload URL valid (fixed by
// Storage at two hours).
const UploadURLTTL = 2 * time.Hour

// SignUpload returns a signed upload URL for one object path inside the bucket.
// POST {SUPABASE_URL}/storage/v1/object/upload/sign/{bucket}/{path}
func (s PhotoStorage) SignUpload(ctx context.Context, path string) (string, error) {
	if !s.Configured() {
		return "", ErrStorageNotConfigured
	}
	var out struct {
		URL string `json:"url"`
	}
	endpoint := s.storageBase() + "/object/upload/sign/" + url.PathEscape(s.Bucket) + "/" + escapePath(path)
	if err := s.do(ctx, http.MethodPost, endpoint, map[string]any{}, &out); err != nil {
		return "", err
	}
	if out.URL == "" {
		return "", errors.New("supabase storage: empty upload url")
	}
	return s.absolute(out.URL), nil
}

// SignRead returns signed read URLs for existing objects, keyed by path.
// Paths that cannot be signed (e.g. not uploaded yet) are left out. A
// failure is logged and yields an empty map: profile and discovery pages
// still render, without photos.
// POST {SUPABASE_URL}/storage/v1/object/sign/{bucket} {expiresIn, paths}
func (s PhotoStorage) SignRead(ctx context.Context, paths []string, ttl time.Duration) map[string]string {
	out := map[string]string{}
	if len(paths) == 0 {
		return out
	}
	if !s.Configured() {
		slog.DebugContext(ctx, "photo storage not configured; photos omitted")
		return out
	}
	var res []struct {
		Path      string  `json:"path"`
		SignedURL string  `json:"signedURL"`
		Error     *string `json:"error"`
	}
	endpoint := s.storageBase() + "/object/sign/" + url.PathEscape(s.Bucket)
	body := map[string]any{"expiresIn": int(ttl.Seconds()), "paths": paths}
	if err := s.do(ctx, http.MethodPost, endpoint, body, &res); err != nil {
		slog.WarnContext(ctx, "photo url signing failed", "err", err)
		return out
	}
	for _, r := range res {
		if r.Error == nil && r.SignedURL != "" {
			out[r.Path] = s.absolute(r.SignedURL)
		}
	}
	return out
}

// List returns the object paths directly under prefix (e.g. "<user id>/"),
// as full paths inside the bucket. At most limit objects.
// POST {SUPABASE_URL}/storage/v1/object/list/{bucket} {prefix, limit, offset}
func (s PhotoStorage) List(ctx context.Context, prefix string, limit int) ([]string, error) {
	if !s.Configured() {
		return nil, ErrStorageNotConfigured
	}
	var res []struct {
		Name string  `json:"name"`
		ID   *string `json:"id"` // null for folders
	}
	endpoint := s.storageBase() + "/object/list/" + url.PathEscape(s.Bucket)
	body := map[string]any{"prefix": prefix, "limit": limit, "offset": 0}
	if err := s.do(ctx, http.MethodPost, endpoint, body, &res); err != nil {
		return nil, err
	}
	dir := strings.TrimSuffix(prefix, "/")
	out := make([]string, 0, len(res))
	for _, r := range res {
		if r.ID == nil || r.Name == "" {
			continue
		}
		if dir == "" {
			out = append(out, r.Name)
		} else {
			out = append(out, dir+"/"+r.Name)
		}
	}
	return out, nil
}

// Delete removes one object. A missing object is not an error.
// DELETE {SUPABASE_URL}/storage/v1/object/{bucket}  {prefixes: [path]}
func (s PhotoStorage) Delete(ctx context.Context, path string) error {
	if !s.Configured() {
		return ErrStorageNotConfigured
	}
	var res []json.RawMessage
	endpoint := s.storageBase() + "/object/" + url.PathEscape(s.Bucket)
	return s.do(ctx, http.MethodDelete, endpoint, map[string]any{"prefixes": []string{path}}, &res)
}

func (s PhotoStorage) storageBase() string { return strings.TrimRight(s.BaseURL, "/") + "/storage/v1" }

func (s PhotoStorage) absolute(u string) string {
	if strings.HasPrefix(u, "http://") || strings.HasPrefix(u, "https://") {
		return u
	}
	if !strings.HasPrefix(u, "/") {
		u = "/" + u
	}
	return s.storageBase() + u
}

func (s PhotoStorage) do(ctx context.Context, method, endpoint string, body, out any) error {
	b, err := json.Marshal(body)
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(ctx, 8*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, method, endpoint, bytes.NewReader(b))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("apikey", s.APIKey)
	req.Header.Set("Authorization", "Bearer "+s.APIKey)
	c := s.Client
	if c == nil {
		c = http.DefaultClient
	}
	res, err := c.Do(req)
	if err != nil {
		return fmt.Errorf("supabase storage: %w", err)
	}
	defer res.Body.Close()
	data, err := io.ReadAll(io.LimitReader(res.Body, 1<<20))
	if err != nil {
		return err
	}
	if res.StatusCode >= 300 {
		// The body may echo object paths (user ids); log only the status.
		return fmt.Errorf("supabase storage: status %d", res.StatusCode)
	}
	return json.Unmarshal(data, out)
}

func escapePath(p string) string {
	parts := strings.Split(p, "/")
	for i, s := range parts {
		parts[i] = url.PathEscape(s)
	}
	return strings.Join(parts, "/")
}

// ErrObjectNotFound means the object does not exist (never uploaded).
var ErrObjectNotFound = errors.New("supabase storage: object not found")

// ErrObjectTooLarge means the object exceeds the caller's byte limit.
var ErrObjectTooLarge = errors.New("supabase storage: object too large")

// Download reads one object with the server key, refusing objects larger
// than maxBytes. GET {SUPABASE_URL}/storage/v1/object/{bucket}/{path}
func (s PhotoStorage) Download(ctx context.Context, path string, maxBytes int64) ([]byte, error) {
	if !s.Configured() {
		return nil, ErrStorageNotConfigured
	}
	ctx, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()
	endpoint := s.storageBase() + "/object/" + url.PathEscape(s.Bucket) + "/" + escapePath(path)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("apikey", s.APIKey)
	req.Header.Set("Authorization", "Bearer "+s.APIKey)
	res, err := s.client().Do(req)
	if err != nil {
		return nil, fmt.Errorf("supabase storage: %w", err)
	}
	defer res.Body.Close()
	switch {
	case res.StatusCode == http.StatusNotFound || res.StatusCode == http.StatusBadRequest:
		// Storage answers 400 "Object not found" for missing objects.
		return nil, ErrObjectNotFound
	case res.StatusCode >= 300:
		return nil, fmt.Errorf("supabase storage: status %d", res.StatusCode)
	}
	data, err := io.ReadAll(io.LimitReader(res.Body, maxBytes+1))
	if err != nil {
		return nil, err
	}
	if int64(len(data)) > maxBytes {
		return nil, ErrObjectTooLarge
	}
	return data, nil
}

// Put writes (overwrites) one object with the server key.
// PUT {SUPABASE_URL}/storage/v1/object/{bucket}/{path} with x-upsert.
func (s PhotoStorage) Put(ctx context.Context, path, contentType string, data []byte) error {
	if !s.Configured() {
		return ErrStorageNotConfigured
	}
	ctx, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()
	endpoint := s.storageBase() + "/object/" + url.PathEscape(s.Bucket) + "/" + escapePath(path)
	req, err := http.NewRequestWithContext(ctx, http.MethodPut, endpoint, bytes.NewReader(data))
	if err != nil {
		return err
	}
	req.Header.Set("apikey", s.APIKey)
	req.Header.Set("Authorization", "Bearer "+s.APIKey)
	req.Header.Set("Content-Type", contentType)
	req.Header.Set("x-upsert", "true")
	res, err := s.client().Do(req)
	if err != nil {
		return fmt.Errorf("supabase storage: %w", err)
	}
	defer res.Body.Close()
	_, _ = io.Copy(io.Discard, io.LimitReader(res.Body, 1<<16))
	if res.StatusCode >= 300 {
		return fmt.Errorf("supabase storage: status %d", res.StatusCode)
	}
	return nil
}

func (s PhotoStorage) client() *http.Client {
	if s.Client == nil {
		return http.DefaultClient
	}
	return s.Client
}
