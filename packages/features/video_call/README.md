# feature_video_call

Paid one-to-one video calls. **The server is authoritative** for authorisation, connection confirmation, billable seconds, pauses, Diamonds charged and settlement. This package only orchestrates the device side and displays server values.

| Layer | Contents |
|---|---|
| Domain | `CallSession`, `CallCredentials`, `CallEvent`, `MediaEvent`; `CallRepository`; `VideoEngine` port; use cases `RequestCall`, `AcceptCall`, `DeclineCall`, `EndCall`, `GetCall`, `GetCallCredentials`, `WatchCall` |
| Data | `CallRemoteDataSource` (Go API), `CallRepositoryImpl` (+ realtime channel `call:<id>`), `providers/stream/StreamVideoEngine` (TODO skeleton) |
| Application | `CallBloc` |
| Presentation | founder-owned call pages; `VideoViewFactory` contract for video surfaces |

Rules:
- The client never sends durations or Diamond amounts. `endCall` sends only a reason.
- Media events (connection lost/restored) drive UI only. Billing pauses come from the server reading the provider's events.
- Per-second billing, 60-second minimum balance to start, 30-second low-balance warning, pause on qualifying interruptions, refund on failed connection: all server-side (founder decision S6). Interruption thresholds are technical assumptions to tune.
- Stream Video is not yet added as a dependency (ADR-005).

See docs/architecture/video-call-architecture.md.
