package discovery

// Wire types for this module. Generated from the API registry; keep in sync
// with api/openapi/dashuri.v1.yaml (the contract).

type HostCard struct {
	UserId        string   `json:"user_id"`
	DisplayName   string   `json:"display_name"`
	PhotoUrl      *string  `json:"photo_url,omitempty"`
	Languages     []string `json:"languages"`
	Level         int      `json:"level"`
	RatePerMinute int64    `json:"rate_per_minute"`
	Availability  string   `json:"availability"`
}
