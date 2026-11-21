package accounts

import (
	"context"
	"errors"
	"log/slog"
	"strings"
	"time"

	"dashuri/backend/internal/modules/keyset"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
)

// ReviewURLTTL is the lifetime of the signed URL a moderator sees.
const ReviewURLTTL = 10 * time.Minute

// slotPolicy lists the user's uploaded objects so abandoned upload tickets
// stop holding a slot. A Storage failure falls back to counting every
// pending photo (conservative).
func (s *Service) slotPolicy(ctx context.Context, userID string) SlotPolicy {
	pol := SlotPolicy{TicketTTL: UploadTicketTTL}
	paths, err := s.deps.Storage.List(ctx, userID+"/", 100)
	if err != nil {
		slog.WarnContext(ctx, "photo slot check: storage list failed", "err", err)
		return pol
	}
	pol.Uploaded = map[string]bool{}
	for _, p := range paths {
		pol.Uploaded[p] = true
	}
	return pol
}

// DeleteMyPhoto: DELETE /v1/me/photos/{photoId} — owner only; frees a slot
// and removes the Storage object when Storage is configured.
func (s *Service) DeleteMyPhoto(ctx context.Context, p auth.Principal, photoID string) error {
	if !isUUID(photoID) {
		return apperr.NotFound("photo")
	}
	repo, err := s.repo()
	if err != nil {
		return err
	}
	path, err := repo.DeletePhoto(ctx, p.UserID, photoID)
	if errors.Is(err, ErrNotFound) {
		return apperr.NotFound("photo")
	}
	if err != nil {
		return internal(err)
	}
	if s.deps.Storage != nil && s.deps.Storage.Configured() {
		if err := s.deps.Storage.Delete(ctx, path); err != nil {
			// The row is gone, so the photo is never shown; the object is an orphan.
			slog.WarnContext(ctx, "photo object delete failed", "err", err)
		}
	}
	return nil
}

func requireModerator(p auth.Principal) error {
	if p.Has(auth.RoleModerator) || p.Has(auth.RoleAdmin) {
		return nil
	}
	return apperr.Forbidden("role_required", "moderator or admin role required")
}

// ListPendingPhotos: GET /v1/admin/photos/pending — oldest first, with
// short-lived signed read URLs. Access is audited.
func (s *Service) ListPendingPhotos(ctx context.Context, p auth.Principal, cursor string, limit int) (Page[PendingPhotoItem], error) {
	if err := requireModerator(p); err != nil {
		return Page[PendingPhotoItem]{}, err
	}
	after, err := keyset.Decode(cursor)
	if err != nil {
		return Page[PendingPhotoItem]{}, validationError(map[string]string{"cursor": "invalid"})
	}
	repo, err := s.repo()
	if err != nil {
		return Page[PendingPhotoItem]{}, err
	}
	rows, err := repo.ListPendingPhotos(ctx, after, limit+1)
	if err != nil {
		return Page[PendingPhotoItem]{}, internal(err)
	}
	out := Page[PendingPhotoItem]{Items: []PendingPhotoItem{}}
	if len(rows) > limit {
		rows = rows[:limit]
		last := rows[len(rows)-1]
		next := keyset.Cursor{At: last.CreatedAt, ID: last.PhotoID}.Encode()
		out.NextCursor = &next
	}
	var signed map[string]string
	if s.deps.Storage != nil && len(rows) > 0 {
		paths := make([]string, len(rows))
		for i, r := range rows {
			paths[i] = r.Path
		}
		signed = s.deps.Storage.SignRead(ctx, paths, ReviewURLTTL)
	}
	for _, r := range rows {
		it := PendingPhotoItem{PhotoId: r.PhotoID, UserId: r.UserID, CreatedAt: r.CreatedAt}
		if u, ok := signed[r.Path]; ok {
			it.ReadUrl = &u
		}
		out.Items = append(out.Items, it)
	}
	if err := repo.Audit(ctx, p.UserID, "photos.review_queue_viewed", ""); err != nil {
		return Page[PendingPhotoItem]{}, internal(err)
	}
	return out, nil
}

// DecidePhoto: POST /v1/admin/photos/{photoId}/decision. Approving needs
// the object to exist in Storage (409 photo_not_uploaded). Audited.
func (s *Service) DecidePhoto(ctx context.Context, p auth.Principal, photoID string, in PhotoDecisionRequest) (PhotoDecision, error) {
	if err := requireModerator(p); err != nil {
		return PhotoDecision{}, err
	}
	if !isUUID(photoID) {
		return PhotoDecision{}, apperr.NotFound("photo")
	}
	if in.Reason != nil {
		r := strings.TrimSpace(*in.Reason)
		in.Reason = &r
		if r == "" {
			in.Reason = nil
		}
	}
	if errs := in.validate(); len(errs) > 0 {
		return PhotoDecision{}, validationError(errs)
	}
	repo, err := s.repo()
	if err != nil {
		return PhotoDecision{}, err
	}
	ph, err := repo.PendingPhoto(ctx, photoID)
	switch {
	case errors.Is(err, ErrNotFound):
		return PhotoDecision{}, apperr.NotFound("photo")
	case errors.Is(err, ErrPhotoNotPending):
		return PhotoDecision{}, apperr.BusinessRule("photo_not_pending", "this photo was already decided")
	case err != nil:
		return PhotoDecision{}, internal(err)
	}
	approve := in.Decision == "approve"
	if approve {
		if s.deps.Storage == nil || !s.deps.Storage.Configured() {
			return PhotoDecision{}, apperr.Unavailable("storage_not_configured", "photo storage is not configured on the server")
		}
		if _, ok := s.deps.Storage.SignRead(ctx, []string{ph.Path}, time.Minute)[ph.Path]; !ok {
			return PhotoDecision{}, apperr.BusinessRule("photo_not_uploaded", "the photo file has not been uploaded")
		}
	}
	switch err := repo.DecidePhoto(ctx, p.UserID, photoID, approve, in.Reason); {
	case errors.Is(err, ErrPhotoNotPending):
		return PhotoDecision{}, apperr.BusinessRule("photo_not_pending", "this photo was already decided")
	case errors.Is(err, ErrNotFound):
		return PhotoDecision{}, apperr.NotFound("photo")
	case err != nil:
		return PhotoDecision{}, internal(err)
	}
	status := "rejected"
	if approve {
		status = "approved"
	}
	return PhotoDecision{PhotoId: photoID, Status: status}, nil
}
