package notifications

import "time"

// Wire types for this module. Generated from the API registry; keep in sync
// with api/openapi/dashuri.v1.yaml (the contract).

type DeviceRegistration struct {
	Token    string `json:"token"`
	Platform string `json:"platform"`
}

func (r DeviceRegistration) validate() map[string]string {
	errs := map[string]string{}
	if r.Token == "" {
		errs["token"] = "required"
	}
	if len(r.Token) > 4096 {
		errs["token"] = "too_long"
	}
	if r.Platform == "" {
		errs["platform"] = "required"
	}
	if r.Platform != "android" && r.Platform != "ios" {
		errs["platform"] = "invalid_value"
	}
	return errs
}

type InboxItem struct {
	Id        string     `json:"id"`
	Kind      string     `json:"kind"`
	Title     string     `json:"title"`
	Body      string     `json:"body"`
	CreatedAt time.Time  `json:"created_at"`
	ReadAt    *time.Time `json:"read_at,omitempty"`
}
