## 0.4.0

*   **BREAKING CHANGE**: Changed `DeepLinkAuthProvider.authStateChanges` from `Stream<bool>?` to `Listenable?` for better Flutter integration.
    *   **Migration**: Instead of passing a `Stream`, pass a `ChangeNotifier`, `ValueNotifier`, or any `Listenable`.
    *   **Before**: `authProvider: SimpleAuthProvider(navigatorKey, authNotifier.authStateStream)`
    *   **After**: `authProvider: SimpleAuthProvider(navigatorKey, authNotifier)`
*   **BREAKING CHANGE**: Removed `StreamController` requirement from example - now uses `ChangeNotifier` directly.
*   **Improvement**: Added `autoSetAppReady` parameter (default: `true`) - automatically marks app as ready on first frame.
    *   Set to `false` if you need to wait for splash screen/config before processing deep links.
    *   No more manual `setAppReady()` calls in most cases!
*   **Improvement**: Pending links are now **automatically cleared on logout** (when `authStateChanges` emits and `isAuthenticated` becomes `false`). No need to manually call `clearPendingLink()` anymore!
*   **Improvement**: Simplified API - no need to manually emit events or close controllers.
*   **Improvement**: Better compatibility with all Flutter state management solutions (Provider, Riverpod, Bloc, etc.).
*   **Fix**: Eliminated potential memory leaks from unclosed `StreamController` instances.

## 0.3.0

*   **Feat**: Added `pendingLinkExpiration` parameter to `initialize()` to configure how long pending links are kept (default: 5 minutes).
*   **Feat**: Added `authStateChanges` stream to `DeepLinkAuthProvider` to allow `DeepLinkManager` to automatically process pending links when authentication state changes.
*   **Fix**: Added error handling (`onError`) to auth state stream subscription to prevent silent failures.
*   **Fix**: Added initial authentication check after subscription setup to handle race conditions when user is already authenticated during initialization.
*   **Fix**: Added `dispose()` method to example `AuthNotifier` to properly close `StreamController` and prevent memory leaks.
*   **Refactor**: Updated `example` project to demonstrate reactive authentication handling using `AuthNotifier` stream.
*   **Test**: Added comprehensive test for reactive auth stream triggering pending link checks.

## 0.2.0

*   **BREAKING CHANGE**: Refactored `DeepLinkStrategy` to be generic `DeepLinkStrategy<T>`.
    *   `extractData` now returns `T?`.
    *   `handle` now receives `T? data`.
    *   This improves type safety for extracted data.
*   Updated `DeepLinkManager` to support heterogeneous generic strategies.
*   Example app updated to demonstrate Generic Strategies and Reactive Auth flow.

## 0.1.4

*   Added `checkPendingLinks()` method to manually trigger pending link processing (e.g., after login).
*   Added support for injecting a custom `navigatorKey` in `initialize`.
*   Added warning log when `requiresAuth` is true but no `authProvider` is set.
*   Added `DeepLinkAuthProvider.fromCallbacks` for simpler auth integration (from 0.1.3).

## 0.1.2

*   Updated documentation to credit `app_links` package.

## 0.1.1

*   Added example project.
*   Updated README integration guide.

## 0.1.0

*   Initial release of `deep_link_manager`.
*   Includes `DeepLinkManager`, `DeepLinkStrategy`, and `DeepLinkAuthProvider` for generic deep link handling.
