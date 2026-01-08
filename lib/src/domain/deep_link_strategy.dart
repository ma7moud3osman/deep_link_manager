import 'package:flutter/material.dart';

/// Abstract class defining a strategy for handling deep links.
/// Implement this to define custom handling logic for specific URL patterns.
abstract class DeepLinkStrategy {
  /// Unique identifier for this strategy (used for logging/debugging).
  /// Example: 'MicroPetDeepLinkStrategy'
  String get identifier;

  /// Priority for strategy ordering. Higher values are processed first.
  /// Default is 0. Use higher values for more specific strategies.
  int get priority => 0;

  /// Checks if this strategy can handle the given URI.
  bool canHandle(Uri uri);

  /// Handles the deep link.
  /// This is called when [canHandle] returns true.
  /// [context] is the [BuildContext] from the navigator key.
  /// [data] is the optional data extracted via [extractData], if any.
  void handle(Uri uri, BuildContext context, Object? data);

  /// Optional: Extracts data from the URI to be stored as pending data
  /// if the app is not ready yet. This data will be passed to [handle] later.
  Object? extractData(Uri uri) => null;

  /// Whether this strategy requires the user to be authenticated.
  /// If true, the manager might delay handling until the user is logged in.
  bool get requiresAuth => false;
}
