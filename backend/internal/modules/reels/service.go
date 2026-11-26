package reels

import (
	"context"
	"errors"
	"log/slog"
	"strings"
	"time"

	"dashuri/backend/internal/modules/keyset"
	"dashuri/backend/internal/modules/reelsrank"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/clock"
)

// Service implements the Reels API.
type Service struct {
	deps Deps
}

func NewService(d Deps) *Service {
	if d.Clock == nil {
		d.Clock = clock.System{}
	}
	if d.Thresholds == (Thresholds{}) {
		d.Thresholds = DefaultThresholds
	}
	if d.FrameInterval <= 0 {
		d.FrameInterval = 2 * time.Second
	}
	return &Service{deps: d}
}

// Enabled reports the REELS_ENABLED flag.
func (s *Service) Enabled() bool { return s.deps.Enabled }

func (s *Service) repo() (Repository, error) {
	if !s.deps.Enabled {
		return nil, apperr.Unavailable("reels_disabled", "Reels is switched off on this server")
	}
	if s.deps.Repo == nil {
		return nil, apperr.Unavailable("database_unavailable", "database not configured")
	}
	return s.deps.Repo, nil
}

func (s *Service) providerReady() bool { return s.deps.Provider != nil && s.deps.Provider.Configured() }

// providerFor returns the configured provider that stores reels of the
// given provider name (the upload provider or a legacy one), or nil.
func (s *Service) providerFor(name string) VideoProvider {
	for _, p := range append([]VideoProvider{s.deps.Provider}, s.deps.Legacy...) {
		if p != nil && p.Name() == name && p.Configured() {
			return p
		}
	}
	return nil
}

// providerNamed is providerFor without the Configured check (webhooks
// answer 503 rather than 404 for a known but unconfigured provider).
func (s *Service) providerNamed(name string) VideoProvider {
	for _, p := range append([]VideoProvider{s.deps.Provider}, s.deps.Legacy...) {
		if p != nil && p.Name() == name {
			return p
		}
	}
	return nil
}

// gate: every Reels endpoint is 18+ (same rule as discovery and calls).
func gate(p auth.Principal) error {
	if !p.AgeEligible {
		return apperr.BusinessRule("not_age_eligible", "complete the 18+ check to use Reels")
	}
	return nil
}

// gateHost: only approved hosts may create reels (customers only watch).
func gateHost(p auth.Principal) error {
	if err := gateWrite(p); err != nil {
		return err
	}
	if !p.Has(auth.RoleHost) {
		return apperr.Forbidden("host_only", "only approved hosts can post reels")
	}
	return nil
}

// gateWrite: creating content additionally needs an unrestricted account.
func gateWrite(p auth.Principal) error {
	if err := gate(p); err != nil {
		return err
	}
	if p.Restricted() {
		return apperr.BusinessRule("account_restricted", "your account cannot post or interact right now")
	}
	return nil
}

// Config: GET /v1/reels/config — lets the app hide upload when the provider
// is not configured instead of failing after the user records a video.
func (s *Service) Config() ReelsConfig {
	cfg := ReelsConfig{
		Enabled: s.deps.Enabled, UploadsAvailable: s.deps.Enabled && s.deps.Repo != nil && s.providerReady(),
		MinDurationMs: MinDurationMs, MaxDurationMs: MaxDurationMs, MaxCaption: MaxCaptionRunes,
		DailyUploadLimit: DailyUploadLimit, MaxUploadBytes: MaxUploadBytes, UploadContentTypes: UploadContentTypes,
	}
	if s.deps.Provider != nil {
		cfg.VideoProvider = s.deps.Provider.Name()
	}
	return cfg
}

// ---------------------------------------------------------------- mapping

func (s *Service) photoURLs(ctx context.Context, rows []CreatorRow) map[string]string {
	if s.deps.Photos == nil {
		return map[string]string{}
	}
	var paths []string
	seen := map[string]bool{}
	for _, r := range rows {
		if r.PhotoPath != nil && !seen[*r.PhotoPath] {
			seen[*r.PhotoPath] = true
			paths = append(paths, *r.PhotoPath)
		}
	}
	return s.deps.Photos.SignRead(ctx, paths, PhotoTTL)
}

