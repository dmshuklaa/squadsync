import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:squadsync/features/roster/providers/player_profile_provider.dart';
import 'package:squadsync/features/roster/providers/roster_providers.dart';
import 'package:squadsync/shared/models/enums.dart';
import 'package:squadsync/shared/models/guardian_link.dart';

part 'guardian_provider.g.dart';

// ── Pending requests for the current guardian user ───────────

@riverpod
Future<List<GuardianLink>> pendingGuardianRequests(
  PendingGuardianRequestsRef ref,
) async {
  final repo = ref.watch(rosterRepositoryProvider);
  return repo.getPendingGuardianRequests();
}

// ── Mutation notifier ─────────────────────────────────────────

@riverpod
class GuardianNotifier extends _$GuardianNotifier {
  @override
  FutureOr<void> build() {}

  /// Sends a guardian link request from a coach/admin to link [guardianProfileId]
  /// to [playerProfileId] with the given [permission].
  Future<void> sendLinkRequest({
    required String playerProfileId,
    required String guardianProfileId,
    required GuardianPermission permission,
  }) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(rosterRepositoryProvider);
      await repo.createGuardianLinkRequest(
        playerProfileId: playerProfileId,
        guardianProfileId: guardianProfileId,
        permissionLevel: permission,
      );
      ref.invalidate(guardianLinksProvider(playerProfileId));
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Confirms a pending guardian link (guardian accepts the request).
  Future<void> confirmLink(String linkId, String playerProfileId) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(rosterRepositoryProvider);
      await repo.confirmGuardianLink(linkId);
      ref.invalidate(guardianLinksProvider(playerProfileId));
      ref.invalidate(pendingGuardianRequestsProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Declines and removes a pending guardian link (guardian declines).
  Future<void> declineLink(String linkId, String playerProfileId) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(rosterRepositoryProvider);
      await repo.declineGuardianLink(linkId);
      ref.invalidate(guardianLinksProvider(playerProfileId));
      ref.invalidate(pendingGuardianRequestsProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Removes a guardian link (admin or guardian).
  Future<void> removeLink(String linkId, String playerProfileId) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(rosterRepositoryProvider);
      await repo.removeGuardianLink(linkId);
      ref.invalidate(guardianLinksProvider(playerProfileId));
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
