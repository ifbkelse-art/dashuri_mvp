package calls

import (
	"sort"
	"time"
)

// LiveChange is a server-observed change in whether BOTH participants are
// connected with media flowing, derived from the video provider's webhooks
// (participant joined/left, track published/unpublished). Client reports are
// never inputs here.
type LiveChange struct {
	At       time.Time
	BothLive bool
}

// BillableSeconds computes billable time from the server timeline.
//
//   - Billing starts at the first moment both streams are live (S6).
//   - A gap shorter than `threshold` is treated as continuous (brief network
//     blips are billed); a gap of `threshold` or longer is a qualifying
//     interruption and is excluded entirely (billing paused, then resumed).
//   - Billing stops at `end` (hang-up, low balance, server timeout).
//
// Result is whole seconds, rounded down (customer's favour).
func BillableSeconds(changes []LiveChange, end time.Time, threshold time.Duration) int64 {
	if len(changes) == 0 {
		return 0
	}
	cs := append([]LiveChange(nil), changes...)
	sort.SliceStable(cs, func(i, j int) bool { return cs[i].At.Before(cs[j].At) })

	var total time.Duration
	var liveSince, gapSince time.Time
	live := false
	for _, c := range cs {
		if c.At.After(end) {
			break
		}
		switch {
		case c.BothLive && !live:
			if !gapSince.IsZero() && c.At.Sub(gapSince) < threshold {
				total += c.At.Sub(gapSince) // short blip: billed
			}
			live, liveSince, gapSince = true, c.At, time.Time{}
		case !c.BothLive && live:
			total += c.At.Sub(liveSince)
			live, gapSince = false, c.At
		}
	}
	if live && end.After(liveSince) {
		total += end.Sub(liveSince)
	}
	return int64(total / time.Second)
}
