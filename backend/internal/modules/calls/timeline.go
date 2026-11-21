package calls

import (
	"sort"
	"time"

	"dashuri/backend/internal/modules/economy"
)

// Timeline derives the "both participants live with video" timeline from
// stored provider events.
//
// A participant is live while joined and publishing video. If the provider
// sent no track events at all for this call (Stream does not always deliver
// track webhooks), joining counts as publishing; once any track event exists
// for the call, video must be explicitly published. A call_ended event makes
// both participants not live.
func Timeline(events []MediaEvent, a, b string) []LiveChange {
	es := append([]MediaEvent(nil), events...)
	sort.SliceStable(es, func(i, j int) bool { return es[i].At.Before(es[j].At) })
	trackEvents := false
	for _, e := range es {
		if e.Kind == EventVideoPublished || e.Kind == EventVideoUnpublished {
			trackEvents = true
			break
		}
	}
	type state struct {
		joined bool
		video  int // 0 unknown, 1 on, -1 off
	}
	st := map[string]*state{a: {}, b: {}}
	live := func(s *state) bool {
		return s.joined && (s.video == 1 || (s.video == 0 && !trackEvents))
	}
	var out []LiveChange
	both := false
	for _, e := range es {
		if e.Kind == EventCallEnded {
			st[a].joined, st[b].joined = false, false
		} else if s, ok := st[e.UserID]; ok {
			switch e.Kind {
			case EventJoined:
				s.joined = true
			case EventLeft:
				s.joined, s.video = false, 0
			case EventVideoPublished:
				s.video = 1
				s.joined = true // publishing implies presence
			case EventVideoUnpublished:
				s.video = -1
			}
		}
		now := live(st[a]) && live(st[b])
		if now != both {
			out = append(out, LiveChange{At: e.At, BothLive: now})
			both = now
		}
	}
	return out
}

// FirstLive returns the first moment both participants were live.
func FirstLive(changes []LiveChange) (time.Time, bool) {
	for _, c := range changes {
		if c.BothLive {
			return c.At, true
		}
	}
	return time.Time{}, false
}

// CurrentState returns whether both are live after the last change, and since when.
func CurrentState(changes []LiveChange) (live bool, since time.Time) {
	if len(changes) == 0 {
		return false, time.Time{}
	}
	last := changes[len(changes)-1]
	return last.BothLive, last.At
}

// SplitSpend splits a charge between the promotional and purchased buckets
// following the configured spend order ("promotional_first" or
// "purchased_first"). The caller guarantees total <= promo + purchased.
func SplitSpend(total, promo, purchased int64, order string) (fromPromo, fromPurchased int64) {
	if total <= 0 {
		return 0, 0
	}
	if order == "purchased_first" {
		fromPurchased = min(total, purchased)
		return total - fromPurchased, fromPurchased
	}
	fromPromo = min(total, promo)
	return fromPromo, total - fromPromo
}

// Charge is the settlement outcome of a paid call.
type Charge struct {
	BillableSeconds int64
	Diamonds        int64 // charged, after caps
	FromPromotional int64
	FromPurchased   int64
	HostBeans       int64
}

// ComputeCharge prices billable seconds at the snapshotted rate, rounds down
// once, caps the amount by the reservation and the balance, splits it by the
// spend order and converts the total to Beans once.
func ComputeCharge(r economy.Rules, rate, billable, reserved, promo, purchased int64) (Charge, error) {
	d := r.DiamondsForSeconds(rate, billable)
	d = min(d, reserved, promo+purchased)
	if d < 0 {
		d = 0
	}
	fp, fu := SplitSpend(d, promo, purchased, r.SpendOrder)
	beans, err := r.BeansForDiamonds(d)
	if err != nil {
		return Charge{}, err
	}
	return Charge{BillableSeconds: billable, Diamonds: d, FromPromotional: fp, FromPurchased: fu, HostBeans: beans}, nil
}
