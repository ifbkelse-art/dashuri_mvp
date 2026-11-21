package notifications

import (
	"context"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
)

// Service implements the notifications module's use cases. Every method is a
// scaffold that returns 501 until implemented; the documented steps are the
// required behaviour (see docs/architecture).
type Service struct {
	deps Deps
}

func NewService(d Deps) *Service { return &Service{deps: d} }

// RegisterDevice: PUT /v1/me/devices — Register a push token.
func (s *Service) RegisterDevice(ctx context.Context, p auth.Principal, in DeviceRegistration) error {
	return apperr.NotImplemented("notifications.RegisterDevice")
}

// UnregisterDevice: DELETE /v1/me/devices/{token} — Remove a push token.
func (s *Service) UnregisterDevice(ctx context.Context, p auth.Principal, token string) error {
	return apperr.NotImplemented("notifications.UnregisterDevice")
}

// ListInbox: GET /v1/notifications — In-app notifications.
func (s *Service) ListInbox(ctx context.Context, p auth.Principal, page PageRequest) (Page[InboxItem], error) {
	return Page[InboxItem]{}, apperr.NotImplemented("notifications.ListInbox")
}

// MarkRead: POST /v1/notifications/{notificationId}/read — Mark a notification read.
func (s *Service) MarkRead(ctx context.Context, p auth.Principal, notificationId string) error {
	return apperr.NotImplemented("notifications.MarkRead")
}
