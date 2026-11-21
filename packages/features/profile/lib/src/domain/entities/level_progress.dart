import 'package:equatable/equatable.dart';

final class LevelProgress extends Equatable {
  const LevelProgress({
    required this.level,
    required this.lifetimeXp,
    required this.currentLevelXp,
    required this.nextLevelXp,
  });

  final int level;
  final int lifetimeXp;
  final int currentLevelXp;
  final int? nextLevelXp;

  @override
  List<Object?> get props => [level, lifetimeXp, currentLevelXp, nextLevelXp];
}
