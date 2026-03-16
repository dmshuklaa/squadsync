import 'package:supabase_flutter/supabase_flutter.dart';

/// Global Supabase client accessor.
/// Always use this instead of Supabase.instance.client directly.
SupabaseClient get supabase => Supabase.instance.client;
