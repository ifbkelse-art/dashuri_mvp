// Package keyset is the opaque (timestamp, id) cursor used by newest-first
// lists (conversations, messages, blocks, enforcement, notifications). It is
// a pure library like economy; modules import it, it imports nothing.
package keyset

import (
	"encoding/base64"
	"errors"
	"regexp"
	"strings"
	"time"
)

// Cursor is the position of the last row of a page.
type Cursor struct {
	At time.Time
	ID string
}

// ErrInvalid is returned for tokens that were not produced by Encode.
var ErrInvalid = errors.New("invalid cursor")

var uuidRE = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

// Encode returns the opaque token.
func (c Cursor) Encode() string {
	return base64.RawURLEncoding.EncodeToString([]byte("c1|" + c.At.UTC().Format(time.RFC3339Nano) + "|" + c.ID))
}

// Decode parses a token; empty means first page (nil, nil).
func Decode(s string) (*Cursor, error) {
	if s == "" {
		return nil, nil
	}
	if len(s) > 200 {
		return nil, ErrInvalid
	}
	b, err := base64.RawURLEncoding.DecodeString(s)
	if err != nil {
		return nil, ErrInvalid
	}
	parts := strings.Split(string(b), "|")
	if len(parts) != 3 || parts[0] != "c1" || !uuidRE.MatchString(parts[2]) {
		return nil, ErrInvalid
	}
	t, err := time.Parse(time.RFC3339Nano, parts[1])
	if err != nil {
		return nil, ErrInvalid
	}
	return &Cursor{At: t, ID: parts[2]}, nil
}
