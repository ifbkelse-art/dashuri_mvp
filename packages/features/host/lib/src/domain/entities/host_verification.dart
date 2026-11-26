import 'package:equatable/equatable.dart';

/// Verified Host statuses (GET /v1/host/verification `status`). Separate
/// from hosting KYC: KYC lets an account host at all; Verified Host is the
/// premium, admin-reviewed status needed to charge above 3,000 D/min.
abstract final class VerificationStatuses {
  static const notApplied = 'not_applied';
  static const submitted = 'submitted';
  static const underReview = 'under_review';
  static const infoRequired = 'info_required';
  static const verified = 'verified';
  static const rejected = 'rejected';
  static const suspended = 'suspended';
  static const revoked = 'revoked';

  /// Host-facing label for a status.
  static String label(String status) => switch (status) {
    submitted => 'Application submitted',
    underReview => 'Under review',
    infoRequired => 'More information needed',
    verified => 'Verified Host',
    rejected => 'Not approved',
    suspended => 'Suspended',
    revoked => 'Revoked',
    _ => 'Not verified',
  };
}

/// Private evidence kinds. The files live in a private bucket; the app only
/// ever sees ids and kinds, never URLs.
enum EvidenceKind {
  faceVideo('face_video', 'Face video'),
  idDocumentFront('id_document_front', 'ID document (front)'),
  idDocumentBack('id_document_back', 'ID document (back, optional)');

  const EvidenceKind(this.wire, this.label);

  final String wire;
  final String label;

  static EvidenceKind? fromWire(String v) =>
      values.where((k) => k.wire == v).firstOrNull;
}

final class VerificationEvidence extends Equatable {
  const VerificationEvidence({
    required this.id,
    required this.kind,
    required this.submitted,
  });

  final String id;
  final EvidenceKind kind;

  /// Already part of an application (false: uploaded, not yet submitted).
  final bool submitted;

  @override
  List<Object?> get props => [id, kind, submitted];
}

/// GET /v1/host/verification.
final class HostVerification extends Equatable {
  const HostVerification({
    required this.status,
    required this.canSubmit,
    this.note,
    this.evidence = const [],
    this.requiredEvidence = const [
      EvidenceKind.faceVideo,
      EvidenceKind.idDocumentFront,
    ],
  });

  final String status;
  final bool canSubmit;

  /// Open information request, or the rejection/suspension/revocation reason.
  final String? note;
  final List<VerificationEvidence> evidence;
  final List<EvidenceKind> requiredEvidence;

  bool get isVerified => status == VerificationStatuses.verified;
  bool get replyingToInfoRequest => status == VerificationStatuses.infoRequired;

  /// Uploaded but not yet submitted.
  List<VerificationEvidence> get pending =>
      evidence.where((e) => !e.submitted).toList();

  bool hasPending(EvidenceKind k) => pending.any((e) => e.kind == k);

  /// A new application needs every required kind; a reply to an information
  /// request needs at least one new upload.
  bool get readyToSubmit =>
      canSubmit &&
      (replyingToInfoRequest
          ? pending.isNotEmpty
          : requiredEvidence.every(hasPending));

  @override
  List<Object?> get props => [
    status,
    canSubmit,
    note,
    evidence,
    requiredEvidence,
  ];
}
