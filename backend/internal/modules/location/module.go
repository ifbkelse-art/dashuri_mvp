package location

import "dashuri/backend/internal/platform/apperr"

// Deps are the ports this module needs. Repo is nil without a database.
type Deps struct {
	Repo Repository
}

func validationError(errs map[string]string) error { return apperr.Validation(errs) }
