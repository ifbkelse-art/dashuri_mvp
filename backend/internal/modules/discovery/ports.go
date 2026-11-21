package discovery

import (
	"context"
	"errors"
	"time"
)

// ErrNotFound: no such approved host visible to the viewer.
var ErrNotFound = errors.New("discovery: not found")

// HostRow is one host as read for discovery.
type HostRow struct {
	UserID        string
	DisplayName   string
	Bio           *string
	Languages     []string
	PhotoPath     *string // first approved photo
	City          *City
	RatePerMinute int64
	KYCApproved   bool
	VerifiedDOB   *time.Time // only when age_method = kyc_verified
	LifetimeXP    int64
	Online        bool // is_available with a heartbeat in the last 90 s
	Busy          bool // in a live call
}

// ListQuery filters and positions a host listing.
type ListQuery struct {
	ViewerID string
	Language string
	CityID   string
	Sort     string
	After    *Cursor
	Limit    int // the repository returns up to Limit rows
}

// Repository reads hosting.hosts with profiles, blocks and calls.
type Repository interface {
	// ListHosts returns approved, active hosts that are online or busy,
	// excluding the viewer and blocks either way, ordered by SortKeys.
	ListHosts(ctx context.Context, q ListQuery) ([]HostRow, error)
	// Host returns one approved host (also offline); ErrNotFound when
	// missing, not approved, inactive or blocked either way.
	Host(ctx context.Context, viewerID, hostID string) (HostRow, error)
	// OnlineCount counts the hosts ListHosts would return without filters.
	OnlineCount(ctx context.Context, viewerID string) (int, error)
}

// PhotoSigner signs read URLs for the private profile-photos bucket.
type PhotoSigner interface {
	SignRead(ctx context.Context, paths []string, ttl time.Duration) map[string]string
}
