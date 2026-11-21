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
