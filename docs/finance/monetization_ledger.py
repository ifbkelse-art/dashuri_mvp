"""Reference ledger for the approved-for-modelling 5:4 rule (documentation only).

This is an executable specification, NOT application code. It shows how the
Go backend could credit 4 Beans per 5 Diamonds exactly, carry the fractional
remainder, and reverse a call's entitlement idempotently. All quantities are
integers; rupees appear only in `reserve()` as exact Fractions.

Units
  Diamonds (D)  int
  Beans (B)     int, whole Beans in held / available / pending / paid
  fifths        int, 1 fifth = 1/5 Bean. A call charging D creates 4*D fifths.

Core identity per host (checked by check_invariants):
  5 * (held + available + pending + paid - receivable) + carry
      == 4 * sum over the host's calls of (charged_D - reversed_D)
  with 0 <= carry <= 4.

Design choices (each is a proposal in the decision pack, section 8):
  * Settlement credit = floor(T_after/5) - floor(T_before/5), where T is the
    host's total entitlement in fifths. The carry is T mod 5.
  * A reversal removes only that call's own fifths (bounded by its charge).
    The Beans clawed back are floor(T_before/5) - floor(T_after/5): the exact
    drop in the host's whole-Bean entitlement caused by that call alone.
  * Clawback is recovered from (1) the call's own held Beans, (2) the host's
    available Beans, (3) a receivable, in that order, each as its own posting.
    It never takes another call's held Beans.
  * A receivable is offset against future releases and blocks withdrawals.
  * Withdrawals already in a payout cycle are not touched; a reversal that
    cannot be recovered becomes a receivable.
"""
from __future__ import annotations

import threading
from dataclasses import dataclass, field
from fractions import Fraction as F

RS_PER_BEAN = F(5, 1000)          # Rs0.005
RS_PER_D_HOST = F(4, 1000)        # Rs0.004 (= 4/5 * 0.005)


class LedgerError(Exception):
    pass


class IdempotencyConflict(LedgerError):
    """Same idempotency key, different payload."""


class ReversalExceedsCharge(LedgerError):
    pass


class InsufficientDiamonds(LedgerError):
    pass


class WithdrawalBlocked(LedgerError):
    pass


@dataclass
class Lot:
    lot_id: str
    caller: str
    kind: str                 # "purchased" | "promotional"
    original: int
    remaining: int
    paise: int = 0            # price paid (0 for promotional)
    expires_day: int | None = None
    charged_back: bool = False


@dataclass
class Funding:
    lot_id: str
    used: int
    returned: int = 0         # given back to the caller (dispute)
    cb_reversed: int = 0      # reversed by a chargeback of the lot (not returned)

    @property
    def net(self) -> int:
        return self.used - self.returned - self.cb_reversed


@dataclass
class Call:
    call_id: str
    caller: str
    host: str
    diamonds: int
    day: int
    funding: list[Funding]
    credited: int             # Beans credited at settlement
    reversed_d: int = 0


@dataclass
class Host:
    carry: int = 0                                        # fifths, 0..4
    fifths: int = 0                                       # total entitlement in fifths (sum 4*(charged-reversed))
    held: dict[str, int] = field(default_factory=dict)    # call_id -> held Beans
    release_day: dict[str, int] = field(default_factory=dict)
    available: int = 0
    pending: int = 0
    paid: int = 0
    receivable: int = 0


