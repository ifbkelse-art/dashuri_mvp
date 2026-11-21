import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/level_progress.dart';

/// Maps the API's snake_case JSON to [LevelProgress]. Keep in sync with api/openapi/dashuri.v1.yaml.
LevelProgress levelProgressFromJson(JsonMap json) => LevelProgress(
  level: json['level']! as int,
  lifetimeXp: json['lifetime_xp']! as int,
  currentLevelXp: json['current_level_xp']! as int,
  nextLevelXp: json['next_level_xp'] as int?,
);
