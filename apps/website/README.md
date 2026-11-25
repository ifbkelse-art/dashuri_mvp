# Dashuri public website

Static marketing and policy site (built 25 Nov 2026). There are no dependencies and no JavaScript in the pages. It is built for Netlify and **not deployed yet**.

## Pages

- **Marketing:** `/`, `/hosts/`, `/safety/`, `/contact/`.
- **Policies (version 1.0):** `/terms/`, `/privacy/`, `/community-guidelines/`, `/child-safety/`, `/refunds/`, `/host-agreement/`, `/grievance/`, `/delete-account/`, plus a `/legal/` index with company information and the 404 page.

Google Play Console needs three of these URLs:
- privacy policy: `/privacy/`;
- account deletion: `/delete-account/`, which explains deletion with and without the app;
- Child Safety Standards: `/child-safety/`.

## Commands

```sh
cd apps/website
node build.mjs     # writes dist/
node check.mjs     # links, titles, CSP-safe markup, no secrets (warns about missing company details)
node check.mjs --production   # also FAILS while required company details are empty (Netlify runs this)
npm run dev        # build + local preview on http://localhost:5174
```

## Editing

- **Contact details, operator name, Grievance Officer, Play link and domain:** `src/site.mjs` only.
  - The download buttons show "Coming soon to Google Play" until `playStoreUrl` is set.
  - Missing company details show as highlighted `[…]` markers in a preview, and block the production build.
- **Policy text:** `src/legal.mjs` is the full, governing version. The in-app texts in `packages/features/settings/lib/src/presentation/widgets/legal_texts.dart` are older short drafts and still need replacing with summaries that link here.
- **Marketing pages:** `src/pages.mjs`. **Styles:** `src/styles.css`, using DashuriTokens colours and Instrument Serif + Manrope.

## Content rules

Only claim what the live app does. Two examples:
- Messaging privacy defaults to "everyone", so the site says users *can* limit who messages them.
- Payouts are off, so the hosts page says withdrawals open after launch.

Do not mention unreleased features, such as Verified Host, Reels, the Free Call Card or specific prices, until they are live.

## Deploying to Netlify (needs the founder's go-ahead)

1. Create a Netlify site from the GitHub repo, with **Base directory** `apps/website`. `netlify.toml` sets the build command (`node build.mjs && node check.mjs --production`, which fails until the company details are filled) and the publish directory (`dist`). The free tier is enough.
2. Optionally add a custom domain, then set `origin` in `src/site.mjs` so the pages carry canonical links.
3. Put the resulting URLs in Play Console: App content › Privacy policy, Data safety › Account deletion URL, and Child Safety Standards.

The build writes `dist/_headers` from `src/headers.mjs`, which Netlify applies for every deploy method, including drag-and-drop. It sets a strict Content-Security-Policy: no scripts, with fonts from Google Fonts only. Pages must not use inline `style=""` attributes or `<script>` tags; `check.mjs` enforces this.

## Legal status (25 Nov 2026)

The policies were written without a lawyer or CA, against the Indian laws listed at the top of `src/legal.mjs`. They are written to be launch-grade, but nobody qualified has reviewed them. Have them reviewed when there is budget, starting with the Terms (liability cap, refunds) and the Host Agreement (tax).

### Before the production build can run (`src/site.mjs`)
- **Legal name of the operator and registered address** (E-Commerce Rules, Rule 4).
- **Customer care phone number** (E-Commerce Rules, Rule 4).
- **Grievance Officer:** a named person in India, with a designation (IT Rules 3(2) and E-Commerce Rules).
- **City for the courts** (Terms §16).

### Business commitments the text makes (founder to confirm)
- Refund unused *purchased* Diamonds if Dashuri shuts down, or closes an account for a reason other than a breach (Terms §11, Refunds).
- Liability cap: the amount paid in the last 3 months or ₹1,000, whichever is higher (Terms §14).
- A 30-day window to dispute a call charge; data-rights replies within 30 days.
- Financial records kept up to 8 years; safety evidence kept for 180 days.

### Gaps between the text and the system (fix before launch)
1. **Phone number deletion is manual.** The deletion job anonymises the account, but the Supabase Auth user (phone number) is removed by hand through the Admin API. The policy promises removal, so automate it or run it for every completed deletion.
2. **Photo files.** The deletion job deletes photo rows; confirm that the Storage objects are deleted too.
3. **Log retention.** The DPDP Rules require logs to be kept for at least one year. Cloud Logging keeps logs for 30 days by default. Extending it is a small paid change, so ask the founder first.
4. **Deletion confirmation email** for requests made without the app is a manual step.
5. **CSAM reporting runbook:** who reports to cybercrime.gov.in and the police, and how evidence is preserved.
6. **Annual reminder:** IT Rules 3(1)(c) require users to be reminded of the rules at least once a year (an in-app notice).
7. **In-app texts** still say "Draft, pending legal review" and differ from these pages.