func summary(c CreatorRow, photos map[string]string) CreatorSummary {
	out := CreatorSummary{UserId: c.UserID, DisplayName: c.DisplayName, FollowedByMe: c.FollowedByMe}
	if c.PhotoPath != nil {
		if u, ok := photos[*c.PhotoPath]; ok {
			out.PhotoUrl = &u
		}
	}
	if c.IsHost {
		out.Host = &HostInfo{Availability: c.Availability, RatePerMinute: c.RatePerMin, IsVerified: c.KYCVerified}
	}
	return out
}

// toReels maps rows and signs playback only where the viewer may watch:
// published videos, the viewer's own videos, or a moderator review.
func (s *Service) toReels(ctx context.Context, viewerID string, rows []VideoRow, review bool) []Reel {
	creators := make([]CreatorRow, len(rows))
	for i, r := range rows {
		creators[i] = r.Creator
	}
	photos := s.photoURLs(ctx, creators)
	out := make([]Reel, 0, len(rows))
	for _, r := range rows {
		mine := r.CreatorID == viewerID
		reel := Reel{
			Id: r.ID, Creator: summary(r.Creator, photos), Caption: r.Caption, Language: r.Language,
			DurationMs: r.DurationMs, Status: r.Status, LikeCount: r.LikeCount, ViewCount: r.ViewCount,
			ShareCount: r.ShareCount, LikedByMe: r.LikedByMe, IsMine: mine, PublishedAt: r.PublishedAt, CreatedAt: r.CreatedAt,
		}
		if mine || review {
			reel.RejectionCode = r.RejectionCode
		}
		canWatch := r.Status == "published" || (mine && r.Status != "deleted") || review
		if prov := s.providerFor(r.Provider); canWatch && r.PlaybackID != nil && prov != nil {
			ttl := PlaybackTTL
			if review {
				ttl = ReviewPlaybackTTL
			}
			if pb, err := prov.Playback(*r.PlaybackID, ttl); err == nil {
				reel.Playback = &PlaybackInfo{Url: pb.URL, Format: pb.Format, ThumbnailUrl: pb.ThumbnailURL, ExpiresAt: pb.ExpiresAt}
				if pb.Format == FormatHLS {
					reel.Playback.HlsUrl = pb.URL // pre-R2 app builds read hls_url
				}
			} else {
				slog.WarnContext(ctx, "reels playback signing failed", "err", err)
			}
		}
		out = append(out, reel)
	}
	return out
}

func notFound() error { return apperr.NotFound("reel") }

// ---------------------------------------------------------------- creators

// GetCreator: GET /v1/creators/{userId}. 404 when blocked either way.
func (s *Service) GetCreator(ctx context.Context, p auth.Principal, creatorID string) (CreatorProfile, error) {
	if err := gate(p); err != nil {
		return CreatorProfile{}, err
	}
	if creatorID == "me" {
		creatorID = p.UserID
	}
	if !isUUID(creatorID) {
		return CreatorProfile{}, apperr.NotFound("creator")
	}
	repo, err := s.repo()
	if err != nil {
		return CreatorProfile{}, err
	}
	c, err := repo.Creator(ctx, p.UserID, creatorID)
	if errors.Is(err, ErrNotFound) {
		return CreatorProfile{}, apperr.NotFound("creator")
	}
	if err != nil {
		return CreatorProfile{}, internal(err)
	}
	counts, err := repo.CreatorCounts(ctx, creatorID)
	if err != nil {
		return CreatorProfile{}, internal(err)
	}
	return CreatorProfile{
		CreatorSummary: summary(c, s.photoURLs(ctx, []CreatorRow{c})), Bio: c.Bio,
		FollowerCount: counts.Followers, FollowingCount: counts.Following, ReelCount: counts.Reels,
		IsSelf: creatorID == p.UserID,
	}, nil
}

