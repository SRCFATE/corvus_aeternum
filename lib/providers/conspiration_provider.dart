import 'package:flutter/material.dart';
import '../models/conspiration.dart';
import '../core/supabase_config.dart';

class ConspirationProvider extends ChangeNotifier {
  Conspiration? _active;

  Conspiration? get active => _active;

  // ── 70 / 20 / 10 ────────────────────────────────────────────────────────────

  /// 70 % — fondo dominante
  Color get base => _active?.baseHex != null
      ? _hex(_active!.baseHex!)
      : const Color(0xFF09090C);

  /// 20 % — superficies y tarjetas
  Color get surface => _active?.surfaceHex != null
      ? _hex(_active!.surfaceHex!)
      : const Color(0xFF100C14);

  Color get card => Color.lerp(base, surface, 0.5)!;

  /// 10 % — acento, CTAs, bordes activos
  Color get accent => _active?.accentColor ?? const Color(0xFFCC3333);

  Color get glow => _active?.glowColor ?? accent;
  double get glowIntensity => _active?.glowIntensity ?? 0.35;
  double get uiRounding => _active?.uiRounding ?? 16;

  Color get border => Color.lerp(surface, accent, 0.12)!;
  Color get borderFocus => Color.lerp(surface, accent, 0.45)!;

  // ── Carga ────────────────────────────────────────────────────────────────────

  Future<void> loadForUser(String? conspirationId) async {
    if (conspirationId == null) {
      _active = null;
      notifyListeners();
      return;
    }
    try {
      final data = await supabase
          .from('conspirations')
          .select()
          .eq('id', conspirationId)
          .single();
      _active = Conspiration.fromMap(data);
    } catch (_) {
      _active = null;
    }
    notifyListeners();
  }

  void setConspiration(Conspiration? c) {
    _active = c;
    notifyListeners();
  }

  void clear() {
    _active = null;
    notifyListeners();
  }

  static Color _hex(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}
