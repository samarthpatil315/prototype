import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_config.dart';

/// Thin, safe wrapper around Supabase.
///
/// The app is fully functional without a backend (offline demo workspace).
/// When `--dart-define=SUPABASE_URL` / `SUPABASE_ANON_KEY` are supplied this
/// service enables real authentication and row-level-security-protected
/// sync. Only the public anon key ever ships in the app — the service-role
/// key and AI secrets live in Edge Function secrets (see supabase/).
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  bool _initialised = false;
  bool get isReady => AppConfig.supabaseConfigured && _initialised;

  SupabaseClient get client => Supabase.instance.client;
  User? get currentUser => isReady ? client.auth.currentUser : null;
  bool get isSignedIn => currentUser != null;

  Future<void> init() async {
    if (!AppConfig.supabaseConfigured || _initialised) return;
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
    _initialised = true;
  }

  /// Returns null on success or a user-safe error message.
  Future<String?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    if (!isReady) return 'Backend is not configured. Continue in demo mode.';
    try {
      final res = await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': name.trim()},
      );
      if (res.user == null) return 'Registration failed. Please try again.';
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Network error. Check your connection and try again.';
    }
  }

  Future<String?> signIn({required String email, required String password}) async {
    if (!isReady) return 'Backend is not configured. Continue in demo mode.';
    try {
      await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Network error. Check your connection and try again.';
    }
  }

  Future<String?> resetPassword(String email) async {
    if (!isReady) return 'Backend is not configured. Continue in demo mode.';
    try {
      await client.auth.resetPasswordForEmail(email.trim());
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Network error. Check your connection and try again.';
    }
  }

  Future<void> signOut() async {
    if (isReady) {
      try {
        await client.auth.signOut();
      } catch (_) {}
    }
  }

  Future<String?> deleteAccount() async {
    if (!isReady) return null; // demo mode: handled locally
    try {
      // Implemented by the `delete-account` Edge Function pattern: the user
      // deletes their own profile row (RLS) and the account is disabled.
      // Full auth-user deletion must run server-side with the service role.
      final uid = currentUser?.id;
      if (uid != null) {
        await client.from('profiles').delete().eq('id', uid);
      }
      await signOut();
      return null;
    } catch (_) {
      return 'Could not delete the account. Please try again.';
    }
  }

  /// Upserts one record into a normalised table. RLS policies in
  /// supabase/migrations guarantee users can only write their own rows.
  Future<bool> upsertRecord(String table, Map<String, dynamic> row) async {
    if (!isReady || !isSignedIn) return false;
    try {
      await client.from(table).upsert(row);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchCollection(String table) async {
    if (!isReady || !isSignedIn) return [];
    try {
      final rows = await client.from(table).select();
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Calls the AI Edge Function. The provider API key never leaves the
  /// server; the client only sends the prompt with the user's JWT.
  Future<String?> invokeAiAssistant(String prompt) async {
    if (!isReady || !isSignedIn) return null;
    try {
      final res = await client.functions.invoke(
        'ai_assistant',
        body: {'prompt': prompt},
      );
      final data = res.data;
      if (data is Map && data['text'] != null) return data['text'].toString();
      return null;
    } catch (_) {
      return null;
    }
  }
}
