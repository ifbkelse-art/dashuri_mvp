package hosts

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"image/jpeg"
	"log/slog"
	"strings"
	"time"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
)

// Arrival photo: an OPTIONAL in-app camera photo a host takes when a new
// online session starts (docs/host/HOST_HOME_SESSION_AND_ARRIVAL_PHOTO.md).
//
//   - It belongs to exactly one online session (hosting.online_sessions,
//     opened and closed by a trigger on hosts.is_available) and is never
//     reused: going offline expires it.
//   - It is shown to customers only while approved AND its session is open,
//     always as "captured <time> ago" — never as live video and never as
//     identity verification.
//   - Uploads go to a PRIVATE bucket through a short-lived signed URL; the
//     server then downloads the object, checks it is a real JPEG of sane
//     size, re-encodes it (which drops EXIF/GPS metadata) and moderates it.
//   - Skipping it never affects availability or ranking.

// ArrivalBucket is the private Storage bucket.
const ArrivalBucket = "host-arrival-photos"

// Arrival photo limits.
const (
	ArrivalMaxBytes     = 2 << 20 // 2 MiB after on-device compression
	ArrivalMinDimension = 240
	ArrivalMaxDimension = 4096
	// ArrivalUploadWindow: the photo must be uploaded and confirmed within
	// this long of the ticket, so an old picture cannot be "captured" later.
	ArrivalUploadWindow = 10 * time.Minute
	// ArrivalReadTTL is the lifetime of signed read URLs handed to clients.
	ArrivalReadTTL = 15 * time.Minute
	// ArrivalReencodeQuality is the server re-encode JPEG quality.
	ArrivalReencodeQuality = 85
)

// Arrival photo statuses (hosting.arrival_photos.status).
const (
	ArrivalAwaitingUpload = "awaiting_upload"
	ArrivalPendingReview  = "pending_review"
	ArrivalApproved       = "approved"
	ArrivalRejected       = "rejected"
	ArrivalRemoved        = "removed"
	ArrivalExpired        = "expired"
)

// OnlineSession is a hosting.online_sessions row.
type OnlineSession struct {
	ID        string
	HostID    string
	StartedAt time.Time
	EndedAt   *time.Time
}

// ArrivalPhoto is a hosting.arrival_photos row.
type ArrivalPhoto struct {
	ID               string
	HostID           string
	SessionID        string
	Status           string
	StoragePath      string
	ContentType      string
	ByteSize         *int
	Width, Height    *int
	ModerationSource *string
	DecisionReason   *string
	UploadExpiresAt  time.Time
	CapturedAt       *time.Time
	CreatedAt        time.Time
	SessionOpen      bool // the photo's session is still open
	HostName         string
}

// ArrivalDecision is what a confirm, staff decision or removal writes.
type ArrivalDecision struct {
	Status           string
	ByteSize         int
	Width, Height    int
	ModerationSource string
	Score            *float64
	Reason           string
	DecidedBy        string
	At               time.Time
	PurgeAfter       *time.Time
}

// Errors from ArrivalRepository.
var (
	ErrNotOnline       = errors.New("hosts: no open online session")
	ErrArrivalNotFound = errors.New("hosts: arrival photo not found")
	ErrArrivalState    = errors.New("hosts: arrival photo is not in a state for this action")
	// ErrArrivalSelfReview: staff may not decide their own arrival photo.
	ErrArrivalSelfReview = errors.New("hosts: staff cannot decide their own arrival photo")
)

// ArrivalRepository persists online sessions and arrival photos.
type ArrivalRepository interface {
	// OpenSession returns the host's open online session (ErrNotOnline).
	OpenSession(ctx context.Context, hostID string) (OnlineSession, error)
	// CreateArrivalPhoto locks the host row, requires an open session (and
	// is_available), ends a previous current photo of that session
	// (status removed, reason "replaced") and inserts an awaiting_upload
	// row. sign is called inside the transaction; its failure rolls back.
	CreateArrivalPhoto(ctx context.Context, hostID, photoID, path string, uploadExpires time.Time, sign func(path string) (string, error)) (sessionID, uploadURL string, err error)
	ArrivalPhoto(ctx context.Context, photoID string) (ArrivalPhoto, error)
	// CurrentArrivalPhoto is the open session's not-ended photo (nil if none).
	CurrentArrivalPhoto(ctx context.Context, hostID string) (*ArrivalPhoto, error)
	// DecideArrivalPhoto locks the photo row, passes it to decide and
	// writes the returned decision plus an audit row when actor is staff.
	DecideArrivalPhoto(ctx context.Context, photoID string, decide func(ArrivalPhoto) (ArrivalDecision, error)) (ArrivalPhoto, error)
	ArrivalReviewQueue(ctx context.Context, limit int) ([]ArrivalPhoto, error)
	// ExpireAbandonedArrivalUploads ends awaiting_upload rows past their window.
	ExpireAbandonedArrivalUploads(ctx context.Context, now time.Time) (int64, error)
	// ArrivalPhotosDueForPurge: ended photos past purge_after whose object
	// was not deleted yet, skipping photos with an open report.
	ArrivalPhotosDueForPurge(ctx context.Context, now time.Time, limit int) ([]ArrivalPhoto, error)
	MarkArrivalPurged(ctx context.Context, photoID string, at time.Time) error
	Audit(ctx context.Context, actor, action, target string, details map[string]any) error
}

