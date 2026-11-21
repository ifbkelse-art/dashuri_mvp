import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';
import 'package:test/test.dart';

void main() {
  test('409 with a rule maps to BusinessRuleFailure', () {
    final f = failureFromProblem(409, {
      'code': 'business_rule',
      'rule': 'insufficient_diamonds',
    });
    expect(f, isA<BusinessRuleFailure>());
    expect(f.code, 'insufficient_diamonds');
  });

  test('409 without a rule maps to ConflictFailure', () {
    expect(
      failureFromProblem(409, {'code': 'call_already_settled'}),
      isA<ConflictFailure>(),
    );
  });

  test('422 maps field errors', () {
    final f = failureFromProblem(422, {
      'code': 'validation_failed',
      'errors': [
        {'field': 'rate_per_minute', 'reason': 'out_of_range'},
      ],
    });
    expect((f as ValidationFailure).fieldErrors, {
      'rate_per_minute': 'out_of_range',
    });
  });

  test('5xx maps to ServerFailure, 401 to Unauthenticated', () {
    expect(failureFromProblem(503, null), isA<ServerFailure>());
    expect(failureFromProblem(401, null), isA<UnauthenticatedFailure>());
  });

  test('idempotency keys are v4 UUIDs and unique', () {
    final a = IdempotencyKey.generate().value;
    final b = IdempotencyKey.generate().value;
    expect(
      a,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(a, isNot(b));
  });
}
