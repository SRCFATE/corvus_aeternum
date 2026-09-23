import 'dart:developer' as developer;
import 'package:flutter/widgets.dart';

/// Opt-in, local-only timing. Names are fixed page names, never user content.
/// The second milestone means controls are enabled in the rendered frame; it
/// is not a browser-wide idle metric or a measurement of input latency.
class PageLoadTrace {
  static const enabled = bool.fromEnvironment('CORVUS_PERFORMANCE');
  final String page;
  final Stopwatch _watch = Stopwatch();
  final developer.TimelineTask _task = developer.TimelineTask();
  bool _finished = false;
  PageLoadTrace(this.page) {
    if (enabled) {
      _watch.start();
      _task.start('corvus.page.$page');
    }
  }

  void rendered({required bool Function() isCurrent, bool interactive = true}) {
    if (!enabled || _finished) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isCurrent()) {
        cancel();
        return;
      }
      if (_finished) return;
      final elapsed = _watch.elapsedMicroseconds / 1000;
      _finished = true;
      _watch.stop();
      final values = {
        'contentVisibleMs': elapsed,
        if (interactive) 'controlsReadyMs': elapsed
      };
      _task.finish(arguments: values);
      developer.log('$page $values', name: 'corvus.performance');
    });
  }

  void cancel() {
    if (!enabled || _finished) return;
    _finished = true;
    _watch.stop();
    _task.finish(arguments: {'cancelled': true});
  }
}
