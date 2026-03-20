import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps Supabase [AuthException] messages to user-friendly strings.
abstract final class AuthErrorMapper {
  static String map(Object error) {
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid login credentials') ||
          msg.contains('invalid credentials')) {
        return 'Email or password is incorrect';
      }
      if (msg.contains('email not confirmed')) {
        return 'Please check your email and confirm your account';
      }
      if (msg.contains('user already registered') ||
          msg.contains('already been registered')) {
        return 'An account with this email already exists';
      }
      if (msg.contains('password should be at least')) {
        return 'Password must be at least 6 characters';
      }
      if (msg.contains('database error')) {
        return 'Account setup failed — please ensure the database migration has been applied in Supabase.';
      }
      return error.message;
    }
    return 'Something went wrong. Please try again.';
  }
}
