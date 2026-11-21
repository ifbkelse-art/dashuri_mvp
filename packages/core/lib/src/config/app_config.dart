import 'package:equatable/equatable.dart';

enum AppEnvironment { development, staging, production }

/// Runtime configuration, read once at startup from `--dart-define-from-file`.
///
/// Contains only values that are safe inside a mobile binary. The Supabase
/// service-role key, Play service-account credentials and payout keys must
/// never appear here.
final class AppConfig extends Equatable {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    this.supportEmail = '',
  });

  /// Reads `--dart-define` values. Missing values are empty strings;
  /// [validate] reports them at bootstrap.
  factory AppConfig.fromEnvironment() => AppConfig(
    environment: AppEnvironment.values.byName(
      const String.fromEnvironment('DASHURI_ENV', defaultValue: 'development'),
    ),
    apiBaseUrl: Uri.parse(const String.fromEnvironment('DASHURI_API_BASE_URL')),
    supabaseUrl: Uri.parse(
      const String.fromEnvironment('DASHURI_SUPABASE_URL'),
    ),
    supabasePublishableKey: const String.fromEnvironment(
      'DASHURI_SUPABASE_PUBLISHABLE_KEY',
    ),
    supportEmail: const String.fromEnvironment('DASHURI_SUPPORT_EMAIL'),
  );

  final AppEnvironment environment;

  /// Go API base, e.g. https://api.example.com (versioned paths start with /v1).
  final Uri apiBaseUrl;
  final Uri supabaseUrl;

  /// Supabase publishable (anon) key. Safe for clients; RLS protects data.
  final String supabasePublishableKey;

  /// Support contact shown in Help & support (D-22). Optional; empty when
  /// not configured, in which case the app says so instead of guessing.
  final String supportEmail;

  /// Names of missing required values; empty when the config is usable.
  List<String> validate() => [
    if (apiBaseUrl.toString().isEmpty) 'DASHURI_API_BASE_URL',
    if (supabaseUrl.toString().isEmpty) 'DASHURI_SUPABASE_URL',
    if (supabasePublishableKey.isEmpty) 'DASHURI_SUPABASE_PUBLISHABLE_KEY',
  ];

  @override
  List<Object?> get props => [
    environment,
    apiBaseUrl,
    supabaseUrl,
    supabasePublishableKey,
    supportEmail,
  ];
}
