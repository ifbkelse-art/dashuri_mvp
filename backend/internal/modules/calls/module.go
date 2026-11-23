package calls

import (
	"context"
	"net/http"
	"regexp"
	"strconv"

	"time"

	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/clock"
)

// Deps are the ports this module needs. Add repository and provider
// interfaces here as the module is implemented; wire them in internal/app.
type Deps struct {
	Rules    economy.Rules
	Video    VideoProvider
	Realtime RealtimePublisher
	Repo     Repository // nil when the database is not configured → 503
	Clock    clock.Clock
	// ProviderName is the {provider} webhook path segment ("stream").
	ProviderName string
	// APIKey is the provider's public key returned with call credentials.
	APIKey string
	// Photos fills peer.photo_url (optional; nil leaves it null).
	Photos PeerPhotos
	// OnTerminated (optional) runs after a call reached a terminal phase
	// and committed, once per transition. Chat uses it to refresh both
	// participants' Chat screens so the call's session chat shows there.
	OnTerminated func(ctx context.Context, callID string)
}

// Timing rules of the call lifecycle (video-call-architecture.md).
const (
	RingTimeout       = 30 * time.Second  // ringing → missed
	ConnectTimeout    = 45 * time.Second  // accepted but never active → failed
	StaleTimeout      = 90 * time.Second  // nobody live and no events → end and settle
	ModerationWindow  = 180 * time.Second // S7: automated checks after active
	ReservationWindow = 120               // seconds reserved per window
	TokenTTL          = time.Hour         // provider user-token lifetime
)

// PageRequest is a parsed cursor page request.
type PageRequest struct {
	Cursor string
	Limit  int
}

// Page is the list envelope {items, next_cursor}.
type Page[T any] struct {
	Items      []T     `json:"items"`
	NextCursor *string `json:"next_cursor,omitempty"`
}

func parsePage(r *http.Request) (PageRequest, error) {
	p := PageRequest{Cursor: r.URL.Query().Get("cursor"), Limit: 20}
	if v := r.URL.Query().Get("limit"); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n < 1 || n > 100 {
			return p, apperr.Validation(map[string]string{"limit": "must_be_1_to_100"})
		}
		p.Limit = n
	}
	return p, nil
}

func validationError(errs map[string]string) error { return apperr.Validation(errs) }

var uuidRE = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

func isUUID(s string) bool { return uuidRE.MatchString(s) }
