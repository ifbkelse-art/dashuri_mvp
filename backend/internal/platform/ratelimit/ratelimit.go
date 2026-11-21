// Package ratelimit limits abusive request rates (OTP-adjacent endpoints,
// reports, messages, call requests).
//
// The in-memory limiter is per Cloud Run instance, so it is a first line of
// defence only. Before scale-out, move limits that protect money or safety
// to a shared store (Postgres counters or Redis; see ADR-007) and put Cloud
// Armor in front of the service.
package ratelimit

import (
	"net/http"
	"sync"
	"time"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/httpx"
)

type Limiter interface {
	Allow(key string) bool
}

// TokenBucket allows `burst` requests then `rate` per second per key.
type TokenBucket struct {
	mu      sync.Mutex
	rate    float64
	burst   float64
	buckets map[string]*bucket
}

type bucket struct {
	tokens float64
	last   time.Time
}

func NewTokenBucket(ratePerSec float64, burst int) *TokenBucket {
	return &TokenBucket{rate: ratePerSec, burst: float64(burst), buckets: map[string]*bucket{}}
}

func (t *TokenBucket) Allow(key string) bool {
	t.mu.Lock()
	defer t.mu.Unlock()
	now := time.Now()
	b, ok := t.buckets[key]
	if !ok {
		b = &bucket{tokens: t.burst, last: now}
		t.buckets[key] = b
	}
	b.tokens = min(t.burst, b.tokens+now.Sub(b.last).Seconds()*t.rate)
	b.last = now
	if b.tokens < 1 {
		return false
	}
	b.tokens--
	return true
}

// PerUser limits by authenticated user and route.
func PerUser(l Limiter, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		p, _ := auth.FromContext(r.Context())
		if !l.Allow(p.UserID + "|" + r.Pattern) {
			httpx.WriteError(w, r, &apperr.Error{Kind: apperr.KindRateLimited, Code: "rate_limited", Detail: "too many requests"})
			return
		}
		next(w, r)
	}
}
