package accounts

import (
	"regexp"

	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/clock"
)

// Deps are the ports this module needs. Repo is nil without a database.
type Deps struct {
	Repo    Repository
	Storage PhotoStorage // nil or unconfigured: uploads 503, photos omitted
	Rules   economy.Rules
	Clock   clock.Clock
}

func validationError(errs map[string]string) error { return apperr.Validation(errs) }

var uuidRE = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

func isUUID(s string) bool { return uuidRE.MatchString(s) }
