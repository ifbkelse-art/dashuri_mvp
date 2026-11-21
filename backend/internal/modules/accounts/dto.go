package accounts

import "time"

// Wire types for this module. Generated from the API registry; keep in sync
// with api/openapi/dashuri.v1.yaml (the contract).

// AccountStatus: Server view of the signed-in account; route guards use this.
type AccountStatus struct {
	UserId      string  `json:"user_id"`
	AgeEligible bool    `json:"age_eligible"`
	IsHost      bool    `json:"is_host"`
	Restriction *string `json:"restriction,omitempty"`
}

type Profile struct {
	UserId      string   `json:"user_id"`
	DisplayName string   `json:"display_name"`
	Bio         *string  `json:"bio,omitempty"`
	Languages   []string `json:"languages"`
	PhotoUrls   []string `json:"photo_urls"`
	IsHost      bool     `json:"is_host"`
	Level       int      `json:"level"`
}

type UpdateProfileRequest struct {
	DisplayName *string  `json:"display_name,omitempty"`
	Bio         *string  `json:"bio,omitempty"`
	Languages   []string `json:"languages,omitempty"`
}

func (r UpdateProfileRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.DisplayName != nil && len(*r.DisplayName) > 40 {
		errs["display_name"] = "too_long"
	}
	if r.Bio != nil && len(*r.Bio) > 300 {
		errs["bio"] = "too_long"
	}
	return errs
}

type PhotoUploadTicketRequest struct {
	ContentType string `json:"content_type"`
}

func (r PhotoUploadTicketRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.ContentType == "" {
		errs["content_type"] = "required"
	}
	if r.ContentType != "image/jpeg" && r.ContentType != "image/png" && r.ContentType != "image/webp" {
		errs["content_type"] = "invalid_value"
	}
	return errs
}

// PhotoUploadTicket: Signed Supabase Storage upload URL for one photo; the photo stays private until moderated.
type PhotoUploadTicket struct {
	PhotoId   string    `json:"photo_id"`
	UploadUrl string    `json:"upload_url"`
	ExpiresAt time.Time `json:"expires_at"`
}

type AgeStatus struct {
	Eligible bool    `json:"eligible"`
	Method   *string `json:"method,omitempty"`
}

type AgeDeclarationRequest struct {
	DateOfBirth string `json:"date_of_birth"`
}

func (r AgeDeclarationRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.DateOfBirth == "" {
		errs["date_of_birth"] = "required"
	}
	return errs
}

type ConsentState struct {
	Analytics bool      `json:"analytics"`
	Marketing bool      `json:"marketing"`
	UpdatedAt time.Time `json:"updated_at"`
}

type UpdateConsentsRequest struct {
	Analytics bool `json:"analytics"`
	Marketing bool `json:"marketing"`
}

func (r UpdateConsentsRequest) validate() map[string]string {
	errs := map[string]string{}
	return errs
}

type DeletionRequest struct {
	RequestId    string     `json:"request_id"`
	Status       string     `json:"status"`
	ScheduledFor *time.Time `json:"scheduled_for,omitempty"`
}

func (r DeletionRequest) validate() map[string]string {
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
	return errs
}

type DataExportRequest struct {
	RequestId string `json:"request_id"`
	Status    string `json:"status"`
}

func (r DataExportRequest) validate() map[string]string {
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
	return errs
}
