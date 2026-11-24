# Dashuri: payment collection and host payout options

**Date:** 24 Nov 2026 · **Purpose:** a briefing for the founder to discuss with advisers and ChatGPT. Research only: no code, config or account was changed. Sources and access date (24 Nov 2026) are at the end. Anything marked **unverified** was not confirmed from an official source.

## 1. Situation

| Fact | Status |
|---|---|
| Cashfree: Payment Gateway, Payment Links and Payment Forms show **Rejected**. Banner: "Your business falls under a restricted category & cannot be served at this time." | Confirmed from the founder's dashboard screenshot |
| PayU onboarding is in progress (MID created, "Business purpose" step) | Founder-reported; outcome unknown |
| Diamonds are virtual currency sold in-app; Google requires Play Billing for that, with an India alternative-billing option | Verified (Google pages below) |
| Callers pay Google; Google pays Dashuri monthly; Dashuri must pay hosts separately | Design fact |
| Host payouts are switched off (`PAYOUTS_ENABLED=false`); incorporation is pending | Repo + founder |
| Decided (register A-9): weekly payouts; Dashuri pays transfer fees; Diamonds→Beans conversion (5:4) approved for modelling only | Register |

**The key point:** there are two separate jobs. Failing at one gateway affects only the optional second rail, not the main one.

## 2. Job A: collecting money from callers

| Option | What it is | Fit | Evidence / cost | Risk |
|---|---|---|---|---|
| **A1. Google Play Billing only** | In-app Diamond purchases go through Google. Google pays Dashuri monthly | **Best.** Required for in-app virtual currency; needs no gateway | Play fee 15% only after enrolling in the 15% tier, otherwise 30% (verified rule; enrolment status unknown) | Play policy review is still needed (register C-01) |
| A2. Play "alternative billing" in India | A second payment system offered alongside Play Billing; fee reduced by 4 points (e.g. 15% → 11%) | Optional later. Needs a gateway that accepts the category, PCI DSS certification, fraud reporting and transaction reports to Google within 24 hours | Google India programme page. 2026 terms **unverified** (a newer page mentions updated fees from 30 Jun 2026) | The gateway must approve the category, which Cashfree did not |
| A3. Another gateway: PayU, Razorpay, PhonePe, Paytm, Juspay, Easebuzz | A card/UPI gateway | Only useful for A2 | Razorpay's lists name no video-chat category but prohibit virtual currency that can be converted to money and list online matchmaking as a gray zone. PayU says some categories are not supported and its list was not found. Others **not checked** | Likely the same "restricted category" answer; account freeze if the business is described inaccurately |
| A4. Web checkout outside the app | Sell Diamonds on a website | **Not recommended**: Google's policy says apps generally may not steer users to other payment methods for digital goods | Google Payments policy | Policy violation |

**Recommendation:** launch with A1 only. Treat A2/A3 as a later optimisation, worth about 4 points of fee if it becomes available.

## 3. Job B: paying hosts

Google Play Billing does **not** pay hosts. It only pays Dashuri.

