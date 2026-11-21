package app

import (
	"dashuri/backend/internal/modules/freecall"
	"dashuri/backend/internal/wiring"
)

// wireFreecall builds the freecall module from shared infrastructure.
func wireFreecall(env wiring.Env) *freecall.Service {
	return freecall.NewService(freecall.Deps{Rules: env.Rules, Enabled: env.Config.FreeCallEnabled})
}
