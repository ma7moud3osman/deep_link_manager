import 'dart:async';
import 'dart:developer';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../domain/deep_link_auth_provider.dart';
import '../domain/deep_link_strategy.dart';

/// Duration after which pending deep links expire and are discarded.
const _kPendingLinkExpiration = Duration(minutes: 5);

class DeepLinkManager {
  // Singleton instance
  static DeepLinkManager _instance = DeepLinkManager._internal();

  /// Returns the singleton instance of [DeepLinkManager].
  factory DeepLinkManager() => _instance;

  /// Internal constructor.
  DeepLinkManager._internal() : _appLinks = AppLinks();

  /// Visible for testing to inject a mock instance.
  @visibleForTesting
  static void setInstance(DeepLinkManager manager) {
    _instance = manager;
  }

  /// Visible for testing to inject dependencies.
  @visibleForTesting
  DeepLinkManager.test({
    AppLinks? appLinks,
  }) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final List<DeepLinkStrategy> _strategies = [];
  StreamSubscription? _linkSubscription;

  Uri? _pendingUri;
  Object? _pendingData;
  DeepLinkStrategy? _pendingStrategy;
  DateTime? _pendingLinkTimestamp;

  bool get hasPendingLink => _pendingStrategy != null;

  /// Flag to indicate if the app has fully started and is ready for navigation
  bool _isAppReady = false;

  /// Guard to prevent re-entrant processing
  bool _isProcessing = false;

  /// Completer to track initialization state
  Completer<void>? _initializationCompleter;

  /// Check if initialization has completed
  bool get isInitialized => _initializationCompleter?.isCompleted ?? false;

  /// Typed auth provider for secure authentication handling
  DeepLinkAuthProvider? _authProvider;

  /// Register a new strategy for handling deep links.
  /// Strategies are sorted by priority (higher first).
  void registerStrategy(DeepLinkStrategy strategy) {
    _strategies.add(strategy);
    // Sort by priority descending (higher priority first)
    _strategies.sort((a, b) => b.priority.compareTo(a.priority));
    log('[DeepLinkManager] Registered strategy: ${strategy.identifier} (priority: ${strategy.priority})');
  }

  /// Initialize deep link listening.
  /// [strategies]: List of strategies to handle deep links.
  /// [authProvider]: Optional typed auth provider for authentication checks.
  Future<void> initialize({
    List<DeepLinkStrategy> strategies = const [],
    DeepLinkAuthProvider? authProvider,
  }) async {
    // Prevent multiple initializations
    if (_initializationCompleter != null) {
      return _initializationCompleter!.future;
    }
    _initializationCompleter = Completer();

    // Register initial strategies
    for (final strategy in strategies) {
      registerStrategy(strategy);
    }

    _authProvider = authProvider;

    // Handle initial link (app opened from terminated state)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        log('[DeepLinkManager] Initial deep link: $initialUri');
        _processLink(initialUri);
      }
    } catch (e) {
      log('[DeepLinkManager] Error getting initial link: $e');
    }

    // Handle links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        log('[DeepLinkManager] Deep link received: $uri');
        _processLink(uri);
      },
      onError: (err) {
        log('[DeepLinkManager] Deep link error: $err');
      },
    );

    _initializationCompleter!.complete();
  }

  void _processLink(Uri uri) {
    // Guard against re-entrant processing
    if (_isProcessing) {
      log('[DeepLinkManager] Already processing a link, ignoring: $uri');
      return;
    }
    _isProcessing = true;

    try {
      for (final strategy in _strategies) {
        if (strategy.canHandle(uri)) {
          log('[DeepLinkManager] Matched strategy: ${strategy.identifier}');
          final data = strategy.extractData(uri);

          // Check auth requirement
          if (strategy.requiresAuth) {
            final isAuthed = _authProvider?.isAuthenticated ?? false;
            if (!isAuthed) {
              log('[DeepLinkManager] Auth required for $uri');
              // Store as pending so we can handle it after login
              _storePending(uri, data, strategy);
              _authProvider?.onAuthRequired(uri);
              return;
            }
          }

          if (_canHandleNow(strategy)) {
            log('[DeepLinkManager] App ready, handling link immediately');
            _executeStrategy(strategy, uri, data);
          } else {
            log('[DeepLinkManager] App not ready, storing pending link data');
            _storePending(uri, data, strategy);
          }
          return; // Handled by first matching strategy
        }
      }
      log('[DeepLinkManager] No strategy found for uri: $uri');
    } finally {
      _isProcessing = false;
    }
  }

  void _storePending(Uri uri, Object? data, DeepLinkStrategy strategy) {
    _pendingUri = uri;
    _pendingData = data;
    _pendingStrategy = strategy;
    _pendingLinkTimestamp = DateTime.now();
  }

  bool _canHandleNow(DeepLinkStrategy strategy) {
    if (!_isAppReady) return false;
    if (navigatorKey.currentContext == null) return false;
    return true;
  }

  void _executeStrategy(DeepLinkStrategy strategy, Uri uri, Object? data) {
    try {
      // Capture context to avoid TOCTOU issues
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        strategy.handle(uri, context, data);
      } else {
        log('[DeepLinkManager] Context unavailable, re-queuing link');
        _storePending(uri, data, strategy);
      }
    } catch (e, stack) {
      log('[DeepLinkManager] Error executing strategy ${strategy.identifier}: $e');
      log('[DeepLinkManager] Stack trace: $stack');
      _clearPending(); // Prevent retry loops on persistent errors
    }
  }

  /// Call this when the app (e.g., SplashScreen) is done and can handle navigation.
  void setAppReady() {
    _isAppReady = true;
    log('[DeepLinkManager] App marked as ready');

    // Only process pending if fully initialized
    if (isInitialized) {
      _checkPendingLink();
    }
  }

  void _checkPendingLink() {
    if (_pendingStrategy == null) return;

    // Check for link expiration
    if (_pendingLinkTimestamp != null) {
      final elapsed = DateTime.now().difference(_pendingLinkTimestamp!);
      if (elapsed > _kPendingLinkExpiration) {
        log('[DeepLinkManager] Pending link expired after ${elapsed.inMinutes} minutes');
        _clearPending();
        return;
      }
    }

    final context = navigatorKey.currentContext;
    final state = navigatorKey.currentState;

    if (context != null && state != null && state.mounted) {
      // Re-check auth if the pending strategy requires it
      if (_pendingStrategy!.requiresAuth) {
        final isAuthed = _authProvider?.isAuthenticated ?? false;
        if (!isAuthed) {
          log('[DeepLinkManager] Pending link requires auth, still not authed. Waiting.');
          return;
        }
      }

      log('[DeepLinkManager] Processing pending deep link');
      _executeStrategy(_pendingStrategy!, _pendingUri ?? Uri(), _pendingData);
      _clearPending();
    }
  }

  void _clearPending() {
    _pendingData = null;
    _pendingStrategy = null;
    _pendingUri = null;
    _pendingLinkTimestamp = null;
  }

  /// Manually clear pending links if needed (e.g., on logout).
  void clearPendingLink() {
    _clearPending();
    // Note: We intentionally do NOT reset _isAppReady on logout to avoid
    // blocking deep links if user re-logins within the same app session.
  }

  /// Dispose resources. Note: For singletons, this is typically only called
  /// on app termination via WidgetsBindingObserver.
  void dispose() {
    _linkSubscription?.cancel();
  }
}
