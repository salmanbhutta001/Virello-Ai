import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

/// Holds the JWT session. Tokens persist on-device; the API client reads them
/// automatically. Sign-in is email OTP, email + password (backend
/// bcrypt-hashed), or Google/Apple OAuth — we never ask for social-media
/// passwords, ever.
class AuthStore extends ChangeNotifier {
  static const _kAccess = 'virello_access_token';
  static const _kRefresh = 'virello_refresh_token';
  static const _kEmail = 'virello_email';

  String? _accessToken;
  String? _refreshToken;
  String? email;

  /// Display name from /users/me (kept in sync after profile edits).
  String? name;
  bool loaded = false;

  /// One-shot notice shown on the sign-in screen (e.g. "session expired").
  String? lastNotice;

  bool get signedIn => _accessToken != null && _accessToken!.isNotEmpty;
  String? get accessToken => _accessToken;

  Future<bool>? _refreshInFlight;

  /// Silently renews the token pair using the stored refresh token.
  /// Concurrent callers share one in-flight request (no refresh storms).
  /// Returns true when the session was renewed; false means the session is
  /// truly dead and the UI should route to sign-in.
  Future<bool> refreshTokens() {
    return _refreshInFlight ??= _doRefresh().whenComplete(
      () => _refreshInFlight = null,
    );
  }

  Future<bool> _doRefresh() async {
    final rt = _refreshToken;
    if (rt == null || rt.isEmpty) return false;
    try {
      final tokens = await ApiClient().refresh(rt);
      final access = tokens['access_token'] as String?;
      if (access == null || access.isEmpty) return false;
      await _persistTokens(tokens, email);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString(_kAccess);
      _refreshToken = prefs.getString(_kRefresh);
      email = prefs.getString(_kEmail);
    } catch (_) {}
    loaded = true;
    notifyListeners();
  }

  Future<void> requestOtp(String email) async {
    await ApiClient().requestOtp(email.trim());
  }

  Future<void> verifyOtp(String email, String code) async {
    final tokens = await ApiClient().verifyOtp(email.trim(), code.trim());
    await _persistTokens(tokens, email.trim());
  }

  /// Google / Apple sign-in: the native SDK hands us a provider id_token,
  /// the backend verifies it and returns the Virello JWT pair.
  Future<void> signInWithProvider(
      String provider, String idToken, String? email) async {
    final tokens = await ApiClient().oauthCallback(provider, idToken);
    await _persistTokens(tokens, email);
  }

  Future<void> _persistTokens(
      Map<String, dynamic> tokens, String? email) async {
    _accessToken = tokens['access_token'] as String?;
    _refreshToken = tokens['refresh_token'] as String?;
    this.email = email;
    final prefs = await SharedPreferences.getInstance();
    if (_accessToken != null) await prefs.setString(_kAccess, _accessToken!);
    if (_refreshToken != null) await prefs.setString(_kRefresh, _refreshToken!);
    if (this.email != null) await prefs.setString(_kEmail, this.email!);
    notifyListeners();
  }

  /// Email + password sign-up. Backend returns the JWT pair (signed in).
  Future<void> signUpWithPassword(
      String email, String password, String? name) async {
    final tokens = await ApiClient()
        .passwordSignup(email.trim(), password, name?.trim().isEmpty ?? true ? null : name?.trim());
    await _persistTokens(tokens, email.trim());
  }

  /// Email + password sign-in.
  Future<void> signInWithPassword(String email, String password) async {
    final tokens =
        await ApiClient().passwordLogin(email.trim(), password);
    await _persistTokens(tokens, email.trim());
  }

  /// Step 1 of "Forgot password": email an OTP code proving ownership.
  Future<void> requestPasswordReset(String email) async {
    await ApiClient().passwordResetRequest(email.trim());
  }

  /// Step 2: verify the code + set the new password (signs the user in).
  Future<void> confirmPasswordReset(
      String email, String code, String newPassword) async {
    final tokens = await ApiClient()
        .passwordResetConfirm(email.trim(), code.trim(), newPassword);
    await _persistTokens(tokens, email.trim());
  }

  /// Signed-in password change (verifies the current password server-side).
  Future<void> changePassword(String currentPassword, String newPassword) async {
    await ApiClient(tokenProvider: () => _accessToken)
        .passwordChange(currentPassword, newPassword);
  }

  /// Refresh cached profile fields after a /users/me update (e.g. name edit).
  void refreshProfile(Map<String, dynamic> me) {
    name = me['name'] as String?;
    notifyListeners();
  }

  Future<void> signOut() async {
    _accessToken = null;
    _refreshToken = null;
    email = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAccess);
      await prefs.remove(_kRefresh);
      await prefs.remove(_kEmail);
    } catch (_) {}
    notifyListeners();
  }
}
