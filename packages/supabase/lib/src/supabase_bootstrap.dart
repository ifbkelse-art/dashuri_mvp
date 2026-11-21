import 'package:dashuri_core/dashuri_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Initialises Supabase with the PUBLISHABLE key only. The service-role key
/// is a server secret and must never be passed here.
Future<SupabaseClient> initSupabase(AppConfig config) async {
  await Supabase.initialize(
    url: config.supabaseUrl.toString(),
    publishableKey: config.supabasePublishableKey,
  );
  return Supabase.instance.client;
}
