#!/usr/bin/env python3
"""Reproducible calculations for docs/dashuri_monetization_math.md (v3, 5:4 model).

Run model:  python3 -I docs/finance/monetization_math_model.py
Run tests:  python3 -I -m unittest discover -s docs/finance -p 'test_*.py' -v

No third-party packages. Money and units use exact Fractions; rupees are
rounded only when printed. Every assumption is in the INPUTS block, labelled
VERIFIED / UNVERIFIED / ESTIMATE / NEEDS-INPUT. The ledger rules (carry,
reversal, chargeback) live in monetization_ledger.py and are tested there.
"""
import os
import sys
from fractions import Fraction as F
from functools import lru_cache
from math import ceil

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # -I drops the script dir
from monetization_ledger import Ledger  # noqa: E402

# ====================================================================== INPUTS
GST = F(18, 100)  # GST inside the customer price [CA to confirm treatment]
MODELS = {        # (Beans per Diamond, rupees per Bean)
    "M1 previous: 16,670 D -> 10,000 B @ Rs0.005": (F(10000, 16670), F(5, 1000)),
    "M2 earlier proposal: 1 D -> 1 B @ Rs0.004": (F(1), F(4, 1000)),
    "M3 APPROVED (modelling only): 5 D -> 4 B @ Rs0.005": (F(4, 5), F(5, 1000)),
}
APPROVED = "M3 APPROVED (modelling only): 5 D -> 4 B @ Rs0.005"

PACKS = [  # seeded: supabase/migrations/20261121000100_mvp_foundation.sql (paise incl. GST, Diamonds) [CODE]
    ("Starter", 9900, 4000), ("Small", 29900, 12500), ("Medium", 59900, 26000),
    ("Popular", 119900, 54000), ("Large", 299900, 140000), ("Premium", 599900, 290000),
]
BRIEF_PACK = ("Rs1,130 example", 113000, 48000)

S = {  # c = conservative, b = base, o = optimistic
    "fx":              {"c": 90,           "b": 89,           "o": 88},            # Rs/US$ [ESTIMATE]
    # Play fee: 15% needs 15%-tier enrolment (account group). Not enrolled = 30%. [NEEDS-INPUT: Play Console]
    "play_fee":        {"c": F(20, 100),   "b": F(15, 100),   "o": F(15, 100)},
    "fee_on_gross":    {"c": True,         "b": True,         "o": False},         # fee base [UNVERIFIED]
    "stream_usd_k":    {"c": F(3),         "b": F(3, 2),      "o": F(3, 2)},       # $/1,000 participant-min [VERIFIED]
    "overhead_min":    {"c": F(6, 10),     "b": F(4, 10),     "o": F(3, 10)},      # unbilled media min/call [ESTIMATE]
    "mod_usd_op":      {"c": F(29, 10000), "b": F(25, 10000), "o": F(20, 10000)},  # Sightengine $/op [VERIFIED plans]
    "loss_rate":       {"c": F(2, 100),    "b": F(1, 100),    "o": F(5, 1000)},    # refunded/charged back after use [ESTIMATE]
    "clawback":        {"c": F(4, 10),     "b": F(5, 10),     "o": F(6, 10)},      # host pay recovered on loss [ESTIMATE]
    "payout_fee_pct":  {"c": F(19, 1000),  "b": F(63, 10000), "o": F(4, 1000)},    # transfer fee+GST / payout [VERIFIED band]
    "api_vcpu_s_call": {"c": F(5),         "b": F(5, 2),      "o": F(3, 2)},       # Cloud Run vCPU-s per call [ESTIMATE]
}
PARTICIPANTS = 2
MOD_WINDOW_S, MOD_FRAME_EVERY_S = 180, 20   # moderation/service.go + app cadence [CODE]
# Cloud Run request-based Tier-1 list price. asia-south1 (Mumbai) is Tier 1 per the Cloud Run
# locations page, but these unit prices come from an older pricing-page snapshot. [UNVERIFIED live]
CLOUD_RUN_USD_VCPU_S = F(24, 1000000)
CLOUD_RUN_USD_GIB_S = F(25, 10000000)
CLOUD_RUN_MEM_GIB = F(1, 4)                 # deployed dev: 256Mi [DEPLOYED]