// Errors an ArrivalStore returns from Download.
var (
	ErrObjectNotFound = errors.New("hosts: stored object not found")
	ErrObjectTooLarge = errors.New("hosts: stored object too large")
)

// ArrivalStore is the private arrival-photo bucket (server key only).
type ArrivalStore interface {
	Configured() bool
	SignUpload(ctx context.Context, path string) (string, error)
	SignRead(ctx context.Context, paths []string, ttl time.Duration) map[string]string
	Download(ctx context.Context, path string, maxBytes int64) ([]byte, error)
	Put(ctx context.Context, path, contentType string, data []byte) error
	Delete(ctx context.Context, path string) error
}

// ImageScanner returns an explicit-content score in [0,1] for an image
// (adapter over the moderation classifier). Optional.
type ImageScanner interface {
	ExplicitScore(ctx context.Context, image []byte) (float64, error)
}

// ArrivalConfig configures the feature (ARRIVAL_PHOTOS_ENABLED etc.).
type ArrivalConfig struct {
	Enabled bool
	Repo    ArrivalRepository
	Store   ArrivalStore
	Scanner ImageScanner // nil: no automated scan
	// FlagThreshold: explicit score at or above it is rejected.
	FlagThreshold float64
	// AutoApproveUnscanned publishes validated photos without a scan when
	// Scanner is nil. Default false: they wait for a moderator.
	AutoApproveUnscanned bool
	// Retention of ended photos before the object is deleted (default 24 h;
	// rejected photos 7 days for appeal/review).
	Retention         time.Duration
	RejectedRetention time.Duration
}

// ---------------------------------------------------------------- wire types

// ArrivalUploadRequest: POST /v1/host/arrival-photo/upload-tickets.
type ArrivalUploadRequest struct {
	ContentType string `json:"content_type"`
}

// ArrivalUploadTicket is the signed upload target for one photo.
type ArrivalUploadTicket struct {
	PhotoId   string    `json:"photo_id"`
	SessionId string    `json:"session_id"`
	UploadUrl string    `json:"upload_url"`
	ExpiresAt time.Time `json:"expires_at"`
	MaxBytes  int       `json:"max_bytes"`
}

// ArrivalPhotoView is the host's own view of the current photo.
type ArrivalPhotoView struct {
	PhotoId    string     `json:"photo_id"`
	SessionId  string     `json:"session_id"`
	Status     string     `json:"status"`
	CapturedAt *time.Time `json:"captured_at"`
	// PhotoUrl is a short-lived signed URL (host's own photo), when uploaded.
	PhotoUrl *string `json:"photo_url"`
	// Reason is set for rejected photos.
	Reason *string `json:"reason,omitempty"`
}

// ArrivalDecisionRequest: POST /v1/admin/arrival-photos/{photoId}/decision.
type ArrivalDecisionRequest struct {
	Decision string `json:"decision"` // approve | reject | remove
	Reason   string `json:"reason"`
}

func (r ArrivalDecisionRequest) validate() map[string]string {
	errs := map[string]string{}
	switch r.Decision {
	case "approve":
	case "reject", "remove":
		if n := len(strings.TrimSpace(r.Reason)); n < 3 || n > 500 {
			errs["reason"] = "required"
		}
	default:
		errs["decision"] = "invalid_value"
	}
	return errs
}

