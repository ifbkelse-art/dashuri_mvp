import 'package:equatable/equatable.dart';

final class WalletEntry extends Equatable {
  const WalletEntry({
    required this.id,
    required this.currency,
    required this.kind,
    required this.amount,
    required this.createdAt,
    required this.reference,
  });

  final String id;
  final String currency;
  final String kind;
  final int amount;
  final DateTime createdAt;
  final String? reference;

  @override
  List<Object?> get props => [id, currency, kind, amount, createdAt, reference];
}