// UpdateMyCreator: PATCH /v1/me/creator {bio}.
func (s *Service) UpdateMyCreator(ctx context.Context, p auth.Principal, in UpdateCreatorRequest) (CreatorProfile, error) {
	if err := gateHost(p); err != nil {
		return CreatorProfile{}, err
	}
	if in.Bio != nil {
		b := strings.TrimSpace(*in.Bio)
		if len([]rune(b)) > MaxBioRunes {
			return CreatorProfile{}, validationError(map[string]string{"bio": "too_long"})
		}
		in.Bio = &b
		if b == "" {
			in.Bio = nil
		}
	}
	repo, err := s.repo()
	if err != nil {
		return CreatorProfile{}, err
	}
	if err := repo.UpsertCreatorBio(ctx, p.UserID, in.Bio); err != nil {
		return CreatorProfile{}, internal(err)
	}
	return s.GetCreator(ctx, p, p.UserID)
}

// CreatorReels: GET /v1/creators/{userId}/reels — published only, except the
// creator's own list (all non-deleted statuses).
func (s *Service) CreatorReels(ctx context.Context, p auth.Principal, creatorID, cursor string, limit int) (Page[Reel], error) {
	if err := gate(p); err != nil {
		return Page[Reel]{}, err
	}
	if creatorID == "me" {
		creatorID = p.UserID
	}
	if !isUUID(creatorID) {
		return Page[Reel]{}, apperr.NotFound("creator")
	}
	after, err := decodeKeyset(cursor)
	if err != nil {
		return Page[Reel]{}, err
	}
	repo, err := s.repo()
	if err != nil {
		return Page[Reel]{}, err
	}
	if creatorID != p.UserID {
		if blocked, err := repo.Blocked(ctx, p.UserID, creatorID); err != nil {
			return Page[Reel]{}, internal(err)
		} else if blocked {
			return Page[Reel]{}, apperr.NotFound("creator")
		}
	}
	limit = clampLimit(limit)
	rows, err := repo.CreatorVideos(ctx, p.UserID, creatorID, creatorID == p.UserID, after, limit+1)
	if err != nil {
		return Page[Reel]{}, internal(err)
	}
	return s.keysetPage(ctx, p.UserID, rows, limit, func(r VideoRow) time.Time { return r.CreatedAt }), nil
}

func clampLimit(limit int) int {
	if limit <= 0 || limit > FeedPageMax {
		return 10
	}
	return limit
}

func decodeKeyset(cursor string) (*Keyset, error) {
	c, err := keyset.Decode(cursor)
	if err != nil {
		return nil, validationError(map[string]string{"cursor": "invalid"})
	}
	if c == nil {
		return nil, nil
	}
	return &Keyset{At: c.At, ID: c.ID}, nil
}

func (s *Service) keysetPage(ctx context.Context, viewer string, rows []VideoRow, limit int, at func(VideoRow) time.Time) Page[Reel] {
	out := Page[Reel]{}
	if len(rows) > limit {
		rows = rows[:limit]
		last := rows[len(rows)-1]
		next := keyset.Cursor{At: at(last), ID: last.ID}.Encode()
		out.NextCursor = &next
	}
	out.Items = s.toReels(ctx, viewer, rows, false)
	return out
}

// ---------------------------------------------------------------- uploads

