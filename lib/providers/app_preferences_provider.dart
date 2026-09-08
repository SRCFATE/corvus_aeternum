import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferencesProvider extends ChangeNotifier {
  static const _reduceMotionKey = 'corvus_reduce_motion';
  static const _largerTextKey = 'corvus_larger_text';
  static const _highContrastKey = 'corvus_high_contrast';

  bool _reduceMotion = false;
  bool _largerText = false;
  bool _highContrast = false;

  bool get reduceMotion => _reduceMotion;
  bool get largerText => _largerText;
  bool get highContrast => _highContrast;

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    _reduceMotion = preferences.getBool(_reduceMotionKey) ?? false;
    _largerText = preferences.getBool(_largerTextKey) ?? false;
    _highContrast = preferences.getBool(_highContrastKey) ?? false;
    notifyListeners();
  }

  Future<void> setReduceMotion(bool value) async {
    if (_reduceMotion == value) return;
    _reduceMotion = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_reduceMotionKey, value);
  }

  Future<void> setLargerText(bool value) async {
    if (_largerText == value) return;
    _largerText = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_largerTextKey, value);
  }

  Future<void> setHighContrast(bool value) async {
    if (_highContrast == value) return;
    _highContrast = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_highContrastKey, value);
  }
}
