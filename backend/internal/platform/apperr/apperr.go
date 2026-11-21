// Package apperr defines the error kinds every module returns. The HTTP
// layer maps them to RFC 9457 problem responses; nothing else in the code
// knows about HTTP status codes.
package apperr

import (
	"errors"
	"fmt"
)

// Kind classifies an error for transport mapping.
type Kind int

const (
	KindInternal Kind = iota
	KindValidation
	KindUnauthenticated
	KindForbidden
	KindNotFound
	KindConflict
	KindBusinessRule
	KindRateLimited
	KindNotImplemented
	KindUnavailable
)

// Error is a classified application error.
type Error struct {
	Kind   Kind
	Code   string            // stable machine code, e.g. "insufficient_diamonds"
	Detail string            // developer-facing detail; never secrets or personal data
	Fields map[string]string // validation errors: field → reason
	Err    error             // wrapped cause, logged but never returned to clients
}

func (e *Error) Error() string {
	if e.Err != nil {
		return fmt.Sprintf("%s: %s: %v", e.Code, e.Detail, e.Err)
	}
	return fmt.Sprintf("%s: %s", e.Code, e.Detail)
}

func (e *Error) Unwrap() error { return e.Err }

// As extracts an *Error, or nil.
func As(err error) *Error {
	var e *Error
	if errors.As(err, &e) {
		return e
	}
	return nil
}

func Validation(fields map[string]string) *Error {
	return &Error{Kind: KindValidation, Code: "validation_failed", Fields: fields}
}

func NotFound(what string) *Error {
	return &Error{Kind: KindNotFound, Code: "not_found", Detail: what + " not found"}
}

func Forbidden(code, detail string) *Error {
	return &Error{Kind: KindForbidden, Code: code, Detail: detail}
}

func Conflict(code, detail string) *Error {
	return &Error{Kind: KindConflict, Code: code, Detail: detail}
}

// BusinessRule reports a refused action, e.g. "insufficient_diamonds",
// "below_minimum_withdrawal", "rate_outside_level_limits".
func BusinessRule(rule, detail string) *Error {
	return &Error{Kind: KindBusinessRule, Code: rule, Detail: detail}
}

func Unauthenticated(detail string) *Error {
	return &Error{Kind: KindUnauthenticated, Code: "unauthenticated", Detail: detail}
}

func Internal(err error) *Error { return &Error{Kind: KindInternal, Code: "internal", Err: err} }

// NotImplemented marks scaffolded operations. Returned as HTTP 501 so the
// app can integrate against the contract before the logic exists.
func NotImplemented(op string) *Error {
	return &Error{Kind: KindNotImplemented, Code: "not_implemented", Detail: op + " is not implemented yet"}
}

// Unavailable marks features switched off by configuration, e.g. payouts
// before incorporation and payout-provider onboarding (founder decision R3-7).
func Unavailable(code, detail string) *Error {
	return &Error{Kind: KindUnavailable, Code: code, Detail: detail}
}
