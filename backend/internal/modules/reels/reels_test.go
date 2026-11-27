package reels

import (
	"context"
	"testing"
	"time"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
)

var adult = auth.Principal{UserID: "00000000-0000-4000-8000-000000000001", Status: "active", AgeEligible: true}

func code(err error) string {
	if e := apperr.As(err); e != nil {
		return e.Code
	}
	return ""
}

func TestEvaluateThresholds(t *testing.T) {
	now := time.Now()
	th := DefaultThresholds
	cases := []struct {
		name  string
		s     FrameScores
		first bool
		want  string
		rsn   string
	}{
		{"clean, established creator", FrameScores{Sexual: 0.05, Suggestive: 0.1, Other: 0.05}, false, "approve", "automated_clear"},
		{"clean but first reel", FrameScores{}, true, "review", "first_reel"},
		{"explicit", FrameScores{Sexual: 0.95}, false, "reject", "sexual_content"},
		{"graphic", FrameScores{Other: 0.9}, false, "reject", "graphic_or_offensive"},
		{"uncertain sexual", FrameScores{Sexual: 0.25}, false, "review", "uncertain_sexual"},
		{"very suggestive", FrameScores{Suggestive: 0.55}, false, "review", "uncertain_sexual"},
		{"uncertain other", FrameScores{Other: 0.4}, false, "review", "uncertain_other"},
		{"boundary review sexual", FrameScores{Sexual: 0.2}, false, "review", "uncertain_sexual"},
	}
	for _, c := range cases {
		o := Evaluate(c.s, th, c.first, now)
		if o.Decision != c.want || o.ReasonCode != c.rsn {
			t.Errorf("%s: got %s/%s", c.name, o.Decision, o.ReasonCode)
		}
		if o.Decision == "reject" && (o.EvidenceHold == nil || o.EvidenceHold.Sub(now) != EvidenceHold) {
			t.Errorf("%s: rejects keep 90-day evidence", c.name)
		}
	}
}

func TestDisabledFlagAndMissingDatabase(t *testing.T) {
	off := NewService(Deps{Enabled: false})
	if _, err := off.Feed(context.Background(), adult, "", "", 10); code(err) != "reels_disabled" {
		t.Fatalf("disabled: %v", err)
	}
	if err := off.HandleWebhook(context.Background(), "mux", nil, nil); code(err) != "reels_disabled" {
		t.Fatalf("disabled webhook: %v", err)
	}
	if off.Config().Enabled || off.Config().UploadsAvailable {
		t.Fatal("config must report disabled")
	}
	noDB := NewService(Deps{Enabled: true})
	if _, err := noDB.Feed(context.Background(), adult, "", "", 10); code(err) != "database_unavailable" {
		t.Fatalf("no db: %v", err)
	}
	if n, err := noDB.ModeratePending(context.Background(), 5); n != 0 || code(err) != "database_unavailable" {
		t.Fatalf("jobs without db: %d %v", n, err)
	}
}

func TestAgeAndRestrictionGates(t *testing.T) {
	s := NewService(Deps{Enabled: true})
	minor := adult
	minor.AgeEligible = false
	if _, err := s.Feed(context.Background(), minor, "", "", 10); code(err) != "not_age_eligible" {
		t.Fatalf("minor: %v", err)
	}
	restricted := adult
	restricted.Status = "restricted"
	ms := 20000
	if _, err := s.CreateUpload(context.Background(), restricted, CreateUploadRequest{DeclaredDurationMs: &ms}); code(err) != "account_restricted" {
		t.Fatalf("restricted upload: %v", err)
	}
	if _, err := s.Queue(context.Background(), adult, "", 10); code(err) != "role_required" {
		t.Fatalf("queue needs moderator: %v", err)
	}
}

