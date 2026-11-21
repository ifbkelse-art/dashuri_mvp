DASHURI — MVP UI/UX DESIGN HANDOFF  (v1.0 · 19 Nov 2026)

START HERE
  Dashuri_MVP_UI_UX_Design.pdf   Complete handoff (142 pages): brand, design system, navigation,
                                 user flows, wireframes, one spec page per screen, open decisions, index.
  Dashuri_Wireframes.pdf         Grayscale wireframes for every screen + flows (33 pages).
  Dashuri_Design_System.pdf      Design-system reference sheets only (16 pages).

FOLDERS (PNG)
  Authentication/   A01–A15   Splash, welcome, login, registration, Google, OTP, profile, age, gender, rules, permissions
  Customer/         C01–C12   Discover, filters, empty/loading states, host profiles, Free Call Card, notifications
                    CH01–CH05 Chat inbox, conversation, empty, restricted, safety-filtered
                    S01–S10   Profile, edit, settings, privacy, notifications, blocked, help, legal, delete account
  Video_Calling/    V01–V18   Pre-call, outgoing, connecting, active, low/insufficient balance, network, summaries,
                              report/block, refunds, free call, host incoming/active/summary
  Wallet/           W01–W09   Wallet, packages, checkout (Cashfree), processing, success, failure, pending, history, detail
  Host/             H01–H25   Application, KYC, agreement, review, profile & rate, dashboard, availability,
                              earnings, Beans conversion, withdrawals, payouts, settings
  Components/       DS01–DS13 Design-system sheets (3200×2000)
  User_Flows/       FL01–FL06 Journeys and sitemap (3200×2000)
  Wireframes/       Grayscale version of every screen, same folder structure

SCREEN EXPORTS
  1170 × 2532 px = 390 × 844 pt artboard @3x (9 : 19.5). Divide pixel measurements by 3 for Flutter logical pixels.
  Fonts: Instrument Serif (display) + Manrope (UI) — Google Fonts. Icons: Lucide (1.75 stroke) + custom Diamond/Bean SVGs.

IMPORTANT
  • Items tagged D-01 … D-22 are open product decisions, not business rules (see the PDF's final section).
  • D-01: the brief asks for Cashfree payment states; docs/architecture ADR-010 specifies Google Play Billing.
  • Names, cities and photos are sample content. Photos are Unsplash placeholders — do not ship them.
