import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:squadsync/core/supabase/supabase_client.dart';
import 'package:squadsync/features/fill_in/data/fill_in_repository.dart';
import 'package:squadsync/shared/models/club.dart';
import 'package:squadsync/shared/models/fill_in_request.dart';
import 'package:squadsync/shared/models/fill_in_rule.dart';
import 'package:squadsync/shared/models/profile.dart';

part 'fill_in_providers.g.dart';

@riverpod
FillInRepository fillInRepository(FillInRepositoryRef ref) {
  return const FillInRepository();
}

@riverpod
Future<Club?> club(ClubRef ref, String clubId) async {
  final data = await supabase
      .from('clubs')
      .select()
      .eq('id', clubId)
      .maybeSingle();
  if (data == null) return null;
  return Club.fromJson(data);
}

@riverpod
class FillInModeNotifier extends _$FillInModeNotifier {
  @override
  FutureOr<void> build() {}

  Future<void> setMode({
    required String clubId,
    required String mode,
  }) async {
    state = const AsyncLoading();
    try {
      await ref.read(fillInRepositoryProvider).updateFillInMode(
            clubId: clubId,
            mode: mode,
          );
      ref.invalidate(clubProvider(clubId));
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

@riverpod
Future<List<FillInRule>> fillInRules(
  FillInRulesRef ref,
  String clubId,
) async {
  return ref.watch(fillInRepositoryProvider).getRules(clubId);
}

@riverpod
Future<List<Profile>> eligiblePlayers(
  EligiblePlayersRef ref, {
  required String clubId,
  required String targetDivisionId,
  required String eventId,
}) async {
  return ref.watch(fillInRepositoryProvider).getEligiblePlayers(
        clubId: clubId,
        targetDivisionId: targetDivisionId,
        eventId: eventId,
      );
}

@riverpod
Future<List<FillInRequest>> pendingFillInRequests(
  PendingFillInRequestsRef ref,
  String playerId,
) async {
  return ref.watch(fillInRepositoryProvider).getPendingRequestsForPlayer(
        playerId,
      );
}

@riverpod
Future<FillInRequest?> fillInRequestById(
  FillInRequestByIdRef ref,
  String requestId,
) async {
  return ref.watch(fillInRepositoryProvider).getRequestById(requestId);
}
