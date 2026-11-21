# ADR-005: Video provider behind a port; Stream pending validation

- **Status:** Accepted (abstraction); provider choice **pending**, 2026-11-17

## Context
Stream Video is the intended provider, "subject to final commercial and technical validation". Billing correctness depends on trustworthy server-side events, and moderation (S7) may need server-side access to frames.

## Decision
- **Client:** a `VideoEngine` port (join, leave, mic/camera, media events) plus `VideoViewFactory` for video surfaces. The Stream adapter is a documented skeleton; the SDK is not yet a dependency.
- **Server:** a `calls.VideoProvider` port (create call, issue a per-user per-call token, force end, verify and normalise webhooks).
- Billing uses only normalised provider webhook events (`calls.BillableSeconds`).

## Alternatives
- **Integrate the Stream SDK directly in BLoCs and pages:** fastest start, but locks billing and UI to one vendor.
- **Self-hosted SFU (LiveKit, mediasoup):** lower unit cost at scale; operational burden too high for launch.
- **Agora, Twilio, 100ms:** candidates if Stream fails validation; the ports make a switch an adapter change.

## Trade-offs
One indirection layer. Provider-specific features (e.g. built-in moderation) must be exposed through the ports deliberately.

## Validation checklist
See `video-call-architecture.md`: webhooks with signatures and ids, scoped tokens, server force-end, frame access, India latency, pricing, DPDP terms.