// ArrivalQueueItem is one photo in the staff review queue.
type ArrivalQueueItem struct {
	PhotoId     string     `json:"photo_id"`
	HostUserId  string     `json:"host_user_id"`
	HostName    string     `json:"host_name"`
	Status      string     `json:"status"`
	CapturedAt  *time.Time `json:"captured_at"`
	SessionOpen bool       `json:"session_open"`
	PhotoUrl    *string    `json:"photo_url"`
}

// ---------------------------------------------------------------- validation

// ErrInvalidImage is a content-validation failure.
var ErrInvalidImage = errors.New("invalid_image")

// ValidateAndReencodeJPEG checks that data is a real, fully decodable JPEG
// within the size and dimension limits, and returns it re-encoded (which
// drops all metadata such as EXIF GPS) with its dimensions.
func ValidateAndReencodeJPEG(data []byte) ([]byte, int, int, error) {
	if len(data) == 0 || len(data) > ArrivalMaxBytes {
		return nil, 0, 0, fmt.Errorf("%w: size", ErrInvalidImage)
	}
	if len(data) < 3 || data[0] != 0xFF || data[1] != 0xD8 || data[2] != 0xFF {
		return nil, 0, 0, fmt.Errorf("%w: not a jpeg", ErrInvalidImage)
	}
	cfg, err := jpeg.DecodeConfig(bytes.NewReader(data))
	if err != nil {
		return nil, 0, 0, fmt.Errorf("%w: header", ErrInvalidImage)
	}
	if cfg.Width < ArrivalMinDimension || cfg.Height < ArrivalMinDimension ||
		cfg.Width > ArrivalMaxDimension || cfg.Height > ArrivalMaxDimension {
		return nil, 0, 0, fmt.Errorf("%w: dimensions", ErrInvalidImage)
	}
	img, err := jpeg.Decode(bytes.NewReader(data))
	if err != nil {
		return nil, 0, 0, fmt.Errorf("%w: body", ErrInvalidImage)
	}
	var out bytes.Buffer
	if err := jpeg.Encode(&out, img, &jpeg.Options{Quality: ArrivalReencodeQuality}); err != nil {
		return nil, 0, 0, err
	}
	b := img.Bounds()
	return out.Bytes(), b.Dx(), b.Dy(), nil
}

// ---------------------------------------------------------------- service

func (s *Service) arrival() (ArrivalConfig, error) {
	a := s.deps.Arrival
	if !a.Enabled {
		return a, apperr.Unavailable("arrival_photos_disabled", "arrival photos are not available yet")
	}
	if a.Repo == nil {
		return a, apperr.Unavailable("database_unavailable", "database not configured")
	}
	if a.Store == nil || !a.Store.Configured() {
		return a, apperr.Unavailable("storage_not_configured", "photo storage is not configured on the server")
	}
	return a, nil
}

func mapArrivalErr(err error) error {
	switch {
	case errors.Is(err, ErrNotOnline):
		return apperr.BusinessRule("not_online", "go online first; the photo belongs to your current online session")
	case errors.Is(err, ErrArrivalNotFound):
		return apperr.NotFound("arrival_photo")
	case errors.Is(err, ErrArrivalState):
		return apperr.BusinessRule("arrival_photo_state", "this photo can no longer be changed")
	case errors.Is(err, ErrArrivalSelfReview):
		return apperr.Forbidden("self_review", "you cannot decide your own arrival photo")
	}
	return mapErr(err)
}

func (s *Service) arrivalNow() time.Time { return s.deps.Clock.Now().UTC() }

// CreateArrivalUpload: POST /v1/host/arrival-photo/upload-tickets. Approved,
// online hosts only; the photo is tied to the open session.
func (s *Service) CreateArrivalUpload(ctx context.Context, p auth.Principal, in ArrivalUploadRequest) (ArrivalUploadTicket, error) {
	if in.ContentType != "image/jpeg" {
		return ArrivalUploadTicket{}, validationError(map[string]string{"content_type": "must_be_image_jpeg"})
	}
	a, err := s.arrival()
	if err != nil {
		return ArrivalUploadTicket{}, err
	}
	if err := s.approvedHost(ctx, p); err != nil {
		return ArrivalUploadTicket{}, err
	}
	if p.Restricted() {
		return ArrivalUploadTicket{}, apperr.BusinessRule("account_restricted", "this account cannot host")
	}
	id, err := newUUID()
	if err != nil {
		return ArrivalUploadTicket{}, apperr.Internal(err)
	}
	path := fmt.Sprintf("%s/%s.jpg", p.UserID, id)
	exp := s.arrivalNow().Add(ArrivalUploadWindow)
	sessionID, url, err := a.Repo.CreateArrivalPhoto(ctx, p.UserID, id, path, exp, func(path string) (string, error) {
		return a.Store.SignUpload(ctx, path)
	})
	if err != nil {
		return ArrivalUploadTicket{}, mapArrivalErr(err)
	}
	return ArrivalUploadTicket{PhotoId: id, SessionId: sessionID, UploadUrl: url, ExpiresAt: exp, MaxBytes: ArrivalMaxBytes}, nil
}

