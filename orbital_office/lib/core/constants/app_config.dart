/// Runtime configuration supplied via --dart-define.
///
/// No credentials are hardcoded. When [supabaseConfigured] is false the app
/// runs entirely in the clearly-labelled offline demo workspace.
class AppConfig {
  const AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get supabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static const String appName = 'ORBITAL OFFICE';
  static const String parentBrand = 'ORBITAL.STUDIO.3';
  static const String tagline = 'Work Smarter. Create Better.';
  static const String instagram = '@orbital.studio.3';
  static const String defaultCurrencyCode = 'INR';
}
