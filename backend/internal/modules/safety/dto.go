package safety

import "time"

// Wire types for this module. Generated from the API registry; keep in sync
// with api/openapi/dashuri.v1.yaml (the contract).

type ReportRequest struct {
	TargetUserId string  `json:"target_user_id"`
	Category     string  `json:"category"`
	CallId       *string `json:"call_id,omitempty"`
	Details      *string `json:"details,omitempty"`
}

func (r ReportRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.TargetUserId == "" {
		errs["target_user_id"] = "required"
	}
	if r.TargetUserId != "" && !isUUID(r.TargetUserId) {
		errs["target_user_id"] = "invalid_uuid"
	}
	if r.Category == "" {
		errs["category"] = "required"
	}
	if r.Category != "nudity" && r.Category != "sexual_content" && r.Category != "minor_safety" && r.Category != "harassment" && r.Category != "spam_or_scam" && r.Category != "fake_profile" && r.Category != "other" {
		errs["category"] = "invalid_value"
	}
	if r.CallId != nil && *r.CallId != "" && !isUUID(*r.CallId) {
		errs["call_id"] = "invalid_uuid"
	}
	if r.Details != nil && len(*r.Details) > 1000 {
		errs["details"] = "too_long"
	}
	return errs
}

type ReportReceipt struct {
	ReportId string `json:"report_id"`
	Status   string `json:"status"`
}

type BlockRequest struct {
	UserId string `json:"user_id"`
}

func (r BlockRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.UserId == "" {
		errs["user_id"] = "required"
	}
	if r.UserId != "" && !isUUID(r.UserId) {
		errs["user_id"] = "invalid_uuid"
	}
	return errs
}

type BlockedUser struct {
	UserId      string    `json:"user_id"`
	DisplayName string    `json:"display_name"`
	BlockedAt   time.Time `json:"blocked_at"`
}

type EnforcementNotice struct {
	Id         string    `json:"id"`
	Action     string    `json:"action"`
	Reason     string    `json:"reason"`
	CreatedAt  time.Time `json:"created_at"`
	Appealable bool      `json:"appealable"`
}

type AppealRequest struct {
	EnforcementId string `json:"enforcement_id"`
	Statement     string `json:"statement"`
}

func (r AppealRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.EnforcementId == "" {
		errs["enforcement_id"] = "required"
	}
	if r.EnforcementId != "" && !isUUID(r.EnforcementId) {
		errs["enforcement_id"] = "invalid_uuid"
	}
	if r.Statement == "" {
		errs["statement"] = "required"
	}
	if len(r.Statement) > 2000 {
		errs["statement"] = "too_long"
	}
	return errs
}

type AppealReceipt struct {
	AppealId string `json:"appeal_id"`
	Status   string `json:"status"`
}
