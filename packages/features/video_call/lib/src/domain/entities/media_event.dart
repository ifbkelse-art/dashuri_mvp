/// Local media-engine events from the video provider SDK. Used only to drive
/// the UI (show "reconnecting", render remote video). They are NOT billing
/// signals; the server reads the provider's own events for billing.
enum MediaEvent {
  joined,
  remoteJoined,
  remoteVideoStarted,
  remoteVideoStopped,
  remoteLeft,
  connectionLost,
  connectionRestored,
  left,
}
