# Dashuri monetization: decision register (v4)

**Last updated:** 24 Nov 2026 · **Supersedes:** v3 register (same file). The v3 recommendations are carried forward. New items come from the engineering audit.

**Companions:**
- [`../dashuri_monetization_math.md`](../dashuri_monetization_math.md)
- [`dashuri_ledger_engineering_spec.md`](dashuri_ledger_engineering_spec.md)
- [`dashuri_monetization_audit_report.md`](dashuri_monetization_audit_report.md)
- [`dashuri_implementation_readiness_checklist.md`](dashuri_implementation_readiness_checklist.md)

**Reproduce:**
- `python3 -I docs/finance/monetization_math_model.py`
- `python3 -I -m unittest discover -s docs/finance -p 'test_*.py' -v`

**Categories:**
- **A. Founder-approved**
- **B. Proposed, awaiting founder approval**
- **C. Blocked**: needs external, legal, accounting or technical evidence

**Priority:**
- **P0:** blocks taking real money or paying hosts.
- **P1:** blocks implementation.
- **P2:** tune after launch.

---

## A. Founder-approved

| ID | Decision | Approved for | Date | Implications | Dependencies |
|---|---|---|---|---|---|
| A-1 | 5 Diamonds spent → 4 Beans; 1 Bean = ₹0.005 (₹0.004 per Diamond; +33.36% vs 16,670 → 10,000) | **Financial modelling only.** Not implementation, migration, pricing, compensation, payouts or deployment | 24 Nov 2026 | Base 5-min call margin 47.7% (model); host share 16.2–19.3% by pack | B-01 to implement |
| A-2 | Host price floor 500, ceiling level × 1,000, > 3,000 needs Verified Host | Built (23 Nov spec) | 23 Nov 2026 | Margin-safe (earnings proportional) | Level basis now A-13 (Host Level from earned Beans) |
| A-3 | ₹500 minimum withdrawal; 30-day promo expiry; 7-day hold (current values) | Earlier founder decisions in code | 17 Nov 2026 | — | Hold changed by A-8 (14/7 days) |
| A-4 | XP = 8D + B (weights) | Earlier founder decision (R3-3) | 17 Nov 2026 | Basis resolved by A-13 (consumed purchased Diamonds + released paid Beans) | B-08 → A-13 |
| A-5 | **Fractional Bean carry per host** (0–4 fifths; order-independent; never discarded) | Decision register only (policy) | 24 Nov 2026 | Exact host entitlement; ≤ ₹0.004 pending per host | Applies to whichever conversion is implemented; spec §4 |
| A-6 | **Clawback recovery order:** reversed call's held Beans → host's available Beans → amount owed by the host; withdrawals blocked while anything is owed; repaid from future releases; write-off after 90 days by two approvers | Decision register only (policy) | 24 Nov 2026 | Lower credit loss; hosts see deductions with reasons | Spec §8; host notices (A-15 display) |
| A-7 | **Free Call Card off at launch** | Decision register only. The dev flag (`FREE_CALL_ENABLED=true`) is **not** changed | 24 Nov 2026 | Saves ~₹11.71 per free call; removes a burner-phone farming route; matches "no free matching" | Can be revisited later with a budget |
| A-8 | **Bean hold: 14 days by default; 7 days for Verified hosts at Host Level ≥ 5.** Conditions below | Decision register only. **Not** implementation; payouts stay disabled | 24 Nov 2026 | Cash gap −18% (worst) to −30% (average) vs 7 days for all | Host Level basis (A-13); reserve policy (A-10) |

| A-9 | **Withdrawals:** weekly payout cycle; Dashuri pays the transfer fee; withdrawals in multiples of 2 Beans (whole paise); ₹500 (100,000 Beans) minimum unchanged | Decision register only. Payouts stay disabled | 24 Nov 2026 | ~0.6% of host pay in fees | Payout provider (C-05); A-8 conditions |
| A-10 | **Reserve before each payout run:** cash ≥ (held + available + payout-pending Beans) × ₹0.005 + fractional carry + outstanding promo Diamonds × ₹0.004 + GST/TDS/TCS payable + refund/chargeback cushion (loss rate × last 120 days of sales). Amounts hosts owe back are **not** netted. If cash is short, the run waits or pays pro rata | Decision register only | 24 Nov 2026 | ~₹1.31 lakh + cushion at 1,000 base paying customers | Cushion horizon and loss rate to be confirmed by CA/Play (C-03); satisfies A-8 condition 5 once funded |
| A-11 | **No promotional Diamonds at launch** (no free grants until there is data) | Decision register only | 24 Nov 2026 | Promo term in A-10 is ₹0 at launch; no unfunded host liability | Supersedes B-13; a promo policy needs a new decision later |
| A-12 | **Payout hold at submission:** re-check at provider submission; withdrawals of hosts with new amounts owed or open disputes/fraud cases go to "held for review" instead of being sent. A payout already sent cannot be stopped | Decision register only | 24 Nov 2026 | Avoids paying out money that is owed back | Spec §8.4; payout provider (C-05) |

