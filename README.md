# Deep Link Feature Documentation

## Overview
The Deep Link feature provides a robust, generic architecture for handling deep links (Universal Links, App Links, Custom Schemes) in Flutter applications. It decouples the deep link handling logic from the main app flow and provides centralized management for authentication requirements.

This package is built on top of the excellent [app_links](https://pub.dev/packages/app_links) package, providing a higher-level abstraction for strategy-based link handling and authentication guards.

## Core Components
1.  **DeepLinkManager**: A singleton that listens for incoming links (initial & stream), manages application readiness state (`isAppReady`), handles queued links with expiration, and guards against race conditions.
2.  **DeepLinkStrategy**: An abstract class that you implement to define how to handle specific types of links. Includes priority ordering and unique identifiers.
3.  **DeepLinkAuthProvider**: A typed interface for secure authentication checks.

---

## 📱 App Configuration

To enable your app to "catch" these links, you must configure the iOS and Android projects.

### 1. iOS Configuration
**File:** `ios/Runner/Info.plist`

Add/Merge the `CFBundleURLTypes` for custom schemes:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLName</key>
    <string><package_name></string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string><scheme></string>
    </array>
  </dict>
</array>
```
*   **`<package_name>`**: Example: `com.example.micropet`
*   **`<scheme>`**: Example: `micropet`

**Universal Links (Entitlements):**
1.  Open `ios/Runner.xcworkspace` in Xcode.
2.  Go to **Signing & Capabilities**.
3.  Add **Associated Domains**.
4.  Add your domain with the `applinks:` prefix: `applinks:<host>`.

> **Note (Flutter 3.24+):** You **MUST** add the following to `Info.plist` to disable Flutter's default deep link handling:
> ```xml
> <key>FlutterDeepLinkingEnabled</key>
> <false/>
> ```

### 2. Android Configuration
**File:** `android/app/src/main/AndroidManifest.xml`

Add `intent-filter` entries inside the main `<activity>`:

```xml
<!-- Custom Scheme (<scheme>://) -->
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="<scheme>" android:host="<host>" />
</intent-filter>

<!-- App Links (https://...) -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https" android:host="<host>" />
</intent-filter>

<meta-data android:name="flutter_deeplinking_enabled" android:value="false" />
```
*   **`<scheme>`**: Example: `micropet`
*   **`<host>`**: Example: `micropet-web.vercel.app`

> **Note (Flutter 3.24+):** You **MUST** add the `flutter_deeplinking_enabled` metadata with value `false` to disable Flutter's default deep link handling, which conflicts with this package.

### 3. Android 13+ Debugging
On Android 13 and newer, App Links may not be automatically enabled in **debug builds**.
*   Go to **App Info** (Long press app icon > App Info).
*   Select **Open by default**.
*   Tap **Add link** and select your supported specific links.

---

## 🧪 Testing

### Android (ADB)
You can test deep links without a web page using ADB:

```bash
# Custom Scheme
adb shell am start -a android.intent.action.VIEW \
  -d "micropet://product/123"

# App Link
adb shell am start -a android.intent.action.VIEW \
  -d "https://micropet-web.vercel.app/product/123"
```

### iOS (Simulator)
You can test on the iOS simulator using `xcrun`:

```bash
# Custom Scheme
xcrun simctl openurl booted "micropet://product/123"

# Universal Link
xcrun simctl openurl booted "https://micropet-web.vercel.app/product/123"
```

---

## 🚀 Quick Setup Guide

### 1. Installation
Add `deep_link_manager` to your `pubspec.yaml`:
```yaml
dependencies:
  deep_link_manager: ^0.4.0
```

> **Note**: `app_links` is automatically included as a dependency - no need to add it manually!

### 2. Create a Strategy
Implement `DeepLinkStrategy` to define your custom handling logic.

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:deep_link_manager/deep_link_manager.dart';

class MyDeepLinkStrategy implements DeepLinkStrategy<String> {
  @override
  String get identifier => 'MyDeepLinkStrategy';

  @override
  int get priority => 10; // Higher = processed first

  @override
  bool canHandle(Uri uri) {
    return uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'product';
  }

  @override
  String? extractData(Uri uri) {
    if (uri.pathSegments.length > 1) return uri.pathSegments[1];
    return null;
  }

  @override
  bool get requiresAuth => true;

  @override
  void handle(Uri uri, BuildContext context, String? data) {
    if (data == null || data.isEmpty) return;
    GoRouter.of(context).push('/product/$data');
  }
}
```

### 3. Create an Auth Provider (Optional)
If you have authenticated routes, implement `DeepLinkAuthProvider`:

```dart
class AppDeepLinkAuthProvider implements DeepLinkAuthProvider {
  final AuthNotifier authNotifier; // Your auth state manager

  AppDeepLinkAuthProvider(this.authNotifier);

  @override
  bool get isAuthenticated => authNotifier.isLoggedIn;

  @override
  Listenable get authStateChanges => authNotifier; // ✅ Reactive!

  @override
  void onAuthRequired(Uri uri) {
    // Navigate to login
    GoRouter.of(context).go('/login');
  }
}
```

### 4. Initialize in `main.dart`

**Simple Setup (Most Apps):**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final deepLinkManager = DeepLinkManager();
  await deepLinkManager.initialize(
    strategies: [MyDeepLinkStrategy()],
    authProvider: AppDeepLinkAuthProvider(authNotifier),
    // ✅ App is automatically marked ready on first frame!
    // ✅ Pending links auto-clear on logout!
  );

  runApp(MyApp());
}
```

**Advanced Setup (Splash Screen Apps):**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final deepLinkManager = DeepLinkManager();
  await deepLinkManager.initialize(
    strategies: [MyDeepLinkStrategy()],
    authProvider: AppDeepLinkAuthProvider(authNotifier),
    autoSetAppReady: false, // Disable auto - wait for splash/config
  );

  runApp(MyApp());
}

// Later, after splash screen finishes
void onSplashFinished() {
  DeepLinkManager().setAppReady();  // Now process pending links
}
```

### 5. Router Configuration
Use the `navigatorKey` from `DeepLinkManager` or provide your own.

```dart
// Option 1: Use built-in key
final _router = GoRouter(
  navigatorKey: deepLinkManager.navigatorKey,
  // ...
);

// Option 2: Provide your own
final customKey = GlobalKey<NavigatorState>();
await deepLinkManager.initialize(
  strategies: [MyDeepLinkStrategy()],
  navigatorKey: customKey,  // Use your key
);
```

### 6. What's Automated in v0.4.0 ✨

**No more manual calls needed!**
- ✅ **Auto `setAppReady()`** - Automatically marks app as ready on first frame (disable with `autoSetAppReady: false`)
- ✅ **Auto logout handling** - Pending links automatically cleared when user logs out
- ✅ **Auto login processing** - Pending links automatically processed when user logs in

**Before v0.4.0** ❌
```dart
// Manual cleanup required
void logout() {
  DeepLinkManager().clearPendingLink(); // ❌ Manual
}

void onLoginSuccess() {
  DeepLinkManager().checkPendingLinks(); // ❌ Manual
}
```

**After v0.4.0** ✅
```dart
// Everything is automatic!
void logout() {
  myAuthNotifier.logout(); // ✅ Auto-clears pending links
}

void onLoginSuccess() {
  myAuthNotifier.login(); // ✅ Auto-processes pending links
}
```

---

## API Reference

### `DeepLinkManager`

| Method | Description |
|--------|-------------|
| `initialize({...})` | Start listener with strategies, auth provider, and options |
| `registerStrategy(DeepLinkStrategy)` | Add a strategy (sorted by priority) |
| `setAppReady()` | Signal UI ready, process pending links (auto-called by default) |
| `checkPendingLinks()` | Manually trigger processing (auto-called on login) |
| `clearPendingLink()` | Clear pending links (auto-called on logout) |
| `navigatorKey` | GlobalKey for Navigation (injected or built-in) |
| `hasPendingLink` | Check if a link is queued |
| `isInitialized` | Check if initialization completed |
| `dispose()` | Clean up listeners and subscriptions |

**Initialize Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `strategies` | `List<DeepLinkStrategy>` | `[]` | Strategies to handle links |
| `authProvider` | `DeepLinkAuthProvider?` | `null` | Auth provider for protected routes |
| `navigatorKey` | `GlobalKey<NavigatorState>?` | Built-in | Navigator key (optional) |
| `pendingLinkExpiration` | `Duration?` | 5 minutes | How long pending links are kept |
| `autoSetAppReady` | `bool` | `true` | Auto-mark ready on first frame |
| `onLog` | `Function(String)?` | `null` | Debug logging callback |
| `onError` | `Function(Object, StackTrace)?` | `null` | Error reporting callback |

**Behaviors:**
- **Link Expiration**: Configurable via `pendingLinkExpiration` (default: 5 minutes)
- **Auto App Ready**: Automatically marks app ready on first frame (disable for splash screens)
- **Auto Logout**: Automatically clears pending links when auth state becomes false
- **Auto Login**: Automatically processes pending links when auth state becomes true
- **Race Protection**: Guards against re-entrant processing
- **Error Handling**: Strategy execution wrapped in try-catch

### `DeepLinkStrategy<T>`

| Property/Method | Description |
|-----------------|-------------|
| `identifier` | Unique string for logging (required) |
| `priority` | Ordering priority; higher = first (default: 0) |
| `canHandle(Uri)` | Returns `true` if this strategy handles the URI |
| `extractData(Uri)` | Extract data of type `T` passed to `handle` |
| `requiresAuth` | Return `true` if user must be logged in |
| `handle(Uri, BuildContext, T?)` | Perform navigation with typed data |

### `DeepLinkAuthProvider`

| Property/Method | Description |
|-----------------|-------------|
| `isAuthenticated` | Returns `true` if user is logged in |
| `authStateChanges` | Optional `Listenable` for reactive auth handling (v0.4.0+) |
| `onAuthRequired(Uri)` | Called when auth is required but missing |

**Note:** Implementing `authStateChanges` enables automatic pending link processing on login/logout.

---

## 🌍 Backend Setup (Universal & App Links)

### 1. iOS Configuration (`apple-app-site-association`)
Host at `https://<your-domain>/.well-known/apple-app-site-association`:

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "<TeamID>.<BundleID>",
        "paths": [ "/pet/*", "/product/*" ]
      }
    ]
  }
}
```

### 2. Android Configuration (`assetlinks.json`)
Host at `https://<your-domain>/.well-known/assetlinks.json`:

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "<package_name>",
      "sha256_cert_fingerprints": ["<SHA256_FINGERPRINT>"]
    }
  }
]
```

### 3. Verification
- Files accessible via **HTTPS** without redirects
- Content-Type: `application/json`
