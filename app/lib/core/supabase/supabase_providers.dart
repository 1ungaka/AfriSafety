import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The initialised Supabase client, injected in `bootstrap.dart`.
final supabaseProvider = Provider<SupabaseClient>(
  (ref) => throw UnimplementedError('supabaseProvider must be overridden'),
);
