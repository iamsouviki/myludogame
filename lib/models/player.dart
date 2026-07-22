import '../utils/constants.dart';

class Player {
  final String id;
  final String name;
  final PlayerColor color;
  final PlayerType type;
  final AIDifficulty? difficulty;

  const Player({
    required this.id,
    required this.name,
    required this.color,
    required this.type,
    this.difficulty,
  });

  bool get isAI => type == PlayerType.ai;
  bool get isHuman => type == PlayerType.human;

  Player copyWith({
    String? id,
    String? name,
    PlayerColor? color,
    PlayerType? type,
    AIDifficulty? difficulty,
  }) =>
      Player(
        id: id ?? this.id,
        name: name ?? this.name,
        color: color ?? this.color,
        type: type ?? this.type,
        difficulty: difficulty ?? this.difficulty,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color.index,
        'type': type.index,
        'difficulty': difficulty?.index,
      };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'] as String,
        name: json['name'] as String,
        color: PlayerColor.values[json['color'] as int],
        type: PlayerType.values[json['type'] as int],
        difficulty: json['difficulty'] != null
            ? AIDifficulty.values[json['difficulty'] as int]
            : null,
      );
}
