import 'package:flutter/material.dart';

/// Holds the app's root NavigatorState so code outside the widget tree —
/// specifically push notification tap handlers, which fire from a
/// background isolate or before any screen context exists — can still
/// push a route. Assigned to MaterialApp's navigatorKey in main.dart.
class NavigationService {
  NavigationService._();
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static NavigatorState? get _navigator => navigatorKey.currentState;

  static Future<T?> push<T>(Widget screen) async {
    final navigator = _navigator;
    if (navigator == null) return null;
    return navigator.push<T>(MaterialPageRoute(builder: (_) => screen));
  }

  static BuildContext? get currentContext => navigatorKey.currentContext;
}