// CreateUpload: POST /v1/reels/uploads (Idempotency-Key). Creates the video
// row (awaiting_upload, never visible) and a one-time provider upload URL.
func (s *Service) CreateUpload(ctx context.Context, p auth.Principal, in CreateUploadRequest) (UploadTicket, error) {
	if err := gateHost(p); err != nil {
		return UploadTicket{}, err
	}
	if errs := in.validate(); len(errs) > 0 {
		return UploadTicket{}, validationError(errs)
	}
	repo, err := s.repo()
	if err != nil {
		return UploadTicket{}, err
	}
	if !s.providerReady() {
		return UploadTicket{}, apperr.Unavailable("video_provider_not_configured", "video hosting is not configured on this server")
	}
	id := newUUID()
	req := UploadRequest{Passthrough: id}
	if in.SizeBytes != nil {
		req.SizeBytes = *in.SizeBytes
	}
	if in.ContentType != nil {
		req.ContentType = *in.ContentType
	}
	sess, err := s.deps.Provider.CreateUpload(ctx, req)
	var me *MediaError
	if errors.As(err, &me) { // the provider needs a declared size/type
		return UploadTicket{}, validationError(map[string]string{me.Code: "required"})
	}
	if err != nil {
		return UploadTicket{}, apperr.Unavailable("video_provider_unavailable", "the video provider did not accept the upload; try again")
	}
	caption := ""
	if in.Caption != nil {
		caption = strings.TrimSpace(*in.Caption)
	}
	now := s.deps.Clock.Now().UTC()
	err = repo.CreateVideo(ctx, NewVideo{
		ID: id, CreatorID: p.UserID, Caption: caption, Language: in.Language, DeclaredMs: *in.DeclaredDurationMs,
		Provider: s.deps.Provider.Name(), UploadID: sess.UploadID, DailyLimit: DailyUploadLimit,
		DayStartUTC: time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC),
	})
	if errors.Is(err, ErrUploadLimit) {
		return UploadTicket{}, apperr.BusinessRule("reel_upload_limit", "you can post up to 10 reels a day")
	}
	if err != nil {
		return UploadTicket{}, internal(err)
	}
	row, err := repo.Video(ctx, p.UserID, id)
	if err != nil {
		return UploadTicket{}, internal(err)
	}
	headers := sess.Headers
	if headers == nil {
		headers = map[string]string{}
	}
	return UploadTicket{Reel: s.toReels(ctx, p.UserID, []VideoRow{row}, false)[0], UploadUrl: sess.URL, UploadHeaders: headers, ExpiresAt: sess.ExpiresAt}, nil
}

// CompleteUpload: POST /v1/reels/{id}/upload-complete — the creator says the
// PUT finished. The server checks the storage itself (never trusts the
// call) and moves awaiting_upload → processing so reels-process-media
// picks it up on its next run. Idempotent; a missing file is 409 and the
// reel stays awaiting_upload (the app may retry the PUT). Mux reels don't
// need it (webhooks) but it is harmless for them.
func (s *Service) CompleteUpload(ctx context.Context, p auth.Principal, id string) (Reel, error) {
	if err := gateHost(p); err != nil {
		return Reel{}, err
	}
	if !isUUID(id) {
		return Reel{}, notFound()
	}
	repo, err := s.repo()
	if err != nil {
		return Reel{}, err
	}
	row, err := repo.Video(ctx, p.UserID, id)
	if errors.Is(err, ErrNotFound) || (err == nil && (row.CreatorID != p.UserID || row.Status == "deleted")) {
		return Reel{}, notFound()
	}
	if err != nil {
		return Reel{}, internal(err)
	}
	if row.Status == "awaiting_upload" && row.ProviderUploadID != nil {
		prov := s.providerFor(row.Provider)
		if prov == nil {
			return Reel{}, apperr.Unavailable("video_provider_not_configured", "video hosting is not configured on this server")
		}
		st, err := prov.UploadStatus(ctx, *row.ProviderUploadID)
		if err != nil {
			return Reel{}, apperr.Unavailable("video_provider_unavailable", "could not check the upload; try again")
		}
		if st.State != "asset_created" {
			return Reel{}, apperr.Conflict("upload_not_received", "the video file has not arrived yet")
		}
		if err := repo.MarkProcessing(ctx, id, st.AssetID); err != nil {
			return Reel{}, internal(err)
		}
		if row, err = repo.Video(ctx, p.UserID, id); err != nil {
			return Reel{}, internal(err)
		}
	}
	return s.toReels(ctx, p.UserID, []VideoRow{row}, false)[0], nil
}

