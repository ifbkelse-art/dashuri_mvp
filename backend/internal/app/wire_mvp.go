package app

import (
	"net/http"

	"dashuri/backend/internal/platform/routing"
	"dashuri/backend/internal/wiring"
)

// mountMVPModules mounts modules added for the MVP (e.g. location). Each
// workstream adds one line here and owns its own wire file.
func mountMVPModules(mux *http.ServeMux, env wiring.Env, stack routing.Stack) {
	_, _, _ = mux, env, stack
}
