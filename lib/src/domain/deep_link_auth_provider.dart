import 'package:flutter/foundation.dart';

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
    Listenable? authStateChanges,
  }) {
    return _CallbackDeepLinkAuthProvider(
      isAuthenticatedCallback: isAuthenticated,
      onAuthRequiredCallback: onAuthRequired,
      authStateListener: authStateChanges,
    );
  }

  /// Returns `true` if the user is currently authenticated.
  bool get isAuthenticated;

  /// Optional [Listenable] that notifies when authentication state changes.
  /// When notified, the [DeepLinkManager] will re-check [isAuthenticated]
  /// and process pending links if authenticated.
  ///
  /// This can be a [ChangeNotifier], [ValueNotifier], or any [Listenable].
  Listenable? get authStateChanges => null;

  /// Called when a deep link requires authentication but the user is not
  /// authenticated. Use this to redirect to login or show an appropriate UI.
  void onAuthRequired(Uri uri);
}

class _CallbackDeepLinkAuthProvider implements DeepLinkAuthProvider {
  final bool Function() isAuthenticatedCallback;
  final void Function(Uri uri) onAuthRequiredCallback;
  final Listenable? authStateListener;

  _CallbackDeepLinkAuthProvider({
    required this.isAuthenticatedCallback,
    required this.onAuthRequiredCallback,
    this.authStateListener,
  });

  @override
  bool get isAuthenticated => isAuthenticatedCallback();

  @override
  Listenable? get authStateChanges => authStateListener;

  @override
  void onAuthRequired(Uri uri) => onAuthRequiredCallback(uri);
}
