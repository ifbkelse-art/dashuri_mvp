// Package idempotency makes value-moving POSTs safe to retry.
//
// The client sends `Idempotency-Key` (one UUID per user intent). The first
// request with a key is executed and its response stored; a retry with the
// same key and same body gets the stored response; a reuse with a different
// body is rejected (422). Keys are scoped per user and expire after 24 h.
//
// The store's Begin must be atomic (INSERT ... ON CONFLICT DO NOTHING) so two
// concurrent requests with one key cannot both execute.
package idempotency

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"io"
	"net/http"
	"time"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/httpx"
)

// Record is a stored outcome.
type Record struct {
	RequestHash string
	Status      int
	Body        []byte
	Completed   bool
}

// Store persists keys (table platform.idempotency_keys).
type Store interface {
	// Begin claims (scope, key). If the key exists it returns the existing
	// record and claimed=false.
	Begin(ctx context.Context, scope, key, requestHash string, ttl time.Duration) (existing *Record, claimed bool, err error)
	Complete(ctx context.Context, scope, key string, status int, body []byte) error
	// Release removes an in-progress claim after a failure that left no effects.
	Release(ctx context.Context, scope, key string) error
}

const ttl = 24 * time.Hour

// Require wraps a handler that moves value or creates resources.
func Require(store Store, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		key := r.Header.Get("Idempotency-Key")
		if len(key) < 16 || len(key) > 64 {
			httpx.WriteError(w, r, apperr.Validation(map[string]string{"Idempotency-Key": "required"}))
			return
		}
		p, _ := auth.FromContext(r.Context())
		body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, httpx.MaxBodyBytes))
		if err != nil {
			httpx.WriteError(w, r, apperr.Validation(map[string]string{"body": "too_large"}))
			return
		}
		sum := sha256.Sum256(append([]byte(r.Method+" "+r.URL.Path+"\n"), body...))
		hash := hex.EncodeToString(sum[:])
		scope := p.UserID + ":" + r.Method + " " + r.Pattern

		existing, claimed, err := store.Begin(r.Context(), scope, key, hash, ttl)
		if err != nil {
			httpx.WriteError(w, r, err)
			return
		}
		if !claimed {
			switch {
			case existing.RequestHash != hash:
				httpx.WriteError(w, r, apperr.Validation(map[string]string{"Idempotency-Key": "reused_with_different_request"}))
			case !existing.Completed:
				httpx.WriteError(w, r, apperr.Conflict("request_in_progress", "a request with this key is still running"))
			default:
				w.Header().Set("Content-Type", "application/json")
				w.Header().Set("Idempotent-Replayed", "true")
				w.WriteHeader(existing.Status)
				_, _ = w.Write(existing.Body)
			}
			return
		}

		rec := &captureWriter{ResponseWriter: w, status: http.StatusOK}
		r.Body = io.NopCloser(bytes.NewReader(body))
		next(rec, r)
		if rec.status >= 500 {
			// No stored outcome for server errors; the client may retry the same key.
			_ = store.Release(r.Context(), scope, key)
			return
		}
		_ = store.Complete(r.Context(), scope, key, rec.status, rec.buf.Bytes())
	}
}

type captureWriter struct {
	http.ResponseWriter
	status int
	buf    bytes.Buffer
}

func (c *captureWriter) WriteHeader(code int) {
	c.status = code
	c.ResponseWriter.WriteHeader(code)
}

func (c *captureWriter) Write(b []byte) (int, error) {
	c.buf.Write(b)
	return c.ResponseWriter.Write(b)
}
