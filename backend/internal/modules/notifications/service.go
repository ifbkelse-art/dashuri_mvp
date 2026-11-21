package notifications

import (
	"context"
	"errors"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
)

// Service implements devices and the in-app inbox.
type Service struct {
	deps Deps
}

func NewService(d Deps) *Service { return &Service{deps: d} }

func (s *Service) repo() (Repository, error) {
	if s.deps.Repo == nil {
		return nil, apperr.Unavailable("database_unavailable", "database not configured")
	}
	return s.deps.Repo, nil
}

// RegisterDevice: PUT /v1/me/devices. A token moves to the latest user.
func (s *Service) RegisterDevice(ctx context.Context, p auth.Principal, in DeviceRegistration) error {
	if errs := in.validate(); len(errs) > 0 {
		return validationError(errs)
	}
	repo, err := s.repo()
	if err != nil {
		return err
	}
	if err := repo.UpsertDevice(ctx, p.UserID, in.Token, in.Platform); err != nil {
		return apperr.Internal(err)
	}
	return nil
}

// UnregisterDevice: DELETE /v1/me/devices/{token}. Idempotent.
func (s *Service) UnregisterDevice(ctx context.Context, p auth.Principal, token string) error {
	if token == "" || len(token) > 4096 {
		return apperr.NotFound("device")
	}
	repo, err := s.repo()
	if err != nil {
		return err
	}
	if err := repo.DeleteDevice(ctx, p.UserID, token); err != nil {
		return apperr.Internal(err)
	}
	return nil
}

// ListInbox: GET /v1/notifications — newest first.
func (s *Service) ListInbox(ctx context.Context, p auth.Principal, page PageRequest) (Page[InboxItem], error) {
	after, err := DecodeCursor(page.Cursor)
	if err != nil {
		return Page[InboxItem]{}, validationError(map[string]string{"cursor": "invalid"})
	}
	repo, err := s.repo()
	if err != nil {
		return Page[InboxItem]{}, err
	}
	rows, err := repo.ListInbox(ctx, p.UserID, after, page.Limit+1)
	if err != nil {
		return Page[InboxItem]{}, apperr.Internal(err)
	}
	out := Page[InboxItem]{Items: []InboxItem{}}
	if len(rows) > page.Limit {
		rows = rows[:page.Limit]
		last := rows[len(rows)-1]
		next := Cursor{At: last.CreatedAt, ID: last.Id}.Encode()
		out.NextCursor = &next
	}
	out.Items = append(out.Items, rows...)
	return out, nil
}

// MarkRead: POST /v1/notifications/{id}/read. Idempotent for own items.
func (s *Service) MarkRead(ctx context.Context, p auth.Principal, notificationId string) error {
	if !isUUID(notificationId) {
		return apperr.NotFound("notification")
	}
	repo, err := s.repo()
	if err != nil {
		return err
	}
	switch err := repo.MarkRead(ctx, p.UserID, notificationId); {
	case errors.Is(err, ErrNotFound):
		return apperr.NotFound("notification")
	case err != nil:
		return apperr.Internal(err)
	}
	return nil
}