// GetReel: GET /v1/reels/{id}. Others see published videos only; the
// creator sees every status (processing, in review, rejected …).
func (s *Service) GetReel(ctx context.Context, p auth.Principal, id string) (Reel, error) {
	if err := gate(p); err != nil {
		return Reel{}, err
	}
	if !isUUID(id) {
		return Reel{}, notFound()
	}
	repo, err := s.repo()
	if err != nil {
		return Reel{}, err
	}
	row, err := repo.Video(ctx, p.UserID, id)
	if errors.Is(err, ErrNotFound) {
		return Reel{}, notFound()
	}
	if err != nil {
		return Reel{}, internal(err)
	}
	if row.CreatorID != p.UserID {
		if row.Status != "published" {
			return Reel{}, notFound()
		}
		if blocked, err := repo.Blocked(ctx, p.UserID, row.CreatorID); err != nil {
			return Reel{}, internal(err)
		} else if blocked {
			return Reel{}, notFound()
		}
	} else if row.Status == "deleted" {
		return Reel{}, notFound()
	}
	return s.toReels(ctx, p.UserID, []VideoRow{row}, false)[0], nil
}

// DeleteReel: DELETE /v1/reels/{id} — creator only. Media is purged by the
// reels-purge-media job (after any evidence hold).
func (s *Service) DeleteReel(ctx context.Context, p auth.Principal, id string) error {
	if err := gate(p); err != nil {
		return err
	}
	if !isUUID(id) {
		return notFound()
	}
	repo, err := s.repo()
	if err != nil {
		return err
	}
	switch err := repo.DeleteVideo(ctx, p.UserID, id, s.deps.Clock.Now().Add(EvidenceHold)); {
	case errors.Is(err, ErrNotFound), errors.Is(err, ErrNotOwner):
		return notFound()
	case err != nil:
		return internal(err)
	}
	return nil
}

// ---------------------------------------------------------------- feed

// Feed: GET /v1/reels/feed?tab=for_you|following.
func (s *Service) Feed(ctx context.Context, p auth.Principal, tab, cursor string, limit int) (Page[Reel], error) {
	if err := gate(p); err != nil {
		return Page[Reel]{}, err
	}
	repo, err := s.repo()
	if err != nil {
		return Page[Reel]{}, err
	}
	limit = clampLimit(limit)
	switch tab {
	case "", "for_you":
		return s.forYou(ctx, repo, p, cursor, limit)
	case "following":
		after, err := decodeKeyset(cursor)
		if err != nil {
			return Page[Reel]{}, err
		}
		rows, err := repo.FollowingFeed(ctx, p.UserID, after, limit+1)
		if err != nil {
			return Page[Reel]{}, internal(err)
		}
		return s.keysetPage(ctx, p.UserID, rows, limit, func(r VideoRow) time.Time { return *r.PublishedAt }), nil
	default:
		return Page[Reel]{}, validationError(map[string]string{"tab": "invalid"})
	}
}

func (s *Service) forYou(ctx context.Context, repo Repository, p auth.Principal, cursor string, limit int) (Page[Reel], error) {
	cur, err := reelsrank.DecodeCursor(cursor)
	if err != nil {
		return Page[Reel]{}, validationError(map[string]string{"cursor": "invalid"})
	}
	asOf := s.deps.Clock.Now().UTC()
	if cur != nil {
		asOf = cur.AsOf
	}
	cands, err := repo.FeedCandidates(ctx, p.UserID, asOf, FeedCandidateLimit)
	if err != nil {
		return Page[Reel]{}, internal(err)
	}
	langs, err := repo.ViewerLanguages(ctx, p.UserID)
	if err != nil {
		return Page[Reel]{}, internal(err)
	}
	ranked := reelsrank.Rank(cands, reelsrank.Viewer{Languages: langs}, asOf, reelsrank.DefaultWeights)
	page := reelsrank.After(ranked, cur, limit+1)
	out := Page[Reel]{Items: []Reel{}}
	if len(page) > limit {
		page = page[:limit]
		last := page[len(page)-1]
		next := reelsrank.Cursor{AsOf: asOf, LastScore: last.Score, LastID: last.VideoID}.Encode()
		out.NextCursor = &next
	}
	page = reelsrank.Diversify(page)
	ids := make([]string, len(page))
	for i, r := range page {
		ids[i] = r.VideoID
	}
	rows, err := repo.VideosByIDs(ctx, p.UserID, ids)
	if err != nil {
		return Page[Reel]{}, internal(err)
	}
	byID := map[string]VideoRow{}
	for _, r := range rows {
		byID[r.ID] = r
	}
	ordered := make([]VideoRow, 0, len(ids))
	for _, id := range ids {
		if r, ok := byID[id]; ok && r.Status == "published" { // taken down since ranking → skipped
			ordered = append(ordered, r)
		}
	}
	out.Items = s.toReels(ctx, p.UserID, ordered, false)
	return out, nil
}

