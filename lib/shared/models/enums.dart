// Dart equivalents of the Postgres enums defined in 001_core_schema.sql.

enum UserRole {
  clubAdmin,
  coach,
  player,
  parent;

  static UserRole fromString(String value) {
    switch (value) {
      case 'club_admin':
        return UserRole.clubAdmin;
      case 'coach':
        return UserRole.coach;
      case 'player':
        return UserRole.player;
      case 'parent':
        return UserRole.parent;
      default:
        throw ArgumentError('Unknown UserRole: $value');
    }
  }

  String toJson() {
    switch (this) {
      case UserRole.clubAdmin:
        return 'club_admin';
      case UserRole.coach:
        return 'coach';
      case UserRole.player:
        return 'player';
      case UserRole.parent:
        return 'parent';
    }
  }
}

enum MembershipStatus {
  active,
  inactive,
  archived,
  pending;

  static MembershipStatus fromString(String value) {
    switch (value) {
      case 'active':
        return MembershipStatus.active;
      case 'inactive':
        return MembershipStatus.inactive;
      case 'archived':
        return MembershipStatus.archived;
      case 'pending':
        return MembershipStatus.pending;
      default:
        throw ArgumentError('Unknown MembershipStatus: $value');
    }
  }

  String toJson() {
    switch (this) {
      case MembershipStatus.active:
        return 'active';
      case MembershipStatus.inactive:
        return 'inactive';
      case MembershipStatus.archived:
        return 'archived';
      case MembershipStatus.pending:
        return 'pending';
    }
  }
}

enum GuardianPermission {
  view,
  manage;

  static GuardianPermission fromString(String value) {
    switch (value) {
      case 'view':
        return GuardianPermission.view;
      case 'manage':
        return GuardianPermission.manage;
      default:
        throw ArgumentError('Unknown GuardianPermission: $value');
    }
  }

  String toJson() {
    switch (this) {
      case GuardianPermission.view:
        return 'view';
      case GuardianPermission.manage:
        return 'manage';
    }
  }
}
