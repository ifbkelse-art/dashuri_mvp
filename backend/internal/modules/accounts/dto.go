package accounts

import (
	"bytes"
	"encoding/json"
	"regexp"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"
)

// Wire types for this module. Keep in sync with api/openapi/dashuri.v1.yaml
// and docs/mvp/MVP_DECISIONS_AND_CONTRACT.md §2.1.

// AccountStatus: Server view of the signed-in account; route guards use this.
type AccountStatus struct {
	UserId          string  `json:"user_id"`
	AgeEligible     bool    `json:"age_eligible"`
	IsHost          bool    `json:"is_host"`
	HostState       *string `json:"host_state"`
	ProfileComplete bool    `json:"profile_complete"`
	RulesAccepted   bool    `json:"rules_accepted"`
	Restriction     *string `json:"restriction"`
}

// City is a coarse, curated city.
type City struct {
	Id    string `json:"id"`
	Name  string `json:"name"`
	State string `json:"state"`
}

type Profile struct {
	UserId      string   `json:"user_id"`
	DisplayName string   `json:"display_name"`
	Bio         *string  `json:"bio"`
	Languages   []string `json:"languages"`
	PhotoUrls   []string `json:"photo_urls"`
	IsHost      bool     `json:"is_host"`
	Level       int      `json:"level"`
	City        *City    `json:"city"`
	// Gender is set only on the caller's own profile; never public (D-03).
	Gender *string `json:"gender,omitempty"`
}

// NullableString distinguishes an absent field (Set=false) from null.
type NullableString struct {
	Set   bool
	Value *string
}

func (n *NullableString) UnmarshalJSON(b []byte) error {
	n.Set = true
	if bytes.Equal(bytes.TrimSpace(b), []byte("null")) {
		n.Value = nil
		return nil
	}
	var s string
	if err := json.Unmarshal(b, &s); err != nil {
		return err
	}
	n.Value = &s
	return nil
}

type UpdateProfileRequest struct {
	DisplayName *string        `json:"display_name,omitempty"`
	Bio         NullableString `json:"bio"`
	Languages   []string       `json:"languages,omitempty"`
	Gender      *string        `json:"gender,omitempty"`
	CityId      NullableString `json:"city_id"`
}

var (
	languageRE = regexp.MustCompile(`^[a-z]{2}$`)
	cityIDRE   = regexp.MustCompile(`^[a-z0-9_]{2,40}$`)
	genders    = map[string]bool{"man": true, "woman": true, "non_binary": true, "prefer_not_to_say": true}
)

// MaxLanguages bounds the languages list.
const MaxLanguages = 10

func hasControl(s string, allowNewline bool) bool {
	for _, r := range s {
		if (r == '\n' || r == '\r') && allowNewline {
			continue
		}
		if unicode.IsControl(r) {
			return true
		}
	}
	return false
}

// normalize trims text fields and lowercases/deduplicates languages in place.
func (r *UpdateProfileRequest) normalize() {
	if r.DisplayName != nil {
		v := strings.TrimSpace(*r.DisplayName)
		r.DisplayName = &v
	}
	if r.Bio.Value != nil {
		v := strings.TrimSpace(*r.Bio.Value)
		if v == "" {
			r.Bio.Value = nil
		} else {
			r.Bio.Value = &v
		}
	}
	if r.Languages != nil {
		seen := map[string]bool{}
		out := make([]string, 0, len(r.Languages))
		for _, l := range r.Languages {
			l = strings.ToLower(strings.TrimSpace(l))
			if !seen[l] {
				seen[l] = true
				out = append(out, l)
			}
		}
		r.Languages = out
	}
}

func (r UpdateProfileRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.DisplayName != nil {
		n := utf8.RuneCountInString(*r.DisplayName)
		switch {
		case n == 0:
			errs["display_name"] = "required"
		case n > 40:
			errs["display_name"] = "too_long"
		case hasControl(*r.DisplayName, false):
			errs["display_name"] = "invalid_characters"
		}
	}
	if r.Bio.Value != nil {
		if utf8.RuneCountInString(*r.Bio.Value) > 300 {
			errs["bio"] = "too_long"
		} else if hasControl(*r.Bio.Value, true) {
			errs["bio"] = "invalid_characters"
		}
	}
	if len(r.Languages) > MaxLanguages {
		errs["languages"] = "too_many"
	}
	for _, l := range r.Languages {
		if !languageRE.MatchString(l) {
			errs["languages"] = "invalid_value"
		}
	}
	if r.Gender != nil && !genders[*r.Gender] {
		errs["gender"] = "invalid_value"
	}
	if r.CityId.Value != nil && !cityIDRE.MatchString(*r.CityId.Value) {
		errs["city_id"] = "invalid_value"
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
	} else if _, ok := photoExtensions[r.ContentType]; !ok {
		errs["content_type"] = "invalid_value"
	}
	return errs
}

