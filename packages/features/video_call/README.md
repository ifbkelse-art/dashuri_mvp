# feature_video_call

Paid one-to-one video calls. **The server is authoritative** for authorisation, connection confirmation, billable seconds, pauses, Diamonds charged and settlement. This package only orchestrates the device side and displays server values.

| Layer | Contents |
|---|---|
| Domain | `CallSession` (+ `peer`, `started_at`, `moderation_window_ends_at`), `CallCredentials`, `PreCallInfo`, `ModerationFrame`; `CallRepository`; ports `VideoEngine`, `ModerationFrameSource`; one use case per action |
| Data | `CallRemoteDataSource`, `CallRepositoryImpl` (realtime `call:<id>` and `user:<id>`), `providers/stream/` (`StreamVideoEngine`, `StreamVideoViewFactory`, `StreamModerationFrameSource`, `JpegEncoder`) |
| Application | `CallBloc`, `ModerationFrameScheduler`, `PreCallCubit`, `CallSummaryCubit`, `CallHistoryCubit`, `IncomingCallCubit` |
| Presentation | `PreCallPage` (V01/V06), `CallPage` (V02–V05, V07, V15–V17), `CallSummaryPage` (V08–V10, V14, V18), `CallHistoryPage` |
| Wiring | `registerVideoCallFeature`, `VideoCallRoutes`, `IncomingCallWatcher` |

Rules:
- The client never sends durations or Diamond amounts. `endCall` sends only a reason.
- Media events (connection lost/restored) drive UI only. "Billing is paused" is shown only when the server phase is `paused`.
- S7: during `moderation_window_ends_at`, a JPEG (≤ 200 KB) of the local camera is posted every 20 s (first after 5 s) via `Call.takeScreenshot` → downscale → `JpegEncoder`.
- Stream api key: from the credentials response (`api_key`), else `--dart-define=DASHURI_STREAM_API_KEY`; otherwise joining fails with `video_not_configured`.
- Host side: wrap the app in `IncomingCallWatcher(onIncomingCall: (id) => router.push('/calls/$id?incoming=1'))`.

See docs/architecture/video-call-architecture.md and docs/mvp/api/calls_hosts_moderation.md.