// ---------------------------------------------------------------- engagement

func (s *Service) publishedVisible(ctx context.Context, repo Repository, p auth.Principal, id string) (VideoRow, error) {
	if !isUUID(id) {
		return VideoRow{}, notFound()
	}
	row, err := repo.Video(ctx, p.UserID, id)
	if errors.Is(err, ErrNotFound) {
		return VideoRow{}, notFound()
	}
	if err != nil {
		return VideoRow{}, internal(err)
	}
	if row.Status != "published" {
		return VideoRow{}, notFound()
	}
	if row.CreatorID != p.UserID {
		if blocked, err := repo.Blocked(ctx, p.UserID, row.CreatorID); err != nil {
			return VideoRow{}, internal(err)
		} else if blocked {
			return VideoRow{}, notFound()
		}
	}
	return row, nil
}

// SetLike: PUT/DELETE /v1/reels/{id}/like — idempotent both ways.
func (s *Service) SetLike(ctx context.Context, p auth.Principal, id string, like bool) (LikeState, error) {
	if err := gateWrite(p); err != nil {
		return LikeState{}, err
	}
	repo, err := s.repo()
	if err != nil {
		return LikeState{}, err
	}
	if _, err := s.publishedVisible(ctx, repo, p, id); err != nil {
		if like {
			return LikeState{}, err
		}
	}
	var n int
	if like {
		n, err = repo.Like(ctx, p.UserID, id)
	} else {
		n, err = repo.Unlike(ctx, p.UserID, id)
	}
	if errors.Is(err, ErrNotFound) {
		return LikeState{}, notFound()
	}
	if err != nil {
		return LikeState{}, internal(err)
	}
	if like {
		s.recordServerEvent(ctx, repo, p.UserID, "reel_liked", &id, nil)
	}
	return LikeState{Liked: like, LikeCount: n}, nil
}

// SetFollow: PUT/DELETE /v1/creators/{userId}/follow — idempotent.
func (s *Service) SetFollow(ctx context.Context, p auth.Principal, creatorID string, follow bool) (FollowState, error) {
	if err := gateWrite(p); err != nil {
		return FollowState{}, err
	}
	if !isUUID(creatorID) {
		return FollowState{}, apperr.NotFound("creator")
	}
	if creatorID == p.UserID {
		return FollowState{}, apperr.BusinessRule("self_follow", "you cannot follow yourself")
	}
	repo, err := s.repo()
	if err != nil {
		return FollowState{}, err
	}
	if follow {
		if _, err := repo.Creator(ctx, p.UserID, creatorID); errors.Is(err, ErrNotFound) {
			return FollowState{}, apperr.NotFound("creator")
		} else if err != nil {
			return FollowState{}, internal(err)
		}
		if err := repo.Follow(ctx, p.UserID, creatorID); err != nil {
			return FollowState{}, internal(err)
		}
		s.recordServerEvent(ctx, repo, p.UserID, "creator_followed", nil, &creatorID)
		return FollowState{Following: true}, nil
	}
	if err := repo.Unfollow(ctx, p.UserID, creatorID); err != nil {
		return FollowState{}, internal(err)
	}
	return FollowState{Following: false}, nil
}