| A-13 | **Split levels.** Host Level (sets the price ceiling) = net eligible Beans released from paid (purchased-Diamond) calls; existing P12 thresholds kept (Level 10 = 40M Beans = ₹2 lakh earned). Account XP (display) = 8 × purchased Diamonds consumed + Host XP. Free-call and promo-funded Beans don't count; levels drop only through refunds/chargebacks (price capped via `CapRate`); progression frozen during fraud cases; payouts don't affect levels | Decision register only | 24 Nov 2026 | Ends buying a price ceiling (₹1,03,431 today) | Promo exclusion needs Diamond lots (A-17); spec §10 |
| A-14 | **Distinct-paying-caller gates** 0/2/5/10/20/35/60/100/150/250 for levels 1–10, plus a 20% per-caller cap; revisit after 3 months of data | Decision register only | 24 Nov 2026 | None direct; blocks collusion | A-13 |
| A-15 | **Caller price display:** Diamonds/min is the authoritative price; "your price ≈ ₹/min" from the caller's own purchases (free Diamonds shown as ₹0 and labelled); pack range before purchase; ₹ of purchased Diamonds used in the end-of-call summary; all server-calculated and labelled approximate | Decision register only | 24 Nov 2026 | No revenue effect; removes up to 19.6% overstatement | Needs Diamond lots + price snapshot (A-17); lawyer review (C-04) |
| A-16 | **Default rate for new hosts: 1,000 D/min** (≈ ₹22/min); 500 floor unchanged | Decision register only. Code default (500) unchanged | 24 Nov 2026 | Base break-even 56 vs 112 paying customers | — |

| A-17 | **Diamond lots + price snapshot:** each purchase/grant is its own lot (promo first, then oldest purchase first); `commerce.purchases` records the price paid; pre-cut-over balances rebuilt by replaying history (documented as an assumption) | Design approval for the register. Implementation needs a separate go-ahead | 24 Nov 2026 | Exact revenue per lot; lot-based chargebacks | Enables A-13 promo exclusion and A-15; spec §3, §13 |
| A-18 | **Fingerprinted idempotency:** same key + different details is refused (409), never treated as a replay | Design approval for the register. Implementation needs a separate go-ahead | 24 Nov 2026 | Prevents silent wrong charges | Spec §6; needed under any conversion |
| A-19 | **Supabase Pro (US$25/month ≈ ₹2,225) at launch only**; stay on Free while testing | Paid service approved for launch; nothing is changed now | 24 Nov 2026 | ₹2,225/month fixed from launch | Launch go/no-go |
| A-20 | **SMS via a registered Indian (DLT) gateway** through Supabase's Send-SMS hook | Route approved; provider and spend still need quotes and a cost yes | 24 Nov 2026 | Conservative OTP per paying customer ₹207.20 → ~₹7.00 (quotes unverified) | C-07 quotes; DLT template registration |

| A-21 | **Cloud Run production minimum instances: 0** (pay per use); revisit if cold starts delay incoming calls | Decision register only. `infrastructure/cloudrun/api.service.yaml` (minScale 1) is **not** changed | 24 Nov 2026 | No always-on charge | C-08 only matters if this changes |
| A-22 | **Lean operating budget, no paid ads** until ~100 paying customers: ~₹7,800/month (CA, legal retainer, domain/tools); founder covers support and safety on-call | Planning assumption | 24 Nov 2026 | Base break-even ~37 paying customers (model) | Legal duty for grievance/safety response remains (C-10) |
| A-23 | **Account deletion with unspent purchased Diamonds:** keep today's explicit-consent forfeiture unchanged pending legal advice | Decision register only | 24 Nov 2026 | — | Lawyer (C-04) before real money |
| A-24 | **Engage a CA and a lawyer now** | Founder action | 24 Nov 2026 | Adviser fees | Unblocks C-01, C-03, C-04, C-06, C-09, C-10 |

**A-8 conditions** (founder wording, 24 Nov 2026):
1. The 7-day hold applies only with **no open disputes, fraud flags or outstanding host receivables**.
2. The hold period **begins at successful call settlement**.
3. **Hold expiry does not guarantee payout eligibility.**
4. Payouts must be **funded by cleared, available cash**.
5. The approved host-liability, refund and chargeback reserves must be maintained before releasing payouts. The reserve policy is now **A-10**.
6. **Transaction-specific hold extensions** are allowed for legitimate disputes, with a documented reason and host notification.
7. **Funds reserved for other host liabilities are never used** to finance withdrawals.

