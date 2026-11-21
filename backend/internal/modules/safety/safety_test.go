package safety

import (
	"strings"
	"testing"
	"time"
)

func TestPriorityFor(t *testing.T) {
	for c, want := range map[string]int{"nudity": 1, "minor_safety": 1, "harassment": 3, "other": 3, "sexual_content": 3} {
		if got := PriorityFor(c); got != want {
			t.Errorf("%s: %d", c, got)
		}
	}
}

func TestWithinReportWindow(t *testing.T) {
	now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
	ago := func(d time.Duration) *time.Time { t := now.Add(-d); return &t }
	cases := []struct {
		c    CallInfo
		want bool
	}{
		{CallInfo{Phase: "active", CreatedAt: now.Add(-48 * time.Hour)}, true},
		{CallInfo{Phase: "ended", EndedAt: ago(23 * time.Hour)}, true},
		{CallInfo{Phase: "ended", EndedAt: ago(24 * time.Hour)}, true},
		{CallInfo{Phase: "ended", EndedAt: ago(25 * time.Hour)}, false},
		{CallInfo{Phase: "declined", CreatedAt: now.Add(-30 * time.Hour)}, false},
	}
	for i, c := range cases {
		if got := WithinReportWindow(c.c, now); got != c.want {
			t.Errorf("case %d: %v", i, got)
		}
	}
}

func TestReportRequestValidate(t *testing.T) {
	id := "11111111-1111-4111-8111-111111111111"
	long := strings.Repeat("x", 1001)
	bad := "nope"
	cases := []struct {
		r     ReportRequest
		field string
	}{
		{ReportRequest{Category: "nudity"}, "target_user_id"},
		{ReportRequest{TargetUserId: "x", Category: "nudity"}, "target_user_id"},
		{ReportRequest{TargetUserId: id}, "category"},
		{ReportRequest{TargetUserId: id, Category: "rude"}, "category"},
		{ReportRequest{TargetUserId: id, Category: "other", CallId: &bad}, "call_id"},
		{ReportRequest{TargetUserId: id, Category: "other", Details: &long}, "details"},
	}
	for _, c := range cases {
		if errs := c.r.validate(); errs[c.field] == "" {
			t.Errorf("%+v: want %s error, got %v", c.r, c.field, errs)
		}
	}
	if errs := (ReportRequest{TargetUserId: id, Category: "minor_safety"}).validate(); len(errs) != 0 {
		t.Error(errs)
	}
	if errs := (AppealRequest{EnforcementId: id, Statement: "  "}).validate(); errs["statement"] != "required" {
		t.Error(errs)
	}
	if errs := (AppealRequest{EnforcementId: id, Statement: strings.Repeat("न", 2000)}).validate(); len(errs) != 0 {
		t.Error("2000 chars must pass", errs)
	}
}
