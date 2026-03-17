import 'package:squadsync/shared/models/enums.dart';

abstract final class PermissionHelper {
  static bool canEditRoster(UserRole role) =>
      role == UserRole.clubAdmin || role == UserRole.coach;

  static bool canArchivePlayer(UserRole role) => role == UserRole.clubAdmin;

  static bool canManageGuardians(UserRole role) => role == UserRole.clubAdmin;

  static bool isOwnProfile(String currentUserId, String profileId) =>
      currentUserId == profileId;
}
