// Package calls owns the paid-call lifecycle, server-side metering and
// settlement. The server is authoritative: it decides when billing starts,
// pauses, resumes and ends, from the video provider's server-side events.
// The client never submits durations or amounts.
package calls

import (
	"errors"
	"fmt"
)

// Phase mirrors the client enum (feature_video_call CallPhase).
type Phase string

const (
	Requested  Phase = "requested"
	Ringing    Phase = "ringing"
	Accepted   Phase = "accepted"
	Connecting Phase = "connecting"
	Active     Phase = "active" // both streams live; billing runs
	Paused     Phase = "paused" // qualifying interruption; billing paused
	Ending     Phase = "ending"
	Ended      Phase = "ended" // terminal, settled or settling
	Declined   Phase = "declined"
	Missed     Phase = "missed"
	Failed     Phase = "failed" // never connected → full refund of reservation (S6)
)

var allowed = map[Phase][]Phase{
	Requested:  {Ringing, Failed},
	Ringing:    {Accepted, Declined, Missed, Ended, Failed},
	Accepted:   {Connecting, Ended, Failed},
	Connecting: {Active, Ended, Failed},
	Active:     {Paused, Ending, Ended},
	Paused:     {Active, Ending, Ended},
	Ending:     {Ended},
}

var ErrIllegalTransition = errors.New("illegal_call_transition")

// Transition validates a state change. Callers persist it with an
// optimistic check (`UPDATE … WHERE id = $1 AND phase = $from`) so two
// concurrent events cannot both win.
func Transition(from, to Phase) error {
	for _, p := range allowed[from] {
		if p == to {
			return nil
		}
	}
	return fmt.Errorf("%w: %s → %s", ErrIllegalTransition, from, to)
}

// Terminal reports whether no further transitions are possible.
func Terminal(p Phase) bool {
	_, ok := allowed[p]
	return !ok
}
