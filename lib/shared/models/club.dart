class Club {
  const Club({
    required this.id,
    required this.name,
    required this.sportType,
    required this.joinCode,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String sportType;
  final String joinCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Club.fromJson(Map<String, dynamic> json) {
    return Club(
      id: json['id'] as String,
      name: json['name'] as String,
      sportType: json['sport_type'] as String,
      joinCode: json['join_code'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sport_type': sportType,
      'join_code': joinCode,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Club copyWith({
    String? id,
    String? name,
    String? sportType,
    String? joinCode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Club(
      id: id ?? this.id,
      name: name ?? this.name,
      sportType: sportType ?? this.sportType,
      joinCode: joinCode ?? this.joinCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

