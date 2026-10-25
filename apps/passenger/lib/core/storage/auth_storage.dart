import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';

/// Watches whether a valid access token exists in secure storage.
/// Used by the router redirect guard.
final authStateProvider = FutureProvider<bool>((ref) async {
  final token = await readAccessToken();
  return token != null && token.isNotEmpty;
});

/// Notifier that lets screens explicitly sign out.
final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, bool>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final token = await readAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> signOut() async {
    await clearTokens();
    state = const AsyncValue.data(false);
  }

  Future<void> signIn(String accessToken, String refreshToken) async {
    await saveTokens(accessToken, refreshToken);
    state = const AsyncValue.data(true);
  }
}