BEHAVIOUR = {  # paid minutes/payer/month, average rate, average call length (min), pack [ESTIMATE]
    "c": (12, 1000, 4, PACKS[5]),
    "b": (F(41, 2), 1500, 5, PACKS[3]),
    "o": (F(317, 10), 2000, 6, PACKS[2]),
}
SMS_RS = {"c": F(74, 10), "b": F(25, 100), "o": F(15, 100)}       # Twilio list / DLT quotes [THIRD-PARTY]
SMS_PER_SIGNUP = {"c": F(14, 10), "b": F(13, 10), "o": F(12, 10)}  # [ESTIMATE]
SIGNUPS_PER_PAYER = {"c": 20, "b": 10, "o": 5}                     # [ESTIMATE]
SUPABASE_PRO_USD = 25                                              # [VERIFIED]
STREAM_FREE_USD = 100                                              # [VERIFIED page]
SIGHTENGINE_FREE_OPS, SIGHTENGINE_STARTER_USD, SIGHTENGINE_STARTER_OPS = 2000, 29, 10000  # [VERIFIED]
CLOUD_RUN_FREE_VCPU_S, CLOUD_RUN_FREE_GIB_S = 180000, 360000       # per billing account [VERIFIED]
NON_INFRA = {  # Rs/month [NEEDS-INPUT]; earlier repo estimates
    "lean": {"CA/GST filings": 4000, "Legal retainer": 2500, "Domain, email, tools": 1300},
    "staffed": {"CA/GST filings": 4000, "Legal retainer": 2500, "Domain, email, tools": 1300,
                "Safety on-call": 10000, "Other fixed": 2000},
}
PROMO_BUDGET_SHARE = F(3, 100)       # promo Diamonds granted <= 3% of Diamonds consumed last month [PROPOSAL]
HOSTS_PER_PAYER = F(1, 10)           # active hosts ~ payers/10, min 10 [ESTIMATE]
HOST_LEVEL_BEANS = [0, 32000, 100000, 250000, 600000, 1500000, 3500000, 8000000, 18000000, 40000000]  # P12 [CODE]
GATES_PROPOSED = [0, 2, 5, 10, 20, 35, 60, 100, 150, 250]          # [PROPOSAL]
GATES_V1_DRAFT = [0, 3, 10, 20, 40, 75, 120, 200, 300, 500]


def sc(key, s):
    return S[key][s]


def rs(x, nd=2):
    return f"{float(x):,.{nd}f}"


def table(headers, rows):
    out = ["| " + " | ".join(headers) + " |",
           "|" + "|".join("---" if i == 0 else "---:" for i in range(len(headers))) + "|"]
    out += ["| " + " | ".join(str(c) for c in row) + " |" for row in rows]
    return "\n".join(out)


def rupee_per_d(pack):
    return F(pack[1], pack[2]) / 100


# ===================================================================== CALLS
@lru_cache(maxsize=None)
def per_call(rate, minutes, rupee_d, model, s, seconds=None):
    beans_per_d, rs_bean = model
    secs = seconds if seconds is not None else minutes * 60
    diamonds = rate * secs // 60                                   # floor once (settle.go)
    gross = diamonds * rupee_d
    ex = 1 / (1 + GST)
    fee_rate = sc("play_fee", s) * (1 if sc("fee_on_gross", s) else ex)
    gst = gross * (1 - ex)
    fee = gross * fee_rate
    net = gross - gst - fee
    beans = diamonds * beans_per_d                                 # exact entitlement (carry)
    host = beans * rs_bean
    fx = sc("fx", s)
    mins = F(secs, 60)
    stream = (mins + sc("overhead_min", s)) * PARTICIPANTS * sc("stream_usd_k", s) / 1000 * fx
    frames = ceil(min(secs, MOD_WINDOW_S) / MOD_FRAME_EVERY_S) * PARTICIPANTS
    moderation = frames * sc("mod_usd_op", s) * fx
    api = sc("api_vcpu_s_call", s) * (CLOUD_RUN_USD_VCPU_S + CLOUD_RUN_MEM_GIB * CLOUD_RUN_USD_GIB_S) * fx
    loss = sc("loss_rate", s) * (net - host * sc("clawback", s))
    payout = host * sc("payout_fee_pct", s)
    contribution = net - host - stream - moderation - api - loss - payout
    return dict(diamonds=diamonds, gross=gross, gst=gst, fee=fee, net=net, beans=beans, host=host,
                stream=stream, moderation=moderation, frames=frames, api=api, loss=loss, payout=payout,
                contribution=contribution, margin=contribution / gross if gross else F(0))


