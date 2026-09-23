import 'package:flutter/material.dart';

/// Estado efímero del recorrido, propiedad del shell. No se comparte entre
/// cuentas ni sobrevive a cerrar la aplicación.
mixin SessionPageState<T extends StatefulWidget> on State<T> {
  PageStorageBucket? _bucket;
  String get sessionKey;
  bool _restored = false;
  Map<String, dynamic> captureSession();
  void restoreSession(Map<String, dynamic> value);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bucket = PageStorage.maybeOf(context);
    if (_restored) return;
    _restored = true;
    final value = _bucket?.readState(context, identifier: sessionKey);
    if (value is Map<String, dynamic>) restoreSession(value);
  }

  @override
  void deactivate() {
    _bucket?.writeState(context, captureSession(), identifier: sessionKey);
    super.deactivate();
  }
}
