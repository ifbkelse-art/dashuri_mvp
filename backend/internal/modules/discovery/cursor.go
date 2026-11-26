package discovery

import (
	"encoding/base64"
	"errors"
	"strconv"
	"strings"
)

// Cursor is the keyset position of the last card of a page. Rows are
// ordered by (K1, K2, user id) ascending, where the keys depend on the sort:
//
//	recommended: K1 = 0 available / 1 busy, K2 = -(lifetime XP + verified boost)
//	rate_low:    K1 = rate,                 K2 = 0
//	rate_high:   K1 = -rate,                K2 = 0
type Cursor struct {
	Sort string
	K1   int64
	K2   int64
	ID   string
}

var errBadCursor = errors.New("invalid cursor")

// SortKeys returns the keyset keys of a row for a sort (no verification boost).
func SortKeys(sort string, h HostRow) (int64, int64) { return RankKeys(sort, h, 0) }

// RankKeys returns the keyset keys with the Verified Host ranking signal:
// in the recommended sort a verified host ranks as if it had boost more XP.
func RankKeys(sort string, h HostRow, boost int64) (int64, int64) {
	switch sort {
	case SortRateLow:
		return h.RatePerMinute, 0
	case SortRateHigh:
		return -h.RatePerMinute, 0
	default:
		var rank int64
		if h.Busy {
			rank = 1
		}
		xp := h.LifetimeXP
		if h.Verified {
			xp += boost
		}
		return rank, -xp
	}
}

// Encode returns the opaque token.
func (c Cursor) Encode() string {
	raw := strings.Join([]string{"h1", c.Sort, strconv.FormatInt(c.K1, 10), strconv.FormatInt(c.K2, 10), c.ID}, "|")
	return base64.RawURLEncoding.EncodeToString([]byte(raw))
}

// DecodeCursor parses a token for the given sort. Empty means first page.
func DecodeCursor(s, sort string) (*Cursor, error) {
	if s == "" {
		return nil, nil
	}
	if len(s) > 200 {
		return nil, errBadCursor
	}
	b, err := base64.RawURLEncoding.DecodeString(s)
	if err != nil {
		return nil, errBadCursor
	}
	parts := strings.Split(string(b), "|")
	if len(parts) != 5 || parts[0] != "h1" || parts[1] != sort || !uuidRE.MatchString(parts[4]) {
		return nil, errBadCursor
	}
	k1, err1 := strconv.ParseInt(parts[2], 10, 64)
	k2, err2 := strconv.ParseInt(parts[3], 10, 64)
	if err1 != nil || err2 != nil {
		return nil, errBadCursor
	}
	return &Cursor{Sort: sort, K1: k1, K2: k2, ID: parts[4]}, nil
}
