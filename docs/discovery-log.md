# Dashuri — Founder Discovery Log

- **Last updated:** 2026-11-17, after the founder's simulation brief (log v4)
- **Business model status:**
  - The six-month financial simulation was **formally authorised by the founder** on 2026-11-17 (S12), lifting the simulation gate.
  - Production development is **not** authorised.
  - *(v3 status, kept for history: "NOT APPROVED. The financial simulation is blocked until the founder writes 'I APPROVE THE DASHURI BUSINESS MODEL'.")*
- **Latest founder decisions:** section **H** (S1–S12). They take precedence over any conflicting earlier entry.
- **Companion report:** `docs/business-model-report.md` (v0.3)
- **Simulation:** `docs/simulation/`, plus the dashboard `simulation/dist/dashuri-simulation.html`

**Labels:**
- CONFIRMED BY FOUNDER
- PROPOSED BY FOUNDER — NOT FINAL
- RESEARCH-SUPPORTED
- PROPOSED BY CLAUDE
- ASSUMPTION REQUIRING VALIDATION
- UNRESOLVED
- REQUIRES PROFESSIONAL REVIEW
- **UNVERIFIED** (claim could not be checked against an official or primary source)

**History rule:** nothing is deleted. Superseded items stay in the log with a pointer to the item that replaced them. Audit corrections are listed in section G.

---

## Business concept (current)

A paid one-to-one video marketplace for India, launching on Android first:

- Customers browse hosts who are online now, choose one, and pay Diamonds **per second** at the rate the host has set.
- Hosts earn **INR-denominated Beans** (preferred value ₹0.005 per Bean) and withdraw them weekly.
- Separately, new customers get a one-minute **Free Call Card** for a random call.
- Content is limited to flirting, romance and mature adult conversation. **No nudity, sexual acts or explicit content.**

---

## A. Founder decisions — CONFIRMED BY FOUNDER

All decisions were recorded on 2026-11-17. Each round took place in this conversation.

### Round 1

