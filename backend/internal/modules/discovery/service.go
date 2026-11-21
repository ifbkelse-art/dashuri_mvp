package discovery

import (
	"context"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
)

// Service implements the discovery module's use cases. Every method is a
// scaffold that returns 501 until implemented; the documented steps are the
// required behaviour (see docs/architecture).
type Service struct {
	deps Deps
}

func NewService(d Deps) *Service { return &Service{deps: d} }

// ListAvailableHosts: GET /v1/discovery/hosts — Hosts online and accepting calls, with their rates. Excludes blocked users.
func (s *Service) ListAvailableHosts(ctx context.Context, p auth.Principal, page PageRequest) (Page[HostCard], error) {
	return Page[HostCard]{}, apperr.NotImplemented("discovery.ListAvailableHosts")
}
