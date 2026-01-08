import 'dart:async';
import 'dart:developer';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../domain/deep_link_auth_provider.dart';
import '../domain/deep_link_strategy.dart';

class DeepLinkManager {
  // Singleton instance
  static DeepLinkManager _instance = DeepLinkManager._internal();

  /// Returns the singleton instance of [DeepLinkManager].
  factory DeepLinkManager() => _instance;

  /// Internal constructor.
  DeepLinkManager._internal() : _appLinks = AppLinks();

  static DeepLinkManager get instance => _instance;

  /// Visible for testing to inject a mock instance.
  @visibleForTesting
  static set instance(DeepLinkManager manager) {
    _instance = manager;
  }

  /// Visible for testing to inject dependencies.
  @visibleForTesting
  DeepLinkManager.test({
    AppLinks? appLinks,
  }) : _appLinks = appLinks ?? AppLinks();

  AppLinks _appLinks;
  GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  /// The navigator key used for navigation.
  /// You can use this key in your [MaterialApp] or [GoRouter],
  /// or providing your own key via [initialize].
  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

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

  // Observability callbacks
  void Function(String message)? _onLog;
  void Function(Object error, StackTrace stack)? _onError;

  /// Duration after which pending deep links expire and are discarded.
  Duration _pendingLinkExpiration = const Duration(minutes: 5);

  /// Register a new strategy for handling deep links.
  /// Strategies are sorted by priority (higher first).
  void registerStrategy(DeepLinkStrategy strategy) {
    _strategies.add(strategy);
    // Sort by priority descending (higher priority first)
    _strategies.sort((a, b) => b.priority.compareTo(a.priority));
    _log(
        'Registered strategy: ${strategy.identifier} (priority: ${strategy.priority})');
  }