# ================================================================== SECTIONS
def sec_models():
    print("## 1. Three conversion models\n")
    rows = [[n, f"{k.numerator}/{k.denominator}", rs(v, 3), rs(k * v, 7)] for n, (k, v) in MODELS.items()]
    print(table(["Model", "Beans per Diamond", "Rs per Bean", "Host Rs per Diamond"], rows))
    m1, m2, m3 = MODELS.values()
    assert m2[0] * m2[1] == m3[0] * m3[1] == F(4, 1000)
    inc = (m3[0] * m3[1]) / (m1[0] * m1[1]) - 1
    print(f"\nM2 = M3 = Rs0.004 per Diamond (asserted). M1 = Rs{rs(m1[0]*m1[1],7)}. "
          f"M1 -> M3: +{rs(inc*100,2)}% (exact {inc.numerator}/{inc.denominator}).\n")
    rows = []
    for d in (500, 1000, 2000, 4000, 10000, 20000, 100000):
        b1 = d * 10000 // 16670
        rows.append([f"{d:,}", f"{b1:,}", rs(F(b1, 200)), f"{d:,}", rs(F(d * 4, 1000)),
                     f"{4 * d // 5:,} + {(4 * d) % 5}/5", rs(F(4 * d, 5) / 200), rs(F(4 * d, 5) / 200 - F(b1, 200))])
    print(table(["Diamonds", "M1 Beans", "M1 Rs", "M2 Beans", "M2 Rs", "M3 Beans", "M3 Rs", "M3 - M1 Rs"], rows))
    print()


