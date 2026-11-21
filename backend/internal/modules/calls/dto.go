package calls

import "time"

// Wire types for this module. Generated from the API registry; keep in sync
// with api/openapi/dashuri.v1.yaml (the contract).

type CallRequestBody struct {
	HostUserId string `json:"host_user_id"`
}

func (r CallRequestBody) validate() map[string]string {
	errs := map[string]string{}
	if r.HostUserId == "" {
		errs["host_user_id"] = "required"
	}
	if r.HostUserId != "" && !isUUID(r.HostUserId) {
		errs["host_user_id"] = "invalid_uuid"
	}
	return errs
}

// CallSession: Server-owned call state. billed_seconds and diamonds_charged are computed only by the server.
type CallSession struct {
	CallId          string  `json:"call_id"`
	Role            string  `json:"role"`
	PeerUserId      string  `json:"peer_user_id"`
	Phase           string  `json:"phase"`
	RatePerMinute   int64   `json:"rate_per_minute"`
	BilledSeconds   int64   `json:"billed_seconds"`
	DiamondsCharged int64   `json:"diamonds_charged"`
	IsFreeCall      bool    `json:"is_free_call"`
	EndReason       *string `json:"end_reason,omitempty"`
	// MVP additions (docs/mvp/MVP_DECISIONS_AND_CONTRACT.md §2.5).
	Peer                   *Peer      `json:"peer"`
	StartedAt              *time.Time `json:"started_at"`
	ModerationWindowEndsAt *time.Time `json:"moderation_window_ends_at"`
	CreatedAt              time.Time  `json:"created_at"`
	EndedAt                *time.Time `json:"ended_at"`
}

type EndCallRequest struct {
	Reason string `json:"reason"`
}

func (r EndCallRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.Reason == "" {
		errs["reason"] = "required"
	}
	if r.Reason != "hangup" && r.Reason != "report" && r.Reason != "low_balance" && r.Reason != "other" {
		errs["reason"] = "invalid_value"
	}
	return errs
}

// CallCredentials: Short-lived token that lets this user join exactly this call.
type CallCredentials struct {
	Provider       string    `json:"provider"`
	ProviderCallId string    `json:"provider_call_id"`
	UserToken      string    `json:"user_token"`
	ExpiresAt      time.Time `json:"expires_at"`
	// APIKey is Stream's public API key; CallType is the Stream call type.
	APIKey   string `json:"api_key"`
	CallType string `json:"call_type"`
}
