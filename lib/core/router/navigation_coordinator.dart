import 'package:flutter/material.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();

typedef NavigationExitGuard = Future<bool> Function();

class AppNavigationCoordinator {
  AppNavigationCoordinator._();

  static final instance = AppNavigationCoordinator._();

  Object? _owner;
  NavigationExitGuard? _exitGuard;
  bool _checkingExit = false;

  bool get hasExitGuard => _exitGuard != null;

  void registerExitGuard(Object owner, NavigationExitGuard guard) {
    _owner = owner;
    _exitGuard = guard;
  }

  void unregisterExitGuard(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _exitGuard = null;
  }

  Future<bool> canNavigate() async {
    if (_checkingExit) return false;
    final guard = _exitGuard;
    if (guard == null) return true;

    _checkingExit = true;
    try {
      return await guard();
    } finally {
      _checkingExit = false;
    }
  }
}
