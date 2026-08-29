import 'package:corvus_aeternum/models/conspiracy_membership.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses server progress and exposes effect metadata', () {
    final progress = ConspiracyProgress.fromMap({
      'conspiracy_id': 'imperial-id',
      'code': 'imperial',
      'name': 'Conspiracion Imperial',
      'metric_value': '112.5',
      'target_value': 100,
      'level': 4,
      'state': 'unlocked',
      'details': {
        'metric_label': 'Indice de dominio',
        'effect_key': 'imperial_crown',
        'effect_active': true,
      },
      'evaluated_at': '2026-08-18T12:00:00Z',
    });

    expect(progress.ratio, 1);
    expect(progress.metricText, '112.5 / 100');
    expect(progress.stateLabel, 'Conspiración conquistada');
    expect(progress.metricLabel, 'Indice de dominio');
    expect(progress.effectLabel, 'Corona Imperial');
    expect(progress.effectActive, isTrue);
    expect(progress.evaluatedAt, DateTime.utc(2026, 8, 18, 12));
  });

  test('keeps incomplete evidence below its target', () {
    const progress = ConspiracyProgress(
      conspiracyId: 'abyss-id',
      code: 'abismo_azul',
      name: 'Abismo Azul',
      metricValue: 3,
      targetValue: 12,
      level: 0,
      state: 'tracking',
      details: {
        'metric_label': 'Meses de progresion continua',
        'effect_key': 'abyss_depth',
      },
    );

    expect(progress.ratio, 0.25);
    expect(progress.stateLabel, 'Evidencia en curso');
    expect(progress.effectActive, isFalse);
  });
}
