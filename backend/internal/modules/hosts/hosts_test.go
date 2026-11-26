package hosts

import (
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"dashuri/backend/internal/platform/httpx"
)

func TestAgeOn(t *testing.T) {
	dob := time.Date(2008, 11, 22, 0, 0, 0, 0, time.UTC)
	if AgeOn(dob, time.Date(2026, 11, 21, 0, 0, 0, 0, time.UTC)) != 17 {
		t.Fatal("day before 18th birthday")
	}
	if AgeOn(dob, time.Date(2026, 11, 22, 0, 0, 0, 0, time.UTC)) != 18 {
		t.Fatal("18th birthday")
	}
}

func TestDayStartIST(t *testing.T) {
	// 20:00 UTC on 21 Nov is 01:30 IST on 22 Nov.
	got := DayStartIST(time.Date(2026, 11, 21, 20, 0, 0, 0, time.UTC))
	if want := time.Date(2026, 11, 21, 18, 30, 0, 0, time.UTC); !got.Equal(want) {
		t.Fatalf("got %v want %v", got.UTC(), want)
	}
}

func TestKycDecisionValidation(t *testing.T) {
	if len((KycDecisionRequest{Decision: "approve"}).validate()) == 0 {
		t.Fatal("approve needs dob")
	}
	if len((KycDecisionRequest{Decision: "approve", DateOfBirth: "1990-01-31"}).validate()) != 0 {
		t.Fatal("valid approve rejected")
	}
	if len((KycDecisionRequest{Decision: "reject"}).validate()) != 0 {
		t.Fatal("reject needs nothing else")
	}
}

// Integer prices only: fractional and exponent forms are refused with a
// field error; the platform bounds are checked before the service runs.
func TestSetRateRequestIntegerOnly(t *testing.T) {
	cases := map[string]string{
		`{"rate_per_minute": 1500}`:   "",
		`{"rate_per_minute": 1500.5}`: "must_be_integer",
		`{"rate_per_minute": 1500.0}`: "must_be_integer",
		`{"rate_per_minute": 1.5e3}`:  "must_be_integer",
		`{"rate_per_minute": 499}`:    "below_minimum",
		`{"rate_per_minute": 500}`:    "",
		`{"rate_per_minute": 10000}`:  "",
		`{"rate_per_minute": 10001}`:  "above_maximum",
		`{}`:                          "below_minimum",
	}
	for body, want := range cases {
		req := httptest.NewRequest("PUT", "/v1/host/rate", strings.NewReader(body))
		var in SetRateRequest
		if err := httpx.DecodeJSON(req, &in); err != nil {
			t.Fatalf("%s: decode %v", body, err)
		}
		if got := in.validate()["rate_per_minute"]; got != want {
			t.Fatalf("%s: got %q want %q", body, got, want)
		}
	}
	req := httptest.NewRequest("PUT", "/v1/host/rate", strings.NewReader(`{"rate_per_minute": 1500, "level": 10}`))
	var in SetRateRequest
	if err := httpx.DecodeJSON(req, &in); err == nil {
		t.Fatal("client-sent level must be refused (unknown field)")
	}
}

func TestEvidenceUploadValidation(t *testing.T) {
	ok := []EvidenceUploadRequest{{"face_video", "video/mp4"}, {"face_video", "video/quicktime"},
		{"id_document_front", "image/jpeg"}, {"id_document_back", "image/png"}}
	for _, r := range ok {
		if errs := r.validate(); len(errs) != 0 {
			t.Fatalf("%+v: %v", r, errs)
		}
	}
	bad := []EvidenceUploadRequest{{"face_video", "image/jpeg"}, {"selfie", "image/jpeg"}, {"id_document_front", "application/pdf"}}
	for _, r := range bad {
		if errs := r.validate(); len(errs) == 0 {
			t.Fatalf("%+v accepted", r)
		}
	}
}

func TestVerificationTransitionsTable(t *testing.T) {
	// Only staff transitions exist; approval needs a started review;
	// negative actions need a reason.
	if _, ok := adminTransitions["submit"]; ok {
		t.Fatal("submit is a host action")
	}
	if a := adminTransitions["approve"]; len(a.from) != 1 || a.from[0] != VerificationUnderReview {
		t.Fatalf("approve from %v", a.from)
	}
	for _, k := range []string{"reject", "suspend", "revoke", "reinstate"} {
		if !adminTransitions[k].reasonRequired {
			t.Fatalf("%s must require a reason", k)
		}
	}
	for _, s := range []string{VerificationSubmitted, VerificationUnderReview, VerificationVerified, VerificationSuspended} {
		if canSubmit(s) {
			t.Fatalf("host can submit while %s", s)
		}
	}
}