// ConfirmArrivalPhoto: POST /v1/host/arrival-photo/{photoId}/confirm. The
// server validates the uploaded object, re-encodes it and moderates it.
func (s *Service) ConfirmArrivalPhoto(ctx context.Context, p auth.Principal, photoID string) (ArrivalPhotoView, error) {
	if !isUUID(photoID) {
		return ArrivalPhotoView{}, apperr.NotFound("arrival_photo")
	}
	a, err := s.arrival()
	if err != nil {
		return ArrivalPhotoView{}, err
	}
	ph, err := a.Repo.ArrivalPhoto(ctx, photoID)
	if err != nil || ph.HostID != p.UserID {
		return ArrivalPhotoView{}, apperr.NotFound("arrival_photo")
	}
	switch ph.Status {
	case ArrivalAwaitingUpload:
	case ArrivalExpired, ArrivalRemoved:
		return ArrivalPhotoView{}, apperr.BusinessRule("arrival_photo_expired", "this photo's online session or upload window has ended; take a new one")
	default:
		return s.arrivalView(ctx, a, ph), nil // idempotent repeat (pending, approved, rejected)
	}
	now := s.arrivalNow()
	if !ph.SessionOpen || now.After(ph.UploadExpiresAt) {
		return ArrivalPhotoView{}, apperr.BusinessRule("arrival_photo_expired", "this photo's online session or upload window has ended; take a new one")
	}
	raw, err := a.Store.Download(ctx, ph.StoragePath, ArrivalMaxBytes)
	switch {
	case errors.Is(err, ErrObjectTooLarge):
		return s.rejectInvalid(ctx, a, ph, now, "too_large")
	case errors.Is(err, ErrObjectNotFound):
		return ArrivalPhotoView{}, apperr.BusinessRule("upload_missing", "the photo has not been uploaded yet")
	case err != nil:
		return ArrivalPhotoView{}, apperr.Unavailable("storage_error", "the photo could not be read; try again")
	}
	clean, w, h, err := ValidateAndReencodeJPEG(raw)
	if errors.Is(err, ErrInvalidImage) {
		return s.rejectInvalid(ctx, a, ph, now, "invalid_image")
	}
	if err != nil {
		return ArrivalPhotoView{}, apperr.Internal(err)
	}
	if err := a.Store.Put(ctx, ph.StoragePath, "image/jpeg", clean); err != nil {
		return ArrivalPhotoView{}, apperr.Unavailable("storage_error", "the photo could not be stored; try again")
	}
	d := ArrivalDecision{ByteSize: len(clean), Width: w, Height: h, At: now, DecidedBy: "system:arrival"}
	switch {
	case a.Scanner != nil:
		score, err := a.Scanner.ExplicitScore(ctx, clean)
		threshold := a.FlagThreshold
		if threshold <= 0 {
			threshold = 0.6
		}
		switch {
		case err != nil:
			slog.WarnContext(ctx, "arrival photo scan failed; queued for review", "err", err)
			d.Status, d.ModerationSource = ArrivalPendingReview, "staff"
		case score >= threshold:
			d.Status, d.ModerationSource, d.Score, d.Reason = ArrivalRejected, "classifier", &score, "content_policy"
			purge := now.Add(s.rejectedRetention())
			d.PurgeAfter = &purge
		default:
			d.Status, d.ModerationSource, d.Score = ArrivalApproved, "classifier", &score
		}
	case a.AutoApproveUnscanned:
		d.Status, d.ModerationSource = ArrivalApproved, "auto_unscanned"
	default:
		d.Status, d.ModerationSource = ArrivalPendingReview, "staff"
	}
	got, err := a.Repo.DecideArrivalPhoto(ctx, photoID, func(cur ArrivalPhoto) (ArrivalDecision, error) {
		if cur.HostID != p.UserID {
			return ArrivalDecision{}, ErrArrivalNotFound
		}
		if cur.Status != ArrivalAwaitingUpload || !cur.SessionOpen {
			return ArrivalDecision{}, ErrArrivalState // went offline meanwhile
		}
		return d, nil
	})
	if err != nil {
		return ArrivalPhotoView{}, mapArrivalErr(err)
	}
	return s.arrivalView(ctx, a, got), nil
}

