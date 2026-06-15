import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moerderspiel/data/models/profile.dart';

class AuthRepository {
  final _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  String? get currentUserId => currentUser?.id;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );
    final uid = response.user?.id;
    if (uid == null) throw Exception('Registrierung fehlgeschlagen');

    // Trigger erstellt das Profil automatisch; Fallback falls nicht
    await _client.from('profiles').upsert({
      'id': uid,
      'username': username,
    });
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<Profile?> getProfile(String userId) async {
    final data = await _client.from('profiles').select().eq('id', userId).maybeSingle();
    return data != null ? Profile.fromJson(data) : null;
  }

  Future<void> updateUsername(String userId, String username) async {
    await _client.from('profiles').update({'username': username}).eq('id', userId);
  }

  Future<String?> uploadAvatar(String userId, XFile file) async {
    final bytes = await file.readAsBytes();
    final ext = file.name.split('.').last;
    final path = '$userId/avatar.$ext';
    await _client.storage.from('avatars').uploadBinary(
      path, bytes, fileOptions: const FileOptions(upsert: true),
    );
    final baseUrl = _client.storage.from('avatars').getPublicUrl(path);
    final url = '$baseUrl?t=${DateTime.now().millisecondsSinceEpoch}';
    await _client.from('profiles').update({'avatar_url': url}).eq('id', userId);
    return url;
  }

  Future<bool> isUsernameAvailable(String username) async {
    final data = await _client.from('profiles').select('id').eq('username', username).maybeSingle();
    return data == null;
  }
}
