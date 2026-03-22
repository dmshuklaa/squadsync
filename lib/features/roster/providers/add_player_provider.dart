import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:squadsync/features/roster/data/csv_mapper.dart';
import 'package:squadsync/features/roster/data/roster_repository.dart';
import 'package:squadsync/features/roster/providers/roster_providers.dart';

part 'add_player_provider.g.dart';

@riverpod
class AddPlayerNotifier extends _$AddPlayerNotifier {
  @override
  FutureOr<void> build() {}

  RosterRepository get _repo => ref.read(rosterRepositoryProvider);

  Future<void> addManually({
    required String teamId,
    required String fullName,
    String? email,
    String? phone,
    String? position,
    int? jerseyNumber,
  }) async {
    state = const AsyncLoading();
    try {
      final profile = await ref.read(currentProfileProvider.future);
      final clubId = profile.clubId ?? '';
      await _repo.addPlayerManually(
        teamId: teamId,
        clubId: clubId,
        fullName: fullName,
        email: email,
        phone: phone,
        position: position,
        jerseyNumber: jerseyNumber,
      );
      ref.invalidate(teamRosterProvider(teamId));
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> sendInvite({
    required String teamId,
    required String email,
    String? fullName,
  }) async {
    state = const AsyncLoading();
    try {
      await _repo.sendInvite(
        teamId: teamId,
        email: email,
        fullName: fullName,
      );
      ref.invalidate(teamRosterProvider(teamId));
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Imports [players] into [teamId] and returns the [ImportResult].
  Future<ImportResult> importPlayers({
    required String teamId,
    required List<PlayerImportRow> players,
    void Function(int current, int total)? onProgress,
  }) async {
    state = const AsyncLoading();
    try {
      final profile = await ref.read(currentProfileProvider.future);
      final clubId = profile.clubId ?? '';
      final result = await _repo.importPlayers(
        teamId: teamId,
        clubId: clubId,
        players: players,
        onProgress: onProgress,
      );
      ref.invalidate(teamRosterProvider(teamId));
      state = const AsyncData(null);
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
