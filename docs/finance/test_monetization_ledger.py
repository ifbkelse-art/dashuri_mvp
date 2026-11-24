"""Tests for the 5:4 reference ledger (documentation only, not application code).

Run:  python3 -I -m unittest discover -s docs/finance -p 'test_*.py' -v
"""
import random
import threading
import unittest
from fractions import Fraction as F

from monetization_ledger import (IdempotencyConflict, InsufficientDiamonds, Ledger, ReversalExceedsCharge,
                                 WithdrawalBlocked)


def funded(ledger, caller="caller", diamonds=1_000_000, pid="p1", paise=None):
    ledger.purchase(pid, caller, diamonds, paise if paise is not None else diamonds * 2220 // 1000)
    return ledger


class Settlement(unittest.TestCase):
    def test_replay_same_payload_returns_original_result(self):
        lg = funded(Ledger())
        first = lg.settle("c1", "caller", "host", 4333, day=0)
        again = lg.settle("c1", "caller", "host", 4333, day=0)
        self.assertEqual(first, again)
        self.assertEqual(lg.hosts["host"].held["c1"], first)          # credited once
        self.assertEqual(lg.d_consumed, 4333)                          # charged once
        lg.check_invariants()

    def test_replay_different_payload_raises_conflict(self):
        lg = funded(Ledger())
        lg.settle("c1", "caller", "host", 4333, day=0)
        for bad in (("caller", "host", 4334), ("caller", "host2", 4333), ("caller2", "host", 4333)):
            with self.assertRaises(IdempotencyConflict):
                lg.settle("c1", bad[0], bad[1], bad[2], day=0)
        self.assertEqual(lg.d_consumed, 4333)
        lg.check_invariants()

    def test_fractional_carry_across_calls_is_exact(self):
        lg = funded(Ledger())
        charges = [4333, 2166, 1001, 7, 1, 1, 1, 1, 1]
        credits = [lg.settle(f"c{i}", "caller", "host", d, day=0) for i, d in enumerate(charges)]
        h = lg.hosts["host"]
        self.assertEqual(credits[:4], [3466, 1733, 801, 5])
        self.assertEqual(5 * sum(credits) + h.carry, 4 * sum(charges))   # nothing lost
        self.assertLessEqual(h.carry, 4)
        lg.check_invariants()

    def test_many_small_calls_lose_nothing(self):
        lg = funded(Ledger(), diamonds=10**9)
        total = 0
        for i in range(1, 2001):
            d = 500 * i // 60                                           # 500 D/min, i seconds
            if d:
                lg.settle(f"s{i}", "caller", "host", d, day=0)
                total += d
        h = lg.hosts["host"]
        self.assertEqual(5 * sum(h.held.values()) + h.carry, 4 * total)
        lg.check_invariants()

    def test_insufficient_balance_refused(self):
        lg = funded(Ledger(), diamonds=100)
        with self.assertRaises(InsufficientDiamonds):
            lg.settle("c1", "caller", "host", 101, day=0)
        lg.check_invariants()

    def test_promo_spent_first_and_host_earns_on_it(self):
        lg = funded(Ledger(), diamonds=1000)
        lg.grant_promo("g1", "caller", 500, expires_day=30)
        lg.settle("c1", "caller", "host", 700, day=0)
        self.assertEqual(lg.balance("caller", "promotional"), 0)
        self.assertEqual(lg.balance("caller", "purchased"), 800)
        self.assertEqual(lg.hosts["host"].held["c1"], 560)
        lg.check_invariants()


class Reversal(unittest.TestCase):
    def setUp(self):
        self.lg = funded(Ledger())
        self.lg.settle("c1", "caller", "host", 4333, day=0)     # 3466 B, carry 2
        self.lg.settle("c2", "caller", "host", 2166, day=0)     # 1733 B, carry 1

    def test_full_reversal(self):
        lg = self.lg
        before_bal = lg.balance("caller")
        claw = lg.reverse("r1", "c2", 2166)
        self.assertEqual(claw, 1733)
        self.assertEqual(lg.hosts["host"].held["c2"], 0)
        self.assertEqual(lg.hosts["host"].held["c1"], 3466)     # other call untouched
        self.assertEqual(lg.hosts["host"].carry, 2)              # back to state after c1
        self.assertEqual(lg.balance("caller"), before_bal + 2166)
        lg.check_invariants()

    def test_partial_reversals_are_cumulative_and_bounded(self):
        lg = self.lg
        held_c2 = lg.hosts["host"].held["c2"]
        a = lg.reverse("r1", "c1", 1000)
        b = lg.reverse("r2", "c1", 3333)
        # c1 alone was worth 4*4333/5 = 3466.4 Beans. Its 2/5 carry helped complete one of c2's
        # whole Beans, so removing c1 entirely lowers the host's whole-Bean entitlement by
        # floor(25996/5) - floor(8664/5) = 5199 - 1732 = 3467, i.e. ceil(4D/5). Never more.
        self.assertEqual(a + b, 5199 - 1732)
        self.assertLessEqual(a + b, -(-4 * 4333 // 5))
        self.assertEqual(lg.hosts["host"].held["c2"], held_c2)   # c2's held Beans untouched
        self.assertEqual(lg.hosts["host"].receivable, 1)         # the extra Bean is an explicit receivable
        with self.assertRaises(ReversalExceedsCharge):
            lg.reverse("r3", "c1", 1)
        lg.check_invariants()

    def test_duplicate_reversal_is_noop_and_conflict_detected(self):
        lg = self.lg
        a = lg.reverse("r1", "c1", 1000)
        self.assertEqual(lg.reverse("r1", "c1", 1000), a)
        self.assertEqual(lg.calls["c1"].reversed_d, 1000)
        with self.assertRaises(IdempotencyConflict):
            lg.reverse("r1", "c1", 999)
        lg.check_invariants()

    def test_over_reversal_refused(self):
        with self.assertRaises(ReversalExceedsCharge):
            self.lg.reverse("r1", "c2", 2167)
        with self.assertRaises(ReversalExceedsCharge):
            self.lg.reverse("r2", "c2", 0)
        self.lg.check_invariants()

    def test_reversal_after_subsequent_settlements_touches_only_that_call(self):
        lg = self.lg
        lg.settle("c3", "caller", "host", 1001, day=1)
        lg.settle("c4", "caller", "host", 7, day=1)
        held_before = dict(lg.hosts["host"].held)
        claw = lg.reverse("r1", "c1", 4333)
        h = lg.hosts["host"]
        self.assertIn(claw, (3466, 3467))                        # exact drop; may differ by 1 from c1's own credit
        for cid in ("c2", "c3", "c4"):
            self.assertEqual(h.held[cid], held_before[cid])      # unrelated calls never touched
        if claw > held_before["c1"]:
            self.assertEqual(h.receivable, claw - held_before["c1"])
        lg.check_invariants()

    def test_reverse_then_resettle_restores_state(self):
        lg = self.lg
        snap = (lg.hosts["host"].fifths, lg.hosts["host"].carry)
        lg.reverse("r1", "c2", 2166)
        lg.settle("c2b", "caller", "host", 2166, day=0)
        self.assertEqual((lg.hosts["host"].fifths, lg.hosts["host"].carry), snap)
        lg.check_invariants()


class AfterRelease(unittest.TestCase):
    def test_reversal_after_release_claws_available(self):
        lg = funded(Ledger(hold_days=14))
        lg.settle("c1", "caller", "host", 200_000, day=0)        # 160,000 B
        lg.release(day=14)
        h = lg.hosts["host"]
        self.assertEqual((h.held["c1"], h.available), (0, 160_000))
        claw = lg.reverse("r1", "c1", 50_000)
        self.assertEqual(claw, 40_000)
        self.assertEqual((h.available, h.receivable), (120_000, 0))
        lg.check_invariants()

    def test_reversal_after_payout_creates_receivable_offset_by_future_earnings(self):
        lg = funded(Ledger(hold_days=14), diamonds=10**7)
        lg.settle("c1", "caller", "host", 125_000, day=0)        # 100,000 B
        lg.release(day=14)
        lg.request_withdrawal("w1", "host", 100_000)
        self.assertEqual(lg.settle_payout("w1", paid=True), "paid")
        claw = lg.reverse("r1", "c1", 125_000)
        h = lg.hosts["host"]
        self.assertEqual((claw, h.receivable, h.paid), (100_000, 100_000, 100_000))
        lg.check_invariants()
        lg.settle("c2", "caller", "host", 200_000, day=20)       # 160,000 B
        with self.assertRaises(WithdrawalBlocked):
            lg.request_withdrawal("w2", "host", 100_000)
        lg.release(day=34)
        self.assertEqual((h.receivable, h.available), (0, 60_000))
        lg.check_invariants()

    def test_failed_payout_returns_to_available(self):
        lg = funded(Ledger())
        lg.settle("c1", "caller", "host", 125_000, day=0)
        lg.release(day=14)
        lg.request_withdrawal("w1", "host", 100_000)
        self.assertEqual(lg.settle_payout("w1", paid=False), "failed")
        self.assertEqual(lg.settle_payout("w1", paid=True), "failed")   # idempotent
        self.assertEqual(lg.hosts["host"].available, 100_000)
        lg.check_invariants()


class RefundsAndChargebacks(unittest.TestCase):
    def test_chargeback_reconciles_unspent_spent_and_beans(self):
        lg = Ledger()
        lg.purchase("p1", "caller", 54_000, 119_900)
        lg.purchase("p2", "caller", 12_500, 29_900)
        lg.settle("c1", "caller", "hostA", 30_000, day=0)        # from p1
        lg.settle("c2", "caller", "hostB", 30_000, day=0)        # 24,000 from p1, 6,000 from p2
        out = lg.chargeback("cb1", "p1")
        self.assertEqual(out["unspent_removed"], 0)
        self.assertEqual(out["spent_reversed"], 54_000)
        self.assertEqual(lg.hosts["hostA"].held["c1"], 0)
        self.assertEqual(lg.calls["c2"].reversed_d, 24_000)
        self.assertEqual(lg.hosts["hostB"].held["c2"], 4_800)    # only p2's 6,000 D remain earned
        self.assertEqual(lg.chargeback("cb1", "p1"), out)        # idempotent
        self.assertEqual(lg.balance("caller"), 6_500)            # p2 left untouched
        self.assertEqual(out["platform_loss_paise"], 119_900)
        lg.check_invariants()

    def test_refund_before_use_removes_unspent_only(self):
        lg = Ledger()
        lg.purchase("p1", "caller", 54_000, 119_900)
        lg.settle("c1", "caller", "host", 4_000, day=0)
        out = lg.chargeback("rf1", "p1")
        self.assertEqual((out["unspent_removed"], out["spent_reversed"]), (50_000, 4_000))
        lg.check_invariants()

    def test_dispute_then_chargeback_never_resurrects_diamonds(self):
        lg = Ledger()
        lg.purchase("p1", "caller", 10_000, 22_200)
        lg.settle("c1", "caller", "host", 6_000, day=0)
        lg.reverse("d1", "c1", 1_000)                            # dispute returns 1,000 D to p1
        out = lg.chargeback("cb1", "p1")
        self.assertEqual(out["unspent_removed"], 5_000)
        self.assertEqual(out["spent_reversed"], 5_000)
        with self.assertRaises(ReversalExceedsCharge):
            lg.reverse("d2", "c1", 1)
        self.assertEqual(lg.balance("caller"), 0)
        lg.check_invariants()

    def test_promo_expiry(self):
        lg = Ledger()
        lg.grant_promo("g1", "caller", 500, expires_day=30)
        lg.settle("c1", "caller", "host", 200, day=0)
        lg.expire(day=30)
        self.assertEqual(lg.balance("caller"), 0)
        self.assertEqual(lg.d_expired, 300)
        lg.check_invariants()


class Concurrency(unittest.TestCase):
    def test_concurrent_duplicate_settlements_credit_once(self):
        lg = funded(Ledger())
        results, errors = [], []

        def worker():
            try:
                results.append(lg.settle("c1", "caller", "host", 4333, day=0))
            except Exception as e:      # pragma: no cover
                errors.append(e)
        threads = [threading.Thread(target=worker) for _ in range(32)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        self.assertEqual(errors, [])
        self.assertEqual(set(results), {3466})
        self.assertEqual(lg.d_consumed, 4333)
        lg.check_invariants()

    def test_concurrent_distinct_settlements_and_reversals(self):
        lg = funded(Ledger(), diamonds=10**8)
        charges = {f"c{i}": 1000 + 37 * i for i in range(200)}

        def settle(cid, d):
            lg.settle(cid, "caller", f"h{int(cid[1:]) % 3}", d, day=0)
        threads = [threading.Thread(target=settle, args=kv) for kv in charges.items()]
        threads += [threading.Thread(target=settle, args=kv) for kv in list(charges.items())[:50]]  # duplicates
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        self.assertEqual(lg.d_consumed, sum(charges.values()))
        rev = [threading.Thread(target=lg.reverse, args=(f"r{i}", f"c{i}", 500)) for i in range(0, 200, 2)]
        rev += [threading.Thread(target=lg.reverse, args=(f"r{i}", f"c{i}", 500)) for i in range(0, 200, 2)]
        for t in rev:
            t.start()
        for t in rev:
            t.join()
        self.assertEqual(sum(c.reversed_d for c in lg.calls.values()), 100 * 500)
        lg.check_invariants()


class RandomisedInvariants(unittest.TestCase):
    def test_random_operation_sequences_keep_invariants(self):
        for seed in range(25):
            rng = random.Random(seed)
            lg = Ledger(hold_days=rng.choice([7, 14]))
            pid = 0
            day = 0
            for step in range(400):
                op = rng.random()
                caller = f"u{rng.randrange(3)}"
                try:
                    if op < 0.15:
                        pid += 1
                        lg.purchase(f"p{pid}", caller, rng.randrange(1, 60_000), rng.randrange(100, 600_000))
                    elif op < 0.2:
                        pid += 1
                        lg.grant_promo(f"g{pid}", caller, rng.randrange(1, 5_000), day + 30)
                    elif op < 0.6:
                        lg.settle(f"c{step}", caller, f"h{rng.randrange(3)}", rng.randrange(0, 9_000), day)
                    elif op < 0.72 and lg.calls:
                        c = rng.choice(list(lg.calls.values()))
                        lg.reverse(f"r{step}", c.call_id, rng.randrange(1, max(2, c.diamonds + 2)))
                    elif op < 0.76 and pid:
                        lg.chargeback(f"cb{step}", f"p{rng.randrange(1, pid + 1)}")
                    elif op < 0.86:
                        day += rng.randrange(0, 5)
                        lg.release(day)
                        lg.expire(day)
                    elif op < 0.93:
                        h = f"h{rng.randrange(3)}"
                        lg.request_withdrawal(f"w{step}", h, lg._host(h).available)
                    elif lg.withdrawals:
                        lg.settle_payout(rng.choice(list(lg.withdrawals)), rng.random() < 0.9)
                    # replay a random earlier key to prove idempotency under noise
                    if lg.calls and rng.random() < 0.1:
                        c = rng.choice(list(lg.calls.values()))
                        lg.settle(c.call_id, c.caller, c.host, c.diamonds, day)
                except (InsufficientDiamonds, ReversalExceedsCharge, WithdrawalBlocked, KeyError):
                    pass
                lg.check_invariants()
            r = lg.reserve()
            self.assertEqual(r["total"], sum(v for k, v in r.items() if k != "total"))
            self.assertIsInstance(r["total"], (int, F))


if __name__ == "__main__":
    unittest.main()
