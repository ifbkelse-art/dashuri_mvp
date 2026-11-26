package hosts

import (
	"bytes"
	"encoding/json"
	"strconv"
	"time"
)

// Wire types for this module. Generated from the API registry; keep in sync
// with api/openapi/dashuri.v1.yaml (the contract).

type HostStatus struct {
	State            string `json:"state"`
	KycState         string `json:"kyc_state"`
	IsAvailable      bool   `json:"is_available"`
	RatePerMinute    int64  `json:"rate_per_minute"`
	MinRatePerMinute int64  `json:"min_rate_per_minute"`
	MaxRatePerMinute int64  `json:"max_rate_per_minute"`
	FreeCallOptIn    bool   `json:"free_call_opt_in"`
	// MVP additions (§2.7).
	TodayEarnedBeans int64 `json:"today_earned_beans"`
	TodayCalls       int64 `json:"today_calls"`
	Level            int   `json:"level"`
	// KycRejectionReason explains a rejected KYC (H08); null otherwise.
	KycRejectionReason *string `json:"kyc_rejection_reason,omitempty"`
	// Verified Host + level pricing (2026-11-23). MaxRatePerMinute is the
	// highest price this host may set now; LevelMaxRatePerMinute is the
	// level's own ceiling (level × 1,000), reachable above
	// VerifiedRateThreshold only as an active Verified Host.
	VerificationStatus        string  `json:"verification_status"`
	IsVerified                bool    `json:"is_verified"`
	VerificationNote          *string `json:"verification_note,omitempty"`
	LevelMaxRatePerMinute     int64   `json:"level_max_rate_per_minute"`
	NextLevelMaxRatePerMinute *int64  `json:"next_level_max_rate_per_minute"`
	VerifiedRateThreshold     int64   `json:"verified_rate_threshold"`
	// OnlineSession is the current online session (2026-11-26); null when
	// offline. Host Home shows the online duration from started_at.
	OnlineSession *OnlineSessionView `json:"online_session"`
}

// OnlineSessionView is the host's open online session.
type OnlineSessionView struct {
	Id        string    `json:"id"`
	StartedAt time.Time `json:"started_at"`
}

// KycDecisionRequest: POST /v1/admin/hosts/{userId}/kyc-decision (moderator).
type KycDecisionRequest struct {
	Decision    string `json:"decision"`
	DateOfBirth string `json:"date_of_birth,omitempty"`
	Reason      string `json:"reason,omitempty"`
}

func (r KycDecisionRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.Decision != "approve" && r.Decision != "reject" {
		errs["decision"] = "invalid_value"
	}
	if r.Decision == "approve" {
		if r.DateOfBirth == "" {
			errs["date_of_birth"] = "required"
		} else if _, err := time.Parse("2006-01-02", r.DateOfBirth); err != nil {
			errs["date_of_birth"] = "invalid_date"
		}
	}
	if len(r.Reason) > 500 {
		errs["reason"] = "too_long"
	}
	return errs
}

type KycSession struct {
	SessionId   string  `json:"session_id"`
	RedirectUrl *string `json:"redirect_url,omitempty"`
}

type SetAvailabilityRequest struct {
	IsAvailable bool `json:"is_available"`
}

func (r SetAvailabilityRequest) validate() map[string]string {
	errs := map[string]string{}
	return errs
}

type SetRateRequest struct {
	RatePerMinute int64 `json:"rate_per_minute"`
	// notInteger is set when the JSON number had a fraction or exponent.
	notInteger bool
}

// UnmarshalJSON accepts only whole-number prices (1500.5 and 1.5e3 are
// rejected with rate_per_minute: must_be_integer, not a generic JSON error).
func (r *SetRateRequest) UnmarshalJSON(b []byte) error {
	var raw struct {
		RatePerMinute json.Number `json:"rate_per_minute"`
	}
	dec := json.NewDecoder(bytes.NewReader(b))
	dec.UseNumber()
	dec.DisallowUnknownFields()
	if err := dec.Decode(&raw); err != nil {
		return err
	}
	if raw.RatePerMinute == "" {
		return nil
	}
	n, err := strconv.ParseInt(raw.RatePerMinute.String(), 10, 64)
	if err != nil {
		r.notInteger = true
		return nil
	}
	r.RatePerMinute = n
	return nil
}

func (r SetRateRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.notInteger {
		errs["rate_per_minute"] = "must_be_integer"
		return errs
	}
	if r.RatePerMinute < 500 {
		errs["rate_per_minute"] = "below_minimum"
	}
	if r.RatePerMinute > 10000 {
		errs["rate_per_minute"] = "above_maximum"
	}
	return errs
}

type SetFreeCallOptInRequest struct {
	OptIn bool `json:"opt_in"`
}

func (r SetFreeCallOptInRequest) validate() map[string]string {
	errs := map[string]string{}
	return errs
}

type HostEarnings struct {
	BeansOnHold        int64      `json:"beans_on_hold"`
	BeansAvailable     int64      `json:"beans_available"`
	BeansPendingPayout int64      `json:"beans_pending_payout"`
	AvailableInrPaise  int64      `json:"available_inr_paise"`
	NextPayoutDate     *time.Time `json:"next_payout_date,omitempty"`
	TodayEarnedBeans   int64      `json:"today_earned_beans"`
	TodayCalls         int64      `json:"today_calls"`
}

