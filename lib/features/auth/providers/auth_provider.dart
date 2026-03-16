import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:squadsync/core/supabase/supabase_client.dart';
import 'package:squadsync/shared/models/enums.dart';

part 'auth_provider.g.dart';

/// Streams every [AuthState] change from Supabase.
@riverpod
Stream<AuthState> authStateChanges(AuthStateChangesRef ref) {
  return supabase.auth.onAuthStateChange;
}

/// Manages sign-in / sign-up / sign-out / password reset operations.
///
/// State is [AsyncData] when idle/successful, [AsyncLoading] while an
/// operation is in flight, and [AsyncError] when the last operation failed.
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  FutureOr<void> build() {}

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    try {
      await supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Returns `true` if signup produced an immediate session (email
  /// confirmation disabled), `false` if the user must confirm their email.
  Future<bool> signUp(
    String email,
    String password,
    String fullName,
    UserRole role,
  ) async {
    state = const AsyncLoading();
    try {
      final response = await supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'role': role.toJson(),
        },
      );
      state = const AsyncData(null);
      return response.session != null;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    try {
      await supabase.auth.signOut();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    state = const AsyncLoading();
    try {
      await supabase.auth.resetPasswordForEmail(email.trim());
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
