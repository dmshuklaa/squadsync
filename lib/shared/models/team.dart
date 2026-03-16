class Team {
  const Team({
    required this.id,
    required this.divisionId,
    required this.name,
    this.season,
    required this.createdAt,
    // Joined from divisions — only present when fetched with a divisions join
    this.divisionName,
  });

  final String id;
  final String divisionId;
  final String name;
  final String? season;
  final DateTime createdAt;

  // Joined division field
  final String? divisionName;

  factory Team.fromJson(Map<String, dynamic> json) {
    final divisions = json['divisions'] as Map<String, dynamic>?;
    return Team(
      id: json['id'] as String,
      divisionId: json['division_id'] as String,
      name: json['name'] as String,
      season: json['season'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      divisionName: divisions?['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'division_id': divisionId,
      'name': name,
      'season': season,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Team copyWith({
    String? id,
    String? divisionId,
    String? name,
    String? season,
    DateTime? createdAt,
    String? divisionName,
  }) {
    return Team(
      id: id ?? this.id,
      divisionId: divisionId ?? this.divisionId,
      name: name ?? this.name,
      season: season ?? this.season,
      createdAt: createdAt ?? this.createdAt,
      divisionName: divisionName ?? this.divisionName,
    );
  }
}