// ---------------------------------------------------------------- Verified Host

// VerificationView is GET /v1/host/verification (the host's own view).
type VerificationView struct {
	Status        string     `json:"status"`
	IsVerified    bool       `json:"is_verified"`
	ApplicationId *string    `json:"application_id"`
	SubmittedAt   *time.Time `json:"submitted_at"`
	DecidedAt     *time.Time `json:"decided_at"`
	VerifiedAt    *time.Time `json:"verified_at"`
	// Note is the open info request, or the rejection/suspension/revocation
	// reason; null otherwise.
	Note *string `json:"note"`
	// CanSubmit: the host may submit (or resubmit) an application now.
	CanSubmit bool `json:"can_submit"`
	// Evidence lists the host's uploaded, unpurged evidence (metadata only;
	// never URLs).
	Evidence []EvidenceItem `json:"evidence"`
	// RequiredEvidence are the kinds a new application must include.
	RequiredEvidence []string `json:"required_evidence"`
}

// EvidenceItem is evidence metadata (no URL, no storage path).
type EvidenceItem struct {
	Id         string    `json:"id"`
	Kind       string    `json:"kind"`
	Submitted  bool      `json:"submitted"`
	UploadedAt time.Time `json:"uploaded_at"`
}

// EvidenceUploadRequest: POST /v1/host/verification/evidence.
type EvidenceUploadRequest struct {
	Kind        string `json:"kind"`
	ContentType string `json:"content_type"`
}

var evidenceTypes = map[string]map[string]bool{
	"face_video":        {"video/mp4": true, "video/quicktime": true},
	"id_document_front": {"image/jpeg": true, "image/png": true},
	"id_document_back":  {"image/jpeg": true, "image/png": true},
}

func (r EvidenceUploadRequest) validate() map[string]string {
	errs := map[string]string{}
	types, ok := evidenceTypes[r.Kind]
	if !ok {
		errs["kind"] = "invalid_value"
	} else if !types[r.ContentType] {
		errs["content_type"] = "invalid_value"
	}
	return errs
}

// EvidenceUploadTicket is a signed upload URL for one private object.
type EvidenceUploadTicket struct {
	EvidenceId string    `json:"evidence_id"`
	UploadUrl  string    `json:"upload_url"`
	ExpiresAt  time.Time `json:"expires_at"`
}

// SubmitVerificationRequest: POST /v1/host/verification/submissions.
type SubmitVerificationRequest struct {
	EvidenceIds []string `json:"evidence_ids"`
}

func (r SubmitVerificationRequest) validate() map[string]string {
	errs := map[string]string{}
	if len(r.EvidenceIds) > 10 {
		errs["evidence_ids"] = "too_many"
	}
	for _, id := range r.EvidenceIds {
		if !isUUID(id) {
			errs["evidence_ids"] = "invalid_value"
		}
	}
	return errs
}

// VerificationActionRequest: POST /v1/admin/hosts/{userId}/verification/actions.
type VerificationActionRequest struct {
	Action      string `json:"action"`
	Reason      string `json:"reason,omitempty"`
	InfoRequest string `json:"info_request,omitempty"`
}

func (r VerificationActionRequest) validate() map[string]string {
	errs := map[string]string{}
	if _, ok := adminTransitions[r.Action]; !ok {
		errs["action"] = "invalid_value"
	}
	if len(r.Reason) > 1000 {
		errs["reason"] = "too_long"
	}
	if len(r.InfoRequest) > 1000 {
		errs["info_request"] = "too_long"
	}
	return errs
}

// AdminVerificationDetail is the staff view of one host's verification.
type AdminVerificationDetail struct {
	HostId        string            `json:"host_id"`
	Status        string            `json:"status"`
	Level         int               `json:"level"`
	RatePerMinute int64             `json:"rate_per_minute"`
	Application   *AdminApplication `json:"application"`
	Evidence      []EvidenceItem    `json:"evidence"`
	History       []HistoryItem     `json:"history"`
}

// AdminApplication is a verification application as staff see it.
type AdminApplication struct {
	Id              string     `json:"id"`
	Status          string     `json:"status"`
	SubmittedAt     time.Time  `json:"submitted_at"`
	ResubmittedAt   *time.Time `json:"resubmitted_at"`
	ReviewerId      *string    `json:"reviewer_id"`
	ReviewStartedAt *time.Time `json:"review_started_at"`
	InfoRequest     *string    `json:"info_request"`
	DecidedBy       *string    `json:"decided_by"`
	DecidedAt       *time.Time `json:"decided_at"`
	DecisionReason  *string    `json:"decision_reason"`
}

// HistoryItem is one audited action.
type HistoryItem struct {
	At      time.Time      `json:"at"`
	Actor   string         `json:"actor"`
	Action  string         `json:"action"`
	Details map[string]any `json:"details"`
}

// VerificationQueueItem is one row of GET /v1/admin/host-verifications.
type VerificationQueueItem struct {
	ApplicationId string    `json:"application_id"`
	HostId        string    `json:"host_id"`
	DisplayName   string    `json:"display_name"`
	Status        string    `json:"status"`
	SubmittedAt   time.Time `json:"submitted_at"`
	Level         int       `json:"level"`
}

// EvidenceAccess is a short-lived signed read URL for staff.
type EvidenceAccess struct {
	Url       string    `json:"url"`
	ExpiresAt time.Time `json:"expires_at"`
}
