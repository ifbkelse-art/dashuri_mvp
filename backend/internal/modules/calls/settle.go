package calls

import (
	"context"
	"errors"
	"log/slog"
	"slices"
	"time"

	"dashuri/backend/internal/modules/ledger"
)

// terminate moves a call to a terminal phase and settles it, in ONE
// transaction: lock the call row, compute billable seconds from the
// provider timeline, charge (capped by reservation and balance), post the
// ledger entry, insert calls.settlements, close the reservation, grant XP
// and write the call row. A call that is already terminal is returned
// unchanged (idempotent: concurrent /end and the stale-call job settle once).
// onlyFrom, when given, restricts the phases the call may be in.
func (s *Service) terminate(ctx context.Context, id string, to Phase, reason string, endProvider bool, onlyFrom ...Phase) (Call, bool, error) {
	var out Call
	changed := false
	err := s.deps.Repo.InTx(ctx, func(tx Tx) error {
		c, err := tx.LockCall(id)
		if err != nil {
			return err
		}
		out = c
		if Terminal(c.Phase) {
			return nil
		}
		if len(onlyFrom) > 0 && !slices.Contains(onlyFrom, c.Phase) {
			return ErrIllegalTransition
		}
		target := to
		if c.Phase == Requested && to == Ended {
			target = Failed
		}
		if err := Transition(c.Phase, target); err != nil {
			return err
		}
		out, err = s.settleTx(tx, c, target, reason, s.now())
		changed = err == nil
		return err
	})
	if err != nil {
		changed = false
		return out, false, err
	}
	if changed {
		if endProvider && reason != "provider_error" {
			if err := s.deps.Video.EndCall(ctx, out.ProviderCallID); err != nil {
				slog.WarnContext(ctx, "video provider end call", "err", err)
			}
		}
		s.publishCall(ctx, out)
		if reason == "moderation" {
			s.publish(ctx, "call:"+out.ID, "call.moderation_ended", map[string]any{"call_id": out.ID})
		}
	}
	return out, changed, nil
}

func (s *Service) settleTx(tx Tx, c Call, to Phase, reason string, now time.Time) (Call, error) {
	r := s.deps.Rules
	var billable int64
	if to == Ended {
		events, err := tx.MediaEvents(c.ID)
		if err != nil {
			return c, err
		}
		billable = BillableSeconds(Timeline(events, c.CallerID, c.ReceiverID), now, r.InterruptionThreshold)
		if c.IsFreeCall {
			billable = min(billable, r.FreeCallSeconds)
		}
	}
	var charged, beans int64
	var entryID *string
	if !c.IsFreeCall {
		res, found, err := tx.LockReservation(c.ID)
		if err != nil {
			return c, err
		}
		if billable > 0 && found {
			promo, purchased, err := tx.LockDiamonds(c.CallerID)
			if err != nil {
				return c, err
			}
			ch, err := ComputeCharge(r, c.RatePerMinute, billable, res.Amount, promo, purchased)
			if err != nil {
				return c, err
			}
			if ch.Diamonds > 0 {
				e, err := ledger.CallSettlement(ledger.CallCharge{
					CallID: c.ID, CustomerID: c.CallerID, HostID: c.ReceiverID,
					FromPromotional: ch.FromPromotional, FromPurchased: ch.FromPurchased, HostBeans: ch.HostBeans,
					RuleSetVersion: c.RuleSetVersion, At: now,
				})
				if err != nil {
					return c, err
				}
				id, _, err := tx.PostEntry(e)
				if err != nil {
					return c, err
				}
				entryID, charged, beans = &id, ch.Diamonds, ch.HostBeans
				if beans > 0 {
					if err := tx.GrantXP(c.ReceiverID, "bean_earning", "call:"+c.ID, beans*r.XPBeanWeight); err != nil {
						return c, err
					}
				}
			}
		}
		if found && res.Status == "active" {
			status := "released"
			if charged > 0 {
				status = "settled"
			}
			if err := tx.CloseReservation(c.ID, status); err != nil {
				return c, err
			}
		}
	} else {
		wasActive := c.ConnectedAt != nil || billable > 0
		if to == Ended && wasActive && !c.FreeCallCompensated {
			b, err := s.compensate(tx, c, now)
			if err != nil {
				return c, err
			}
			beans = b
		}
		if !wasActive {
			if err := tx.ReleaseFreeCard(c.ID); err != nil {
				return c, err
			}
		}
	}
	if err := tx.InsertSettlement(Settlement{CallID: c.ID, EntryID: entryID, BilledSeconds: billable, DiamondsCharged: charged, BeansEarned: beans}); err != nil {
		return c, err
	}
	ok, err := tx.UpdatePhase(c.ID, c.Phase, to, PhaseUpdate{
		EndedAt: &now, EndReason: &reason, BilledSeconds: &billable, DiamondsCharged: &charged,
	})
	if err != nil {
		return c, err
	}
	if !ok {
		return c, ErrIllegalTransition
	}
	c.Phase, c.EndedAt, c.EndReason, c.BilledSeconds, c.DiamondsCharged = to, &now, &reason, &billable, &charged
	return c, nil
}