| Option | How it works | Cost (evidence) | Pros | Cons / unknowns |
|---|---|---|---|---|
| **B1. Manual bank transfers** from the business current account (bank's bulk upload) | Weekly batch file/UPI/NEFT/IMPS from your own bank | ICICI states its bulk payments (BizPay360) work with an existing current account with no extra setup or transaction charges beyond standard account fees. Another bank's bulk tool may lack IMPS/UPI (**unverified** for current HDFC/Axis) | Lowest cost; no category review by a payments company | You handle TDS, records and errors; needs a bank that allows this business; scale limit |
| B2. RazorpayX Payouts | Payout API from a RazorpayX account | List ₹4 / ₹6 / ₹9 per IMPS/UPI transfer, free allowance 250–500 payouts a month (pages conflict), GST extra, monthly subscription on some plans. Limits ₹5 lakh IMPS, ₹1 lakh UPI | API, webhooks, reconciliation | Business-category review applies to the account; get a written quote |
| B3. Cashfree Payouts | Same, via Cashfree | Pricing is custom (sales). Earlier page: ₹6 / ₹8 / ₹15 plus GST | Already has an account | The same company just rejected the business as restricted; ask whether Payouts is affected |
| B4. PayU, Paytm Payouts, Easebuzz, Decentro | Payout APIs | Prices not published (quote-based); one third-party example ₹2–10 per transfer, **unverified** | More options | Each has its own category policy and onboarding |
| B5. A bank's corporate API banking | The bank's own payout API | **Not researched** | Fewer intermediaries | Needs a corporate banking relationship |

**Recommendation:** start with B1 and move to an API provider (B2 or another that approves the category in writing) when payout volume makes manual work risky. Do not build the payout adapter until a provider confirms in writing.

## 4. Other points to settle

- **TDS and GST on host payouts:** unresolved. CA to decide whether section 194-O (0.1%, nil up to ₹5 lakh a year for individuals with PAN/Aadhaar) or another section applies (register C-06).
- **Bank and RBI framing:** Diamonds funded by callers, paid out as Beans to hosts in rupees. Lawyer to confirm it fits outside prepaid-instrument rules (register C-09).
- **Incorporation:** needed for the current account and payout onboarding (register C-11).
- **Cash timing:** Google pays about 15–45 days after purchase; payouts need the approved reserve (register A-10).
- **Describe the business accurately to every provider.** Misdescribing the business is the usual reason accounts are frozen later.

## 5. Questions to ask in writing (copy and send)

> We run an app for adults aged 18 and above in India. Callers buy in-app credits through Google Play Billing and spend them per minute on live one-to-one video calls with approved hosts. Hosts set their own per-minute price and are paid for their time. Calls are moderated, users can report and block, and support is available. Hosts can withdraw their earnings in rupees to their own bank account or UPI. **(1) Do you provide payout services to individuals for this kind of business? (2) Are there restricted categories we should know about? (3) What are your fees, free allowance, limits and onboarding documents?** Please reply in writing.

## 6. What to ask ChatGPT

- Which Indian payout providers accept paid 1:1 video-calling apps, and what would they require?
- Is manual bank bulk payout compliant at small scale (TDS, GST, record-keeping)?
- Do the TDS and GST rules depend on whether hosts are treated as service providers to Dashuri or through Dashuri?
- Are there any payment rails that serve apps like this? Verify against official sources.

Treat answers about categories, tax and RBI rules as leads, not facts. Confirm with the provider in writing and with a CA and lawyer.

## Sources (accessed 24 Nov 2026)

- Cashfree rejection: the founder's dashboard screenshot.
- [Google Payments policy](https://support.google.com/googleplay/android-developer/answer/10281818?hl=en) · [India billing changes](https://support.google.com/googleplay/android-developer/answer/13306652?hl=en) · [Alternative billing systems](https://support.google.com/googleplay/answer/11174377?hl=en) · [User choice billing](https://support.google.com/googleplay/android-developer/answer/13821247?hl=en) · [Play service fees](https://support.google.com/googleplay/android-developer/answer/112622?hl=en)
- [Razorpay terms](https://razorpay.com/terms/) · [Razorpay high-risk guide](https://razorpay.com/blog/payment-gateway-for-high-risk-merchant-accounts/) · [Razorpay Route docs](https://razorpay.com/docs/payments/route/) · [RazorpayX pricing](https://razorpay.com/x/pricing/)
- [PayU high-risk merchants](https://payu.in/blog/what-is-a-high-risk-merchant-account/)
- [Cashfree Payouts](https://www.cashfree.com/payouts) · [Cashfree API banking](https://www.cashfree.com/api-banking-india/) · [Cashfree bulk payment blog](https://cashfree.com/blog/bulk-payment/)
- [ICICI bulk payments](https://www.icici.bank.in/business-banking/cms/payment-solutions/bulk-payments/bizpay360)
- [Easebuzz pricing](https://easebuzz.in/pricing/) · [Decentro payouts](https://decentro.tech/products/payouts)
