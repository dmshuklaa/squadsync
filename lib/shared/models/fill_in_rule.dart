class FillInRule {
  const FillInRule({
    required this.id,
    required this.clubId,
    required this.sourceDivisionId,
    required this.targetDivisionId,
    this.minAge,
    required this.enabled,
    required this.createdAt,
    this.sourceDivisionName,
    this.targetDivisionName,
  });

  final String id;
  final String clubId;
  final String sourceDivisionId;
  final String targetDivisionId;
  final int? minAge;
  final bool enabled;
  final DateTime createdAt;
  final String? sourceDivisionName;
  final String? targetDivisionName;

  factory FillInRule.fromJson(Map<String, dynamic> json) {
    final src = json['source_divisions'] as Map<String, dynamic>?;
    final tgt = json['target_divisions'] as Map<String, dynamic>?;
    return FillInRule(
      id: json['id'] as String,
      clubId: json['club_id'] as String,
      sourceDivisionId: json['source_division_id'] as String,
      targetDivisionId: json['target_division_id'] as String,
      minAge: json['min_age'] as int?,
      enabled: json['enabled'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      sourceDivisionName: src?['name'] as String?,
      targetDivisionName: tgt?['name'] as String?,
    );
  }

  FillInRule copyWith({
    String? id,
    String? clubId,
    String? sourceDivisionId,
    String? targetDivisionId,
    int? minAge,
    bool? enabled,
    DateTime? createdAt,
    String? sourceDivisionName,
    String? targetDivisionName,
  }) =>
      FillInRule(
        id: id ?? this.id,
        clubId: clubId ?? this.clubId,
        sourceDivisionId: sourceDivisionId ?? this.sourceDivisionId,
        targetDivisionId: targetDivisionId ?? this.targetDivisionId,
        minAge: minAge ?? this.minAge,
        enabled: enabled ?? this.enabled,
        createdAt: createdAt ?? this.createdAt,
        sourceDivisionName: sourceDivisionName ?? this.sourceDivisionName,
        targetDivisionName: targetDivisionName ?? this.targetDivisionName,
      );
}
