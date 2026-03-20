// Dart equivalents of the Postgres enums defined in the migrations.

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

enum EventType {
  game,
  training;

  static EventType fromString(String value) {
    switch (value) {
      case 'game':
        return EventType.game;
      case 'training':
        return EventType.training;
      default:
        throw ArgumentError('Unknown EventType: $value');
    }
  }

  String toJson() {
    switch (this) {
      case EventType.game:
        return 'game';
      case EventType.training:
        return 'training';
    }
  }

  String get label {
    switch (this) {
      case EventType.game:
        return 'Game';
      case EventType.training:
        return 'Training';
    }
  }
}

enum EventStatus {
  scheduled,
  cancelled,
  completed;

  static EventStatus fromString(String value) {
    switch (value) {
      case 'scheduled':
        return EventStatus.scheduled;
      case 'cancelled':
        return EventStatus.cancelled;
      case 'completed':
        return EventStatus.completed;
      default:
        throw ArgumentError('Unknown EventStatus: $value');
    }
  }

  String toJson() {
    switch (this) {
      case EventStatus.scheduled:
        return 'scheduled';
      case EventStatus.cancelled:
        return 'cancelled';
      case EventStatus.completed:
        return 'completed';
    }
  }
}

enum RsvpStatus {
  going,
  notGoing,
  maybe;

  static RsvpStatus fromString(String value) {
    switch (value) {
      case 'going':
        return RsvpStatus.going;
      case 'not_going':
        return RsvpStatus.notGoing;
      case 'maybe':
        return RsvpStatus.maybe;
      default:
        throw ArgumentError('Unknown RsvpStatus: $value');
    }
  }

  String toJson() {
    switch (this) {
      case RsvpStatus.going:
        return 'going';
      case RsvpStatus.notGoing:
        return 'not_going';
      case RsvpStatus.maybe:
        return 'maybe';
    }
  }
}

enum NotificationType {
  fillInRequest,
  fillInAccepted,
  fillInDeclined,
  guardianRequest,
  guardianAccepted,
  eventReminder,
  general;

  static NotificationType fromString(String value) {
    switch (value) {
      case 'fill_in_request':
        return NotificationType.fillInRequest;
      case 'fill_in_accepted':
        return NotificationType.fillInAccepted;
      case 'fill_in_declined':
        return NotificationType.fillInDeclined;
      case 'guardian_request':
        return NotificationType.guardianRequest;
      case 'guardian_accepted':
        return NotificationType.guardianAccepted;
      case 'event_reminder':
        return NotificationType.eventReminder;
      case 'general':
        return NotificationType.general;
      default:
        return NotificationType.general;
    }
  }

  String toJson() {
    switch (this) {
      case NotificationType.fillInRequest:
        return 'fill_in_request';
      case NotificationType.fillInAccepted:
        return 'fill_in_accepted';
      case NotificationType.fillInDeclined:
        return 'fill_in_declined';
      case NotificationType.guardianRequest:
        return 'guardian_request';
      case NotificationType.guardianAccepted:
        return 'guardian_accepted';
      case NotificationType.eventReminder:
        return 'event_reminder';
      case NotificationType.general:
        return 'general';
    }
  }
}

enum FillInRequestStatus {
  pending,
  accepted,
  declined,
  expired,
  cancelled;

  static FillInRequestStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return FillInRequestStatus.pending;
      case 'accepted':
        return FillInRequestStatus.accepted;
      case 'declined':
        return FillInRequestStatus.declined;
      case 'expired':
        return FillInRequestStatus.expired;
      case 'cancelled':
        return FillInRequestStatus.cancelled;
      default:
        throw ArgumentError('Unknown FillInRequestStatus: $value');
    }
  }

  String toJson() {
    switch (this) {
      case FillInRequestStatus.pending:
        return 'pending';
      case FillInRequestStatus.accepted:
        return 'accepted';
      case FillInRequestStatus.declined:
        return 'declined';
      case FillInRequestStatus.expired:
        return 'expired';
      case FillInRequestStatus.cancelled:
        return 'cancelled';
    }
  }
}