| ID | Decision (founder's words, summarised faithfully) | Founder reasoning | Dependencies | Risks | Research needed | Status |
|---|---|---|---|---|---|---|
| C1 | Dashuri is primarily a revenue-generating business. | "My primary motivation is earning money." | — | — | — | CONFIRMED |
| C2 | No free random matchmaking at launch. The experience is a paid marketplace where customers browse and choose. (Later qualified by R3-5: a separate one-minute random Free Call Card.) | Paid marketplace is the business | — | — | — | CONFIRMED |
| C3 | Customer = person who starts and pays for a call. Earner = person who receives the call ("call-getter"). | — | R14 | Hosts may count as platform workers | Social Security Code | CONFIRMED |
| C4 | Both men and women are eligible to earn in principle. Women being the majority of earners is a hypothesis. | — | C17 | — | — | CONFIRMED |
| C5 | Two currencies: Diamonds → Beans → real money. | — | R4 | PPI or redemption treatment | Lawyer + CA | CONFIRMED |
| C6 | Lean, revenue-focused MVP that still meets minimum safety and legal requirements. | Avoid months of unnecessary features | — | Under-built safety (§7 of report) | — | CONFIRMED |
| C7 | Live streaming is optional and only if it pays for itself. Not in the MVP. | — | — | — | — | CONFIRMED |
| C8 | India first. International expansion only after India works. | — | — | — | — | CONFIRMED |
| C9 | The founder builds the Flutter UI. Claude assists with business work and later with technical work. | — | — | — | — | CONFIRMED |

### Round 2

| ID | Decision | Founder reasoning | Dependencies | Risks | Research needed | Status |
|---|---|---|---|---|---|---|
| C10 | **Founder's answer: "B + C"**: flirting and romance, plus broader consensual adult interaction. **Audit correction:** v1/v2 of this log recorded only "B". The verbatim answer is restored here. Option C was flagged as conflict X1, then **refined by R3-1**. | Not limited to friendly conversation | R9–R12 | — | — | CONFIRMED as answered. Superseded by R3-1. |
| C11 | Users control who can message them: everyone, or only people they have had a video call with. Explore message requests, blocking and reporting. | User privacy control | — | Spam from hosts | — | CONFIRMED |
| C12 | Only hosts online now can be called. No scheduled bookings. Availability must update correctly (offline / busy / in call). | — | — | — | — | CONFIRMED |
| C13 | Hosts set their own Diamond-per-minute rate within Dashuri's minimum and maximum. Rate shown before the call. Hosts can change it within limits. | — | P3 | Stolen cards turned into cash through a high-rate host | — | CONFIRMED |
| C14 | Hosts are completely independent: no compulsory hours, minimum calls, required acceptance or performance targets. Only safety, fraud and legitimate enforcement rules apply. | "I don't want dictatorship by Dashuri." Social-platform model. | — | Too few hosts online at peak | — | CONFIRMED |
| C15 | Hosts can accept or reject calls and end them any time. No penalties. Customers pay, and hosts earn, only for billable time. | — | C20 | — | — | CONFIRMED |
| C16 | Explore every host recruitment channel. | — | — | Agency fraud | Channel economics | CONFIRMED |
| C17 | Women hosts at launch. Male hosts later. A launch strategy, not an exclusion. | — | — | — | — | CONFIRMED |
| C18 | Beans are INR-denominated. Withdrawals in INR. No USD peg. **Supersedes F2's USD element.** | — | — | — | — | CONFIRMED |
| C19 | Weekly payouts, ₹500 minimum, 7-day hold. (Founder approved Claude's proposal.) Re-confirmed in R3-6. | Protects against chargebacks | R3-7 | Cash gap (R17) | Settlement timing | CONFIRMED |
| C20 | Per-second proportional billing. No rounding up to a full minute. Example from founder: 1 min 5 s ≈ 4,333 Diamonds at 4,000 D/min. | — | P4 | — | — | CONFIRMED |
| C21 | Billing pauses during qualifying interruptions and resumes on recovery. Affected time credited automatically. A call that never connects is fully refunded. Hosts earn only for eligible time. | — | P5 | Refund abuse | Interruption detection | CONFIRMED |
| C22 | Begin as a sole proprietorship. Refined by R3-7. | Minimise early cost | — | Personal liability | CA / lawyer | CONFIRMED |
| C23 | Founder funds the technical stack. Advertising and marketing are managed separately and excluded from the technical budget. No ad budget is invented. Customer acquisition is analysed separately. | — | — | — | — | CONFIRMED |
| C24 | No six-month loss limit has been given. None will be invented. | — | — | — | — | CONFIRMED |

### Round 3

| ID | Decision | Founder reasoning | Dependencies | Risks | Research needed | Status |
|---|---|---|---|---|---|---|
| R3-1 | **Content.** Permitted: flirting, romantic conversation, broader consensual adult conversation, mature personal conversation. Prohibited: nudity, sexual acts, explicit sexual content. **Resolves X1.** | — | R9–R12, R19 | The store listing or actual use drifting towards "sex for compensation" | Written confirmation from payment provider; lawyer | CONFIRMED |
| R3-2 | Android first. iOS-ready architecture. No iOS build until Apple's policies and commercial case have been reviewed. | — | R10, R11 | — | Apple review | CONFIRMED |
| R3-3 | **XP formula `XP = 8×D + B`**, with all integrity rules (separate from wallets; never reduced by spending or withdrawing; one XP grant per purchase; reversals for refunds and fraud; cannot be transferred or redeemed). **Thresholds, levels, names and rewards are NOT approved.** | Diamonds should carry far more weight in progression | P12 | Levels becoming a fraud target | Spending and earning distributions | CONFIRMED (formula + rules only) |
| R3-4 | Keep Claude's six Diamond packs **for evaluation**. Not final prices. | — | P1 | — | Validation list in report §11 | CONFIRMED as evaluation set |
| R3-5 | Keep the **original Free Call Card**: one minute of free random video calling, separate from browse-and-choose. **Claude's P6 is rejected.** | Founder's original design | R18, R10 | Fake-account farming; Apple | Policy, fraud, host compensation | CONFIRMED (concept). Mechanics UNRESOLVED. |
| R3-6 | Payouts stay weekly, ₹500 minimum, 7-day hold. **Founder accepts responsibility for funding the settlement gap.** | — | R17 | Cash crunch | Working capital (report §22) | CONFIRMED |
| R3-7 | Sequence: sole proprietorship for development, internal testing and closed beta, with **no money withdrawals**. Before withdrawals: evaluate Pvt Ltd vs OPC, get legal, tax and accounting advice, sign host agreements, complete registrations and payment onboarding. **Pvt Ltd vs OPC is UNRESOLVED.** | Avoid early cost; avoid a structure that later can't operate | — | — | CA / lawyer | CONFIRMED (sequence) |
| R3-8 | Technical budget is founder-funded and excludes marketing. No monthly ceiling approved. Acquisition economics analysed separately. | — | — | — | — | CONFIRMED |
| R3-9 | **₹0.005 per Bean (200 Beans = ₹1) is the founder's confirmed preferred conversion rate.** **Audit correction:** v2 recorded this as "PROPOSED BY FOUNDER — NOT FINAL". The founder's audit instruction of 2026-11-17 confirms it as the preferred rate. **Not confirmed:** the earning ratio of Beans per Diamond spent (P2: 1 D → 1 B). Host pay depends on both. | Market-matching host share | P2 | — | — | **CONFIRMED BY FOUNDER** (preferred rate). Earning ratio UNRESOLVED. |

---

## B. Proposed by founder — not final

| ID | Item | Status |
|---|---|---|
| F1 | One-minute random Free Call Card. Re-issue and host compensation undecided. | Concept CONFIRMED (R3-5). Mechanics UNRESOLVED (P13). |
| F2 | ₹1,130 → 48,000 D; 4,000 D/min; 0.6 Beans per Diamond; 10,000 Beans = $1. | **Superseded:** USD element by C18; packs by R3-4; Bean value by R3-9. Kept for history. |
| F3 | Customers mostly men. | ASSUMPTION REQUIRING VALIDATION |
| F4 | A $1M ambition. Its meaning is undefined. | UNRESOLVED |

## C. Conflicts (history)

| ID | Item | Resolution |
|---|---|---|
| X1 | Round 2 option C, which could include explicit content. | Resolved 2026-11-17 by R3-1. |
| X2 | **Host rate description mismatch.** The founder's Round 3 brief described Claude's host rate proposal as "2,000 / 4,000 / 8,000 Diamonds/minute". Claude's actual P3 is a **continuous range of 2,000–8,000**, with new hosts **capped at 4,000** until 5 billable hours. | **UNRESOLVED.** Founder to confirm the intended reading (decision sheet item 2). |

## D. Proposed by Claude (none approved unless stated)

| ID | Proposal | Status |
|---|---|---|
| P1 | Packs: ₹99/4,000 · ₹299/12,500 · ₹599/26,000 · ₹1,199/54,000 · ₹2,999/140,000 · ₹5,999/290,000 | Evaluation set (R3-4). **Not approved as prices.** |
| P2 | Earning ratio 1 Diamond spent = 1 Bean | **UNRESOLVED.** The value part (₹0.005) is confirmed in R3-9. |
| P3 | Host range 2,000–8,000 D/min. New-host cap 4,000 until 5 billable hours. | NOT APPROVED (see X2) |
| P4 | Diamonds calculated over the whole call and rounded once, in the customer's favour. 60 s balance needed to start. 30 s warning. Call ends automatically at zero. | NOT APPROVED |
| P5 | Billing starts when the server confirms both streams are live. 5 s grace period. Pause if the host's connection signal is missing for more than 10 s. | NOT APPROVED |
| P6 | Free Call Card with a chosen host pool and payment only on conversion | **REJECTED (R3-5).** Kept for history. |
| P7 | Purchased Diamonds never expire. Promotional Diamonds expire after 30 days. No transfers. Not refundable once spent. | NOT APPROVED. **Note:** Apple 3.1.1 requires IAP currencies "may not expire" (verified), so the no-expiry rule is mandatory for any future iOS build. |
| P8 | Earned Beans never expire. | NOT APPROVED |
| P9 | Reversed purchase after spending: claw back held Beans, block the customer, Dashuri absorbs the rest. | NOT APPROVED |
| P10 | No agencies at launch. Host referral programme instead. | NOT APPROVED |
| P11 | Proprietorship beta with no payouts. Incorporate before withdrawals. | Adopted in substance by R3-7 |
| P12 | 10 XP levels: 0 / 32k / 100k / 250k / 600k / 1.5M / 3.5M / 8M / 18M / 40M. Names Newcomer → Legend. Cosmetic rewards only. One shared level per user. | **NOT APPROVED** (thresholds, names, rewards, shared vs separate) |
| P13 | Free Call Card: random among opted-in hosts; ₹10 (2,000 Beans) per completed free minute; 20 per host per day; one per phone and device; disabled on iOS. | NOT APPROVED |
| P14 | Play organisation account (D-U-N-S number) | NOT APPROVED |
| P15 | On-device nudity pre-check, plus server frame sampling every 20 s, plus a report button that ends the call | NOT APPROVED |
| P16 | Voluntarily apply Play's minor-blocking tools even if Dashuri is not formally in scope as a random-chat app | NOT APPROVED (new in audit) |

## E. Research findings

Labels: VERIFIED-OFFICIAL = checked against the primary or official source in this session · RS = research-supported (credible secondary) · UNVERIFIED · PR = professional review needed

| ID | Finding | Status |
|---|---|---|
| R1 | India live video chat spend about $46M (2022). Chamet about $15.4M (Data.ai via TechCrunch, 2023-09-01). Historical. | RS |
| R2 | Chamet removed from Play, Aug 2023, under the UGC policy | RS (TechCrunch; Google confirmed to TechCrunch) |
| R3 | MeitY s.69A order against 119 apps (Feb 2025); 15 blocked | RS. Order not public. |
| R4 | Closed-system PPI: no cash redemption | RS (law-firm commentary). Current Master Direction UNVERIFIED. |
| R5 | Stream: HD $1.50 per 1,000 participant-min; $100/month free credit; rate set by aggregate received resolution | **VERIFIED-OFFICIAL** (pricing guide + pricing page) |
| R6 | Cashfree prohibits "Adult goods and services, which include pornography and other sexually suggestive materials" and "escort or prostitution services". **Dating, chat and live streaming are not listed.** Catch-all: services not compliant with law. Cashfree may deactivate accounts at its discretion. | **VERIFIED-OFFICIAL** (Cashfree FAQ) |
| R7 | Founder's original ratio pays hosts about 22% of gross | Calculated |
| R8 | Chamet agency ladder 5–30% | **UNVERIFIED** (reseller sources only) |
| R9 | Google Play: "We don't allow apps or app content that appear to promote or solicit a sexual act in exchange for compensation." | **VERIFIED-OFFICIAL** |
| R10 | Apple 1.2, official text: "Apps with user-generated content or services that end up being used primarily for pornographic content, Chatroulette-style experiences, random or anonymous chat, objectification of real people… do not belong on the App Store and may be removed without notice." **The "Feb 2026" date of the random-chat wording is UNVERIFIED** (the official page shows no date). | Text **VERIFIED-OFFICIAL**; date UNVERIFIED |
| R11 | Apple 3.1.3(d), official text: real-time person-to-person services between two individuals "may use purchase methods other than in-app purchase". Apple 3.1.1: in-app currencies require IAP and "may not expire". Whether Dashuri's Diamonds could use 3.1.3(d) is uncertain. | Text **VERIFIED-OFFICIAL**; applicability PR |
| R12 | IT Act ss.67 / 67A | Claude's statutory knowledge; PR |
| R13 | DPDP Rules notified Nov 2025 (13 or 14 Nov; sources differ). Main obligations about May 2027. | RS |
| R14 | Social Security Code in force 21 Nov 2025. Social Security (Central) Rules 2026 in force 8 May 2026. **Aggregator rate and start date NOT notified as of Oct 2026.** Karnataka has a separate state gig-worker fee (notified Feb 2026). | RS; PR |
| R15 | Play fee: "15% for the first $1M (USD) revenue earned by the developer each year" and "30% for earnings in excess of $1M" for "all remaining markets" (India is not among the AU/EEA/JP/UK/US new-fee markets). Enrolment required. India alternative billing: fee "reduced by 4%". Whether that means percentage points or a relative 4% is **ambiguous in the official text**. | **VERIFIED-OFFICIAL**; ambiguity noted |
| R16 | No reliable public customer-acquisition-cost data for the category | Data gap |
| R17 | Google payout "starts on the 15th of each month for the previous month's sales". Bank transfer 2–7 business days. India split disbursement and BillDesk verification: **UNVERIFIED** in this audit (seen only in search snippets). | Schedule **VERIFIED-OFFICIAL** |
| R18 | Play Policy Deadlines table: **2026-08-26** Age-Restricted Content and Functionality, and Child Endangerment (Child Safety Standards), extended to anonymous and random chat apps; Families policy bars anonymous-chat apps from targeting children. **2026-09-30** developer verification. Announcement dated **2026-07-15**. Scope wording: "Apps whose core functionality is to facilitate randomly connecting users to spontaneously communicate". The tool name "Restrict Minor Access" is **UNVERIFIED** (the official page says "Play Console functionality and tools to block minors"). | **VERIFIED-OFFICIAL** (dates, scope) |
| R19 | IT (Amendment) Rules 2026, G.S.R. 120(E): notified 10 Feb 2026, in force 20 Feb 2026. Intimate-image complaint takedown 24 h → **2 h**. Takedown on government or court orders 36 h → **3 h**. Exact rule numbering conflicts between sources. | RS (multiple law firms). Gazette text not read: PR. |
| R20 | Personal Play accounts created after 13 Nov 2023: closed test with at least 12 testers for 14 days | **VERIFIED-OFFICIAL** |
| R21 | Cashfree Payouts table ₹6 / ₹8 / ₹15 per IMPS/UPI by band, but labelled "Wallets/Connected BaaS". The help centre says custom pricing. | **UNVERIFIED** for Dashuri's use case |
| R22 | KYC: ₹10 (Aadhaar offline) and ₹18 (with liveness) per check, from one vendor's page | Vendor-published; others UNVERIFIED |
| R23 | Cloud Vision SafeSearch about $1.50 per 1,000 images | **UNVERIFIED** (official page did not render) |
| R24 | Play Payments policy: "Items (such as virtual currencies…)" require Play Billing. "In-app virtual currencies must only be used within the app… for which they were purchased." The peer-to-peer exemption covers P2P payments, not virtual currency (Claude's interpretation). | **VERIFIED-OFFICIAL** (text) |
| R25 | Apple 1.1.4 excludes "'hookup' apps and other apps that may include pornography or be used to facilitate prostitution" | **VERIFIED-OFFICIAL** |
| R26 | Google support pages **conflict** on who pays GST on Play in-app sales to Indian buyers by India-based developers. One page says the developer "may be responsible". Older and other pages say Google collects it. Google also deducts Indian withholding tax from Indian developers' proceeds. | **UNVERIFIED (conflicting official sources)**; PR |
| R27 | TDS s.194-O cut to **0.1%** from 1 Oct 2024. 5% if no PAN. | RS (statute as amended, via tax sources) |
| R28 | Supabase Pro: from $25/mo; $10 compute credit; 8 GB disk; 250 GB egress; 100k MAU; 100 GB storage; spend cap on by default | **VERIFIED-OFFICIAL** |
| R29 | Cloud Run pricing | **UNVERIFIED** (official page did not render) |
| R30 | OTP SMS about ₹0.15–0.25 + GST + DLT | **UNVERIFIED** (third-party) |
| R31 | Other payment processors: Amazon Payment Services lists "escort, dating, chatting" as prohibited. Razorpay calls dating "high risk". | Secondary / UNVERIFIED for Razorpay's actual policy |

## F. Unresolved

The short founder list is in report §29 (decision sheet). Professional and evidence items are in report §27.

## G. Audit corrections log (2026-11-17)

| # | Correction |
|---|---|
| 1 | C10: restored the founder's verbatim "B + C" (v2 said "B"). |
| 2 | R3-9: ₹0.005 per Bean moved to **CONFIRMED BY FOUNDER** (preferred rate). Beans-per-Diamond ratio split out as unresolved. |
| 3 | X2 added: mismatch between the founder's description of the host rates and P3. |
| 4 | R10: Apple random-chat **text verified**; "Feb 2026" **date marked UNVERIFIED**. |
| 5 | R18: 26 Aug 2026 **verified** from the official deadlines table. "Restrict Minor Access" name UNVERIFIED. Scope is "core functionality" (see P16). |
| 6 | R17: added 2–7 business-day bank transit. Working-capital gap revised (report §22). |
| 7 | R21, R23, R29, R30 downgraded to UNVERIFIED. |
| 8 | R26 added: conflicting official guidance on GST for Play sales. Store-fee base also uncertain. |
| 9 | ₹1,199 example recalculated with moderation included: contribution ₹533.97 (was ≈₹539 without moderation). |
| 10 | P7: Apple 3.1.1 no-expiry requirement noted. |

---

## H. Founder decisions from the simulation brief (2026-11-17), CONFIRMED BY FOUNDER

**These take precedence over conflicting earlier entries.** Superseded entries above are kept and cross-referenced here.

| ID | Date | Decision | Founder reasoning | Supersedes / resolves | Dependencies | Risks | Research needed | Status |
|---|---|---|---|---|---|---|---|---|
| S1 | 2026-11-17 | Build a profitable business and take whatever profit it generates. No fixed $1M revenue, valuation or wealth target. | Optimise for sustainable profit and cash. | F4 (resolved) | — | — | — | CONFIRMED |
| S2 | 2026-11-17 | Hosts set their own Diamond rate, limited by their Dashuri level. Minimum 500, maximum 10,000 D/min. | Host freedom within platform limits. | P3, X2 (resolved: neither reading; new range) | S8 | Stolen cards turned into cash through high-rate new hosts if the ladder is loose | Ladder and thresholds | Range CONFIRMED. Ladder UNRESOLVED (3 proposals simulated). |
| S3 | 2026-11-17 | 16,670 Diamonds spent = 10,000 Beans. 1 Bean = ₹0.005 (10,000 Beans = ₹50; ≈ ₹0.003 per Diamond). Exact formula, no early rounding. | — | P2 (1:1 earning ratio superseded); completes R3-9 | — | Host share ≈ 13.5% of price; host supply risk | Host acceptance of earnings level | CONFIRMED |
| S4 | 2026-11-17 | Free Call Card approved: one free random minute for eligible new customers; ₹10 host compensation per eligible free-call minute; voluntary host opt-in pool; max 20 per host per day; one card per phone and device; disabled on iOS; Android only, subject to policy. Free-to-paid conversion unknown. | Founder design (R3-5) | P13 (approved); F1 mechanics resolved | R18 | Play random-chat scope; farming; largest host cost in Base simulation | Conversion data from beta | CONFIRMED |
| S5 | 2026-11-17 | Wallet rules: purchased Diamonds never expire; promotional Diamonds expire after 30 days; non-transferable; Beans never expire; refunds, chargebacks and fraud trigger reversals; unspent Diamonds are a customer liability; earned Beans are a host liability. | — | P7, P8, P9 (approved) | — | — | Accounting treatment (CA) | CONFIRMED |
| S6 | 2026-11-17 | Billing: per second, no rounding up; starts when both streams connect; sufficient balance required; 30 s warning; pauses on qualifying interruptions and resumes; eligible failed connections refunded; final charge once, in the customer's favour. | — | P4, P5 (approved except thresholds) | — | Refund abuse | Interruption thresholds remain a technical assumption | CONFIRMED (thresholds = ASSUMPTION) |
| S7 | 2026-11-17 | Minor protection is mandatory. Nudity bot runs during the **first three minutes** of each call only; after that, moderation is report-based; nudity reports trigger investigation and enforcement. | Lean moderation cost | P15 (superseded) | R9, R19 | **Play UGC and Sexual Content enforcement; IT Rules 2-hour takedown; not shown to be compliant** | Lawyer + Play policy review | CONFIRMED by founder; compliance REQUIRES PROFESSIONAL REVIEW |
| S8 | 2026-11-17 | XP = 8×D + B (all R3-3 rules). One shared level per account, whether acting as customer or host. Host pricing limits depend on that level. Levels, thresholds, names and rewards unresolved. | — | P12 (shared vs separate resolved: shared) | S2 | Customers who are also hosts gain rate headroom from top-ups (8× weight) | Threshold calibration from beta | CONFIRMED (formula + shared level) |
| S9 | 2026-11-17 | Host recruitment, sourcing, agencies, relationships and onboarding are managed by the founder. No Claude recruitment strategy or agency recommendation. | Founder ownership | P10 and report §15.1 recommendation (withdrawn) | — | — | — | CONFIRMED |
| S10 | 2026-11-17 | Publish on the existing BK Enterprises Google Play developer account (Route already in production). Android first; iOS-ready architecture; iOS not in the launch simulation. | Existing account | P14 (superseded) | R20 | **Policy action on Dashuri could affect the whole account, including Route** | Account type (personal or organisation) and Play account-level enforcement rules | CONFIRMED; risk flagged |
| S11 | 2026-11-17 | Six proposed packages used for simulation only; not final prices. | — | Re-confirms R3-4 | — | — | Price testing | CONFIRMED |
| S12 | 2026-11-17 | Founder formally authorises the six-month financial simulation and lifts the simulation gate. Production development not authorised. | — | Phase 8 gate | — | — | — | CONFIRMED |

### H.1 New research inputs used by the simulation (retrieved 2026-11-17)

| ID | Finding | Status |
|---|---|---|
| R32 | Sightengine: Starter $29/mo for 10k operations; Pro $99/mo for 40k; overage $0.002/op; 1 nudity check on 1 image = 1 operation. | VENDOR (official pricing page) |
| R33 | Google refunds: refunds are subtracted from developer payouts and the service fee is returned (Google help). Developer-borne chargebacks for orders after 3 Aug 2026, plus bank fees of $15–25 per case, are reported by third parties only. | Partly UNVERIFIED |
| R34 | Cloud Run official pricing page did not render. Secondary sources: Tier 1 $0.000024/vCPU-s, free tier 180k vCPU-s. asia-south1 tier unknown. | UNVERIFIED |

### H.2 Still unresolved after the simulation brief

1. Level thresholds, names, rewards and the rate ladder (S2, S8)
2. Exact interruption thresholds (S6)
3. Promotional Diamond grants (none decided; simulated as 0)
4. Pvt Ltd vs OPC
5. GST principal/agent, who remits GST on Play sales, Play-fee base (CA)
6. TDS section on payouts (CA)
7. Payout provider acceptance (launch blocker)
8. Legal sufficiency of S7 moderation (lawyer)
9. Whether to isolate Dashuri from the Route developer account (S10 risk)
10. Customer acquisition budget (founder-managed; none assumed)

---

## I. Engineering foundation (2026-11-17)

The founder authorised the architecture and project scaffold. Production feature implementation is still not authorised. Architectural choices made in this phase are **PROPOSED BY CLAUDE** and recorded as ADRs in `docs/architecture/decisions/`. They do not change any business decision.

| ID | Item | Status |
|---|---|---|
| A1 | Flutter Melos 8 monorepo on pub workspaces; 12 feature packages (customer, matchmaking, levels and location folded or excluded, with reasons) | PROPOSED BY CLAUDE (ADR-001, ADR-002) |
| A2 | Go modular monolith on Cloud Run (API + jobs) | PROPOSED BY CLAUDE (ADR-003), matches founder preference |
| A3 | Immutable double-entry ledger with database-enforced invariants | PROPOSED BY CLAUDE (ADR-004) |
| A4 | Video provider behind ports; Stream not yet added | PROPOSED BY CLAUDE (ADR-005); provider still pending validation |
| A5 | App uses Supabase only for Auth, Realtime (receive-only) and signed-URL Storage; all domain data via Go | PROPOSED BY CLAUDE (ADR-006, ADR-009) |
| A6 | No Redis at launch | PROPOSED BY CLAUDE (ADR-007) |
| A7 | Play Billing for Diamonds; provider-neutral payouts, disabled until R3-7 | PROPOSED BY CLAUDE (ADR-010); follows audit B3 |
| A8 | Application id `com.bkenterprises.dashuri` (permanent once uploaded) | UNRESOLVED: founder to confirm |
| A9 | Newly surfaced decisions needed: Diamond spend order (promotional vs purchased first), whether promotional Diamonds earn Beans, Bean rounding residue, interruption threshold (10 s technical assumption), moderation frame source (server vs client) | UNRESOLVED |