// compensate posts FreeCallCompensation (₹10 = 2,000 Beans) once per free call.
func (s *Service) compensate(tx Tx, c Call, now time.Time) (int64, error) {
	r := s.deps.Rules
	beans := r.BeansForPaise(r.FreeCallHostCompPaise)
	if beans <= 0 {
		return 0, nil
	}
	if _, _, err := tx.PostEntry(ledger.FreeCallCompensation(c.ID, c.ReceiverID, beans, c.RuleSetVersion, now)); err != nil {
		return 0, err
	}
	if err := tx.MarkFreeCallCompensated(c.ID); err != nil {
		return 0, err
	}
	if err := tx.GrantXP(c.ReceiverID, "bean_earning", "free_call:"+c.ID, beans*r.XPBeanWeight); err != nil {
		return 0, err
	}
	return beans, nil
}

// evaluate recomputes a live call from its provider timeline: connecting →
// active (billing starts; moderation window opens), active ↔ paused,
// reservation extension, the low-balance warning, the free-call cap and the
// stale timeout. Ending the call happens after the transaction commits.
func (s *Service) evaluate(ctx context.Context, id string, now time.Time) error {
	r := s.deps.Rules
	var (
		publish    bool
		lowBalance int64 = -1
		endReason  string
		snapshot   Call
	)
	err := s.deps.Repo.InTx(ctx, func(tx Tx) error {
		c, err := tx.LockCall(id)
		if err != nil {
			return err
		}
		if Terminal(c.Phase) {
			return nil
		}
		events, err := tx.MediaEvents(c.ID)
		if err != nil {
			return err
		}
		changes := Timeline(events, c.CallerID, c.ReceiverID)
		live, since := CurrentState(changes)
		switch c.Phase {
		case Accepted, Connecting:
			if first, ok := FirstLive(changes); ok && live {
				if err := Transition(Connecting, Active); err != nil {
					return err
				}
				win := first.Add(ModerationWindow)
				ok, err := tx.UpdatePhase(c.ID, c.Phase, Active, PhaseUpdate{ConnectedAt: &first, ModerationWindowEndsAt: &win})
				if err != nil {
					return err
				}
				if ok {
					c.Phase, c.ConnectedAt, c.ModerationWindowEndsAt, publish = Active, &first, &win, true
				}
			}
		case Active:
			if !live && now.Sub(since) >= r.InterruptionThreshold {
				if ok, err := tx.UpdatePhase(c.ID, Active, Paused, PhaseUpdate{}); err != nil {
					return err
				} else if ok {
					c.Phase, publish = Paused, true
				}
			}
		case Paused:
			if live {
				if ok, err := tx.UpdatePhase(c.ID, Paused, Active, PhaseUpdate{}); err != nil {
					return err
				} else if ok {
					c.Phase, publish = Active, true
				}
			}
		}
		snapshot = c
		if c.Phase != Active && c.Phase != Paused {
			return nil
		}
		billable := BillableSeconds(changes, now, r.InterruptionThreshold)
		if !live {
			last := since
			if c.LastEventAt != nil && c.LastEventAt.After(last) {
				last = *c.LastEventAt
			}
			if now.Sub(last) >= StaleTimeout {
				endReason = "timeout"
				return nil
			}
		}
		if c.IsFreeCall {
			if billable >= r.FreeCallSeconds {
				if !c.FreeCallCompensated {
					if _, err := s.compensate(tx, c, now); err != nil {
						return err
					}
				}
				endReason = "free_call_limit"
			}
			return nil
		}
		if c.Phase != Active {
			return nil
		}
		res, found, err := tx.LockReservation(c.ID)
		if err != nil {
			return err
		}
		promo, purchased, err := tx.LockDiamonds(c.CallerID)
		if err != nil {
			return err
		}
		total := promo + purchased
		due := r.DiamondsForSeconds(c.RatePerMinute, billable)
		remaining := total - due
		secondsLeft := r.SecondsAffordable(remaining, c.RatePerMinute)
		if secondsLeft <= 0 {
			endReason = "low_balance"
			return nil
		}
		if found && res.Status == "active" && res.Amount < total &&
			res.Amount-due < r.DiamondsForSeconds(c.RatePerMinute, r.MinStartBalanceSeconds) {
			next := min(total, res.Amount+r.DiamondsForSeconds(c.RatePerMinute, ReservationWindow))
			if err := tx.SetReservationAmount(c.ID, next); err != nil {
				return err
			}
		}
		if secondsLeft <= r.LowBalanceWarnSeconds && c.LowBalanceNotifiedAt == nil {
			if err := tx.SetLowBalanceNotified(c.ID, now); err != nil {
				return err
			}
			lowBalance = secondsLeft
		}
		return nil
	})
	if err != nil {
		return err
	}
	if publish {
		s.publishCall(ctx, snapshot)
	}
	if lowBalance >= 0 {
		s.publish(ctx, "call:"+id, "call.low_balance", map[string]int64{"seconds_remaining": lowBalance})
	}
	if endReason != "" {
		_, _, err := s.terminate(ctx, id, Ended, endReason, true, Active, Paused)
		if errors.Is(err, ErrIllegalTransition) {
			return nil
		}
		return err
	}
	return nil
}

