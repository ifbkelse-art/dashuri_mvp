package calls

import (
	"errors"
	"testing"
	"time"
)

var t0 = time.Date(2026, 11, 17, 10, 0, 0, 0, time.UTC)

func at(s int) time.Time { return t0.Add(time.Duration(s) * time.Second) }

func TestNoBillingBeforeBothStreamsConnect(t *testing.T) {
	if got := BillableSeconds(nil, at(120), 10*time.Second); got != 0 {
		t.Fatalf("never connected billed %d s", got)
	}
	// Connected at 20 s, ended at 85 s → 65 s, not 85.
	got := BillableSeconds([]LiveChange{{at(20), true}}, at(85), 10*time.Second)
	if got != 65 {
		t.Fatalf("got %d, want 65", got)
	}
}

func TestShortBlipBilledLongInterruptionPaused(t *testing.T) {
	changes := []LiveChange{
		{at(0), true},
		{at(30), false}, {at(35), true}, // 5 s blip < 10 s threshold → billed
		{at(60), false}, {at(90), true}, // 30 s interruption → not billed
	}
	got := BillableSeconds(changes, at(120), 10*time.Second)
	// 0–60 (60 s incl. blip) + 90–120 (30 s) = 90 s
	if got != 90 {
		t.Fatalf("got %d, want 90", got)
	}
}

func TestEventsAfterEndIgnoredAndOrderIndependent(t *testing.T) {
	changes := []LiveChange{{at(100), true}, {at(0), true}, {at(50), false}, {at(55), true}}
	got := BillableSeconds(changes, at(60), 10*time.Second)
	if got != 60 {
		t.Fatalf("got %d, want 60", got)
	}
}

func TestLifecycleTransitions(t *testing.T) {
	if err := Transition(Ringing, Accepted); err != nil {
		t.Fatal(err)
	}
	if err := Transition(Ended, Active); !errors.Is(err, ErrIllegalTransition) {
		t.Fatal("ended call must not resume")
	}
	if err := Transition(Requested, Active); !errors.Is(err, ErrIllegalTransition) {
		t.Fatal("billing cannot start before ringing/accept/connect")
	}
	if !Terminal(Ended) || Terminal(Active) {
		t.Fatal("terminal states wrong")
	}
}
