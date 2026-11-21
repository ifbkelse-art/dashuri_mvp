package hosts

import (
	"testing"
	"time"
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
