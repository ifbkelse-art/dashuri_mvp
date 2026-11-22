package chat

import (
	"net/http"
	"regexp"
	"strconv"

	"dashuri/backend/internal/platform/apperr"
)

// Deps are the ports this module needs. Repo is nil without a database.
type Deps struct {
	Repo     Repository
	Realtime Publisher     // optional
	Photos   PhotoSigner   // optional
	Push     MessagePusher // optional
	// MessageContext stores in-call metadata (context, call_id,
	// client_message_id). Needs migration 20261123000200; config
	// CHAT_MESSAGE_CONTEXT_ENABLED, default off.
	MessageContext bool
}

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
