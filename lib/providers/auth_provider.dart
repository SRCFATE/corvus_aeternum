import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/conspiracy_pulse.dart';

enum AuthStatus { loading, authenticated, unauthenticated, noProfile }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.loading;
  UserProfile? _profile;
  String? _error;
  String? _pendingUserId; // ID guardado del signup cuando no hay sesión activa aún

  AuthStatus get status => _status;
  UserProfile? get profile => _profile;
  String? get error => _error;

  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;

  Future<void> initialize() async {
    _status = AuthStatus.loading;
    notifyListeners();

    final user = _authService.currentUser;
    if (user == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    await _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _authService.getCurrentProfile();
      if (profile == null) {
        _status = AuthStatus.noProfile;
      } else {
        _profile = profile;
        _status = AuthStatus.authenticated;
        // Marca el día en el archivo y reevalúa el progreso de las casas.
        // No se espera: el pulso nunca debe retrasar la entrada.
        unawaited(ConspiracyPulse.instance.recordIfNeeded());
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    _error = null;
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      await _authService.signIn(email, password);
      await _loadProfile();
      return _status == AuthStatus.authenticated;
    } catch (e) {
      _error = _parseError(e.toString());
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp(String email, String password) async {
    _error = null;
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final response = await _authService.signUp(email, password);
      _pendingUserId = response.user?.id;
      _status = AuthStatus.noProfile;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _parseError(e.toString());
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> createProfile({
    required String username,
    required String displayName,
    required String bio,
    required List<String> disciplines,
    String? country,
  }) async {
    _error = null;
    notifyListeners();

    try {
      _profile = await _authService.createProfile(
        userId: _pendingUserId,
        username: username,
        displayName: displayName,
        bio: bio,
        disciplines: disciplines,
        country: country,
      );
      _pendingUserId = null;

      if (_profile == null) {
        _error = 'No se pudo crear el perfil. El perfil regresó vacío.';
        _status = AuthStatus.noProfile;
        notifyListeners();
        return false;
      }

      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      debugPrint('CREATE PROFILE ERROR: $e');
      debugPrint('CREATE PROFILE STACK: $stackTrace');
      _error = _parseError(e.toString());
      _status = AuthStatus.noProfile;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    ConspiracyPulse.instance.reset();
    _profile = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    _error = null;
    notifyListeners();
    try {
      await _authService.deleteAccount();
      _profile = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _parseError(e.toString());
      notifyListeners();
      return false;
    }
  }

  void updateProfile(UserProfile profile) {
    _profile = profile;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _parseError(String error) {
    if (error.contains('Invalid login credentials')) return 'Correo o contraseña incorrectos.';
    if (error.contains('Email already registered')) return 'Este correo ya está registrado.';
    if (error.contains('Password should be at least')) return 'La contraseña debe tener al menos 6 caracteres.';
    if (error.contains('duplicate key') && error.contains('username')) return 'Ese nombre de usuario ya está en uso.';
    if (error.contains('network')) return 'Error de conexión. Verifica tu internet.';
    return error;
  }
}
