import '../domain/entities/host_status.dart';

/// Where the host application flow (FL04) continues from a server status.
/// Order: apply → agreement (H06) → identity verification session (H03–H05)
/// → profile (H09) → rate (H10) → review (H07).
enum HostApplicationStep {
  apply,
  agreement,
  verification,
  review,
  attention,
  approved,
  suspended,
}

HostApplicationStep nextApplicationStep(HostStatus status) {
  if (!status.hasApplied) return HostApplicationStep.apply;
  if (status.isApproved) return HostApplicationStep.approved;
  if (status.isSuspended) return HostApplicationStep.suspended;
  if (status.kycRejected) return HostApplicationStep.attention;
  if (status.kycNotStarted) return HostApplicationStep.agreement;
  return HostApplicationStep.review;
}