**Declined on 24 Nov 2026:** implementing 5:4 (B-01). The founder kept it **modelling-only**.

Existing code behaviour that is **not** a founder decision is preserved until decided:
- the Free Call Card is enabled in dev;
- promo-first spend order is marked UNRESOLVED in code;
- P12 thresholds are marked UNRESOLVED.

---

## B. Proposed, awaiting founder approval

| ID | Pri | Decision | Current proposal | Alternatives | Financial impact | Technical impact | Risk | Dependencies | Recommendation | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| B-01 | P1 | Implement 5:4 | New rule set `…-5to4` at a stated effective date | Keep 16,670 → 10,000; 1:1 @ ₹0.004 (same money) | +33.36% host pay; per-call margin stays ≥ 20% worst case | Rule set + carry + templates | Irreversible once Beans are credited and withdrawn | C-01…C-06 for real money | Approve after C-items for real money; may build behind a flag earlier | **Founder kept modelling-only (24 Nov)**; revisit later |
| B-02 | P1 | Fractional carry per host (0–4 fifths), order-independent | Spec §4 | Per-call floor (loses ~0.4 Bean/call at 500/1,000 D/min); milli-Bean unit | Hosts +≈ ₹0.002/call vs flooring; ≤ ₹0.004 pending/host | New `bean_carry`, `BEAN_FIFTH` unit | Low | — | Approve | **Approved → A-5** |
| B-03 | P1 | Reversal recovery order: call's held → available → receivable | Spec §8 | Always receivable (host withdraws first); claw only own held (leaves unsupported Beans) | Lower credit loss | `CallReversal`, receivable account | Host disputes over deductions → needs clear notices | B-14 display | Approve | **Approved → A-6** |
| B-04 | P1 | Receivable: offset at next release; block withdrawals; write off after N days by dual approval | Spec §8.3 | No block; collect off-platform | Bounded write-offs | Release job change | Host churn on blocked withdrawals | B-03 | Approve with N = 90 days | **Approved → A-6** |
| B-05 | P1 | Hold payouts at submission if a receivable or fraud case appears | Spec §8.4 | Let payouts complete (today's behaviour in the reference/prototype) | Avoids paying out what is owed back | Payout cycle check | Slower payouts in disputes | Payout provider (C-05) | Approve | **Approved → A-12** |
| B-06 | P1 | Diamond lots (FIFO, promo first) + price snapshot | Spec §3 | Keep pooled buckets | Enables exact revenue per lot, lot-based chargebacks, "your price" | New tables; backfill by replay (assumption) | Backfill assumption for pre-cut-over balances | — | Approve | **Approved → A-17** |
| B-07 | P1 | Host Level = net eligible Beans released from purchased-Diamond calls; Account XP = 8 × purchased D consumed + HostXP; level can drop only via reversals | Spec §10 | Keep shared XP from purchases (Level 10 buyable for ₹1,03,431) | None direct | XP sources; Host Level view; `CapRate` on drop | Hosts lose levels after reversals | B-06 for promo exclusion | Approve | **Approved → A-13** |
| B-08 | P1 | Exclude promo-funded and free-call Beans from Host XP; freeze progression during fraud cases | Spec §10 | Include them | — | Needs `call_funding` | — | B-06 | Approve | **Approved → A-13** |
| B-09 | P1 | Distinct-caller gates 0/2/5/10/20/35/60/100/150/250 + 20% per-caller cap; P12 thresholds kept | Math §12 | v2 draft 0/3/…/500; no gates | — | Distinct-caller count per host | Gates too strict or too lax without data | — | Approve; revisit after 3 months of data | **Approved → A-14** |
| B-10 | P0 | Hold 14 days; 7 for Verified + Host Level ≥ 5, no open case | Math §16 | Keep 7 for all | Cash gap −18% to −30% | Hold per trust | Slower host cash | — | Approve | **Approved → A-8** |
| B-11 | P0 | Withdrawals: weekly cycle; platform pays transfer fee; withdraw in multiples of 2 Beans (whole paise) | Math §11; spec §4 | Host pays fee; any Bean count with ½-paisa rounding | ~0.6% of host pay | — | — | C-05 | Approve | **Approved → A-9** |
| B-12 | P0 | Reserve before each cycle = Beans (held + available + pending) × ₹0.005 + carry + promo D × ₹0.004 + taxes payable **+ refund/chargeback reserve (loss rate × last 120 days of sales)**; receivables not netted | Audit §4 | Without the refund reserve (v3) | ₹1.31 L + refund reserve at 1,000 base payers | Finance view | Under-reserving if the dispute window is longer | C-03 | Approve | **Approved → A-10** |
| B-13 | P0 | Promotional Diamonds: spent first; 30-day expiry; budget ≤ 3% of last month's consumption; hosts paid on promo spend; no XP; returns to an expired lot expire immediately | Math §11; spec §8.5 R1 | Hosts not paid on promo; no budget | 3% promo share ≈ −₹14,286/month at 1,000 base payers; 10% ≈ −₹47,620 | Budget ledger | Promo farming | B-06 | Approve | **Superseded by A-11 (no promos at launch)** |
| B-14 | P0 | Caller display: D/min authoritative; "your price ≈ ₹/min" from own lots (promo ₹0, labelled); pack range before purchase; end-of-call ₹ of purchased Diamonds used | Math §21 | Keep Starter rate for all (overstates by up to 19.6%; prices free Diamonds) | None | Server endpoint | Consumer-law exposure if not fixed | B-06, C-04 | Approve | **Approved → A-15** |
| B-15 | P0 | Free Call Card | **Keep it switched off for any real-money launch until decided** (it is on in dev) | Keep with monthly ₹ budget, compensation after hold, no XP | ₹11.71 per free call; burner-phone exposure ₹200/host/day | Flag only | Fraud; conflicts with "no free matching" | — | Off at launch | **Approved → A-7** |
| B-16 | P2 | Default rate for new hosts 1,000 D/min | Math §15 | 500 (code default) | Break-even 56 vs 112 payers | Config | Demand | — | Approve | **Approved → A-16** |
| B-17 | P0 | Supabase Pro in production | US$25/month | Stay on Free (pauses after 7 idle days) | ₹2,225/month | — | — | — | Approve at launch only | **Approved → A-19** |
| B-18 | P0 | SMS: DLT gateway via Supabase Send-SMS hook | Quotes needed | Twilio (₹7.40/SMS) | Conservative OTP/payer ₹207.20 → ₹7.00 | Auth hook | Delivery reliability | C-07 | Approve | **Approved → A-20** |
| B-19 | P2 | Cloud Run production min instances 0 | Template says 1 | 1 (always-on) | 0 vs one always-on instance (price unverified) | Config | Cold-start delay on incoming calls | C-08 | Keep 0 | **Approved → A-21** |
| B-20 | P2 | Operating budget: lean ₹7,800/month; ads off until ~100 payers | Math §14 | Staffed ₹19,800 | Break-even 37 vs 72 payers (base) | — | Founder load | — | Lean | **Approved → A-22** |
| B-21 | P0 | Deletion with unspent purchased Diamonds | Block with explicit consent pending legal advice | Refund; forfeit | — | — | Consumer law | C-04 | Hold current behaviour; legal review | **Approved → A-23** |
| B-22 | P0 | Engage a CA and a lawyer now | — | Defer | Adviser fees | — | Launch blocked without them | — | Yes | **Approved → A-24** |
| B-23 | P1 | Fingerprinted idempotency in `PostEntry` (a different payload under a used key → 409) | Spec §6 | Keep key-only (silently accepts) | — | Small Go/SQL change | High if not fixed | — | Approve (needed under any ratio) | **Approved → A-18** |

---

## C. Blocked (external evidence, legal/accounting advice, technical proof)

| ID | Pri | Question | Why it blocks | Evidence / source required | Who | Blocks payments? | Blocks payouts? |
|---|---|---|---|---|---|---|---|
| C-01 | P0 | **Play policy:** does a pay-per-minute 1:1 video app with strangers fall under the prohibition on compensated arrangements where one participant provides money or gifts to another? Also UGC moderation, sexual content, Child Safety Standards self-certification, age gate | Listing removal | [Developer Program Policy](https://support.google.com/googleplay/android-developer/answer/17190352?hl=en), [UGC](https://support.google.com/googleplay/android-developer/answer/9876937?hl=en), [Inappropriate Content](https://support.google.com/googleplay/android-developer/answer/9878810?hl=en), [Child Endangerment](https://support.google.com/googleplay/android-developer/answer/9878809) | Lawyer / policy specialist | **Yes** | Yes |
| C-02 | P0 | Play Console: 15%-tier enrolment (account group), fee on a test purchase, fee base (incl./excl. GST) | Fee 15% vs 30% (margin 47.7% vs 32.9%) | Play Console screenshots; [fee rules](https://support.google.com/googleplay/android-developer/answer/10632485?hl=en) | Founder | Yes | — |
| C-03 | P0 | GST on Diamond sales (at sale or on use; voucher rules); reverse charge on Google's fee; revenue recognition; breakage; chargeback credit notes; refund-reserve horizon | Tax and books | [Play India tax](https://support.google.com/paymentscenter/answer/7421525?hl=en); CBIC | CA | Yes | — |
| C-04 | P0 | Consumer protection: ₹ display, promo expiry, refund policy, deletion forfeiture, dark patterns | Penalties | [E-Commerce Rules 2020](https://consumeraffairs.gov.in/public/upload/files/E%20commerce%20rules_1732703966.pdf), [2026 amendment](https://consumeraffairs.gov.in/public/upload/files/E%20Commerce%20Amendment%20Rules%202026_1789127949.pdf), [Dark Patterns Guidelines](https://ccpa.doca.gov.in/files/The%20Guidelines%20for%20Prevention%20and%20Regulation%20of%20Dark%20Patterns,%202023_1732707717.pdf) | Lawyer | Yes | — |
| C-05 | P0 | Payout provider: written quote, KYC flow, webhook semantics | Payout cost and safety | Provider contract | Founder | — | **Yes** |
| C-06 | P0 | TDS on host payouts (194-O 0.1% with ₹5 L threshold, or another section); GST TCS u/s 52; host GST registration; principal vs agent | Withholding duties | [194-O](https://wm.incometaxindia.gov.in/w/section-194-o), [GST e-commerce FAQ](https://gstcouncil.gov.in/sites/default/files/2024-02/faq-e-commerc.pdf) | CA | — | **Yes** |
| C-07 | P0 | SMS provider quotes (₹/SMS, DLT registration) | Decides conservative viability | Provider quotes (third-party ₹0.15–0.25 unverified) | Founder | Yes (sign-ups) | — |
| C-08 | P2 | Live asia-south1 Cloud Run unit prices; idle min-instance price | Only material with min instances > 0 | Cloud Billing SKUs (Mumbai = Tier 1 [verified](https://docs.cloud.google.com/run/docs/locations)) | Founder | — | — |
| C-09 | P0 | RBI/PPI: Diamonds funding host cash-outs | Authorisation risk | [RBI PPI FAQ](https://www.rbi.org.in/commonman/english/scripts/FAQs.aspx?Id=2812) | Lawyer | Yes | Yes |
| C-10 | P0 | DPDP Act/Rules notices and retention; IT Rules 2021 grievance officer | Privacy and intermediary duties | [DPDP Act](https://www.meity.gov.in/static/uploads/2024/06/2bf1f0e9f04e6fb4f8fef35e82c42aa5.pdf); IT Rules text (not retrieved) | Lawyer | Yes | Yes (KYC data) |
| C-11 | P0 | Incorporation | Contracts, PAN, payout onboarding | — | Founder | — | **Yes** |
| C-12 | P1 | Production proof of the ledger design: Go + PostgreSQL implementation tests (spec §12.2) | The prototype is PL/pgSQL in a scratch cluster, not the service | Integration test run | Engineering | Yes | Yes |
| C-13 | P2 | Measured demand: paid minutes per payer, rate mix, call length, sign-ups per payer, refund rate | All margins and break-evens are model outputs | 4–8 weeks of pilot data | Founder | — | — |
| C-14 | P2 | Stream billed resolution and usage; Supabase usage per call; actual GCP bills | Replace estimates | Provider dashboards | Founder | — | — |

---

## Change log

- **v4.1 (24 Nov):** founder decisions A-5…A-8 recorded; B-01 kept modelling-only. Then A-9…A-12 (withdrawals, reserve, no promos at launch, payout hold at submission) and A-13…A-16 (split levels, caller gates, caller price display, default rate 1,000) and A-17…A-20 (Diamond lots, idempotency fix, Supabase Pro at launch, DLT SMS) and A-21…A-24 (Cloud Run min 0, lean budget, deletion unchanged pending legal advice, engage advisers). **Only B-01 (implement 5:4) remains open in category B.**
- **v4 (24 Nov):** three-category register; new B-03…B-08, B-12 (refund reserve), B-23 (idempotency fingerprint), C-01 (Play compensated-arrangement policy), C-12; corrected code facts (no host clawback today; key-only idempotency).
- **v3 (24 Nov):** reversal and carry design; gates aligned with the script; OTP ₹207.20 / ₹7.00; Cloud Run Tier 1; Play enrolment; caller display; reserve with promo and carry.
- **v2 (24 Nov):** 5:4 approved for modelling; infrastructure audit.
