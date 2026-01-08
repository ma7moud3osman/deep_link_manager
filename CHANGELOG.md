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
