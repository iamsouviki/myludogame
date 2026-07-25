import '../utils/constants.dart';

class Player {
  final String id;
  final String name;
  final PlayerColor color;
  final PlayerType type;
  final AIDifficulty? difficulty;
  final int avatarIndex;
  final int? teamId; // 0 for Team A, 1 for Team B, null for solo free-for-all

  const Player({
    required this.id,
    required this.name,
    required this.color,
    required this.type,
    this.difficulty,
    this.avatarIndex = 0,
    this.teamId,
  });

  bool get isAI => type == PlayerType.ai;
  bool get isHuman => type == PlayerType.human;

  Player copyWith({
    String? id,
    String? name,
    PlayerColor? color,
    PlayerType? type,
    AIDifficulty? difficulty,
    int? avatarIndex,
    int? teamId,
  }) =>
      Player(
        id: id ?? this.id,
        name: name ?? this.name,
        color: color ?? this.color,
        type: type ?? this.type,
        difficulty: difficulty ?? this.difficulty,
        avatarIndex: avatarIndex ?? this.avatarIndex,
        teamId: teamId ?? this.teamId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color.index,
        'type': type.index,
        'difficulty': difficulty?.index,
        'avatarIndex': avatarIndex,
        'teamId': teamId,
      };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: (json['id'] as String?) ?? 'player',
        name: (json['name'] as String?) ?? 'Player',
        color: json['color'] != null
            ? PlayerColor.values[(json['color'] as num).toInt()]
            : PlayerColor.red,
        type: json['type'] != null
            ? PlayerType.values[(json['type'] as num).toInt()]
            : PlayerType.human,
        difficulty: json['difficulty'] != null
            ? AIDifficulty.values[(json['difficulty'] as num).toInt()]
            : null,
        avatarIndex: (json['avatarIndex'] as num?)?.toInt() ?? 0,
        teamId: (json['teamId'] as num?)?.toInt(),
      );
}
