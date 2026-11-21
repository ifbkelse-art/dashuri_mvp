# ADR-013: Nudity checks use client-captured frames for the first 3 minutes

- **Status:** Accepted for the MVP, 2026-11-21. Resolves the "frame source" open question in `security-architecture.md` for now.

## Context
Founder decision S7: automated nudity detection during the first three minutes of each call, report-based afterwards. Stream Video's server-side frame access requires recording or egress features that have not been validated (ADR-005 checklist).

## Decision
- Each participant's app captures a JPEG of **its own outgoing camera** about every 20 s while `now < moderation_window_ends_at` (= `connected_at` + 180 s) and uploads it to `POST /v1/calls/{id}/moderation-frames`.
- The server classifies frames with the `NudityClassifier` port (Sightengine `nudity-2.1` adapter). A flagged frame ends the call (`moderation`), opens a priority-1 automated report and records evidence metadata.
- **Tamper resistance:** the server, not the client, owns the window. A participant who sends no frames for 60 s inside the window gets a queued review (`moderation-missing-frames` job). A modified client could still skip uploads; that risk is accepted for the MVP and documented.

## Consequences
- Cost is about 9 frames per participant per call (business report R32 pricing).
- Production should move to server-side capture (Stream recording or egress for the first 3 minutes) once validated. The port makes that an adapter change.
- **This design does not by itself establish legal, Play or IT Rules compliance** (PRO-REVIEW).
