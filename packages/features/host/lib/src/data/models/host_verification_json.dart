import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/host_verification.dart';

/// Maps GET /v1/host/verification (api/openapi/dashuri.v1.yaml VerificationView).
HostVerification hostVerificationFromJson(JsonMap json) {
  final evidence = <VerificationEvidence>[];
  for (final e in (json['evidence'] as List<Object?>? ?? const [])) {
    if (e is! JsonMap) continue;
    final kind = EvidenceKind.fromWire(e['kind'] as String? ?? '');
    final id = e['id'];
    if (kind == null || id is! String) continue;
    evidence.add(
      VerificationEvidence(
        id: id,
        kind: kind,
        submitted: e['submitted'] == true,
      ),
    );
  }
  final required = [
    for (final k in (json['required_evidence'] as List<Object?>? ?? const []))
      if (k is String) ?EvidenceKind.fromWire(k),
  ];
  return HostVerification(
    status: json['status'] as String? ?? VerificationStatuses.notApplied,
    canSubmit: json['can_submit'] == true,
    note: json['note'] as String?,
    evidence: evidence,
    requiredEvidence: required.isEmpty
        ? const [EvidenceKind.faceVideo, EvidenceKind.idDocumentFront]
        : required,
  );
}
