package freecall

import "time"

// Wire types for this module. Generated from the API registry; keep in sync
// with api/openapi/dashuri.v1.yaml (the contract).

type FreeCallCard struct {
	Status string     `json:"status"`
	UsedAt *time.Time `json:"used_at,omitempty"`
}

type FreeCallRequestBody struct {
	PlayIntegrityToken *string `json:"play_integrity_token,omitempty"`
	// Platform is optional (android|ios); the X-Client-Platform header is
	// used when absent.
	Platform *string `json:"platform,omitempty"`
}

func (r FreeCallRequestBody) validate() map[string]string {
	errs := map[string]string{}
	if r.Platform != nil && *r.Platform != "android" && *r.Platform != "ios" {
		errs["platform"] = "invalid_value"
	}
	if r.PlayIntegrityToken != nil && len(*r.PlayIntegrityToken) > 16<<10 {
		errs["play_integrity_token"] = "too_long"
	}
	return errs
}

type FreeCallRequest struct {
	RequestId string  `json:"request_id"`
	Status    string  `json:"status"`
	CallId    *string `json:"call_id,omitempty"`
}

func (r FreeCallRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.RequestId == "" {
		errs["request_id"] = "required"
	}
	if r.RequestId != "" && !isUUID(r.RequestId) {
		errs["request_id"] = "invalid_uuid"
	}
	if r.Status == "" {
		errs["status"] = "required"
	}
	if r.Status != "searching" && r.Status != "matched" && r.Status != "no_host_available" && r.Status != "cancelled" {
		errs["status"] = "invalid_value"
	}
	if r.CallId != nil && *r.CallId != "" && !isUUID(*r.CallId) {
		errs["call_id"] = "invalid_uuid"
	}
	return errs
}
