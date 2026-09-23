import 'dart:js_interop';
import 'package:web/web.dart' as web;

class BrowserExitGuard {
  late final JSFunction _listener;

  BrowserExitGuard(bool Function() hasPendingChanges) {
    _listener = ((web.Event event) {
      if (!hasPendingChanges()) return;
      event.preventDefault();
      (event as web.BeforeUnloadEvent).returnValue = '';
    }).toJS;
    web.window.addEventListener('beforeunload', _listener);
  }

  void dispose() => web.window.removeEventListener('beforeunload', _listener);
}
