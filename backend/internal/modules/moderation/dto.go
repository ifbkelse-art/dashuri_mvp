package moderation

import "time"

// Wire types for this module. Generated from the API registry; keep in sync
// with api/openapi/dashuri.v1.yaml (the contract).

type ModerationCase struct {
	ReportId      string    `json:"report_id"`
	Status        string    `json:"status"`
	Category      string    `json:"category"`
	TargetUserId  string    `json:"target_user_id"`
	CreatedAt     time.Time `json:"created_at"`
	EvidenceCount int       `json:"evidence_count"`
	// Details is the reporter's own text (staff-only queue; may be null).
	Details *string `json:"details"`
}

type ModerationDecisionRequest struct {
	Action string `json:"action"`
	Reason string `json:"reason"`
}

func (r ModerationDecisionRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.Action == "" {
		errs["action"] = "required"
	}
	if r.Action != "dismiss" && r.Action != "warn" && r.Action != "restrict_calls" && r.Action != "suspend" && r.Action != "ban" && r.Action != "escalate_legal" {
		errs["action"] = "invalid_value"
	}
	if r.Reason == "" {
		errs["reason"] = "required"
	}
	if len(r.Reason) > 2000 {
		errs["reason"] = "too_long"
	}
	return errs
}

type ModerationDecision struct {
	DecisionId string `json:"decision_id"`
	Action     string `json:"action"`
	Status     string `json:"status"`
	// Internal: who was decided about and whether an account restriction
	// was applied (live calls are then ended). Not serialised.
	TargetUserID string `json:"-"`
	Enforced     bool   `json:"-"`
}

type AppealDecisionRequest struct {
	Outcome string `json:"outcome"`
	Reason  string `json:"reason"`
}

func (r AppealDecisionRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.Outcome == "" {
		errs["outcome"] = "required"
	}
	if r.Outcome != "upheld" && r.Outcome != "overturned" {
		errs["outcome"] = "invalid_value"
	}
	if r.Reason == "" {
		errs["reason"] = "required"
	}
	if len(r.Reason) > 2000 {
		errs["reason"] = "too_long"
	}
	return errs
}

// ModerationFrameRequest: POST /v1/calls/{callId}/moderation-frames.
type ModerationFrameRequest struct {
	ImageBase64 string    `json:"image_base64"`
	CapturedAt  time.Time `json:"captured_at"`
}

// MaxFrameBytes is the decoded JPEG limit (200 KB).
const MaxFrameBytes = 200 * 1024

func (r ModerationFrameRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.ImageBase64 == "" {
		errs["image_base64"] = "required"
	} else if len(r.ImageBase64) > (MaxFrameBytes+2)/3*4+64 {
		errs["image_base64"] = "too_large"
	}
	if r.CapturedAt.IsZero() {
		errs["captured_at"] = "required"
	}
	return errs
}

// FrameAccepted is the 202 response for a frame.
type FrameAccepted struct {
	Accepted bool `json:"accepted"`
}
