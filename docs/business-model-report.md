# DASHURI — CONSOLIDATED BUSINESS MODEL DISCOVERY REPORT

- **Version:** 0.3 (2026-11-17)
  - Adds **Part C**: the founder's latest decisions from the simulation brief. **They take precedence over anything earlier in this document.**
  - Adds **Part D**: a summary of the six-month simulation.
  - v0.1 and v0.2 text is kept for history.
- **Date:** 2026-11-17
- **Status:**
  - The founder formally authorised the six-month financial simulation on 2026-11-17, lifting the simulation gate. See Part C.
  - Development of the production app is **not** authorised.
  - The business model as a whole remains open to founder correction.
  - *Previous status (v0.2):* "NOT APPROVED. No financial simulation or development may start until the founder writes 'I APPROVE THE DASHURI BUSINESS MODEL'."
- **Decision record:** `docs/discovery-log.md`. The IDs in this report (C#, R3-#, P#, R#) refer to that file.

**Labels used in this report:**

| Label | Meaning |
|---|---|
| **[FOUNDER]** | Confirmed by founder |
| **[FOUNDER-DRAFT]** | Proposed by founder, not final |
| **[RESEARCH]** | Research-supported |
| **[CLAUDE]** | Proposed by Claude |
| **[ASSUMPTION]** | Assumption requiring validation |
| **[UNRESOLVED]** | Not yet decided |
| **[PRO-REVIEW]** | Requires review by a lawyer, CA or payments specialist |

**Working assumptions used throughout:**
- **₹88 = US$1** [ASSUMPTION]
- Google Play fee of **15%** on the first US$1M a year [RESEARCH + ASSUMPTION; see §18]
- **All figures are per-unit illustrations, not forecasts.** Contribution is *not* net profit.

---

# PART C — LATEST FOUNDER DECISIONS (2026-11-17, simulation brief)

> **These decisions take precedence over every conflicting proposal in Parts A and B.** Superseded items remain below for history. Log IDs are S1–S12 in `docs/discovery-log.md` §H.

| ID | Decision | Supersedes | Status |
|---|---|---|---|
| S1 | **Ambition:** a profitable business; the founder takes whatever profit Dashuri generates. No fixed $1M revenue, valuation or wealth target. Analysis optimises for sustainable profit, cash generation and long-term viability. | F4 / B8 item 1 | [FOUNDER] |
| S2 | **Host pricing:** hosts set their own rate, limited by their Dashuri level. Platform minimum **500 D/min**, maximum **10,000 D/min**. Level thresholds and rate ladder are **not decided**; the simulation models three proposed ladders (A, B, C). | P3 (2,000–8,000; 4,000 new-host cap), X2 | [FOUNDER] range; ladder [UNRESOLVED] |
| S2a | **Verified Host + price ladder (2026-11-23):** minimum **500 D/min** for every host; maximum **level × 1,000** (levels 1–10); prices **above 3,000** need an **active Verified Host** status (staff-reviewed face video + ID). Integer prices only. Revocation or a level drop caps the price before new calls; live calls are never re-priced. Spec: `docs/mvp/VERIFIED_HOST_AND_PRICING.md`, ADR-014. | S2 ladder [UNRESOLVED], P3 | [FOUNDER] |
| S3 | **Conversion:** **16,670 Diamonds spent = 10,000 Beans earned**. 1 Bean = ₹0.005, so 10,000 Beans = ₹50 and ≈ ₹0.003 host payout per eligible Diamond. Use the exact formula. | P2 (1 D = 1 Bean); completes R3-9 | [FOUNDER] |
| S4 | **Free Call Card approved:** one-minute free random video call for eligible new customers. ₹10 host compensation per eligible free-call minute. Hosts opt in. Max 20 free calls per host per day. One card per phone and device. Disabled on iOS. Android only, subject to policy. Free-to-paid conversion is unknown and is modelled as an assumption. | P13 (now approved), F1 mechanics | [FOUNDER] |
| S5 | **Wallet rules:** purchased Diamonds never expire; promotional Diamonds expire after 30 days; Diamonds cannot be transferred; Beans never expire; refunds, chargebacks and fraud trigger reversals; unspent purchased Diamonds are a customer liability; eligible earned Beans are a host liability. | P7, P8, P9 (now approved) | [FOUNDER] |
| S6 | **Billing:** per second, proportional, no rounding up; billing starts only when both streams connect; balance must be sufficient before a call; warning 30 s before the balance runs out; billing pauses during qualifying interruptions and resumes on recovery; eligible failed connections refunded; final charge calculated once, in the customer's favour. **Exact interruption thresholds are simulation assumptions, not founder decisions.** | P4, P5 (approved except thresholds) | [FOUNDER] + [ASSUMPTION] |
| S7 | **Safety:** minor protection is mandatory. Nudity moderation model: **automated nudity bot during the first three minutes of each call only; after that, report-based**. Reports of nudity must trigger investigation and enforcement. | P15 (on-device + server sampling every 20 s throughout) | [FOUNDER]. Compliance [PRO-REVIEW] |
| S8 | **XP and levels:** `XP = 8×D + B`, with all integrity rules (R3-3). **One shared level per account** (customer or host). Host pricing limits depend on that shared level. Number of levels, thresholds, names and rewards remain unresolved. | P12 "shared vs separate" question | [FOUNDER]; thresholds [UNRESOLVED] |
| S9 | **Host recruitment** (sourcing, agencies, relationships, onboarding) is managed by the founder. Claude does not make recruitment or agency recommendations. The simulation uses host supply only as a capacity input. | P10, §15.1 recommendation | [FOUNDER] |
| S10 | **Google Play account:** Dashuri will be published on the existing **BK Enterprises** developer account (Route is already in production there). Android first; architecture iOS-ready; iOS not in the launch simulation. | P14 | [FOUNDER] |
| S11 | **Packages:** the six proposed packages are used for simulation only, not as final prices. | — (re-confirms R3-4) | [FOUNDER] |
| S12 | **Simulation authorised:** the founder formally authorised the six-month simulation and lifted the simulation gate. Production development remains out of scope. | Gate in Phase 8 | [FOUNDER] |

### C1. Consequences of the latest decisions

These are Claude's findings; they need founder attention.

1. **Host share drops to about 13.5% of the customer's price.** S3 pays ₹0.003 per Diamond versus a typical customer price of about ₹0.022 per Diamond.
   - This is about **43% less per Bean** than the competitor figure of 10,000 Beans ≈ US$1 (≈ ₹88). That competitor figure comes from third-party reports only.
   - Margin is higher. Host earnings, and possibly host supply, are at risk.
2. **The moderation model (S7) is a compliance risk.**
   - Google removed Chamet under its UGC policy for content during calls.
   - A bot that stops after minute three leaves the rest of every call to reports.
   - The IT Rules 2026 amendment (reported) requires removal of intimate imagery within 2 hours of a complaint.
   - Whether S7 is enough for Play policy and the law needs a lawyer's opinion and a careful read of Play's UGC policy before launch. [PRO-REVIEW]
3. **Publishing on the BK Enterprises account (S10) puts Route at risk.**
   - Google can suspend a developer account for serious or repeated policy violations. That would affect every app on the account, including Route.
   - A separate developer account, and possibly a separate entity, would isolate Route. This is the founder's decision to make.
   - Also check whether the account is a personal or an organisation account. Personal accounts created after 13 Nov 2023 must run a 12-tester, 14-day closed test for each new app (R20).
4. **Free Call Card (S4).** It brings Dashuri within Play's random-chat scope (minor-blocking tools from 26 Aug 2026). The simulation also shows it is the largest host cost in the Base case (Part D).
5. **No payout provider has accepted Dashuri.** The simulation pays hosts through a hypothetical ₹8-per-transfer channel, labelled UNVERIFIED. This remains a launch blocker for payouts.

---

# PART D — SIX-MONTH SIMULATION SUMMARY (2026-11-17)

Full outputs:
- `docs/simulation/six-month-simulation-report.md`
- Monthly projections, unit economics, sensitivity, cash flow, CSV data
- The interactive dashboard: `simulation/dist/dashuri-simulation.html`

All results are **conditional what-if scenarios, not forecasts**. They are means of 5 seeded runs per scenario, and demand inputs have no market data behind them.

| | Worst | Base | Best |
|---|---:|---:|---:|
| Six-month top-ups (incl. GST) | ₹59,985 | ₹6,97,489 | ₹61,76,977 |
| Recognised revenue (ex GST) | ₹36,775 | ₹4,73,927 | ₹43,39,496 |
| Six-month operating profit before acquisition | **−₹3,16,456** | **−₹1,19,958** | **₹19,77,447** |
| Month 6 operating profit | −₹38,714 | ₹18,045 | ₹7,70,988 |
| First month with operating profit | none | Month 3 to 6 | Month 2 |
| Peak cash requirement (mean / worst run) | ₹3,01,766 / ₹3,18,675 | ₹1,96,707 / ₹2,08,162 | ₹2,48,410 / ₹2,66,479 |
| Break-even acquisition cost per install | none (negative) | none (negative) | ₹15.06 |
| Month 6 median host earnings | ₹567 | ₹1,593 | ₹4,512 |

- Every scenario includes a ₹1,00,000 pre-launch placeholder for incorporation and professional advice, which has not been quoted.
- No marketing spend is included. The "break-even acquisition cost" is the most Dashuri could pay per install and still break even over six months.

**What the simulation shows:**
- Demand, not host supply, decides the outcome. Hosts are 7–21% utilised in Month 6.
- Unit margin is high: about 53% of a fully spent pack's price.
- The Free Call Card and safety operations are the largest costs at small scale.
- Host earnings are low.

---

## 1. Executive summary

**What Dashuri is.** Dashuri is a paid one-to-one video marketplace in India:
- Customers, expected to be mostly men [ASSUMPTION], browse women hosts who are online now [FOUNDER].
- Each host sets her own per-minute Diamond rate within platform limits [FOUNDER].
- Customers are billed per second [FOUNDER].
- Hosts earn Beans denominated in INR and withdraw them weekly [FOUNDER].
- New customers receive a one-minute free random call [FOUNDER].
- Content is limited to flirting, romance and mature adult conversation, with no nudity or sexual content [FOUNDER].

**Demand is proven.** Indians spent about **US$46M on live video chat apps in 2022**, more than they spent on dating apps. Chamet alone took about US$15.4M [RESEARCH, historical].

**Unit economics are strong.** At the proposed economics, every paid minute contributes about **44–45% of what the customer pays**, before acquisition and fixed costs [CLAUDE, calculated in §23]. Video infrastructure is a rounding error: about ₹0.27 a minute.

**The model will not fail on unit margin. It can fail in four ways:**

1. **Being removed or blocked.**
   - Google removed the category leader (Chamet) in 2023.
   - MeitY targeted 119 video and voice chat apps in 2025.
   - Cashfree prohibits adult services.

   Dashuri's survival depends on *visibly* holding the content line it has chosen.
2. **Customer acquisition.** There is no reliable public data on acquisition cost for this category. Ad platforms restrict dating-style advertising. No marketing budget has been set [FOUNDER].
3. **Fraud.** Stolen payments can be pushed through colluding host accounts and withdrawn as cash, which also makes Dashuri a money-laundering route.
4. **Cash timing.** Google pays monthly, but hosts are paid weekly, so the founder pre-funds roughly **3 to 5½ weeks of host payouts** [RESEARCH + CLAUDE, calculated in §22].
   - *Audit (v0.2):* adding Google's official 2–7 business-day bank transit gives **about 22–30 days on average and up to about 48 days at worst**. See B5.

**Bottom line:** commercially attractive per unit, with high platform and regulatory risk. It is viable only if safety, KYC and fraud controls are built *into* the MVP rather than added afterwards.

---

## 2. Product concept

| Element | Decision | Label |
|---|---|---|
| Core | Paid one-to-one video with chosen hosts who are online now | [FOUNDER] C2, C12 |
| Discovery | Browse list of available hosts. No scheduling. | [FOUNDER] |
| Promotional | One-minute free random call for new customers | [FOUNDER] R3-5 |
| Messaging | Each user sets who can message them: everyone, or only past call partners. Blocking and reporting included. | [FOUNDER] C11 |
| Live streaming | Not in the MVP. Later, only if it pays for itself. | [FOUNDER] C7 |
| Platform | Android first. Architecture iOS-ready. | [FOUNDER] R3-2 |
| Market | India | [FOUNDER] |

---

## 3. Target customers

| Segment | Description | Evidence | Label |
|---|---|---|---|
| Paying customers | Adult men, mid-income, in metro cities and tier-2/3 towns | Curiosity Letter (Feb 2023, anecdotal); TechCrunch (Sep 2023) | [ASSUMPTION] F3 |
| Hosts (supply) | Women aged 18–40, often from tier-2/3 cities, wanting flexible income | Curiosity Letter (anecdotal) | [ASSUMPTION] |
| Later: male hosts | After launch | — | [FOUNDER] C17 |

**Validation needed:**
- The actual gender mix of payers.
- The share of installs that convert to paying.
- Spend per paying customer.

There is no public data on any of these. They must be measured in the closed beta.

---

## 4. Customer journey

1. Install from Play. The Play 18+ restriction is applied, which blocks users Google identifies as minors (§18).
2. Register with phone number and one-time code. Confirm age (18+). Accept terms and content rules.
3. **Free Call Card:** one random one-minute free call with a host who has opted in to free calls [FOUNDER concept; mechanics proposed in P13].
4. Browse hosts who are online now. Each profile shows photos, languages and rate in Diamonds per minute.
5. Tap call. The app checks the customer has at least 60 seconds of balance at that rate [CLAUDE P4]. If not, it shows the Diamond packs.
6. Buy Diamonds through Google Play Billing (§19).
7. The call connects. Billing starts when both video streams are live [CLAUDE P5]. Charging is per second [FOUNDER].
8. The customer sees a warning 30 seconds before the balance runs out. The call ends automatically at zero [CLAUDE P4].
9. After the call: rate or report the host. Messaging opens if the host's privacy settings allow it.
10. XP increases from Diamonds purchased, not from Diamonds spent [FOUNDER R3-3].

---

## 5. Host journey

1. **Apply.** Women only at launch [FOUNDER]. Verification required:
   - Phone number.
   - Aadhaar offline e-KYC or DigiLocker.
   - PAN, needed for tax withholding.
   - Liveness check and face match against the profile photos.
   - Age 18+ confirmed from the ID.

   [CLAUDE; legal basis in §17]
2. **Accept the host agreement:**
   - Independent creator status.
   - Content rules.
   - Bean terms.
   - Tax withholding.
   - Consent to data processing.

   [PRO-REVIEW]
3. **Set up a profile and choose a rate** within Dashuri's limits [FOUNDER C13]: 500 to level × 1,000 D/min, at most 3,000 until she becomes a **Verified Host** [FOUNDER S2a].
3a. **Optional: become a Verified Host.** Submit a short face video and an ID image; staff review it. The badge shows on her profile and cards, and she may charge above 3,000 D/min up to her level limit [FOUNDER S2a].
4. **Go online whenever she likes.** Accept or decline calls, end calls any time, opt in or out of Free Call Card calls. No quotas, no penalties [FOUNDER C14, C15].
5. **Earn Beans per second** of eligible time [FOUNDER].
6. **Withdraw.** Beans become withdrawable 7 days after they are earned. Withdrawals are weekly, minimum ₹500, to a bank account or UPI ID in her own name [FOUNDER C19]. **Withdrawals are only enabled after incorporation and onboarding [FOUNDER R3-7].**

---

## 6. Marketplace operating model

Dashuri is a **two-sided marketplace**:
- **Demand:** paying customers.
- **Supply:** independent hosts.
- **Dashuri's role:** sells Diamonds, runs discovery, calls, billing, safety and payouts.

The founder has chosen **creator-style independence** for hosts, not an employment-style relationship [FOUNDER C14]. That choice:
- **Helps** the argument that hosts are independent contractors rather than employees.
- **Probably brings hosts within the definition of "platform workers"** under the Code on Social Security, 2020, which may trigger an aggregator levy (§17).

**How much host supply is needed.** The $1M sizing in Round 2 showed that **demand, not host supply, is the binding constraint**. A few dozen hosts online at peak hours can serve thousands of paying customers.

The real supply problem is **peak-hour coverage**, because hosts cannot be scheduled. The usual tools are:
- Bean bonuses at peak hours.
- Showing hosts when demand is high.

Both are **incentives, not obligations**, so they are consistent with C14 [CLAUDE].

---

## 7. Content boundaries and safety requirements

### 7.1 The boundary [FOUNDER R3-1]

| Permitted | Prohibited |
|---|---|
| Flirting, romance, mature personal conversation between adults | Nudity, sexual acts, explicit sexual content |
| — | Soliciting off-platform paid sexual services |
| — | Minors in any role |
| — | Pre-recorded or fake video presented as a live host |
| — | Sharing contact details to move customers off the platform (recommended) |

### 7.2 Legally permissible versus what platforms allow

| Layer | Status for Dashuri's positioning | Label |
|---|---|---|
| **Indian law** | Non-explicit adult conversation is generally lawful. Transmitting obscene material (IT Act s.67) or sexually explicit acts (s.67A, up to 5 years) is an offence. Platforms keep safe-harbour protection (s.79) only if they meet the IT Rules 2021 due-diligence duties. | [PRO-REVIEW] |
| **Google Play** | Allowed in principle. **Not allowed:** apps that "appear to promote or solicit a sexual act in exchange for compensation" or promote "sex-related entertainment". The **store listing, screenshots and ads matter as much as the product.** Chamet was removed under the UGC policy because of how it was actually used. | [RESEARCH, official] |
| **Apple** | 1.2 excludes "objectification of real people" and "random or anonymous chat" (official text verified). The **date** the random-chat wording was added (reported as Feb 2026) is **UNVERIFIED**. 1.1.4 excludes "hookup" apps. **High risk.** That is why iOS is deferred [FOUNDER R3-2]. | [VERIFIED-OFFICIAL text; see B2] |
| **Cashfree** | Prohibits "adult goods and services… sexually suggestive materials". Flirting and romance is a grey zone. **Get written confirmation before relying on Cashfree.** | [RESEARCH, official] + [PRO-REVIEW] |
| **MeitY (s.69A)** | Has blocked foreign video chat apps. An Indian operator with visible compliance is better placed, but this is not guaranteed. | [RESEARCH] |

### 7.3 Minimum safety needed before launch

These are not features to add later.

| # | Requirement | Why | Label |
|---|---|---|---|
| S1 | Play Console **Restrict Minor Access** set to 18+ only | Mandatory for random-chat apps from 26 Aug 2026; the Free Call Card brings Dashuri into scope | [RESEARCH] |
| S2 | Child Safety Standards: published policy against child sexual abuse, in-app reporting, a process for handling abuse material, a named child-safety contact | Mandatory for Play | [RESEARCH] |
| S3 | Host KYC: Aadhaar offline or DigiLocker, PAN, liveness check, age from ID | Age assurance; payouts; fraud | [CLAUDE] |
| S4 | **Nudity detection on the host's video:** an on-device check plus server sampling of a frame every 20 s; flagged calls cut automatically and sent to review | Keeps the R3-1 line enforceable | [CLAUDE P15] |
| S5 | Report button during calls that ends the call and keeps an evidence frame | IT Rules complaint handling | [CLAUDE] |
| S6 | Grievance Officer in India; acknowledge complaints within 24 h and resolve within 15 days; remove nudity or sexual-act content within **24 h, possibly 2 h** under the 2026 amendment | IT Rules 2021, Rule 3(2) | [RESEARCH] + [PRO-REVIEW] |
| S7 | Privacy notice, consent and data-deletion flow | DPDP Rules, fully effective about 13 May 2027; build now | [RESEARCH] |
| S8 | Blocking, plus user-controlled messaging settings | C11 | [FOUNDER] |
| S9 | No contact details in profiles; automatic filtering of phone numbers and links in chat | Off-platform payments; loss of revenue; solicitation | [CLAUDE] |

**Can wait until later:**
- Human moderation team working shifts.
- Customer age estimation from video.
- Audio analysis.
- Detection of known abuse images using external hash databases.

These should be added as volume grows.

---

## 8. Diamond economy

| Rule | Proposal | Label |
|---|---|---|
| How Diamonds are bought | Google Play Billing (User Choice Billing evaluated separately) | [CLAUDE] |
| What they can be used for | Paid calls only at MVP | [FOUNDER] |
| Transfers | Cannot be transferred between users | [CLAUDE P7] |
| Expiry | Purchased: never. Promotional: 30 days. | [CLAUDE P7] |
| Refunds | Unused Diamonds: per Play refund policy. Once any have been spent: not refundable. | [CLAUDE P7] |
| Cash value | **None.** Diamonds can never be redeemed for cash. This keeps them within the "closed-system" treatment that does not allow cash redemption. | [RESEARCH R4] + [PRO-REVIEW] |

**Accounting.** Unspent Diamonds are a **liability to customers** for services not yet delivered. Revenue is recognised **when Diamonds are spent**, not when they are bought.

**Principal or agent: this could materially change GST and revenue.** The question is whether Dashuri:
- **(a) sells call time to customers as principal and buys services from hosts**, in which case revenue is gross and GST applies to the whole sale; or
- **(b) acts as agent for hosts**, in which case revenue is commission only and the host's portion may be the host's own GST matter.

[PRO-REVIEW, high priority]

---

## 9. Bean economy

| Rule | Proposal | Label |
|---|---|---|
| Currency | INR | [FOUNDER C18] |
| Earning | 1 Diamond spent in an eligible call = 1 Bean | [CLAUDE P2] |
| Value | **200 Beans = ₹1** (1 Bean = ₹0.005) | [FOUNDER R3-9: confirmed preferred rate; audit correction] |
| Host earnings at 4,000 D/min | ₹20 per eligible minute; ₹1,200 per hour of talk time | Calculated |
| Host share of customer payment | About 20–24% depending on pack size | Calculated |
| Hold | 7 days | [FOUNDER C19] |
| Expiry | Never | [CLAUDE P8] |
| Legal character | **A record of service fees owed** to a verified host under a contract. Not a currency, not a cash-out of Diamonds. | [CLAUDE] + [PRO-REVIEW] |

**Beans earned but not yet withdrawn are a liability**: money Dashuri owes hosts. Dashuri should always hold cash at least equal to the Bean balance outstanding [CLAUDE].

**The main setting is Bean value.** Each extra ₹0.001 per Bean moves about **4.5 percentage points** of the customer's payment from Dashuri to hosts.

At ₹0.005, host pay is roughly in line with what third-party sources report for competitors. Those sources are unverified.

---

## 10. User Level and XP progression

### 10.1 Approved formula [FOUNDER R3-3]

`XP = 8 × (eligible cumulative Diamonds purchased) + (eligible cumulative Beans earned)`

### 10.2 What the 8:1 weighting means in rupees

Calculated:
- **Customer:** 323–387 XP per ₹ spent on Diamonds. Larger packs give more Diamonds per rupee, so more XP per rupee.
- **Host:** 200 XP per ₹ earned.
- **Per minute of call at 4,000 D/min:** the customer gets 32,000 XP (counted at purchase) and the host gets 4,000 XP.

Customers therefore progress about **8× faster per call** than hosts, and about **1.6–1.9× faster per rupee**.

### 10.3 Proposed levels [CLAUDE P12, not approved]

There is no spending or earning distribution data yet (R16), so these thresholds are **anchored to economic milestones, not fitted to real users**. They must be recalibrated after the closed beta. A suggested target: about 50% of payers reach Level 3, and fewer than 5% reach Level 7 or above.

| Level | XP | Customer ≈ ₹ spent | Host ≈ ₹ earned | Proposed name |
|---|---:|---:|---:|---|
| 1 | 0 | 0 | 0 | Newcomer |
| 2 | 32,000 | 93 (≈ one ₹99 pack) | 160 | Spark |
| 3 | 100,000 | 290 | 500 (first withdrawal) | Glow |
| 4 | 250,000 | 725 | 1,250 | Charm |
| 5 | 600,000 | 1,740 | 3,000 | Star |
| 6 | 1,500,000 | 4,350 | 7,500 | Shine |
| 7 | 3,500,000 | 10,150 | 17,500 | Gold |
| 8 | 8,000,000 | 23,190 | 40,000 | Platinum |
| 9 | 18,000,000 | 52,170 | 90,000 | Diamond |
| 10 | 40,000,000 | 115,940 | 200,000 | Legend |

### 10.4 Rewards and abuse prevention [CLAUDE]

**Rewards:**
- Cosmetic only at launch: badge, profile frame, colour of name in the host's incoming-call screen.
- **Do not** link levels to host rate limits, payouts or safety features. Anything valuable that can be bought becomes a target for laundering fraud.
- Discovery filters by language or city should stay free for everyone. They help conversions, so locking them behind levels would cost revenue.

**Shared or separate progression:** use **one shared level per user**, which is what the formula implies, with role badges for customers and hosts. Whether to show separate customer and host levels instead is a founder decision.

**XP integrity:**
- XP is written as entries in an append-only ledger tied to the Play order ID (each purchase gives XP once) and to individual Bean-earning entries.
- Refunds and reversals create negative XP entries.
- Beans that are clawed back for fraud reverse their XP.

---

## 11. Diamond packages [FOUNDER R3-4, evaluation set]

| Pack | Price (incl. GST) | Diamonds | ₹ per 1k D | Minutes at 4,000/min | Host share of gross | Dashuri share after 15% Play fee* | after 30% Play fee* |
|---|---:|---:|---:|---:|---:|---:|---:|
| Starter | ₹99 | 4,000 | 24.75 | 1.0 | 20.2% | 51.8% | 39.1% |
| Small | ₹299 | 12,500 | 23.92 | 3.1 | 20.9% | 51.1% | 38.4% |
| Medium | ₹599 | 26,000 | 23.04 | 6.5 | 21.7% | 50.3% | 37.6% |
| Popular | ₹1,199 | 54,000 | 22.20 | 13.5 | 22.5% | 49.5% | 36.8% |
| Large | ₹2,999 | 140,000 | 21.42 | 35.0 | 23.3% | 48.7% | 36.0% |
| Premium | ₹5,999 | 290,000 | 20.69 | 72.5 | 24.2% | 47.9% | 35.2% |

\* Dashuri's share is before refunds, fraud, video, moderation, acquisition and fixed costs.

**Benchmark:** about ₹22 per 1k Diamonds, from an anecdotal 2023 source.

**Still to validate:**
- Current competitor pack prices, from a live check of the app's own price list rather than reseller sites.
- Whether a ₹49 pack would convert more first-time buyers.
- The Play price-tier constraints for India.

---

## 12. Host pricing model

| Rule | Proposal | Label |
|---|---|---|
| Who sets the rate | The host, within limits | [FOUNDER C13] |
| Range | 2,000–8,000 D/min, about ₹44–₹178 per minute to the customer | [CLAUDE P3], **superseded by S2a** |
| New-host cap | 4,000 D/min until 5 billable hours are completed | [CLAUDE P3], **superseded by S2a** |
| Ladder (decided) | Minimum 500; maximum level × 1,000; above 3,000 only for an active Verified Host | [FOUNDER S2a] |
| Changes | Take effect on the next call. Never during a call. | [CLAUDE] |
| Shown to customer | Rate shown before the call, plus a "₹ per minute ≈" hint | [CLAUDE] |

---

## 13. Billing and refunds

| Situation | Rule | Label |
|---|---|---|
| Unit | Per second, proportional | [FOUNDER C20] |
| Rounding | Calculated over the whole call, rounded once, in the customer's favour | [CLAUDE P4] |
| Start of billing | Server confirms both video streams are live, plus a 5-second grace period | [CLAUDE P5] |
| Starting a call | Requires at least 60 seconds of balance at the host's rate | [CLAUDE P4] |
| Low balance | Warning at 30 s; call ends automatically at 0 | [CLAUDE P4] |
| Technical interruption | Pause billing when the host's connection signal is missing for more than 10 s; resume on recovery; credit affected time automatically | [FOUNDER C21] + [CLAUDE P5] |
| Never connected | Full refund of anything reserved | [FOUNDER C21] |
| Host or customer ends the call | Billing stops; no penalty | [FOUNDER C15] |
| Refund abuse | Credits only from server-detected events (never customer claims); daily cap on credits; flag repeated drops in the first 10 s | [CLAUDE] |
| Purchase reversed after Diamonds were spent | Claw back the host's Beans still in hold, block the customer, Dashuri absorbs the rest | [CLAUDE P9] |

**How interruptions are detected:**
- The server reads Stream call events (participant joined or left, video track published or unpublished).
- Both apps send a "still connected" signal every 5 s.
- **The server alone decides what is billable.** The app is never trusted to report billable time.

---

## 14. Free Call Card

### 14.1 Founder concept [FOUNDER R3-5]

- One minute of free **random** video calling for new customers.
- Separate from the paid browse experience.
- Claude's earlier redesign (P6) was rejected.

### 14.2 Can it be offered within the rules?

| Platform | Finding | Verdict |
|---|---|---|
| Google Play | Random chat is **allowed**, with obligations. From **26 Aug 2026** (official deadlines table), apps "whose core functionality is to facilitate randomly connecting users" must use "Play Console functionality and tools to block minors" and meet the Child Safety Standards. Dashuri's *core* function is browse-and-choose, so it may be out of formal scope. **Applying the 18+ block anyway is recommended (P16).** | **Feasible on Android** [VERIFIED-OFFICIAL; see B2] |
| Apple | "Random or anonymous chat" is excluded (official text; date UNVERIFIED). | **Not feasible on iOS as designed.** Disable the card, or redesign it, for any future iOS build. [VERIFIED-OFFICIAL] |

### 14.3 Proposed mechanics [CLAUDE P13, not approved]

| Element | Proposal | Rationale |
|---|---|---|
| Matching | Random among hosts who are online, **not busy**, and have **opted in** to free calls | Honours "random" while keeping hosts free to say no (C14) |
| Host compensation | Flat **2,000 Beans (₹10)** per completed free minute (45 s or more with video live) | Without pay, hosts won't opt in |
| Eligibility | One card per verified phone number **and** device (Play Integrity check and device signal) | Stops repeat claims |
| Anti-farming | Free-call Beans capped at **20 free calls per host per day**; 7-day hold; a host's own devices or phone numbers can never match her | Limits fake-customer farming to ₹200 per host per day at most, and claws it back if detected |
| Re-issue | Not at launch. Re-engagement cards come later as a data-driven decision. | [UNRESOLVED] |

### 14.4 Cost per card used [CLAUDE, calculated]

| Item | Cost |
|---|---:|
| Host Beans | ₹10.00 |
| Video (1 min × 2 participants) | ₹0.27 |
| Nudity detection (3 frames) | ~₹0.40 |
| SMS one-time code | ~₹0.25 [ASSUMPTION] |
| **Total** | **≈ ₹11** |

This is an acquisition cost. If, for example, 10% of card users go on to pay [ASSUMPTION], the cost is about **₹110 per paying customer acquired**.

---

## 15. Host recruitment and retention

### 15.1 Channels [FOUNDER C16: all channels]

The qualitative ratings below are [CLAUDE] judgements, not measured data.

| Channel | Cost | Quality / control | Retention | Risks |
|---|---|---|---|---|
| Personal network | Very low | High trust | Medium | Small pool |
| Instagram / social (organic) | Time only | Mixed | Medium | Platform rules on recruiting ads |
| Creator outreach (micro-influencers) | Fee or revenue share | Good on-camera skills | Medium–high | Cost |
| Agencies | **5–30% commission ladder** reported for Chamet (third-party, conflicting) | Agency controls hosts | High while paid | Fraud rings, hosts treated as employees, agencies poaching hosts, extra margin layer |
| Joining bonus (e.g., Beans after first 2 h of billable calls) | Fixed per host | Attracts bonus-hunters | Low | Abuse; must be tied to billable time |
| Host referral (referrer gets x% of the referred host's Beans for 90 days, paid by Dashuri) | Variable, only paid if the host performs | Good | Good | Referral rings |

**Recommendation [CLAUDE P10]:**
- At launch, use personal network, organic social media, creators and host referral.
- **No agencies until there are 100+ active hosts and fraud tooling is mature.**

The founder has chosen to explore *all* channels, so agencies remain an option. This recommendation is about timing only.

### 15.2 Retention levers that respect host independence (C14)

- Fast, reliable weekly payouts. This is the main retention factor.
- Transparent earnings dashboard.
- Bonuses at peak hours.
- Safety tools, such as ending a call instantly and blocking.
- Visibility on levels and badges.

---

## 16. Payout operations

| Rule | Value | Label |
|---|---|---|
| Frequency | Weekly | [FOUNDER] |
| Minimum | ₹500 (100,000 Beans) | [FOUNDER] |
| Hold | 7 days from earning | [FOUNDER] |
| Destination | Bank account or UPI ID in the host's own name, matched to her KYC | [CLAUDE] |
| Provider | Cashfree Payouts, about ₹6–8 per IMPS/UPI transfer (published table, ambiguous; custom pricing possible). UPI limit ₹1 lakh. | [RESEARCH, official] |
| Tax withholding | Section 194-O / 194J / 194C, depending on how hosts are classified. PAN mandatory. | [PRO-REVIEW] |
| Fraud review | Automatic hold on payouts flagged as suspicious; a payout under review is frozen, not paid | [CLAUDE] |
| **When it starts** | **Only after incorporation, legal and tax advice, host agreements, and payout onboarding** | [FOUNDER R3-7] |

---

## 17. Legal and regulatory considerations

| Area | Potential requirement | Risk | Verification needed |
|---|---|---|---|
| Obscenity | IT Act ss.67/67A; BNS obscenity provisions | **Criminal; personal liability as proprietor** | Lawyer |
| Intermediary status | IT Rules 2021: due diligence, Grievance Officer, takedown deadlines (24 h, possibly 2 h after 2026) | Losing safe-harbour protection | Lawyer; check the 2026 amendment text in the Gazette |
| Blocking | IT Act s.69A | App blocked nationally | Ongoing monitoring |
| Prepaid instruments | Diamonds closed-loop with no cash redemption; Beans as contractual fees | Being treated as a payment intermediary or a PPI issuer | Lawyer or payments specialist |
| Anti-money-laundering / fraud | KYC on hosts; velocity limits; payout holds | Laundering of stolen payments | Lawyer |
| Data protection | DPDP Act + Rules (Nov 2025; main duties from about May 2027): notice, consent, security, breach reporting, erasure. Video frames and KYC data are sensitive. | Penalties up to ₹250 crore | Lawyer |
| Children | No under-18 users; DPDP verifiable parental consent rules make minors' data toxic | Severe | Age assurance design |
| Social security | Code on SS 2020 (in force 21 Nov 2025): platform levy of 1–2% of turnover, capped at 5% of payouts | Extra cost of up to 2% of turnover | Lawyer: notification status; whether hosts count as platform workers |
| GST | 18% on Diamond sales; **principal vs agent**; who is liable on Play sales; whether hosts need to register | Margin swings of about ±4% of gross | **CA (high priority)** |
| Income tax / TDS | Correct section for host payouts; filing TDS returns; Form 16A | Penalties, interest | CA |
| Contracts | Host agreement (independence, content, tax, Beans), customer terms, refund policy | Disputes | Lawyer |

---

## 18. App-store compliance

| Item | Requirement | Label |
|---|---|---|
| Account type | Personal accounts created after 13 Nov 2023 need a **closed test with 12 testers for 14 days**. An organisation account needs a D-U-N-S number. **Recommendation:** an organisation account once incorporated; a proprietorship can try for a D-U-N-S number. | [RESEARCH, official] + [CLAUDE P14] |
| Developer verification | Android developer verification registration; deadline was 30 Sep 2026 | [RESEARCH, secondary] |
| Billing | Diamonds are digital goods, so **Play Billing is required**, or User Choice Billing (fee reduced by 4, likely 15% → 11%) | [RESEARCH] |
| Fee | India is in the "remaining markets" tier: **15% on the first US$1M per year (developer must enrol)**, 30% above. India reportedly excluded from the 2026 overhaul. | [RESEARCH, secondary] + [ASSUMPTION] |
| Content policy | No promoting sex-related entertainment. Listing, screenshots and ads must show conversation, not sexuality. | [RESEARCH, official] |
| UGC policy | In-app reporting, blocking, moderation; the app must not "primarily feature" objectionable content | [RESEARCH] |
| Random chat (Free Call Card) | Restrict Minor Access, Child Safety Standards | [RESEARCH] |
| iOS (future) | 1.2 random chat and objectification exclusions; 3.1.3(d) person-to-person payment exception needs review | [PRO-REVIEW] |

---

## 19. Payment-provider eligibility

| Flow | Provider | Status |
|---|---|---|
| Customer buys Diamonds (Android) | **Google Play Billing** | Required by Play. Google handles cards, UPI and chargebacks, and deducts reversals from payouts. |
| Customer buys Diamonds (alternative) | Cashfree under User Choice Billing | Optional. Saves about 4 points of fee. **Category eligibility must be confirmed in writing.** [PRO-REVIEW] |
| Host payouts | Cashfree Payouts (or alternatives: Razorpay X, bank APIs) | **Category eligibility must be confirmed in writing.** Needs business KYC, best after incorporation. |

**Serious dependency.** If Cashfree, or every payout provider, refuses the category, there is no compliant way to pay hosts.

**Ask Cashfree's sales or risk team in writing before building payouts.** Show them the content policy and moderation design.

---

## 20. Technical infrastructure

The planned stack is recorded here for costing only. **Nothing is to be built yet.**

| Layer | Choice | Notes |
|---|---|---|
| App | Flutter, Android first, iOS-ready | [FOUNDER] |
| Backend | Go on Cloud Run | [FOUNDER] |
| Database | Supabase Postgres | Wallet, Bean and XP **ledgers must be append-only and double-entry** [CLAUDE] |
| Video | Stream | Server-side webhooks for billing [CLAUDE] |
| Payments | Play Billing; server-side purchase verification; real-time notifications for refunds and reversals | [CLAUDE] |
| Payouts | Cashfree Payouts (later) | — |
| KYC | Aadhaar offline / DigiLocker + PAN + liveness vendor | — |
| Moderation | On-device NSFW model plus server frame sampling | — |
| Notifications | FCM (free) | — |

---

## 21. Technical operating costs

> **Audit (v0.2): verification status of each price is in B6.**

These are estimates. Prices are in US$ where the vendor bills in US$, at ₹88 = $1. Marketing is excluded [FOUNDER C23].

| Item | Type | Estimate | Source / label |
|---|---|---|---|
| Google Play developer account | One-time | $25 | Official |
| D-U-N-S number | One-time | Free | Official (for organisation accounts) |
| Apple Developer | Annual (deferred) | $99/yr | Official; not needed until iOS |
| Domain + email | Fixed | ~₹1,500/yr | [ASSUMPTION] |
| Supabase Pro | Fixed + usage | $25/mo + compute/storage | Published pricing |
| Cloud Run (Go API) | Usage | ~$0–50/mo at MVP scale | [ASSUMPTION] |
| Logging / monitoring | Usage | Free tiers at MVP (Cloud Logging, Sentry free) | [ASSUMPTION] |
| Stream video | Usage | $100/mo free, then about **₹0.27 per call-minute** (HD, 2 participants) | Published pricing |
| SMS one-time codes | Usage | ~₹0.15–0.30 per message | [ASSUMPTION] |
| Host KYC + liveness | Usage, per host | ~₹10–18 per check (one vendor's published price); budget ₹20–50 including retries | Vendor page |
| Nudity detection | Usage | ~$1.50 per 1,000 frames, so a frame every 20 s ≈ **₹0.40 per call-minute**; an on-device first check reduces this | Secondary |
| Storage (photos, evidence frames) | Usage | Small at MVP | [ASSUMPTION] |
| Payout transfers | Usage, per payout | ~₹6–8 | Official table |
| Security (secrets manager, Play Integrity) | Usage | Near zero at MVP | [ASSUMPTION] |
| Professional fees (CA, lawyer) | One-time, before payouts | **Unknown; get quotes** | [UNRESOLVED] |

**Summary of the MVP cost floor [CLAUDE]:**

| Cost type | Estimate |
|---|---|
| Fixed | About **$40–75 a month (₹3.5k–6.5k)** before traffic |
| Variable, per paid minute | About **₹0.7** (video plus moderation) |
| Per new host | About **₹20–50** |
| Per payout | About **₹7** |
| Per Free Call Card used | About **₹11**, mostly host Beans |

**Flutter development itself:** the founder's own time. There is no tooling cost beyond Play and, later, Apple accounts.

---

## 22. Settlement and working capital

> **Audit (v0.2): this section understates the gap. Use B5.**

### 22.1 Timeline [RESEARCH R17 + CLAUDE]

**Cash in:** a purchase on day *p* of month M is paid by Google from the **15th of M+1**, net of Google's fee. That is **15 to 45 days later** (plus weekends and holidays).

**Cash out:** Beans earned on day *t* are withdrawable from *t + 7* and paid at the next weekly cycle, so between **7 and 14 days later**.

**Gap:** the host is paid before Google pays Dashuri by about **20 days on average**, and up to about **38 days in the worst case**. Example: a purchase on the 1st, spent the same day, host paid on the 8th, Google pays on the 15th of the following month.

**So the earlier 3–6 week estimate is about right at the worst point (5½ weeks), and is about 3 weeks on average** [now RESEARCH-SUPPORTED + calculated].

### 22.2 Working capital by monthly host earnings [CLAUDE]

| Monthly host Bean payouts | Average pre-funding (×20/30) | Worst-case peak (×38/30) | + 10% refund and chargeback buffer | Suggested reserve |
|---:|---:|---:|---:|---:|
| ₹1 lakh | ₹0.67 L | ₹1.27 L | ₹0.13 L | **₹1.4 L** |
| ₹5 lakh | ₹3.3 L | ₹6.3 L | ₹0.6 L | **₹7 L** |
| ₹20 lakh | ₹13.3 L | ₹25.3 L | ₹2.5 L | **₹28 L** |

**Growth makes the gap worse,** because each month's payouts exceed the previous month's Google settlement.

**Note:** the gap only exists once withdrawals are on [FOUNDER R3-7]. During the closed beta no cash leaves the business.

---

## 23. Revenue model

### 23.1 Revenue streams

| Stream | MVP? | Label |
|---|---|---|
| Diamond sales spent on paid calls | Yes | [FOUNDER] |
| Breakage on promotional Diamonds | Minor | [CLAUDE] |
| Virtual gifts during calls | Not approved; candidate | [CLAUDE] |
| Live streaming with gifts | Later, if profitable | [FOUNDER C7] |
| Subscriptions or VIP | Not approved; candidate | [CLAUDE] |

### 23.2 Per-minute contribution at ₹22.2 per 1k D, 15% Play fee [CLAUDE, calculated]

| Host rate | Customer pays | GST | Play fee | Host | Video + moderation | 5% reserve | **Contribution** | % of gross |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 2,000 D/min | ₹44.40 | ₹6.77 | ₹5.64 | ₹10.00 | ₹0.67 | ₹1.88 | **₹19.43** | 43.8% |
| 4,000 D/min | ₹88.80 | ₹13.55 | ₹11.29 | ₹20.00 | ₹0.67 | ₹3.76 | **₹39.53** | 44.5% |
| 8,000 D/min | ₹177.60 | ₹27.09 | ₹22.58 | ₹40.00 | ₹0.67 | ₹7.53 | **₹79.74** | 44.9% |

**This is contribution, not profit.** It still has to cover:
- Customer acquisition.
- Free Call Cards.
- KYC.
- Payout fees.
- Fixed infrastructure.
- Professional fees.
- The possible social-security levy.
- Income tax.

**Affordable acquisition cost** (the formula to use once beta data exists):

Max cost per install = install-to-payer conversion × lifetime contribution per payer

Example, using hypotheses only: 5% conversion × ₹600 contribution = **₹30 per install**.

---

## 24. Cost structure

| Category | Behaviour | Main driver |
|---|---|---|
| GST | Variable, 18/118 of gross | Principal vs agent (§8) |
| Store fee | Variable, 15% (30% above US$1M a year) | Billing choice |
| Host Beans | Variable, about 20–24% of gross | Bean value |
| Video + moderation | Variable, about ₹0.7 per minute | Minutes |
| Refunds, chargebacks, fraud | Variable, 5% reserve [ASSUMPTION] | Fraud controls |
| Free Call Cards | Variable per new user, about ₹11 | New users |
| KYC | Per host | Host churn |
| Payout fees | Per payout, about ₹7 | Number of payouts |
| Social-security levy | 1–2% of turnover (if applicable) | Law |
| Infrastructure | Fixed floor about ₹3.5k–6.5k a month | — |
| Professional fees | One-time and annual | Incorporation, opinions, audit |
| Marketing | Founder-managed, **no budget assumed** | [FOUNDER C23] |
| Working capital | Cash tied up, not an expense | Payout timing |

---

## 25. Risks and mitigations

> **Superseded by the ranked register in B7.** The v0.1 table is kept below for history.

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| 1 | Play removal for UGC or sexual content (Chamet precedent) | **High** if the content line slips | Fatal | S1–S9; conservative listing and ads; nudity detection on host video; quick takedowns |
| 2 | Payout provider refuses the category | Medium | Fatal to payouts | Written pre-approval; a backup provider; clean positioning |
| 3 | MeitY s.69A block | Low–medium | Fatal | Indian entity, Grievance Officer, compliance records |
| 4 | Stolen payments laundered through colluding hosts | **High** | High | Play Billing (Google carries card risk), 7-day hold, new-host rate cap, KYC name-match on payouts, velocity limits, clawback |
| 5 | Fake hosts (pre-recorded video, bots) | Medium | Reputation, store risk | Liveness checks, random liveness challenges during calls, reports |
| 6 | Minors on the platform | Medium | Severe | Play 18+ restriction, host ID age checks, customer age declaration, reports |
| 7 | Customer acquisition unaffordable or ads restricted | **High** | High | Organic and creator-led growth, host referrals, Free Call Card; measure in beta |
| 8 | Not enough hosts online at peak | Medium | Medium | Peak bonuses (incentives, not obligations) |
| 9 | Cash crunch from settlement gap | Medium, rising with growth | High | Reserve per §22; monitor weekly |
| 10 | GST or principal/agent misclassification | Medium | ±4% margin plus penalties | CA opinion before launch |
| 11 | Social-security levy | Medium | −1 to 2% of turnover | Lawyer opinion; budget for it |
| 12 | Personal liability as proprietor | Certain while a proprietorship | High | No payouts before incorporation (R3-7) |
| 13 | Free Call Card farming | Medium | Low–medium | Per-device/phone limits, Play Integrity, daily cap, hold |
| 14 | Apple rejection | High (random chat) | Medium (iOS deferred) | Android first; redesign for iOS |

---

## 26. Unresolved founder decisions

> **Superseded by the decision sheet in B8.** The v0.1 list is kept below for history.

1. **Meaning of the $1M ambition:** revenue, profit, valuation, personal wealth or ARR (F4).
2. Pvt Ltd or OPC (R3-7).
3. Approve or adjust the host rate range and new-host cap (P3).
4. Final Bean value (R3-9) and final pack prices (R3-4).
5. XP level thresholds, names and rewards; one shared level or separate customer and host levels (P12).
6. Free Call Card mechanics: host compensation, opt-in pool, caps, re-issue (P13).
7. Diamond expiry and refund rules (P7); Beans never expire (P8); reversal handling (P9).
8. Agencies at launch: yes or no (P10).
9. Play Billing only, or User Choice Billing with Cashfree.
10. Moderation design (P15) and vendors.
11. Monthly technical budget ceiling (optional).

---

## 27. Research gaps

| Gap | Why it matters | How to close it |
|---|---|---|
| Acquisition cost for this category in India | Decides viability | Beta experiments; ad-platform policy check (Meta and Google dating-ad rules) |
| Install → payer conversion, spend per paying customer, retention | Simulation inputs | Closed beta telemetry |
| Current official competitor prices | Pack pricing | Install the apps and record the price lists (not reseller sites) |
| India Play fee for 2026–27 | Margin | Play Console service fee page |
| Who is liable for GST on Play India sales | Margin | CA |
| Status of the 2026 IT Rules amendment | Takedown deadline | Gazette text |
| Social-security levy notification | Cost | Labour Ministry Gazette |
| Cashfree eligibility for the category | Payouts | Written request |
| Agency economics (official) | Recruitment | Direct conversations with agencies |
| Host earning distribution | XP thresholds, retention | Beta |

---

## 28. Recommended next steps

**Before approval (business):**
1. Founder answers the §26 items, at minimum items 1, 3, 4, 6 and 7.
2. Founder reviews the content boundary and safety list (§7) and the working-capital table (§22).
3. Request written category confirmation from Cashfree, and from one alternative payout provider.
4. Get a **CA consultation** (GST principal/agent, TDS section, proprietorship to company) and a **lawyer consultation** (IT Act / IT Rules, DPDP, host agreement, social security). Ask for fixed-fee quotes first.

**After the founder writes "I APPROVE THE DASHURI BUSINESS MODEL":**

5. Six-month and twelve-month financial simulations, with worst, base and best cases plus the stress tests. Customer acquisition will be modelled separately and no marketing budget will be invented.

**Only after the simulation has been reviewed:**

6. Melos/BLoC architecture foundation (placeholders only).

---

# PART B — FINAL EVIDENCE AND CONSISTENCY AUDIT (2026-11-17)

**Method:**
- Every claim was rechecked against the **official** source where one could be retrieved in this session.
- **VERIFIED-OFFICIAL** = text read on the official page today.
- **UNVERIFIED** = could not be checked against a primary source.
- "Interpretation" = Claude's reading. It is not policy and not legal advice.

## B1. Decision-log consistency

| Check | Result | Action |
|---|---|---|
| Round 2 Q1 recorded as "B" | **Error.** The founder answered "B + C". | Restored verbatim (log C10). R3-1 is the current rule. |
| ₹0.005 per Bean | Was "proposed by founder, not final" | **Now CONFIRMED BY FOUNDER** as the preferred rate (R3-9) |
| Beans per Diamond spent (1:1) | Never confirmed by the founder | Marked UNRESOLVED. Host pay depends on it (B8 item 3). |
| 8:1 XP formula and integrity rules | Recorded correctly | Kept (R3-3) |
| XP thresholds, names, rewards | Correctly not approved | P12, NOT APPROVED |
| Host rates | **Mismatch.** The founder's brief described "2,000 / 4,000 / 8,000". The proposal is a range of 2,000–8,000 with a 4,000 cap for new hosts. | Conflict X2, decision sheet item 2 |
| Diamond packs | "Evaluation set", not prices | Correct (R3-4) |
| Free Call Card | Founder's original kept; P6 rejected | Correct (R3-5) |
| Payouts, structure, budget | Correct | — |
| Other C1–C24 | Rechecked against the founder's answers; consistent | Founder reasoning added where it was stated |

## B2. App-store compliance (official text)

### Google Play

| Policy | Official text / fact | Date | Interpretation |
|---|---|---|---|
| Sexual Content | "We don't allow apps or app content that appear to promote or solicit a sexual act in exchange for compensation." | Current | Store listing, ads and actual use must never suggest paid sexual content |
| Payments | Play Billing is required for "Items (such as virtual currencies…)". "In-app virtual currencies must only be used within the app… for which they were purchased." The exemption is for "peer-to-peer payments", meaning payment apps. | Current | **Diamonds must go through Play Billing**, or Play's alternative billing programme |
| Age-Restricted Content and Functionality | Covers apps "whose core functionality is to facilitate randomly connecting users to spontaneously communicate" and apps whose core functionality is matchmaking or dating. Such apps "are required to use the Play Console functionality and tools to block minors." | **Deadline 2026-08-26** (official Policy Deadlines table). Announced 2026-07-15. | Dashuri's core is browse-and-choose, so it may be outside formal scope. **Recommended: block minors anyway (P16).** The tool name "Restrict Minor Access" is UNVERIFIED. |
| Child Safety Standards | Applies to anonymous chat, random chat, Social and Dating apps. Requires published standards against child sexual abuse, in-app feedback, handling of abuse material, legal compliance, a named contact. | Extended 2026-08-26 | Needed if Dashuri declares itself "Social" or "Dating", or is treated as random chat |
| Developer verification | Register apps in Play Console | **2026-09-30** | A new developer registers at account setup |
| Testing (personal accounts) | 12 testers, 14 days, for accounts created after 13 Nov 2023 | Current | An organisation account avoids this |

### Apple (future iOS only)

| Guideline | Official text (verified) | Interpretation |
|---|---|---|
| 1.2 | "…used primarily for pornographic content, Chatroulette-style experiences, random or anonymous chat, objectification of real people… do not belong on the App Store and may be removed without notice." | **The random Free Call Card is incompatible.** A browse-and-choose paid marketplace is not random chat, but "objectification of real people" is a judgement risk. **Date the wording was added: UNVERIFIED.** |
| 1.1.4 | Excludes "'hookup' apps and other apps that may… be used to facilitate prostitution" | Content line (R3-1) must be enforced |
| 3.1.1 | In-game currencies require IAP. Purchased currencies "may not expire". Tipping digital content providers through IAP currency is allowed. | Diamonds on iOS = IAP; P7 no-expiry is mandatory there |
| 3.1.3(d) | Real-time person-to-person services between two individuals "may use purchase methods other than in-app purchase" | Might allow paying for calls directly (in INR, without Diamonds) on iOS. **UNVERIFIED applicability. Ask Apple App Review before relying on it.** |

**Free Call Card verdict:**
- **Android:** permitted, provided minors are blocked and child-safety standards are in place.
- **iOS:** not permitted as designed.

The founder's design (R3-5) stands for Android.

## B3. Payment feasibility

| Flow | Option | Evidence | Feasibility |
|---|---|---|---|
| Customer buys Diamonds | **Google Play Billing** | Required (R24). Google is the payment processor, so no third-party gateway category approval is needed. Google's content policies still apply. | **Viable. Primary.** |
| Customer buys Diamonds | Alternative billing (India) through Cashfree | Fee "reduced by 4%" (ambiguous: 15%→11% or 15%→14.4%). Requires PCI DSS attestation, reporting each transaction within 24 h, and acceptance by Cashfree. | Optional saving. **Defer.** |
| Host payouts | Cashfree Payouts | The prohibited list names adult and sexually suggestive services but **not** dating, chat or live streaming. Deactivation is at Cashfree's discretion. | **UNVERIFIED until written approval** |
| Host payouts | RazorpayX / other payout APIs | Razorpay calls dating "high risk". Amazon Payment Services prohibits "dating, chatting". | **UNVERIFIED.** Ask in writing. |
| Host payouts | **Bank current account, bulk NEFT/IMPS** (corporate net-banking upload or bank API) | Dashuri pays its own contractors from its own account after Google settles to it | **Viable fallback** (interpretation; PR). Manual at small scale. |

**Is there a compliant architecture? Yes, in principle** [interpretation, PR]:

1. Customer → **Play Billing** → Google settles to Dashuri's bank account.
2. Dashuri recognises revenue as Diamonds are spent and records the Beans it owes hosts.
3. After the 7-day hold, Dashuri pays **contracted, KYC-verified hosts** from its own current account, through a payout provider or bank bulk transfer, withholding TDS.

Under this structure:
- **No customer money passes directly to a host.**
- **Diamonds are never cashed out.**

This is the structure to put to the lawyer (B4).

## B4. Indian legal and tax review

### Confirmed statutory or official requirements

These are well-sourced. A professional should still confirm how they apply to Dashuri.

| Area | Requirement | Source quality |
|---|---|---|
| IT Act s.67 / 67A | Transmitting obscene or sexually explicit material electronically is an offence | Statute (Claude's knowledge) |
| IT Act s.79 + IT Rules 2021 | Safe harbour depends on due diligence: Grievance Officer, complaint timelines, takedowns | Statute / Rules |
| IT (Amendment) Rules 2026 | G.S.R. 120(E), notified 10 Feb 2026, in force 20 Feb 2026. Intimate-image complaints: **2 h**. Takedown on government or court orders: **3 h**. | Multiple law-firm notes. **Gazette not read. Rule numbering conflicts.** |
| DPDP Act 2023 + Rules 2025 | Notified Nov 2025. Main obligations about May 2027. Under the Act, a "child" is under 18, and processing a child's data needs verifiable parental consent. | Press and law firms; the statutory points are Claude's knowledge |
| TDS s.194-O | **0.1%** from 1 Oct 2024; **5% without PAN** | Statute as amended (tax sources) |
| Social Security Code | In force 21 Nov 2025. Central Rules 8 May 2026. Aggregator levy of 1–2% of turnover, capped at 5% of payouts to workers. **Rate and start date not notified as of Oct 2026.** | Secondary |
| GST | 18% on Diamond sales (standard rate for online services) | Interpretation: needs CA |

### Questions for a CA

1. **Principal vs agent:** is Dashuri the supplier of call time (GST on the full Diamond price), or an agent for hosts (GST on commission)? Which treatment is defensible given that Diamonds are a platform currency?
2. **GST on Play sales:** Google's official pages conflict on whether Google or an India-based developer remits GST on in-app purchases by Indian buyers. Which applies to Dashuri, and does Google's fee apply to the GST-inclusive price?
3. **Timing of GST:** is GST due when Diamonds are bought (advance for services) or when they are spent?
4. **TDS on host payouts:** 194-O (Dashuri as e-commerce operator), 194J, 194C, or none? What are the PAN collection, returns and Form 16A workflow?
5. **Host GST registration:** do hosts need to register, given the threshold and any rules for suppliers selling through an e-commerce operator? Must Dashuri collect TCS under GST s.52?
6. **What Google withholds:** what Indian withholding does Google deduct from Indian developers' proceeds, and can it be credited?
7. **Accounting:** treatment of unspent Diamonds (liability), Beans owed, breakage on promotional Diamonds, and the revenue recognition policy.
8. **Pvt Ltd vs OPC:** tax, compliance cost and conversion path from a proprietorship. Can existing Play and bank accounts be transferred?

### Questions for a lawyer

1. Does the structure in B3 (closed-loop Diamonds + contractual Beans paid from Dashuri's own account) avoid PPI or payment-aggregator classification under RBI rules?
2. With the R3-1 content rules and the moderation in §7.3, what is the residual risk under ss.67 / 67A and obscenity provisions, and what records preserve s.79 safe harbour?
3. What exactly does Dashuri have to do under the IT Rules as amended in 2026: Grievance Officer, 2 h and 3 h takedowns, user notices?
4. Are hosts "platform workers" under the Social Security Code, and when would the levy start? Does any state law (for example Karnataka's) apply to where Dashuri or its hosts are located?
5. DPDP: lawful basis for KYC and video-frame processing, retention periods, handling of children's data if a minor gets through, breach response.
6. Host agreement: independent-contractor wording consistent with C14, content obligations, Bean terms, clawback on fraud, termination.
7. Customer terms: no cash value for Diamonds, refund policy, consumer protection compliance.
8. Can anti-money-laundering obligations arise under the B3 structure? If not legally required, what controls are prudent?

## B5. Financial model audit

### B5.1 The ₹1,199 pack, recalculated

**Assumptions:**
- The whole pack is spent at 4,000 D/min.
- ₹88 = US$1.
- 1 Diamond spent = 1 Bean (unresolved).

| Line | Formula | ₹ | Status |
|---|---|---:|---|
| Price paid (P) | Given | 1,199.00 | Proposed pack |
| GST | P × 18/118 | 182.90 | Rate standard; **who remits UNVERIFIED (R26)** |
| Net sales (N) | P − GST | 1,016.10 | — |
| Play fee (F) | N × 15% | 152.42 | Rate VERIFIED-OFFICIAL. **Whether the fee is charged on N or on P is UNVERIFIED.** |
| Host Beans (H) | 54,000 × 1 × ₹0.005 | 270.00 | ₹0.005 confirmed; 1:1 ratio unresolved |
| Minutes | 54,000 ÷ 4,000 | 13.5 | — |
| Video (V) | 13.5 × 2 × $1.50/1,000 × 88 | 3.56 | Price VERIFIED-OFFICIAL |
| Moderation (M) | 13.5 × 3 frames × $1.50/1,000 × 88 | 5.35 | **Price UNVERIFIED** |
| Refund and fraud reserve (R) | N × 5% | 50.81 | **ASSUMPTION; no data** |
| **Contribution** | N − F − H − V − M − R | **533.97 (44.5% of P)** | v0.1 said ≈₹539 because moderation was left out |

### B5.2 Sensitivities (each changes one input)

| Scenario | Contribution | % of P |
|---|---:|---:|
| Base | ₹533.97 | 44.5% |
| Play fee charged on the GST-inclusive price (P) | ₹506.54 | 42.2% |
| Play fee 30% (above US$1M a year) | ₹381.56 | 31.8% |
| Alternative billing at 11%, before gateway fees (gateway fee UNVERIFIED) | ₹574.62 | 47.9% |
| Agent model, if GST applies only to Dashuri's margin (PR) | up to +₹41.19 | up to ~48% |
| Bean value ₹0.006 instead of ₹0.005 | ₹479.97 | 40.0% |

### B5.3 Why this is not net profit

The contribution figure **excludes**:
- Customer acquisition (no data; not invented).
- Free Call Card costs.
- Host KYC.
- Payout fees.
- Fixed infrastructure.
- Professional fees.
- The possible social-security levy.
- Income tax.
- The founder's own time.

It also assumes:
- The **whole pack is spent**. Unspent Diamonds are a liability, not revenue.
- **No fraud beyond the 5% reserve.**

### B5.4 Working capital, recalculated

**Formulas:**

- Gap = (Google payout date + bank transit) − (date the host is paid)
- Google payout: from the 15th of the month after purchase, so **45 − p** days after a purchase on day p of a 31-day month. **Average 30.0 days.**
- Bank transit: 2–7 business days (official), about **3–10 calendar days**.
- Host paid: 7-day hold + wait for the weekly cycle (0–7 days) = **7–14 days, average 10.5**.

**Results:**

| | Formula | Result |
|---|---|---|
| Average gap | 30.0 + (3 to 10) − 10.5 | **22.5–29.5 days** (v0.1: 20) |
| Worst gap | 45 + 10 − 7 | **48 days** (v0.1: 38). v0.1 left out bank transit. |

These figures assume Diamonds are spent on the day they are bought, which is conservative. Later spending shortens the gap.

| Monthly host payouts | Reserve = payouts × 48/30 × 1.1 |
|---:|---:|
| ₹1 lakh | **₹1.76 L** |
| ₹5 lakh | **₹8.8 L** |
| ₹20 lakh | **₹35.2 L** |

If Dashuri itself owes GST (R26), monthly GST returns are due around the 20th. That is close to when Google's payout arrives, which adds timing pressure. **CA question 3.**

## B6. Technical cost audit

All costs exclude marketing (C23).

| Item | Type | Price | Verification |
|---|---|---|---|
| Play developer account | One-time | $25 | Widely documented; not re-read today |
| Supabase Pro | Fixed + usage | From $25/mo; $10 compute credit; 8 GB disk ($0.125/GB over); 250 GB egress ($0.09/GB); 100k MAU; 100 GB storage; spend cap on by default | **VERIFIED-OFFICIAL** |
| Stream Video | Usage | HD $1.50 per 1,000 participant-min (SD $0.75, audio $0.30); first $100 a month free | **VERIFIED-OFFICIAL** |
| Cloud Run | Usage | Free tier plus per vCPU-second, GiB-second and request charges | **UNVERIFIED** (official page did not render; about $0–50/mo at MVP is Claude's estimate) |
| OTP SMS | Usage | About ₹0.15–0.25 per SMS + 18% GST + DLT fees | **UNVERIFIED** (third-party) |
| KYC + liveness | Per host | ₹10 offline Aadhaar / ₹18 with liveness (one vendor) | Vendor-published; others UNVERIFIED |
| Nudity detection | Usage | About $1.50 per 1,000 images (Cloud Vision); Sightengine $99/mo for 40k operations | **UNVERIFIED** (Vision); Sightengine vendor-published |
| Payout transfers | Per payout | ₹6–15 by band (Cashfree table) | **UNVERIFIED** for this use case |
| Logging / monitoring | Usage | Free tiers | UNVERIFIED |
| Apple Developer | Annual | $99 (deferred) | Widely documented |
| Professional fees | One-time | Unknown | Get quotes |

**Cost floor summary:**
- **Verified fixed floor:** Supabase $25/mo. Everything else is usage-based or UNVERIFIED.
- **Claude's estimate:** about $40–75/mo before traffic.
- **Per paid minute:** about ₹0.27 video (verified) + about ₹0.40 moderation (UNVERIFIED).

## B7. Ranked risk register

| Rank | Risk | Severity | Probability | Financial impact | Blocks? | Resolved by |
|---|---|---|---|---|---|---|
| 1 | Play removal for sexual content or UGC (Chamet precedent) | Critical | Medium–High | Total revenue loss | **Public launch:** moderation and content controls must exist first | P15 + P16 built; conservative listing; documented enforcement |
| 2 | No payout channel accepts the category | Critical | Medium | Hosts cannot be paid; supply collapses | **Payouts** | Written approval from Cashfree or an alternative, or confirmation that bank bulk transfer works |
| 3 | Legal structure (PPI / aggregator / obscenity / safe harbour) | Critical | Low–Medium | Penalties; personal liability | **Payouts** | Lawyer opinion (B4); incorporation (R3-7) |
| 4 | Laundering of stolen payments through colluding hosts | High | High | Chargebacks, account bans | **Payouts** | KYC, 7-day hold, new-host cap, velocity rules, clawback (P3, P9) |
| 5 | GST or principal/agent error; conflicting guidance on Play GST | High | Medium | About ±₹41 per ₹1,199 plus penalties | **Paid launch** | CA opinion (B4 Q1–3) |
| 6 | Customer acquisition unaffordable or ad channels restricted | High | High | Business unviable | No (beta measures it) | Beta data; ad-policy check |
| 7 | Settlement cash gap (48 days at worst) | High | Certain once payouts start | Up to about 1.6× monthly payouts tied up | **Payouts** (founder accepted) | Reserve per B5.4 |
| 8 | Minors on the platform | Critical | Low–Medium | Removal; DPDP liability | **Public launch** | Play minor-blocking, host ID age check, reports |
| 9 | Social-security levy | Medium | Medium | 1–2% of turnover | No | Notification watch; lawyer |
| 10 | Personal liability as proprietor | High | Certain while a proprietorship | Personal assets | **Payouts** (R3-7) | Incorporation |
| 11 | Fake hosts or pre-recorded video | Medium | Medium | Refunds, reputation | No | Liveness checks, reports |
| 12 | Free Call Card farming | Low | Medium | Up to ₹200 per host per day | No | P13 caps |
| 13 | Too few hosts online at peak | Medium | Medium | Lost sales | No | Peak bonuses |
| 14 | Apple rejection | Medium | High | iOS upside lost | No (Android first) | Redesign for iOS |
| 15 | Price assumptions UNVERIFIED (Cloud Run, OTP, KYC, moderation) | Low | — | Small | No | Vendor quotes |

## B8. Founder decision sheet

Only the decisions that genuinely need the founder now:

| # | Decision | Options / Claude's recommendation |
|---|---|---|
| 1 | **What does "$1M" mean?** | Revenue / profit / valuation / personal wealth / ARR. Needed to set simulation targets. |
| 2 | **Host rate structure (X2)** | (a) Continuous range 2,000–8,000 D/min with a 4,000 cap for new hosts (Claude) · (b) Three fixed tiers: 2k / 4k / 8k · (c) Other |
| 3 | **Beans earned per Diamond spent** | 1:1 (hosts get about 22% of gross at ₹0.005) · or another ratio |
| 4 | **Free Call Card mechanics** | Host compensation (₹10 flat per completed minute?); opt-in host pool; cap of 20 per host per day; one per phone and device; off on iOS; no re-issue at launch |
| 5 | **Diamond / Bean / reversal rules** | P7 (purchased Diamonds never expire; promotional 30 days; no transfers; not refundable once spent), P8 (Beans never expire), P9 (clawback on reversal) |
| 6 | **Billing mechanics** | P4 (60 s to start, 30 s warning, round once at the end) and P5 (server-confirmed start, 5 s grace, pause after 10 s) |
| 7 | **Safety baseline as a launch requirement** | P15 (nudity detection + report-to-end-call) and P16 (block minors via Play) |
| 8 | **XP levels for the beta** | Approve P12 as a temporary beta setting, recalibrated after real data. Shared or separate customer and host levels. |
| 9 | **Agencies at launch** | No, until 100+ hosts (Claude) · Yes |
| 10 | **Play account type** | Organisation account with D-U-N-S number (Claude) · Personal account (12 testers, 14 days) |

**Deferred deliberately (no decision now):**
- Pvt Ltd vs OPC: before payouts, after CA advice.
- Alternative billing: after launch.
- iOS: after Android validation.

---

## Source register

All sources were accessed on 2026-11-17.

| # | Source | Published | Type | What it establishes | Limitations |
|---|---|---|---|---|---|
| 1 | [TechCrunch — Google pulls Chamet](https://techcrunch.com/2023/09/01/google-pulls-popular-but-controversial-live-video-chat-app-chamet-from-the-play-store/) | 2023-09-01 | Secondary (reputable press) | Chamet removed; Data.ai India spend | Historical; Data.ai figures second-hand |
| 2 | [Curiosity Letter — "Bharat users need a dream girl"](https://curiosityletter.substack.com/p/bharat-users-need-a-dream-girl) | 2023-02-05 | Anecdotal | Pricing, Beans, demographics | Author's estimates |
| 3 | [Storyboard18 — 119-app block order](https://www.storyboard18.com/how-it-works/indias-app-block-order-on-google-play-store-119-targeted-15-down-developers-in-the-dark-57252.htm) | 2025-02-20 | Secondary | MeitY s.69A action against chat apps | Order itself is confidential |
| 4 | [Google Play — Sexual Content and Profanity](https://support.google.com/googleplay/android-developer/answer/9878810?hl=en) | Current | **Official** | Ban on sexual acts for compensation | — |
| 5 | [Google Play — Child Safety Standards](https://support.google.com/googleplay/android-developer/answer/14747720?hl=en) | Current | **Official** | Scope includes random chat, social, dating | Page did not show deadlines |
| 6 | [eCorpIT — Play random-chat changes, Aug 2026](https://ecorpit.com/google-play-anonymous-chat-age-restricted-policy-august-2026/) | 2026 | Secondary (cites Google) | Age-Restricted policy extended; Restrict Minor Access | Verify on Google's policy deadlines page |
| 7 | [Google Play — Service fees](https://support.google.com/googleplay/android-developer/answer/112622?hl=en) | Current | **Official** | 15% / 30% tiers | India 2026 status unclear |
| 8 | [Google — User Choice Billing](https://support.google.com/googleplay/android-developer/answer/13306652) | Current | **Official** | 4-point reduction | — |
| 9 | [vmobify — Play fees in India](https://vmobify.com/blog/google-play-service-fees-india) | 2026 | Secondary | India in "remaining markets" | Unverified |
| 10 | [Google Payments — Payout schedule](https://support.google.com/paymentscenter/answer/7159355) | Current | **Official** | Payout from the 15th for the previous month; India split disbursement | "Guideline; may vary" |
| 11 | [Google Play — Testing requirements for personal accounts](https://support.google.com/googleplay/android-developer/answer/14151465) | Current | **Official** | 12 testers for 14 days | — |
| 12 | [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) | Current | **Official** | 1.2, 3.1.3(d) | Full text not retrieved in this session |
| 13 | [GadgetHacks — Apple bans anonymous chat](https://apple.gadgethacks.com/news/apple-bans-anonymous-chat-apps-from-app-store/) | 2026 | Secondary | Random chat added to 1.2 | Verify official text |
| 14 | [Cashfree — FAQ (prohibited businesses)](https://www.cashfree.com/docs/help/account/faq) | Current | **Official** | Adult and sexually suggestive prohibited | Full list not retrieved |
| 15 | [Cashfree Payouts](https://www.cashfree.com/en/payouts/) | Current | **Official** | ₹6–8 per transfer table | Labelled "Wallets/Connected BaaS"; custom pricing |
| 16 | [Stream Video pricing guide](https://getstream.io/video/docs/api/pricing-guide/) | Current | **Official** | $1.50 per 1k participant-minutes HD; $100 free | — |
| 17 | [Nishith Desai — PPI regulations](https://nishithdesai.com/research-and-articles/hotline/technology-law-analysis/regulations-on-e-wallets-gift-cards-and-vouchers-given-a-facelift-4972) | 2021 | Secondary (law firm) | Closed-system PPI: no cash redemption | Check the current Master Direction |
| 18 | [YourStory — DPDP Rules](https://yourstory.com/2025/11/digital-personal-data-protection-dpdp-rules-2025-rollout-over-18-months) | 2025-11 | Secondary | Notified 13 Nov 2025; 18-month rollout | Check the Gazette |
| 19 | [Inc42 — Social Security Code](https://inc42.com/buzz/labour-ministry-notifies-national-social-security-board-for-gig-platform-workers/) | 2025-11 | Secondary | Code in force 21 Nov 2025 | Levy notification status unclear |
| 20 | [Taxguru — levy status](https://taxguru.in/?p=1091866) | 2026-10 | Secondary | Rate and start date "awaiting notification" | Conflicts with other reports |
| 21 | [SAM — IT Rules Amendment 2026](https://www.amsshardul.com/wp-content/uploads/2026/02/Legislative-Update-IT-Rules-Amendment.pdf) | 2026-02 | Secondary (law firm) | Takedown deadlines shortened | In-force status unverified |
| 22 | [Income Tax Dept — s.194-O](https://incometaxindia.gov.in/w/section-194-o-3) | Current | **Official** | E-commerce operator TDS | Applicability needs a CA |
| 23 | [eKYCNow — pricing](https://www.messagecentral.com/en-in/product/ekyc-now/pricing/india) | Current | Vendor | ₹10–18 per check | Single vendor |
| 24 | [Sightengine pricing](https://sightengine.com/pricing) | Current | Vendor | $99 / 40k operations | — |
| 25 | [BitTopup — Chamet agency commission](https://bittopup.com/article/Chamet-Agency-vs-Solo-Host-2025-Commission-Earnings) | 2025 | **Unreliable** (Diamond reseller) | Agency ladder 5–30% | Conflicting; commercial interest |
| 26 | [Buffget — Chamet call price](https://buffget.com/news/chamet-video-call-price-2026-minute-cost-breakdown) | 2026 | **Unreliable** (reseller) | 1,200–20,000 D/min range | Commercial interest |
| 27 | [IndianStartupNews — FRND](https://indianstartupnews.com/funding/isn-exclusive-made-in-india-social-networking-and-dating-app-frnd-looks-to-raise-25-million-10524768) | 2025 | Secondary | FRND revenue ₹74 cr FY24 | Conflicts with other databases |
| 28 | [Google Play — Policy Deadlines](https://support.google.com/googleplay/android-developer/table/12921780) | Current | **Official** | 2026-08-26 random/anonymous chat policies; 2026-09-30 verification | — |
| 29 | [Google Play — Policy announcement](https://support.google.com/googleplay/android-developer/answer/17134731) | 2026-07-15 | **Official** | Random and anonymous chat changes | — |
| 30 | [Google Play — Age-Restricted Content](https://support.google.com/googleplay/android-developer/answer/17036597) | Current | **Official** | "Core functionality" scope; minor blocking | Tool name not stated |
| 31 | [Google Play — Payments policy](https://support.google.com/googleplay/android-developer/answer/9858738) | Current | **Official** | Virtual currencies require Play Billing | — |
| 32 | [Google Payments — GST guidance](https://support.google.com/paymentscenter/answer/7421525) | Current | **Official** | India developers "may be responsible" for GST | Conflicts with other Google pages |
| 33 | [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) (re-read in audit) | Current | **Official** | 1.1.4, 1.2, 3.1.1, 3.1.3(d) text | No date of change |
| 34 | [Supabase pricing](https://supabase.com/pricing) | Current | **Official** | Pro plan inclusions | — |
| 35 | [Stream Video pricing page](https://getstream.io/video/pricing/) | Current | **Official** | $100/mo free; plan structure | HD rate on the pricing guide (#16) |
| 36 | [Khaitan & Co — IT Amendment Rules 2026](https://www.khaitanco.com/thought-leadership/MeitY-notifies-the-IT-Amendment-Rules-2026) | 2026-02 | Secondary (law firm) | G.S.R. 120(E), 10/20 Feb 2026 | Gazette not read |
| 37 | [Taxguru — s.194-O amendment](https://taxguru.in/income-tax/section-194-o-amendment-lower-tds-rate-e-commerce-payments.html) | 2024 | Secondary | 0.1% from 1 Oct 2024 | — |
| 38 | [Mondaq — Social security for gig workers](https://www.mondaq.com/india/constitutional-administrative-law/1759312/social-security-for-gig-workers-in-india-do-central-and-state-laws-signal-higher-costs-for-online-platforms) | 2026 | Secondary | Levy framework; state laws | — |
| 39 | [Razorpay — High-risk merchants](https://razorpay.com/learn/what-is-a-high-risk-merchant-account/) | Current | Official (educational) | Dating treated as high-risk | Not a policy list |
| 40 | [MessageCentral — OTP pricing India](https://www.messagecentral.com/en-in/blog/sms-otp-pricing-india) | 2026 | Vendor (competitor) | OTP ₹0.15–0.25 | Biased |

**How much to trust the evidence:**

| Area | Evidence quality |
|---|---|
| Platform policies | **Strong** (official sources) |
| India legal and tax | **Moderate** (mostly law-firm or press commentary; needs professional confirmation) |
| Competitor economics | **Weak** (anecdotal or reseller sources) |
| Customer behaviour and acquisition cost | **Absent** (must be generated in beta) |
