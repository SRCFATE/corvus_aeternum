import 'dart:async';

/// Coalesces bursts and serializes refreshes without interrupting editing.
class LiveRefresh {
  final Future<void> Function() refresh;
  late final StreamSubscription<void> _subscription;
  Timer? _timer;
  bool _running = false;
  bool _pending = false;
  bool _disposed = false;

  LiveRefresh(Stream<void> changes, this.refresh) {
    _subscription = changes.listen((_) => request());
  }

  void request() {
    if (_disposed) return;
    _pending = true;
    if (_running || _timer != null) return;
    _timer = Timer(const Duration(milliseconds: 600), _run);
  }

  Future<void> _run() async {
    _timer = null;
    if (_disposed) return;
    _running = true;
    _pending = false;
    try {
      await refresh();
    } finally {
      _running = false;
      if (_pending) request();
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_subscription.cancel());
  }
}