var photoExtensions = map[string]string{"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"}

// PhotoUploadTicket: Signed Supabase Storage upload URL for one photo; the photo stays private until moderated.
type PhotoUploadTicket struct {
	PhotoId   string    `json:"photo_id"`
	UploadUrl string    `json:"upload_url"`
	ExpiresAt time.Time `json:"expires_at"`
	Status    string    `json:"status"`
}

type AgeStatus struct {
	Eligible bool    `json:"eligible"`
	Method   *string `json:"method"`
	Declared bool    `json:"declared"`
}

type AgeDeclarationRequest struct {
	DateOfBirth string `json:"date_of_birth"`
}

// parse validates the date (YYYY-MM-DD, not in the future, not before 1900).
func (r AgeDeclarationRequest) parse(today time.Time) (time.Time, map[string]string) {
	errs := map[string]string{}
	if r.DateOfBirth == "" {
		errs["date_of_birth"] = "required"
		return time.Time{}, errs
	}
	d, err := time.Parse(time.DateOnly, r.DateOfBirth)
	switch {
	case err != nil:
		errs["date_of_birth"] = "invalid_date"
	case d.After(today):
		errs["date_of_birth"] = "in_future"
	case d.Year() < 1900:
		errs["date_of_birth"] = "too_old"
	}
	return d, errs
}

// AgeOn returns the age in whole years on the given calendar day.
func AgeOn(dob, day time.Time) int {
	age := day.Year() - dob.Year()
	if day.Month() < dob.Month() || (day.Month() == dob.Month() && day.Day() < dob.Day()) {
		age--
	}
	return age
}

// ist is India Standard Time (fixed offset; no tzdata needed in distroless).
var ist = time.FixedZone("IST", 5*3600+1800)

// todayIST is the current calendar day in India as a UTC-midnight date.
func todayIST(now time.Time) time.Time {
	y, m, d := now.In(ist).Date()
	return time.Date(y, m, d, 0, 0, 0, 0, time.UTC)
}

type ConsentState struct {
	Analytics bool      `json:"analytics"`
	Marketing bool      `json:"marketing"`
	UpdatedAt time.Time `json:"updated_at"`
}

type UpdateConsentsRequest struct {
	Analytics *bool `json:"analytics"`
	Marketing *bool `json:"marketing"`
}

func (r UpdateConsentsRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.Analytics == nil {
		errs["analytics"] = "required"
	}
	if r.Marketing == nil {
		errs["marketing"] = "required"
	}
	return errs
}

type DeletionRequest struct {
	RequestId    string     `json:"request_id"`
	Status       string     `json:"status"`
	ScheduledFor *time.Time `json:"scheduled_for"`
}

type DataExportRequest struct {
	RequestId string `json:"request_id"`
	Status    string `json:"status"`
}

// RulesAcceptanceRequest: POST /v1/me/rules-acceptance.
type RulesAcceptanceRequest struct {
	Version string `json:"version"`
}

func (r RulesAcceptanceRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.Version == "" {
		errs["version"] = "required"
	} else if len(r.Version) > 20 {
		errs["version"] = "too_long"
	}
	return errs
}

// PendingPhotoItem is one entry of GET /v1/admin/photos/pending.
type PendingPhotoItem struct {
	PhotoId   string    `json:"photo_id"`
	UserId    string    `json:"user_id"`
	ReadUrl   *string   `json:"read_url"` // null until the object is uploaded
	CreatedAt time.Time `json:"created_at"`
}

// PhotoDecisionRequest: POST /v1/admin/photos/{photoId}/decision.
type PhotoDecisionRequest struct {
	Decision string  `json:"decision"`
	Reason   *string `json:"reason,omitempty"`
}

// MaxDecisionReason bounds the moderator's reason.
const MaxDecisionReason = 500

func (r PhotoDecisionRequest) validate() map[string]string {
	errs := map[string]string{}
	if r.Decision != "approve" && r.Decision != "reject" {
		errs["decision"] = "invalid_value"
	}
	if r.Reason != nil && utf8.RuneCountInString(*r.Reason) > MaxDecisionReason {
		errs["reason"] = "too_long"
	}
	return errs
}

// PhotoDecision is the decision response.
type PhotoDecision struct {
	PhotoId string `json:"photo_id"`
	Status  string `json:"status"`
}

// Page is the list envelope {items, next_cursor}.
type Page[T any] struct {
	Items      []T     `json:"items"`
	NextCursor *string `json:"next_cursor,omitempty"`
}
