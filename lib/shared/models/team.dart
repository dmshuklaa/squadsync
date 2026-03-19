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
    return Team(
      id: json['id'] as String,
      divisionId: json['division_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown Team',
      season: json['season'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      divisionName:
          (json['divisions'] as Map<String, dynamic>?)?['name'] as String?,
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
