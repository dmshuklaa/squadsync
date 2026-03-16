import 'package:flutter/material.dart';

/// App-wide colour constants.
abstract final class AppColors {
  static const Color primary = Color(0xFF1E3A5F); // dark navy
  static const Color secondary = Color(0xFF2E75B6); // blue
}

/// Provides static [lightTheme] and [darkTheme] for the app.
abstract final class AppTheme {
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          brightness: Brightness.light,
        ),
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          brightness: Brightness.dark,
        ),
      );
}
