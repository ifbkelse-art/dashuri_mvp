# video_call pages (founder-owned)

- CallPage (RoutePaths.call): local preview + remote video (from `VideoViewFactory`), status from `CallBloc.state.status`, billed time and Diamonds from `state.session` (server values), hang-up → `CallEndRequested()`, report → `CallEndRequested(reason: 'report')` then navigate to `RoutePaths.report`.
- IncomingCallPage/overlay: accept → `CallIncomingAccepted(callId)`, decline → `CallIncomingDeclined(callId)`.
- Outgoing "Calling…" state while `status == ringing`.

Show `state.lowBalanceSecondsRemaining` as the 30-second warning. Never show a locally computed charge.
