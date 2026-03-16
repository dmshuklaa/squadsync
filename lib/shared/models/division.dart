class Division {
  const Division({
    required this.id,
    required this.clubId,
    required this.name,
    required this.displayOrder,
    required this.fillInEnabled,
    required this.createdAt,
  });

  final String id;
  final String clubId;
  final String name;
  final int displayOrder;
  final bool fillInEnabled;
  final DateTime createdAt;

  factory Division.fromJson(Map<String, dynamic> json) {
    return Division(
      id: json['id'] as String,
      clubId: json['club_id'] as String,
      name: json['name'] as String,
      displayOrder: json['display_order'] as int,
      fillInEnabled: json['fill_in_enabled'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'club_id': clubId,
      'name': name,
      'display_order': displayOrder,
      'fill_in_enabled': fillInEnabled,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Division copyWith({
    String? id,
    String? clubId,
    String? name,
    int? displayOrder,
    bool? fillInEnabled,
    DateTime? createdAt,
  }) {
    return Division(
      id: id ?? this.id,
      clubId: clubId ?? this.clubId,
      name: name ?? this.name,
      displayOrder: displayOrder ?? this.displayOrder,
      fillInEnabled: fillInEnabled ?? this.fillInEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