func (s *Service) rejectedRetention() time.Duration {
	if r := s.deps.Arrival.RejectedRetention; r > 0 {
		return r
	}
	return 7 * 24 * time.Hour
}

func (s *Service) retention() time.Duration {
	if r := s.deps.Arrival.Retention; r > 0 {
		return r
	}
	return 24 * time.Hour
}

func (s *Service) rejectInvalid(ctx context.Context, a ArrivalConfig, ph ArrivalPhoto, now time.Time, reason string) (ArrivalPhotoView, error) {
	purge := now // invalid uploads are deleted at the next purge run
	_, err := a.Repo.DecideArrivalPhoto(ctx, ph.ID, func(cur ArrivalPhoto) (ArrivalDecision, error) {
		if cur.Status != ArrivalAwaitingUpload {
			return ArrivalDecision{}, ErrArrivalState
		}
		return ArrivalDecision{Status: ArrivalRejected, Reason: reason, DecidedBy: "system:arrival", At: now, PurgeAfter: &purge}, nil
	})
	if err != nil && !errors.Is(err, ErrArrivalState) {
		return ArrivalPhotoView{}, mapArrivalErr(err)
	}
	return ArrivalPhotoView{}, validationError(map[string]string{"photo": reason})
}

func (s *Service) arrivalView(ctx context.Context, a ArrivalConfig, ph ArrivalPhoto) ArrivalPhotoView {
	v := ArrivalPhotoView{PhotoId: ph.ID, SessionId: ph.SessionID, Status: ph.Status, CapturedAt: ph.CapturedAt}
	if ph.Status == ArrivalRejected {
		v.Reason = ph.DecisionReason
	}
	if ph.Status == ArrivalApproved || ph.Status == ArrivalPendingReview {
		if u, ok := a.Store.SignRead(ctx, []string{ph.StoragePath}, ArrivalReadTTL)[ph.StoragePath]; ok {
			v.PhotoUrl = &u
		}
	}
	return v
}

// GetArrivalPhoto: GET /v1/host/arrival-photo — the current session's
// photo, or nil when there is none.
func (s *Service) GetArrivalPhoto(ctx context.Context, p auth.Principal) (*ArrivalPhotoView, error) {
	a, err := s.arrival()
	if err != nil {
		return nil, err
	}
	ph, err := a.Repo.CurrentArrivalPhoto(ctx, p.UserID)
	if err != nil {
		return nil, mapArrivalErr(err)
	}
	if ph == nil {
		return nil, nil
	}
	v := s.arrivalView(ctx, a, *ph)
	return &v, nil
}

// DeleteArrivalPhoto: DELETE /v1/host/arrival-photo — the host removes the
// current photo (no effect on availability). Idempotent.
func (s *Service) DeleteArrivalPhoto(ctx context.Context, p auth.Principal) error {
	a, err := s.arrival()
	if err != nil {
		return err
	}
	ph, err := a.Repo.CurrentArrivalPhoto(ctx, p.UserID)
	if err != nil || ph == nil {
		return mapArrivalErr(err)
	}
	now := s.arrivalNow()
	purge := now.Add(s.retention())
	_, err = a.Repo.DecideArrivalPhoto(ctx, ph.ID, func(cur ArrivalPhoto) (ArrivalDecision, error) {
		if cur.HostID != p.UserID {
			return ArrivalDecision{}, ErrArrivalNotFound
		}
		switch cur.Status {
		case ArrivalAwaitingUpload, ArrivalPendingReview, ArrivalApproved:
		default:
			return ArrivalDecision{}, ErrArrivalState
		}
		return ArrivalDecision{Status: ArrivalRemoved, Reason: "removed_by_host", DecidedBy: p.UserID, At: now, PurgeAfter: &purge}, nil
	})
	if errors.Is(err, ErrArrivalState) {
		return nil
	}
	return mapArrivalErr(err)
}