// Share: POST /v1/reels/{id}/share — counts the share and returns the link
// text the app copies or hands to the system share sheet.
func (s *Service) Share(ctx context.Context, p auth.Principal, id string) (ShareLink, error) {
	if err := gate(p); err != nil {
		return ShareLink{}, err
	}
	repo, err := s.repo()
	if err != nil {
		return ShareLink{}, err
	}
	row, err := s.publishedVisible(ctx, repo, p, id)
	if err != nil {
		return ShareLink{}, err
	}
	if err := repo.CountShare(ctx, id); err != nil {
		return ShareLink{}, internal(err)
	}
	s.recordServerEvent(ctx, repo, p.UserID, "reel_shared", &id, nil)
	url := "https://dashuri.app/r/" + id
	return ShareLink{Url: url, Text: "Watch " + row.Creator.DisplayName + " on Dashuri: " + url}, nil
}

// RecordEvents: POST /v1/reels/events — client analytics. Views always
// update counters (they drive the feed); stored events need analytics
// consent (DPDP), otherwise they are dropped after counting.
func (s *Service) RecordEvents(ctx context.Context, p auth.Principal, in EventsRequest) error {
	if err := gate(p); err != nil {
		return err
	}
	if len(in.Events) == 0 || len(in.Events) > MaxEventsPerBatch {
		return validationError(map[string]string{"events": "between_1_and_50"})
	}
	evs := make([]Event, 0, len(in.Events))
	for i, e := range in.Events {
		key := "events[" + itoa(i) + "]"
		if !ClientEvents[e.Event] {
			return validationError(map[string]string{key + ".event": "invalid"})
		}
		if e.ReelId != nil && !isUUID(*e.ReelId) {
			return validationError(map[string]string{key + ".reel_id": "invalid"})
		}
		if e.CreatorId != nil && !isUUID(*e.CreatorId) {
			return validationError(map[string]string{key + ".creator_id": "invalid"})
		}
		if e.ValueMs != nil && (*e.ValueMs < 0 || *e.ValueMs > 600000) {
			return validationError(map[string]string{key + ".value_ms": "out_of_range"})
		}
		if e.SessionId != nil && len(*e.SessionId) > 64 {
			return validationError(map[string]string{key + ".session_id": "too_long"})
		}
		if e.ReelId == nil && e.Event != "creator_profile_opened" && e.Event != "host_call_cta_clicked" {
			return validationError(map[string]string{key + ".reel_id": "required"})
		}
		if e.ReelId == nil && e.CreatorId == nil {
			return validationError(map[string]string{key + ".creator_id": "required"})
		}
		evs = append(evs, Event{Name: e.Event, VideoID: e.ReelId, CreatorID: e.CreatorId, ValueMs: e.ValueMs, SessionID: e.SessionId})
	}
	repo, err := s.repo()
	if err != nil {
		return err
	}
	day := s.deps.Clock.Now().UTC()
	for _, e := range evs {
		if e.VideoID == nil {
			continue
		}
		switch e.Name {
		case "reel_play_started", "reel_play_completed", "reel_watch_duration":
			watched := 0
			if e.ValueMs != nil {
				watched = *e.ValueMs
			}
			if err := repo.RecordView(ctx, p.UserID, *e.VideoID, day, watched, e.Name == "reel_play_completed"); err != nil && !errors.Is(err, ErrNotFound) {
				return internal(err)
			}
		}
	}
	ok, err := repo.AnalyticsConsent(ctx, p.UserID)
	if err != nil {
		return internal(err)
	}
	if !ok {
		return nil
	}
	if err := repo.InsertEvents(ctx, p.UserID, evs); err != nil {
		return internal(err)
	}
	return nil
}

// recordServerEvent stores a server-observed event (consent-gated); failures
// never fail the user action.
func (s *Service) recordServerEvent(ctx context.Context, repo Repository, userID, name string, videoID, creatorID *string) {
	ok, err := repo.AnalyticsConsent(ctx, userID)
	if err != nil || !ok {
		return
	}
	if err := repo.InsertEvents(ctx, userID, []Event{{Name: name, VideoID: videoID, CreatorID: creatorID}}); err != nil {
		slog.WarnContext(ctx, "reels event insert failed", "event", name, "err", err)
	}
}

func itoa(i int) string {
	if i == 0 {
		return "0"
	}
	var b []byte
	for i > 0 {
		b = append([]byte{byte('0' + i%10)}, b...)
		i /= 10
	}
	return string(b)
}