class Ledger:
    def __init__(self, hold_days: int = 14, min_withdrawal: int = 100_000):
        self.hold_days = hold_days
        self.min_withdrawal = min_withdrawal
        self.lots: dict[str, Lot] = {}
        self.calls: dict[str, Call] = {}
        self.hosts: dict[str, Host] = {}
        self.keys: dict[str, tuple] = {}          # idempotency key -> payload
        self.results: dict[str, object] = {}      # idempotency key -> stored result
        self.withdrawals: dict[str, tuple[str, int, str]] = {}  # id -> (host, beans, state)
        self.postings: list[tuple] = []           # audit trail
        # system counters (Diamonds)
        self.d_issued = 0
        self.d_consumed = 0
        self.d_returned = 0
        self.d_cb_spent = 0
        self.d_cb_unspent = 0
        self.d_expired = 0
        self.lock = threading.Lock()              # stands in for DB transactions + row locks

    # ------------------------------------------------------------ helpers
    def _idem(self, key: str, payload: tuple):
        """Return (True, stored result) for an exact replay; raise on a conflicting payload."""
        if key in self.keys:
            if self.keys[key] != payload:
                raise IdempotencyConflict(f"{key}: stored {self.keys[key]} != new {payload}")
            return True, self.results[key]
        return False, None

    def _store(self, key: str, payload: tuple, result):
        self.keys[key] = payload
        self.results[key] = result
        return result

    def _host(self, host_id: str) -> Host:
        return self.hosts.setdefault(host_id, Host())

    def _post(self, *entry):
        self.postings.append(entry)

    # ------------------------------------------------------------ Diamonds
    def purchase(self, purchase_id: str, caller: str, diamonds: int, paise: int) -> Lot:
        with self.lock:
            key, payload = f"purchase:{purchase_id}", (caller, diamonds, paise)
            replay, res = self._idem(key, payload)
            if replay:
                return res
            lot = Lot(purchase_id, caller, "purchased", diamonds, diamonds, paise)
            self.lots[purchase_id] = lot
            self.d_issued += diamonds
            self._post("PurchaseCredit", purchase_id, caller, diamonds)
            return self._store(key, payload, lot)

    def grant_promo(self, grant_id: str, caller: str, diamonds: int, expires_day: int) -> Lot:
        with self.lock:
            key, payload = f"promo:{grant_id}", (caller, diamonds, expires_day)
            replay, res = self._idem(key, payload)
            if replay:
                return res
            lot = Lot(grant_id, caller, "promotional", diamonds, diamonds, 0, expires_day)
            self.lots[grant_id] = lot
            self.d_issued += diamonds
            self._post("PromoGrant", grant_id, caller, diamonds)
            return self._store(key, payload, lot)

    def balance(self, caller: str, kind: str | None = None) -> int:
        return sum(l.remaining for l in self.lots.values() if l.caller == caller and (kind is None or l.kind == kind))

    def expire(self, day: int):
        with self.lock:
            for lot in self.lots.values():
                if lot.kind == "promotional" and lot.expires_day is not None and day >= lot.expires_day and lot.remaining:
                    self.d_expired += lot.remaining
                    self._post("PromoExpiry", lot.lot_id, lot.remaining)
                    lot.remaining = 0

    # ------------------------------------------------------------ settlement
    def settle(self, call_id: str, caller: str, host_id: str, diamonds: int, day: int) -> int:
        """Charge the caller and credit the host exactly once per call id. Returns Beans credited."""
        if diamonds < 0:
            raise LedgerError("negative charge")
        with self.lock:
            key, payload = f"call_settlement:{call_id}", (caller, host_id, diamonds)
            replay, res = self._idem(key, payload)
            if replay:
                return res
            if self.balance(caller) < diamonds:
                raise InsufficientDiamonds(call_id)
            # spend promotional (earliest expiry) first, then purchased FIFO
            order = sorted((l for l in self.lots.values() if l.caller == caller and l.remaining),
                           key=lambda l: (l.kind != "promotional", l.expires_day or 0, l.lot_id))
            need, funding = diamonds, []
            for lot in order:
                take = min(need, lot.remaining)
                if take:
                    lot.remaining -= take
                    funding.append(Funding(lot.lot_id, take))
                    need -= take
                if need == 0:
                    break
            self.d_consumed += diamonds
            h = self._host(host_id)
            t_before, t_after = h.fifths, h.fifths + 4 * diamonds
            credit = t_after // 5 - t_before // 5
            h.fifths, h.carry = t_after, t_after % 5
            h.held[call_id] = h.held.get(call_id, 0) + credit
            h.release_day[call_id] = day + self.hold_days
            self.calls[call_id] = Call(call_id, caller, host_id, diamonds, day, funding, credit)
            self._post("CallSettlement", call_id, diamonds, credit, t_before % 5, h.carry)
            return self._store(key, payload, credit)

    # ------------------------------------------------------------ reversal
    def reverse(self, reversal_id: str, call_id: str, diamonds: int, *, return_to_caller: bool = True,
                _cb_lot: str | None = None) -> int:
        """Reverse `diamonds` of one call's charge. Idempotent on reversal_id. Returns Beans clawed back."""
        with self.lock:
            return self._reverse(reversal_id, call_id, diamonds, return_to_caller, _cb_lot)

    def _reverse(self, reversal_id, call_id, diamonds, return_to_caller, cb_lot):
        key, payload = f"reversal:{reversal_id}", (call_id, diamonds, return_to_caller, cb_lot)
        replay, res = self._idem(key, payload)
        if replay:
            return res
        call = self.calls.get(call_id)
        if call is None:
            raise LedgerError(f"unknown call {call_id}")
        if diamonds <= 0 or call.reversed_d + diamonds > call.diamonds:
            raise ReversalExceedsCharge(f"{call_id}: {call.reversed_d}+{diamonds} > {call.diamonds}")
        # caller side
        if cb_lot is not None:                     # chargeback: only Diamonds funded by that lot
            f = next(x for x in call.funding if x.lot_id == cb_lot)
            if diamonds > f.net:
                raise ReversalExceedsCharge(f"{call_id}: more than lot {cb_lot} funded")
            f.cb_reversed += diamonds
            self.d_cb_spent += diamonds
        elif return_to_caller:                     # dispute: give back, last-spent lot first
            left = diamonds
            for f in reversed(call.funding):
                give = min(left, f.net)
                if give:
                    f.returned += give
                    lot = self.lots[f.lot_id]
                    if lot.charged_back:           # never resurrect a charged-back purchase
                        self.d_cb_unspent += give
                    else:
                        lot.remaining += give
                    left -= give
                if left == 0:
                    break
            self.d_returned += diamonds
        else:
            raise LedgerError("a reversal either returns Diamonds or belongs to a chargeback")
        call.reversed_d += diamonds
        # host side
        h = self._host(call.host)
        t_before, t_after = h.fifths, h.fifths - 4 * diamonds
        claw = t_before // 5 - t_after // 5
        h.fifths, h.carry = t_after, t_after % 5
        left = claw
        own = min(left, h.held.get(call_id, 0))
        if own:
            h.held[call_id] -= own
            left -= own
            self._post("BeanClawback", reversal_id, "held:" + call_id, own)
        avail = min(left, h.available)
        if avail:
            h.available -= avail
            left -= avail
            self._post("BeanClawback", reversal_id, "available", avail)
        if left:
            h.receivable += left
            self._post("HostReceivable", reversal_id, left)
        self._post("CallReversal", reversal_id, call_id, diamonds, claw, h.carry)
        return self._store(key, payload, claw)

    def chargeback(self, cb_id: str, purchase_id: str) -> dict:
        """Reverse a purchase: remove its unspent Diamonds, reverse each call it funded."""
        with self.lock:
            key, payload = f"chargeback:{cb_id}", (purchase_id,)
            replay, res = self._idem(key, payload)
            if replay:
                return res
            lot = self.lots[purchase_id]
            unspent = lot.remaining
            lot.remaining = 0
            lot.charged_back = True
            self.d_cb_unspent += unspent
            clawed = 0
            spent = 0
            for call in self.calls.values():
                for f in call.funding:
                    if f.lot_id == purchase_id and f.net > 0:
                        d = f.net
                        spent += d
                        clawed += self._reverse(f"cb:{cb_id}:{call.call_id}", call.call_id, d, False, purchase_id)
            out = {"unspent_removed": unspent, "spent_reversed": spent, "beans_clawed": clawed,
                   "platform_loss_paise": lot.paise * spent // lot.original if lot.original else 0}
            self._post("PurchaseReversal", cb_id, purchase_id, unspent, spent)
            return self._store(key, payload, out)

    # ------------------------------------------------------------ Beans lifecycle
    def release(self, day: int):
        """Move held Beans past their hold to available, offsetting any receivable first."""
        with self.lock:
            for hid, h in self.hosts.items():
                for cid, beans in list(h.held.items()):
                    if beans and h.release_day[cid] <= day:
                        h.held[cid] = 0
                        offset = min(beans, h.receivable)
                        if offset:
                            h.receivable -= offset
                            self._post("ReceivableOffset", hid, cid, offset)
                        h.available += beans - offset
                        self._post("BeanRelease", hid, cid, beans - offset)

    def request_withdrawal(self, wid: str, host_id: str, beans: int) -> str:
        with self.lock:
            key, payload = f"withdrawal:{wid}", (host_id, beans)
            replay, res = self._idem(key, payload)
            if replay:
                return res
            h = self._host(host_id)
            if h.receivable:
                raise WithdrawalBlocked("open receivable")
            if beans < self.min_withdrawal or beans > h.available:
                raise WithdrawalBlocked("amount")
            h.available -= beans
            h.pending += beans
            self.withdrawals[wid] = (host_id, beans, "pending")
            return self._store(key, payload, "pending")

    def settle_payout(self, wid: str, paid: bool):
        with self.lock:
            host_id, beans, state = self.withdrawals[wid]
            if state != "pending":
                return state                        # idempotent
            h = self._host(host_id)
            h.pending -= beans
            if paid:
                h.paid += beans
            else:
                h.available += beans
            state = "paid" if paid else "failed"
            self.withdrawals[wid] = (host_id, beans, state)
            return state

    # ------------------------------------------------------------ checks
    def check_invariants(self):
        for hid, h in self.hosts.items():
            calls = [c for c in self.calls.values() if c.host == hid]
            ent = 4 * sum(c.diamonds - c.reversed_d for c in calls)
            issued = sum(h.held.values()) + h.available + h.pending + h.paid - h.receivable
            assert 0 <= h.carry <= 4, (hid, h.carry)
            assert h.fifths == ent, (hid, h.fifths, ent)
            assert 5 * issued + h.carry == ent, (hid, issued, h.carry, ent)
            assert min(h.available, h.pending, h.paid, h.receivable, *(h.held.values() or [0])) >= 0
        for c in self.calls.values():
            assert 0 <= c.reversed_d <= c.diamonds
            assert sum(f.net for f in c.funding) == c.diamonds - c.reversed_d
            assert all(f.net >= 0 for f in c.funding)
        balances = sum(l.remaining for l in self.lots.values())
        assert self.d_issued == balances + self.d_consumed - self.d_returned + self.d_expired + self.d_cb_unspent, "diamond conservation"
        net_host_d = sum(c.diamonds - c.reversed_d for c in self.calls.values())
        assert net_host_d == self.d_consumed - self.d_returned - self.d_cb_spent, "consumed vs host entitlement"
        assert all(l.remaining >= 0 for l in self.lots.values())

    def reserve(self, taxes_payable: F = F(0)) -> dict:
        """Cash the platform must hold before a payout cycle (rupees, exact)."""
        held = sum(sum(h.held.values()) for h in self.hosts.values())
        avail = sum(h.available for h in self.hosts.values())
        pend = sum(h.pending for h in self.hosts.values())
        carry = sum(h.carry for h in self.hosts.values())
        promo = sum(l.remaining for l in self.lots.values() if l.kind == "promotional")
        parts = {
            "beans_held": held * RS_PER_BEAN,
            "beans_available": avail * RS_PER_BEAN,
            "beans_payout_pending": pend * RS_PER_BEAN,
            "fractional_carry": F(carry, 5) * RS_PER_BEAN,
            "promo_diamonds_if_spent": promo * RS_PER_D_HOST,
            "taxes_payable": taxes_payable,
        }
        parts["total"] = sum(parts.values())
        return parts
