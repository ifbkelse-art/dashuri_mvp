// Package httpx holds HTTP plumbing shared by every module: problem
// responses, JSON helpers and middleware.
package httpx

import (
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"

	"dashuri/backend/internal/platform/apperr"
)

// Problem is an RFC 9457 problem detail. `code` is the stable contract field
// clients switch on; for business rules `rule` repeats it.
type Problem struct {
	Type      string       `json:"type"`
	Title     string       `json:"title"`
	Status    int          `json:"status"`
	Code      string       `json:"code"`
	Rule      string       `json:"rule,omitempty"`
	Detail    string       `json:"detail,omitempty"`
	Errors    []FieldError `json:"errors,omitempty"`
	RequestID string       `json:"request_id,omitempty"`
}

type FieldError struct {
	Field  string `json:"field"`
	Reason string `json:"reason"`
}

func statusFor(k apperr.Kind) int {
	switch k {
	case apperr.KindValidation:
		return http.StatusUnprocessableEntity
	case apperr.KindUnauthenticated:
		return http.StatusUnauthorized
	case apperr.KindForbidden:
		return http.StatusForbidden
	case apperr.KindNotFound:
		return http.StatusNotFound
	case apperr.KindConflict, apperr.KindBusinessRule:
		return http.StatusConflict
	case apperr.KindRateLimited:
		return http.StatusTooManyRequests
	case apperr.KindNotImplemented:
		return http.StatusNotImplemented
	case apperr.KindUnavailable:
		return http.StatusServiceUnavailable
	default:
		return http.StatusInternalServerError
	}
}

// WriteError converts any error to a problem response. Unclassified errors
// become 500 with no detail; the cause is logged, never sent.
func WriteError(w http.ResponseWriter, r *http.Request, err error) {
	e := apperr.As(err)
	if e == nil {
		e = apperr.Internal(err)
	}
	status := statusFor(e.Kind)
	p := Problem{
		Type:      "https://docs.dashuri.invalid/problems/" + e.Code, // TODO: real docs URL
		Title:     http.StatusText(status),
		Status:    status,
		Code:      e.Code,
		RequestID: RequestID(r.Context()),
	}
	if e.Kind == apperr.KindBusinessRule {
		p.Code, p.Rule = "business_rule", e.Code
	}
	if status < 500 || e.Kind == apperr.KindNotImplemented || e.Kind == apperr.KindUnavailable {
		p.Detail = e.Detail
	}
	for f, reason := range e.Fields {
		p.Errors = append(p.Errors, FieldError{Field: f, Reason: reason})
	}
	if status >= 500 && e.Kind == apperr.KindInternal {
		slog.ErrorContext(r.Context(), "request failed", "err", err, "route", r.Pattern)
	}
	w.Header().Set("Content-Type", "application/problem+json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(p)
}

// WriteJSON writes a success body.
func WriteJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}

// MaxBodyBytes bounds every JSON request body.
const MaxBodyBytes = 64 << 10

// DecodeJSON reads a bounded JSON body and rejects unknown fields.
func DecodeJSON(r *http.Request, dst any) error {
	dec := json.NewDecoder(http.MaxBytesReader(nil, r.Body, MaxBodyBytes))
	dec.DisallowUnknownFields()
	if err := dec.Decode(dst); err != nil {
		var tooBig *http.MaxBytesError
		if errors.As(err, &tooBig) {
			return apperr.Validation(map[string]string{"body": "too_large"})
		}
		return apperr.Validation(map[string]string{"body": "invalid_json"})
	}
	return nil
}

// ReadRaw reads a bounded raw body (webhooks verify signatures over raw bytes).
func ReadRaw(r *http.Request) ([]byte, error) {
	b, err := io.ReadAll(http.MaxBytesReader(nil, r.Body, 1<<20))
	if err != nil {
		return nil, apperr.Validation(map[string]string{"body": "unreadable_or_too_large"})
	}
	return b, nil
}

// HeaderMap flattens headers for signature verification.
func HeaderMap(r *http.Request) map[string]string {
	m := make(map[string]string, len(r.Header))
	for k := range r.Header {
		m[k] = r.Header.Get(k)
	}
	return m
}
