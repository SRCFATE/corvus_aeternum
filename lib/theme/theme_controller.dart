import 'package:flutter/foundation.dart';
import 'app_skin.dart';

class ThemeController extends ChangeNotifier {
  AppSkin _skin = AppSkin.base;
  AppSkin get skin => _skin;

  /// Aplica un skin nuevo.
  /// Dispara notifyListeners() si:
  /// - Cambia la key (lo normal entre conspiraciones), o
  /// - Cambia cualquier atributo visual importante.

  void setSkin(AppSkin next) {
    // Fast-path: si es exactamente el mismo objeto
    if (identical(_skin, next)) return;

    if (_sameVisualState(_skin, next)) return;

    _skin = next;

    if (kDebugMode) {
      debugPrint(
          '[ThemeController] skin aplicado: ${_skin.key}(${_skin.name})');
    }
    notifyListeners();
  }

  void resetToBase() => setSkin(AppSkin.base);

  bool _sameVisualState(AppSkin a, AppSkin b){
  return a.key == b.key &&
    a.name == b.name &&
    a.primary == b.primary &&
    a.secondary == b.secondary &&
    a.tertiary == b.tertiary &&
    a.surface == b.surface &&
    a.surfaceContainerHighest == b.surfaceContainerHighest &&
    a.onSurface == b.onSurface &&
    a.onPrimary == b.onPrimary &&
    a.outline == b.outline &&
    a.glow == b.glow;
  }
}

final ThemeController themeController = ThemeController();