// ArrivalReviewQueue: GET /v1/admin/arrival-photos (moderator/admin).
// Viewing is audited because it signs private images.
func (s *Service) ArrivalReviewQueue(ctx context.Context, p auth.Principal, limit int) ([]ArrivalQueueItem, error) {
	a, err := s.arrival()
	if err != nil {
		return nil, err
	}
	rows, err := a.Repo.ArrivalReviewQueue(ctx, limit)
	if err != nil {
		return nil, mapArrivalErr(err)
	}
	paths := make([]string, 0, len(rows))
	for _, r := range rows {
		paths = append(paths, r.StoragePath)
	}
	urls := a.Store.SignRead(ctx, paths, ArrivalReadTTL)
	out := make([]ArrivalQueueItem, 0, len(rows))
	for _, r := range rows {
		it := ArrivalQueueItem{PhotoId: r.ID, HostUserId: r.HostID, HostName: r.HostName, Status: r.Status,
			CapturedAt: r.CapturedAt, SessionOpen: r.SessionOpen}
		if u, ok := urls[r.StoragePath]; ok {
			it.PhotoUrl = &u
		}
		out = append(out, it)
	}
	if len(rows) > 0 {
		_ = a.Repo.Audit(ctx, p.UserID, "arrival_photo.queue_viewed", "", map[string]any{"count": len(rows)})
	}
	return out, nil
}

// DecideArrivalPhotoStaff: POST /v1/admin/arrival-photos/{photoId}/decision.
// approve (pending only), reject (pending/approved) or remove (any current).
func (s *Service) DecideArrivalPhotoStaff(ctx context.Context, p auth.Principal, photoID string, in ArrivalDecisionRequest) (ArrivalQueueItem, error) {
	if errs := in.validate(); len(errs) > 0 {
		return ArrivalQueueItem{}, validationError(errs)
	}
	if !isUUID(photoID) {
		return ArrivalQueueItem{}, apperr.NotFound("arrival_photo")
	}
	a, err := s.arrival()
	if err != nil {
		return ArrivalQueueItem{}, err
	}
	now := s.arrivalNow()
	got, err := a.Repo.DecideArrivalPhoto(ctx, photoID, func(cur ArrivalPhoto) (ArrivalDecision, error) {
		d := ArrivalDecision{Reason: strings.TrimSpace(in.Reason), DecidedBy: p.UserID, At: now, ModerationSource: "staff"}
		// Same rule as every other staff decision: never your own content
		// (a moderator who is also a host could approve their own photo).
		if cur.HostID == p.UserID {
			return d, ErrArrivalSelfReview
		}
		switch in.Decision {
		case "approve":
			if cur.Status != ArrivalPendingReview {
				return d, ErrArrivalState
			}
			d.Status = ArrivalApproved
		case "reject":
			if cur.Status != ArrivalPendingReview && cur.Status != ArrivalApproved {
				return d, ErrArrivalState
			}
			purge := now.Add(s.rejectedRetention())
			d.Status, d.PurgeAfter = ArrivalRejected, &purge
		case "remove":
			if cur.Status == ArrivalRemoved || cur.Status == ArrivalRejected {
				return d, ErrArrivalState
			}
			purge := now.Add(s.retention())
			d.Status, d.PurgeAfter = ArrivalRemoved, &purge
		}
		return d, nil
	})
	if err != nil {
		return ArrivalQueueItem{}, mapArrivalErr(err)
	}
	return ArrivalQueueItem{PhotoId: got.ID, HostUserId: got.HostID, HostName: got.HostName, Status: got.Status,
		CapturedAt: got.CapturedAt, SessionOpen: got.SessionOpen}, nil
}

// PurgeArrivalPhotos is the purge-arrival-photos job: abandoned tickets
// expire, then objects of ended photos past their retention are deleted.
func (s *Service) PurgeArrivalPhotos(ctx context.Context, now time.Time) (expired int64, purged int, err error) {
	a := s.deps.Arrival
	if a.Repo == nil || a.Store == nil || !a.Store.Configured() {
		return 0, 0, nil
	}
	if expired, err = a.Repo.ExpireAbandonedArrivalUploads(ctx, now); err != nil {
		return 0, 0, err
	}
	rows, err := a.Repo.ArrivalPhotosDueForPurge(ctx, now, 200)
	if err != nil {
		return expired, 0, err
	}
	for _, r := range rows {
		if err := a.Store.Delete(ctx, r.StoragePath); err != nil {
			slog.WarnContext(ctx, "arrival photo purge failed", "photo_id", r.ID, "err", err)
			continue
		}
		if err := a.Repo.MarkArrivalPurged(ctx, r.ID, now); err != nil {
			return expired, purged, err
		}
		purged++
	}
	return expired, purged, nil
}