// SweepResult counts what one sweep changed.
type SweepResult struct {
	Examined, Missed, Failed, Ended, Evaluated int
}

// Sweep is one pass of the settle-stale-calls job: ringing > 30 s → missed;
// accepted but not active within 45 s → failed (no charge); active/paused
// calls are re-evaluated (pause, reservation, low balance, free-call cap) and
// ended when nobody has been live for 90 s.
func (s *Service) Sweep(ctx context.Context, now time.Time) (SweepResult, error) {
	var res SweepResult
	if err := s.ready(); err != nil {
		return res, err
	}
	live, err := s.deps.Repo.LiveCalls(ctx, 500)
	if err != nil {
		return res, err
	}
	for _, c := range live {
		res.Examined++
		var err error
		switch c.Phase {
		case Requested:
			if now.Sub(c.CreatedAt) > RingTimeout {
				_, _, err = s.terminate(ctx, c.ID, Failed, "provider_error", false, Requested)
				res.Failed++
			}
		case Ringing:
			if now.Sub(c.CreatedAt) > RingTimeout {
				var changed bool
				_, changed, err = s.terminate(ctx, c.ID, Missed, "missed", true, Ringing)
				if changed {
					res.Missed++
				}
			}
		case Accepted, Connecting:
			if err = s.evaluate(ctx, c.ID, now); err != nil {
				break
			}
			started := c.CreatedAt
			if c.AcceptedAt != nil {
				started = *c.AcceptedAt
			}
			if now.Sub(started) > ConnectTimeout {
				var changed bool
				_, changed, err = s.terminate(ctx, c.ID, Failed, "connect_timeout", true, Accepted, Connecting)
				if errors.Is(err, ErrIllegalTransition) {
					err = nil // became active meanwhile
				}
				if changed {
					res.Failed++
				}
			}
		case Active, Paused:
			err = s.evaluate(ctx, c.ID, now)
			res.Evaluated++
		case Ending:
			var changed bool
			_, changed, err = s.terminate(ctx, c.ID, Ended, "server_end", true, Ending)
			if changed {
				res.Ended++
			}
		}
		if err != nil {
			slog.ErrorContext(ctx, "sweep call", "call_id", c.ID, "err", err)
		}
	}
	return res, nil
}
