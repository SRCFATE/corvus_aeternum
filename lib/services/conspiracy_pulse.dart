import 'package:flutter/foundation.dart';

import '../models/conspiracy_membership.dart';
import 'conspiracy_service.dart';

/// Latido de presencia del archivo.
///
/// Las casas libres miden continuidad: días distintos con actividad real, no
/// tiempo de pantalla. `record_conspiracy_presence` marca el día y reevalúa
/// todo el progreso del usuario, así que basta llamarlo una vez por sesión.
///
/// Sin este latido el progreso de las conspiraciones nunca avanza.
class ConspiracyPulse {
  ConspiracyPulse._();
  static final ConspiracyPulse instance = ConspiracyPulse._();

  final _service = ConspiracyService();

  DateTime? _lastRecordedDay;
  bool _inFlight = false;

  /// Progreso más reciente devuelto por el servidor, para que la UI pueda
  /// mostrarlo sin una consulta extra.
  final ValueNotifier<List<ConspiracyProgress>> progress =
      ValueNotifier<List<ConspiracyProgress>>(const []);

  /// Marca presencia si aún no se hizo hoy. Silencioso ante fallos: el pulso
  /// nunca debe bloquear ni interrumpir la sesión del artista.
  Future<void> recordIfNeeded() async {
    final today = DateTime.now();
    final already = _lastRecordedDay != null &&
        _lastRecordedDay!.year == today.year &&
        _lastRecordedDay!.month == today.month &&
        _lastRecordedDay!.day == today.day;
    if (already || _inFlight) return;

    _inFlight = true;
    try {
      final result = await _service.recordPresence();
      _lastRecordedDay = today;
      if (result.isNotEmpty) progress.value = result;
    } catch (_) {
      // Sin conexión o sin sesión: se reintentará en la próxima apertura.
    } finally {
      _inFlight = false;
    }
  }

  /// Al cerrar sesión el pulso se olvida, para que otra cuenta en el mismo
  /// dispositivo registre su propio día.
  void reset() {
    _lastRecordedDay = null;
    progress.value = const [];
  }
}