func TestOnlyHostsCanPostReels(t *testing.T) {
	s := NewService(Deps{Enabled: true})
	ms := 20000
	if _, err := s.CreateUpload(context.Background(), adult, CreateUploadRequest{DeclaredDurationMs: &ms}); code(err) != "host_only" {
		t.Fatalf("customer upload must be refused with host_only: %v", err)
	}
	bio := "hello"
	if _, err := s.UpdateMyCreator(context.Background(), adult, UpdateCreatorRequest{Bio: &bio}); code(err) != "host_only" {
		t.Fatalf("customer creator update must be refused with host_only: %v", err)
	}
	host := adult
	host.Roles = []auth.Role{auth.RoleCustomer, auth.RoleHost}
	// A host passes the role gate; with no database it then fails for another reason.
	if _, err := s.CreateUpload(context.Background(), host, CreateUploadRequest{DeclaredDurationMs: &ms}); code(err) == "host_only" {
		t.Fatalf("host must not be refused as host_only: %v", err)
	}
}

func TestUploadValidation(t *testing.T) {
	long := string(make([]rune, MaxCaptionRunes+1))
	bad := "EN"
	short, ok := 9000, 30000
	if errs := (CreateUploadRequest{DeclaredDurationMs: &short}).validate(); errs["duration_ms"] != "out_of_range" {
		t.Fatal("15 s minimum")
	}
	if errs := (CreateUploadRequest{}).validate(); errs["duration_ms"] != "required" {
		t.Fatal("duration required")
	}
	if errs := (CreateUploadRequest{DeclaredDurationMs: &ok, Caption: &long, Language: &bad}).validate(); errs["caption"] == "" || errs["language"] == "" {
		t.Fatalf("got %v", errs)
	}
	if errs := (CreateUploadRequest{DeclaredDurationMs: &ok}).validate(); len(errs) != 0 {
		t.Fatalf("valid request rejected: %v", errs)
	}
}

func TestEventValidation(t *testing.T) {
	s := NewService(Deps{Enabled: true}) // validation runs before any repo use
	id := "00000000-0000-4000-8000-0000000000aa"
	bad := []EventsRequest{
		{},
		{Events: []EventIn{{Event: "reel_liked", ReelId: &id}}}, // server-side only
		{Events: []EventIn{{Event: "reel_impression"}}},         // reel id required
		{Events: []EventIn{{Event: "reel_impression", ReelId: ptr("x")}}},
		{Events: []EventIn{{Event: "reel_watch_duration", ReelId: &id, ValueMs: ptr(-1)}}},
	}
	for i, in := range bad {
		if err := s.RecordEvents(context.Background(), adult, in); code(err) != "validation_failed" {
			t.Errorf("case %d: %v", i, err)
		}
	}
	many := EventsRequest{}
	for range MaxEventsPerBatch + 1 {
		many.Events = append(many.Events, EventIn{Event: "reel_impression", ReelId: &id})
	}
	if err := s.RecordEvents(context.Background(), adult, many); code(err) != "validation_failed" {
		t.Fatal("batch limit")
	}
}

func TestDecisionAndReportValidation(t *testing.T) {
	if errs := (DecisionRequest{Decision: ptr("publish"), ReasonCode: ptr("x")}).validate(); errs["decision"] != "invalid" {
		t.Fatal("unknown decision")
	}
	if errs := (DecisionRequest{Decision: ptr("approve")}).validate(); errs["reason_code"] != "required" {
		t.Fatal("reason required")
	}
	if errs := (ReportRequest{Category: ptr("boring")}).validate(); errs["category"] != "invalid" {
		t.Fatal("category")
	}
}

func ptr[T any](v T) *T { return &v }

func TestProcessingTimingInvariants(t *testing.T) {
	if ProcessingDeadline >= ProcessingLease {
		t.Fatalf("deadline %v must be below the lease %v", ProcessingDeadline, ProcessingLease)
	}
	want := []time.Duration{2, 4, 8, 16, 32, 32, 32}
	for i, w := range want {
		if got := ProcessingBackoff(i + 1); got != w*time.Minute {
			t.Fatalf("backoff(%d) = %v, want %v", i+1, got, w*time.Minute)
		}
	}
}
