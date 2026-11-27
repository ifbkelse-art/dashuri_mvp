# Phase 9: future improvements (not implemented)

These are ideas found during the redesign that are **new features or contract changes**, so they are out of Phase 9 scope (founder rule 19). Each needs its own approval.

| Idea | Why | What it needs |
|---|---|---|
| `payouts_enabled` on `GET /v1/host/earnings` | The app currently learns whether payouts are on from an app flag (`DASHURI_PAYOUTS_ENABLED`). A server field would keep app and server in step without a release. | An additive API field (backend contract change). |
| In-app legal texts synced to website v1.0, or opened from the website | The in-app legal page still says "draft, not legally binding". | A founder decision on the text source. |
| Host photo gallery on the host profile | Profiles show one hero image; hosts can have several approved photos. | A design and a check that the discovery API already returns them. |
| Haptics on Accept/Decline and Go online | A premium feel on key actions. | Small; check battery and accessibility settings. |
| Reels: refresh a reel whose 6-hour playback URL expired (on 403) | Long-open feeds fail to play until refreshed. | A player change plus `GET /v1/reels/{id}`. |