def sec_calls_by_rate():
    print("## 2. Calls at representative rates (host side, M3)\n")
    rows = []
    for rate in (500, 1000, 1500, 2000, 4000, 10000):
        for m in (1, 5, 10, 30):
            d = rate * m
            rows.append([f"{rate:,}", m, f"{d:,}", f"{4*d//5:,}", rs(F(4 * d, 5) / 200), rs(F(d * 10000 // 16670, 200))])
    print(table(["Rate D/min", "Min", "Diamonds", "Beans (M3)", "Host Rs (M3)", "Host Rs (M1)"], rows))
    print()


def sec_remainder():
    print("## 3. Remainder carry and reversals (reference ledger, monetization_ledger.py)\n")
    lg = Ledger()
    lg.purchase("p1", "caller", 10**6, 10**6 * 2220 // 1000)
    rows = []
    for cid, d in (("c1", 4333), ("c2", 2166), ("c3", 1001), ("c4", 7)):
        before = lg._host("host").carry
        credit = lg.settle(cid, "caller", "host", d, day=0)
        rows.append([cid, f"{d:,}", f"{before}/5", f"{4*d:,}", f"{credit:,}", f"{lg.hosts['host'].carry}/5", f"{4*d//5:,}"])
    print(table(["Call", "Diamonds", "Carry in", "Fifths added", "Beans credited", "Carry out", "Per-call floor"], rows))
    lg.check_invariants()
    h = lg.hosts["host"]
    print(f"\nExact entitlement {rs(F(4 * 7507, 5), 1)} Beans = credited {sum(h.held.values()):,} + carry {h.carry}/5. "
          f"Per-call floor would credit 6,003.\n")
    # reversal of c1 after c2..c4: exact drop, bounded by ceil(4D/5)
    claw = lg.reverse("r1", "c1", 4333)
    print(f"Full reversal of c1 after c2-c4 settled: claws {claw:,} Beans (c1 credited 3,466; bound ceil(4x4,333/5) = "
          f"{-(-4*4333//5):,}). Recovered: c1's own held Beans {3466:,}, then receivable {h.receivable}. "
          f"Other calls' held Beans unchanged. Carry now {h.carry}/5.\n")
    lg.check_invariants()
    for rate in (500, 1000, 1500):
        lost = sum((4 * (rate * s // 60)) % 5 for s in range(1, 1801) if rate * s // 60)
        n = sum(1 for s in range(1, 1801) if rate * s // 60)
        print(f"- {rate:,} D/min, {n:,} calls (every length 1 s-30 min): per-call floor loses {lost/5:,.1f} Beans "
              f"(Rs{rs(F(lost,5)/200)}, {rs(F(lost,5)/n,2)} Bean/call); carry loses 0.")
    print()


def sec_packs():
    print("## 4. Packs: price per Diamond and host share\n")
    rows = []
    for p in PACKS + [BRIEF_PACK]:
        rpd = rupee_per_d(p)
        row = [p[0], rs(p[1] / 100, 0), f"{p[2]:,}", f"{p[2] - int(p[1] * F(4000, 9900)):,}", rs(rpd * 100, 4)]
        row += [rs(k * v / rpd * 100, 1) + "%" for k, v in MODELS.values()]
        row.append(rs(F(4, 1000) / (rpd / (1 + GST)) * 100, 1) + "%")
        rows.append(row)
    print(table(["Pack", "Rs", "Diamonds", "Volume bonus D", "paise/D", "M1 host %", "M2 host %", "M3 host %",
                 "M3 host % of ex-GST"], rows))
    print()


def sec_display():
    print("## 5. Caller Rs/min display\n")
    current = min(PACKS, key=lambda p: p[1])        # purchases.ApproxPaisePerDiamondMilli: lowest PricePaise
    cur_milli = current[1] * 1000 // current[2]
    print(f"Code today shows rate x {cur_milli} milli-paise/D (the {current[0]} pack, lowest total price), "
          f"for every caller.\n")
    rows = []
    for p in PACKS:
        eff = rupee_per_d(p) * 1500
        shown = F(cur_milli, 1000) / 100 * 1500
        rows.append([p[0], rs(eff), rs(shown), rs((shown / eff - 1) * 100, 1) + "%"])
    rows.append(["Promotional Diamonds", "0.00", rs(F(cur_milli, 1000) / 100 * 1500), "n/a (caller paid nothing)"])
    print(table(["Caller's Diamonds came from", "Effective Rs/min at 1,500 D/min", "Shown today Rs/min", "Overstatement"], rows))
    # proposed: value the next Diamonds in the caller's own spend order
    lg = Ledger()
    lg.grant_promo("g1", "u", 2000, 30)
    lg.purchase("p1", "u", 4000, 9900)
    lg.purchase("p2", "u", 54000, 119900)
    order = sorted((l for l in lg.lots.values() if l.caller == "u" and l.remaining),
                   key=lambda l: (l.kind != "promotional", l.expires_day or 0, l.lot_id))
    need, value = 1500 * 5, F(0)
    for lot in order:
        take = min(need, lot.remaining)
        value += take * F(lot.paise, lot.original) / 100
        need -= take
        if not need:
            break
    print(f"\nProposed 'your price' example: wallet = 2,000 promo + Starter + Popular; a 5-minute call at 1,500 D/min "
          f"(7,500 D) is valued at Rs{rs(value)} from the caller's own lots in spend order "
          f"(= Rs{rs(value/5)}/min), versus Rs{rs(F(cur_milli,1000)/100*7500)} shown by today's rule.\n")


def sec_unit():
    print("## 6. Unit economics per call (M3)\n")
    st = MODELS[APPROVED]
    cases = [("Base: Popular, 1,500 D/min, base costs", PACKS[3], 1500, "b"),
             ("Conservative: Premium, 1,000 D/min, conservative costs", PACKS[5], 1000, "c"),
             ("Worst floor: Premium, 500 D/min, conservative costs", PACKS[5], 500, "c"),
             ("Optimistic: Medium, 2,000 D/min, optimistic costs", PACKS[2], 2000, "o"),
             ("High rate: Popular, 4,000 D/min, base costs", PACKS[3], 4000, "b")]
    for label, pack, rate, s in cases:
        rows = []
        for m in (1, 5, 10, 30):
            c = per_call(rate, m, rupee_per_d(pack), st, s)
            rows.append([m, f"{c['diamonds']:,}", rs(c["gross"]), rs(c["gst"]), rs(c["fee"]), rs(c["net"]),
                         rs(c["beans"], 1), rs(c["host"]), rs(c["stream"]), rs(c["moderation"]), rs(c["api"], 3),
                         rs(c["loss"] + c["payout"]), rs(c["contribution"]), rs(c["margin"] * 100, 1) + "%"])
        print(f"### {label}\n")
        print(table(["Min", "D", "Gross Rs", "GST Rs", "Store fee Rs", "Net cash Rs", "Beans", "Host Rs", "Video Rs",
                     "Moderation Rs", "API Rs", "Loss+payout Rs", "Contribution Rs", "Margin"], rows))
        print()
    print("Play fee sensitivity (5-min base call, Popular, 1,500 D/min):\n")
    rows = []
    for fee, label in ((F(15, 100), "15% (enrolled in 15% tier)"), (F(20, 100), "20% (stress)"),
                       (F(30, 100), "30% (NOT enrolled / above US$1M)")):
        old = S["play_fee"]["b"]
        S["play_fee"]["b"] = fee
        per_call.cache_clear()
        c = per_call(1500, 5, rupee_per_d(PACKS[3]), st, "b")
        rows.append([label, rs(c["contribution"]), rs(c["margin"] * 100, 1) + "%"])
        S["play_fee"]["b"] = old
        per_call.cache_clear()
    print(table(["Play fee on gross", "Contribution Rs", "Margin"], rows))
    print()


# ------------------------------------------------------------- MONTHLY MODEL
def month(n_payers, s, rate=None, minutes=None, pack=None, sms=None):
    mins, r, call_len, pk = BEHAVIOUR[s]
    r = rate or r
    mins = minutes if minutes is not None else mins
    pk = pack or pk
    fx = sc("fx", s)
    c = per_call(r, call_len, rupee_per_d(pk), MODELS[APPROVED], s)
    calls = F(mins) / call_len * n_payers
    gross, net, host = c["gross"] * calls, c["net"] * calls, c["host"] * calls
    stream = max(F(0), c["stream"] / fx * calls - STREAM_FREE_USD) * fx
    ops = c["frames"] * calls
    mod_usd = F(0) if ops <= SIGHTENGINE_FREE_OPS else \
        SIGHTENGINE_STARTER_USD + max(F(0), ops - SIGHTENGINE_STARTER_OPS) * F(2, 1000)
    vcpu = sc("api_vcpu_s_call", s) * calls
    api = (max(F(0), vcpu - CLOUD_RUN_FREE_VCPU_S) * CLOUD_RUN_USD_VCPU_S +
           max(F(0), vcpu * CLOUD_RUN_MEM_GIB - CLOUD_RUN_FREE_GIB_S) * CLOUD_RUN_USD_GIB_S) * fx
    loss = (c["loss"] + c["payout"]) * calls
    otp = n_payers * SIGNUPS_PER_PAYER[s] * SMS_PER_SIGNUP[s] * (sms if sms is not None else SMS_RS[s])
    contribution = net - host - stream - mod_usd * fx - api - loss - otp
    return dict(gross=gross, net=net, host=host, stream=stream, mod=mod_usd * fx, api=api, loss=loss, otp=otp,
                contribution=contribution, provider_min=SUPABASE_PRO_USD * fx, calls=calls, ops=ops,
                diamonds=c["diamonds"] * calls)


def first_at_least(f, target, lo, hi):
    """Smallest x in [lo, hi] (integers) with f(x) >= target, given f non-decreasing on [lo, hi]."""
    if f(hi) < target:
        return None
    while lo < hi:
        mid = (lo + hi) // 2
        if f(mid) >= target:
            hi = mid
        else:
            lo = mid + 1
    return lo


def solve(f_of_k, ops_of_k, target, hi):
    """Break-even on an integer k where f has one downward step (Sightengine free -> Starter).
    Bisect each monotone segment separately; verified by checking k-1 and k."""
    step = first_at_least(lambda k: ops_of_k(k) > SIGHTENGINE_FREE_OPS, True, 1, hi) or hi + 1
    k = first_at_least(f_of_k, target, 1, step - 1) if step > 1 else None
    if k is None and step <= hi:
        k = first_at_least(f_of_k, target, step, hi)
    if k is not None:
        assert f_of_k(k) >= target and (k == 1 or k == step or f_of_k(k - 1) < target)
    return k


def sec_monthly():
    print("## 7. Monthly scenarios (M3, usage-based infrastructure)\n")
    rows = []
    for n in (100, 1000, 10000):
        for s in ("c", "b", "o"):
            m = month(n, s)
            rows.append([f"{n:,}", s, rs(m["gross"], 0), rs(m["net"], 0), rs(m["host"], 0), rs(m["stream"], 0),
                         rs(m["mod"], 0), rs(m["api"], 0), rs(m["otp"], 0), rs(m["loss"], 0),
                         rs(m["contribution"], 0), rs(m["provider_min"], 0), rs(m["contribution"] - m["provider_min"], 0)])
    print(table(["Payers", "Scen.", "Gross Rs", "Net cash Rs", "Host Rs", "Video Rs", "Moderation Rs", "Cloud Run Rs",
                 "OTP Rs", "Loss+payout Rs", "Contribution Rs", "Provider minimum Rs", "After provider minimum Rs"], rows))
    print()
    for k, v in NON_INFRA.items():
        print(f"- {k}: Rs{sum(v.values()):,}/month ({', '.join(f'{a} {b:,}' for a, b in v.items())})")
    print()
    rows = []
    for n in (100, 1000, 10000):
        for s in ("c", "b", "o"):
            after = month(n, s)["contribution"] - month(n, s)["provider_min"]
            rows.append([f"{n:,}", s] + [rs(after - sum(v.values()), 0) for v in NON_INFRA.values()])
    print(table(["Payers", "Scen.", "Operating result, lean Rs", "Operating result, staffed Rs"], rows))
    print()


def sec_break_even():
    print("## 8. Break-even (bisection per monotone segment; exact)\n")
    hi = 200_000
    fixed_sets = {"provider minimum only": 0, "lean": sum(NON_INFRA["lean"].values()),
                  "staffed": sum(NON_INFRA["staffed"].values())}
    rows = []
    variants = [("c", "c (Twilio Rs7.40)", None), ("c", "c + DLT SMS Rs0.25", F(25, 100)),
                ("b", "b", None), ("o", "o", None)]
    for s, label, sms in variants:
        for fl, extra in fixed_sets.items():
            fixed = SUPABASE_PRO_USD * sc("fx", s) + extra
            n = solve(lambda k: month(k, s, sms=sms)["contribution"], lambda k: month(k, s, sms=sms)["ops"], fixed, hi)
            rows.append([label, fl, rs(fixed, 0), f"{n:,}" if n else "never (contribution per payer <= 0)"])
    print(table(["Scenario", "Fixed set", "Fixed Rs/month", "Break-even paying customers"], rows))
    per_payer = {lab: month(1000, s, sms=sms)["contribution"] / 1000 for s, lab, sms in variants}
    print("\nContribution per paying customer per month: " +
          "; ".join(f"{k} Rs{rs(v)}" for k, v in per_payer.items()) + "\n")
    rows = []
    fixed = SUPABASE_PRO_USD * sc("fx", "b") + sum(NON_INFRA["lean"].values())
    for rate in (500, 1000, 1500, 2000, 4000):
        row = [f"{rate:,}"]
        for pk in (PACKS[3], PACKS[5]):
            n = solve(lambda k: month(k, "b", rate=rate, pack=pk)["contribution"],
                      lambda k: month(k, "b", rate=rate, pack=pk)["ops"], fixed, hi)
            row.append(f"{n:,}" if n else "never")
        rows.append(row)
    print("Break-even paying customers by average rate (base costs, 20.5 paid min, lean):\n")
    print(table(["Avg rate D/min", "Popular pack", "Premium pack"], rows))
    print()
    rows = []
    for n in (100, 300, 1000):
        for s, label, sms in variants:
            fixed = SUPABASE_PRO_USD * sc("fx", s) + sum(NON_INFRA["lean"].values())
            k = solve(lambda k: month(n, s, minutes=F(k, 2), sms=sms)["contribution"],
                      lambda k: month(n, s, minutes=F(k, 2), sms=sms)["ops"], fixed, 4000)
            rows.append([f"{n:,}", label, rs(F(k, 2), 1) if k else "never (OTP exceeds contribution)"])
    print("Break-even paid minutes per paying customer per month (lean):\n")
    print(table(["Payers", "Scenario", "Paid minutes/payer/month"], rows))
    print()
    rows = []
    for spp in (5, 10, 20, 50):
        row = [spp]
        for sms_n, sms in ((F(13, 10), F(15, 100)), (F(13, 10), F(25, 100)), (F(14, 10), F(25, 100)),
                           (F(13, 10), F(74, 10)), (F(14, 10), F(74, 10))):
            row.append(rs(spp * sms_n * sms))
        rows.append(row)
    print("OTP cost per paying customer (Rs):\n")
    print(table(["Sign-ups per payer", "1.3 SMS x Rs0.15", "1.3 x Rs0.25", "1.4 x Rs0.25", "1.3 x Rs7.40",
                 "1.4 x Rs7.40"], rows))
    print()


def sec_cash():
    print("## 9. Cash timing and reserve (M3, base behaviour)\n")
    rows = []
    for n in (100, 1000, 10000):
        m = month(n, "b")
        daily = m["host"] / 30
        hosts = max(10, int(n * HOSTS_PER_PAYER))
        promo_d = PROMO_BUDGET_SHARE * m["diamonds"]                  # outstanding promo <= one month of grants (30-day expiry)
        promo_rs = promo_d * F(4, 1000)
        carry_rs = hosts * F(4, 5) * F(5, 1000)                        # worst case 4/5 Bean per host
        for hold in (7, 14):
            gap_worst = daily * max(0, 45 - hold)
            rows.append([f"{n:,}", hold, rs(m["host"], 0), rs(daily * max(0, 30 - hold), 0), rs(gap_worst, 0),
                         rs(promo_rs, 0), rs(carry_rs, 2), rs(gap_worst + promo_rs + carry_rs, 0)])
    print(table(["Payers", "Hold days", "Host earnings Rs/month", "Cash gap avg Rs", "Cash gap worst Rs",
                 "Promo D liability Rs", "Fraction carry Rs (max)", "Reserve before taxes Rs"], rows))
    print()


def sec_levels():
    print("## 10. Host Level (P12 thresholds as Beans released, M3)\n")
    rows = []
    for lvl, t in enumerate(HOST_LEVEL_BEANS, 1):
        caller_rs = ceil(F(t) * 5 / 4) * rupee_per_d(PACKS[3])
        g1, g2 = GATES_V1_DRAFT[lvl - 1], GATES_PROPOSED[lvl - 1]
        rows.append([lvl, f"{t:,}", rs(F(t, 200), 0), rs(caller_rs, 0), g1, rs(caller_rs / g1, 0) if g1 else "-",
                     g2, rs(caller_rs / g2, 0) if g2 else "-"])
    print(table(["Level", "HostXP (Beans)", "Host Rs earned", "Caller Rs spent (Popular)", "v1 draft gate",
                 "Implied Rs/caller", "Proposed gate", "Implied Rs/caller"], rows))
    print("\nLevel 10 reconciliation (Rs of host earnings for a pure host):")
    print(f"- Code today (Account XP = 8D + B, M1): 40,000,000 XP = 40,000,000 Beans x Rs0.005 = Rs{rs(40000000*F(5,1000),0)}")
    print(f"- Decision pack v1 (HostXP, 1:1 @ Rs0.004): 50,000,000 Beans x Rs0.004 = Rs{rs(50000000*F(4,1000),0)}")
    print(f"- Decision pack v2/v3 (HostXP, 5:4 @ Rs0.005): 40,000,000 Beans x Rs0.005 = Rs{rs(40000000*F(5,1000),0)}")
    print(f"- Code today, pure buyer: 40,000,000 / 8 = 5,000,000 D = Rs{rs(5000000 * rupee_per_d(PACKS[5]), 0)} (Premium)\n")


if __name__ == "__main__":
    sec_models()
    sec_calls_by_rate()
    sec_remainder()
    sec_packs()
    sec_display()
    sec_unit()
    sec_monthly()
    sec_break_even()
    sec_cash()
    sec_levels()
    print("Model complete; ledger invariants checked.")
