/// Abstract interface for authentication checks in deep link handling.
///
/// Implement this to provide typed, secure authentication callbacks
/// to the [DeepLinkManager].
abstract class DeepLinkAuthProvider {
  /// Returns `true` if the user is currently authenticated.
  bool get isAuthenticated;

  /// Called when a deep link requires authentication but the user is not
  /// authenticated. Use this to redirect to login or show an appropriate UI.
  void onAuthRequired(Uri uri);
}
