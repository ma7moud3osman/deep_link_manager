/// Abstract interface for authentication checks in deep link handling.
///
/// Implement this to provide typed, secure authentication callbacks
/// to the [DeepLinkManager].
abstract class DeepLinkAuthProvider {
  /// Factory constructor to create an auth provider from callbacks.
  ///
  /// This is useful for simpler use cases where creating a full class
  /// implementation feels verbose.
  factory DeepLinkAuthProvider.fromCallbacks({
    required bool Function() isAuthenticated,
    required void Function(Uri uri) onAuthRequired,
  }) {
    return _CallbackDeepLinkAuthProvider(
      isAuthenticatedCallback: isAuthenticated,
      onAuthRequiredCallback: onAuthRequired,
    );
  }

  /// Returns `true` if the user is currently authenticated.
  bool get isAuthenticated;

  /// Called when a deep link requires authentication but the user is not
  /// authenticated. Use this to redirect to login or show an appropriate UI.
  void onAuthRequired(Uri uri);
}

class _CallbackDeepLinkAuthProvider implements DeepLinkAuthProvider {
  final bool Function() isAuthenticatedCallback;
  final void Function(Uri uri) onAuthRequiredCallback;

  _CallbackDeepLinkAuthProvider({
    required this.isAuthenticatedCallback,
    required this.onAuthRequiredCallback,
  });

  @override
  bool get isAuthenticated => isAuthenticatedCallback();

  @override
  void onAuthRequired(Uri uri) => onAuthRequiredCallback(uri);
}
