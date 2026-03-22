import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralised access to app-level configuration values loaded from .env.
abstract final class AppConfig {
  static String get anthropicApiKey =>
      dotenv.env['ANTHROPIC_API_KEY'] ?? '';
}
