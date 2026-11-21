package discovery

import (
	"regexp"
)

// Wire types. Keep in sync with api/openapi/dashuri.v1.yaml and
// docs/mvp/MVP_DECISIONS_AND_CONTRACT.md §2.3.

// City is a coarse, curated city.
type City struct {
	Id    string `json:"id"`
	Name  string `json:"name"`
	State string `json:"state"`
}

type HostCard struct {
	UserId        string   `json:"user_id"`
	DisplayName   string   `json:"display_name"`
	PhotoUrl      *string  `json:"photo_url"`
	Languages     []string `json:"languages"`
	Level         int      `json:"level"`
	RatePerMinute int64    `json:"rate_per_minute"`
	// Availability: available | busy | offline (offline only on the detail endpoint).
	Availability string `json:"availability"`
	City         *City  `json:"city"`
	// Age from the KYC-verified date of birth; null when not verified.
	Age        *int `json:"age"`
	IsVerified bool `json:"is_verified"`
}

// HostDetail is GET /v1/discovery/hosts/{userId}: a HostCard plus bio.
type HostDetail struct {
	HostCard
	Bio *string `json:"bio"`
	// PhotoUrls are all approved photos, signed, in profile order.
	PhotoUrls []string `json:"photo_urls"`
}

// Summary is GET /v1/discovery/summary.
type Summary struct {
	OnlineCount int `json:"online_count"`
}

// Sort orders (D-06).
const (
	SortRecommended = "recommended"
	SortRateLow     = "rate_low"
	SortRateHigh    = "rate_high"
)

// ListRequest holds the parsed GET /v1/discovery/hosts query.
type ListRequest struct {
	Language string
	CityID   string
	Sort     string
	Cursor   string
	Limit    int
}

var (
	languageRE = regexp.MustCompile(`^[a-z]{2}$`)
	cityIDRE   = regexp.MustCompile(`^[a-z0-9_]{2,40}$`)
)

func (r *ListRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.Language != "" && !languageRE.MatchString(r.Language) {
		errs["language"] = "invalid_value"
	}
	if r.CityID != "" && !cityIDRE.MatchString(r.CityID) {
		errs["city_id"] = "invalid_value"
	}
	switch r.Sort {
	case "":
		r.Sort = SortRecommended
	case SortRecommended, SortRateLow, SortRateHigh:
	default:
		errs["sort"] = "invalid_value"
	}
	if r.Limit < 1 || r.Limit > 100 {
		errs["limit"] = "must_be_1_to_100"
	}
	return errs
}
