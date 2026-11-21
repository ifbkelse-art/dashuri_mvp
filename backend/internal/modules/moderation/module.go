package moderation

import (
	"net/http"
	"regexp"
	"strconv"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/clock"
)

// Deps are the ports this module needs. Add repository and provider
// interfaces here as the module is implemented; wire them in internal/app.
type Deps struct {
	// Enabled is MODERATION_ENABLED. When true but Classifier is nil
	// (credentials missing) frames are refused with 503 moderation_not_configured.
	Enabled    bool
	Classifier NudityClassifier
	Frames     FrameSource
	Evidence   EvidenceStore
	Repo       Repository // nil without a database → 503
	Calls      CallEnder
	Clock      clock.Clock
	// Threshold flags a frame when any explicit class reaches it (default 0.6).
	Threshold float64
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
