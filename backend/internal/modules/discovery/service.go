package discovery

import (
	"context"
	"errors"
	"time"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/clock"
)

// PhotoTTL is the lifetime of signed card photo URLs.
const PhotoTTL = time.Hour

// Service implements discovery (D-06 sort, D-08 offline only).
type Service struct {
	deps Deps
}

func NewService(d Deps) *Service {
	if d.Clock == nil {
		d.Clock = clock.System{}
	}
	return &Service{deps: d}
}

func (s *Service) repo() (Repository, error) {
	if s.deps.Repo == nil {
		return nil, apperr.Unavailable("database_unavailable", "database not configured")
	}
	return s.deps.Repo, nil
}

// ListAvailableHosts: GET /v1/discovery/hosts — hosts online or busy,
// filtered by language and city, keyset paginated.
func (s *Service) ListAvailableHosts(ctx context.Context, p auth.Principal, in ListRequest) (Page[HostCard], error) {
	if errs := in.validate(); len(errs) > 0 {
		return Page[HostCard]{}, validationError(errs)
	}
	after, err := DecodeCursor(in.Cursor, in.Sort)
	if err != nil {
		return Page[HostCard]{}, validationError(map[string]string{"cursor": "invalid"})
	}
	repo, err := s.repo()
	if err != nil {
		return Page[HostCard]{}, err
	}
	rows, err := repo.ListHosts(ctx, ListQuery{
		ViewerID: p.UserID, Language: in.Language, CityID: in.CityID, Sort: in.Sort, After: after, Limit: in.Limit + 1,
		Verification: in.Verification, VerifiedBoost: s.deps.VerifiedBoostXP,
	})
	if err != nil {
		return Page[HostCard]{}, apperr.Internal(err)
	}
	page := Page[HostCard]{Items: []HostCard{}}
	if len(rows) > in.Limit {
		rows = rows[:in.Limit]
		last := rows[len(rows)-1]
		k1, k2 := RankKeys(in.Sort, last, s.deps.VerifiedBoostXP)
		next := Cursor{Sort: in.Sort, K1: k1, K2: k2, ID: last.UserID}.Encode()
		page.NextCursor = &next
	}
	photos := s.sign(ctx, rows)
	arrivals := s.signArrival(ctx, rows)
	for _, h := range rows {
		c := s.card(h, photos)
		c.ArrivalPhoto = arrivalOf(h, arrivals)
		page.Items = append(page.Items, c)
	}
	return page, nil
}

// ArrivalPhotoTTL is the lifetime of signed arrival-photo URLs (short: the
// photo is only current while the host stays online).
const ArrivalPhotoTTL = 15 * time.Minute

func (s *Service) signArrival(ctx context.Context, rows []HostRow) map[string]string {
	if s.deps.ArrivalPhotos == nil {
		return nil
	}
	var paths []string
	for _, h := range rows {
		if h.ArrivalPhotoPath != nil && Availability(h) != "offline" {
			paths = append(paths, *h.ArrivalPhotoPath)
		}
	}
	if len(paths) == 0 {
		return nil
	}
	return s.deps.ArrivalPhotos.SignRead(ctx, paths, ArrivalPhotoTTL)
}

// arrivalOf is the card's arrival photo: only for an online or busy host
// whose current session photo could be signed.
func arrivalOf(h HostRow, urls map[string]string) *ArrivalPhoto {
	if h.ArrivalPhotoPath == nil || h.ArrivalCapturedAt == nil || Availability(h) == "offline" {
		return nil
	}
	u, ok := urls[*h.ArrivalPhotoPath]
	if !ok {
		return nil
	}
	id := ""
	if h.ArrivalPhotoID != nil {
		id = *h.ArrivalPhotoID
	}
	return &ArrivalPhoto{PhotoId: id, Url: u, CapturedAt: h.ArrivalCapturedAt.UTC()}
}

// GetHost: GET /v1/discovery/hosts/{userId} — host detail, also offline.
func (s *Service) GetHost(ctx context.Context, p auth.Principal, userID string) (HostDetail, error) {
	if !isUUID(userID) {
		return HostDetail{}, apperr.NotFound("host")
	}
	repo, err := s.repo()
	if err != nil {
		return HostDetail{}, err
	}
	h, err := repo.Host(ctx, p.UserID, userID)
	if errors.Is(err, ErrNotFound) {
		return HostDetail{}, apperr.NotFound("host")
	}
	if err != nil {
		return HostDetail{}, apperr.Internal(err)
	}
	paths := h.PhotoPaths
	if h.PhotoPath != nil && len(paths) == 0 {
		paths = []string{*h.PhotoPath}
	}
	var photos map[string]string
	if s.deps.Photos != nil && len(paths) > 0 {
		photos = s.deps.Photos.SignRead(ctx, paths, PhotoTTL)
	}
	d := HostDetail{HostCard: s.card(h, photos), Bio: h.Bio, PhotoUrls: []string{}}
	d.ArrivalPhoto = arrivalOf(h, s.signArrival(ctx, []HostRow{h}))
	for _, p := range paths {
		if u, ok := photos[p]; ok {
			d.PhotoUrls = append(d.PhotoUrls, u)
		}
	}
	return d, nil
}

// GetSummary: GET /v1/discovery/summary.
func (s *Service) GetSummary(ctx context.Context, p auth.Principal) (Summary, error) {
	repo, err := s.repo()
	if err != nil {
		return Summary{}, err
	}
	n, err := repo.OnlineCount(ctx, p.UserID)
	if err != nil {
		return Summary{}, apperr.Internal(err)
	}
	return Summary{OnlineCount: n}, nil
}

func (s *Service) sign(ctx context.Context, rows []HostRow) map[string]string {
	if s.deps.Photos == nil {
		return nil
	}
	var paths []string
	for _, h := range rows {
		if h.PhotoPath != nil {
			paths = append(paths, *h.PhotoPath)
		}
	}
	if len(paths) == 0 {
		return nil
	}
	return s.deps.Photos.SignRead(ctx, paths, PhotoTTL)
}

func (s *Service) card(h HostRow, photos map[string]string) HostCard {
	level := s.deps.Rules.LevelForXP(h.LifetimeXP)
	c := HostCard{
		UserId: h.UserID, DisplayName: h.DisplayName, Languages: h.Languages, Level: level,
		// Discovery exposes the price the next call will use: the stored
		// rate within current eligibility (the same cap call creation applies).
		RatePerMinute: h.RatePerMinute, City: h.City, IsVerified: h.Verified, Availability: Availability(h),
	}
	if s.deps.Rules.LevelRateStep > 0 {
		c.RatePerMinute = s.deps.Rules.CapRate(h.RatePerMinute, level, h.Verified)
	}
	if c.Languages == nil {
		c.Languages = []string{}
	}
	if h.PhotoPath != nil {
		if u, ok := photos[*h.PhotoPath]; ok {
			c.PhotoUrl = &u
		}
	}
	if h.VerifiedDOB != nil {
		age := ageOn(*h.VerifiedDOB, s.deps.Clock.Now())
		c.Age = &age
	}
	return c
}

// Availability maps a host row to available | busy | offline.
func Availability(h HostRow) string {
	switch {
	case h.Busy:
		return "busy"
	case h.Online:
		return "available"
	default:
		return "offline"
	}
}

var ist = time.FixedZone("IST", 5*3600+1800)

func ageOn(dob, now time.Time) int {
	y, m, d := now.In(ist).Date()
	age := y - dob.Year()
	if m < dob.Month() || (m == dob.Month() && d < dob.Day()) {
		age--
	}
	return age
}