  /// Initialize deep link listening.
  /// [strategies]: List of strategies to handle deep links.
  /// [authProvider]: Optional typed auth provider for authentication checks.
  /// [navigatorKey]: Optional navigator key if you want to use your own instead of the built-in one.
  /// [pendingLinkExpiration]: Duration after which pending links expire (default: 5 minutes).
  /// [autoSetAppReady]: If true, automatically marks app as ready on first frame (default: true).
  ///                     Set to false if you need to wait for splash screen/config before processing links.
  /// [onLog]: Optional callback for debugging logs (e.g. print to console).
  /// [onError]: Optional callback for reporting errors (e.g. to Crashlytics).
  Future<void> initialize({
    List<DeepLinkStrategy> strategies = const [],
    DeepLinkAuthProvider? authProvider,
    GlobalKey<NavigatorState>? navigatorKey,
    Duration? pendingLinkExpiration,
    bool autoSetAppReady = true,
    void Function(String message)? onLog,
    void Function(Object error, StackTrace stack)? onError,
  }) async {
    // Prevent multiple initializations
    if (_initializationCompleter != null) {
      return _initializationCompleter!.future;
    }
    _initializationCompleter = Completer();

    _onLog = onLog;
    _onError = onError;
    _authProvider = authProvider;

    if (navigatorKey != null) {
      _navigatorKey = navigatorKey;
    }

    if (pendingLinkExpiration != null) {
      _pendingLinkExpiration = pendingLinkExpiration;
    }

    // Register initial strategies
    for (final strategy in strategies) {
      // Validate auth configuration
      if (strategy.requiresAuth && _authProvider == null) {
        // We log a warning instead of throwing to prevent crashing the app startup,
        // but this is a critical configuration error.
        _log(
            'WARNING: Strategy "${strategy.identifier}" requires auth, but no authProvider was provided.');
      }
      registerStrategy(strategy);
    }

    // Handle initial link (app opened from terminated state)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _log('Initial deep link: $initialUri');
        _processLink(initialUri);
      }
    } catch (e, stack) {
      _reportError(e, stack);
    }

    // Handle links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _log('Deep link received: $uri');
        _processLink(uri);
      },
      onError: (Object err, stack) {
        _reportError(err, stack is StackTrace ? stack : StackTrace.current);
      },
    );

    // Listen to reactive auth changes
    final authListener = _authProvider?.authStateChanges;
    if (authListener != null) {
      authListener.addListener(_onAuthStateChanged);
    }

    // Check if user is already authenticated (handles race conditions during init)
    if (_authProvider?.isAuthenticated == true) {
      _log('User already authenticated, checking pending links');
      checkPendingLinks();
    }

    // Auto-set app ready on first frame if enabled
    if (autoSetAppReady) {
      _log('Auto-setting app ready on first frame');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_navigatorKey.currentContext != null) {
          setAppReady();
        }
      });
    }

    _initializationCompleter!.complete();
  }

  void _onAuthStateChanged() {
    final isAuthenticated = _authProvider?.isAuthenticated ?? false;

    if (isAuthenticated) {
      _log('Auth state changed to true, checking pending links');
      checkPendingLinks();
    } else {
      _log('Auth state changed to false, clearing pending links');
      _clearPending();
    }
  }

  void _log(String message) {
    if (_onLog != null) {
      _onLog?.call('[DeepLinkManager] $message');
    } else {
      log('[DeepLinkManager] $message');
    }
  }

  void _reportError(Object error, StackTrace stack) {
    _log('Error: $error');
    _onError?.call(error, stack);
  }

  void _processLink(Uri uri) {
    // Guard against re-entrant processing
    if (_isProcessing) {
      _log('Already processing a link, ignoring: $uri');
      return;
    }
    _isProcessing = true;

    try {
      for (final strategy in _strategies) {
        if (strategy.canHandle(uri)) {
          _log('Matched strategy: ${strategy.identifier}');
          final data = strategy.extractData(uri);

          // Check auth requirement
          if (strategy.requiresAuth) {
            final isAuthed = _authProvider?.isAuthenticated ?? false;
            if (!isAuthed) {
              _log('Auth required for $uri');
              // Store as pending so we can handle it after login
              _storePending(uri, data, strategy);
              _authProvider?.onAuthRequired(uri);
              return;
            }
          }

          if (_canHandleNow(strategy)) {
            _log('App ready, handling link immediately');
            _executeStrategy(strategy, uri, data);
          } else {
            _log('App not ready, storing pending link data');
            _storePending(uri, data, strategy);
          }
          return; // Handled by first matching strategy
        }
      }
      _log('No strategy found for uri: $uri');
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
        _log('Context unavailable, re-queuing link');
        _storePending(uri, data, strategy);
      }
    } catch (e, stack) {
      _log('Error executing strategy ${strategy.identifier}: $e');
      _reportError(e, stack);
      _clearPending(); // Prevent retry loops on persistent errors
    }
  }

  /// Call this when the app (e.g., SplashScreen) is done and can handle navigation.
  void setAppReady() {
    _isAppReady = true;
    _log('App marked as ready');

    // Only process pending if fully initialized
    if (isInitialized) {
      _checkPendingLink();
    }
  }

  /// Triggers a check for pending links.
  /// Use this method after a successful login to automatically process
  /// any deep links that were waiting for authentication.
  void checkPendingLinks() {
    _log('Manually checking pending links');
    _checkPendingLink();
  }

  void _checkPendingLink() {
    if (_pendingStrategy == null) return;

    // Check for link expiration
    if (_pendingLinkTimestamp != null) {
      final elapsed = DateTime.now().difference(_pendingLinkTimestamp!);
      if (elapsed > _pendingLinkExpiration) {
        _log('Pending link expired after ${elapsed.inMinutes} minutes');
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
          _log('Pending link requires auth, still not authed. Waiting.');
          return;
        }
      }

      _log('Processing pending deep link');
      _executeStrategy(_pendingStrategy!, _pendingUri ?? Uri(), _pendingData);
      _clearPending();
    }
    // Else: context still null/unmounted, wait for next check or setAppReady
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
    _authProvider?.authStateChanges?.removeListener(_onAuthStateChanged);
    _linkSubscription?.cancel();
  }
}
