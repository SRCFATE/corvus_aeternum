// lib/auth/create_profile_page.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/profile_service.dart';
import 'signup_role.dart';

class CreateProfilePage extends StatefulWidget {
  const CreateProfilePage({super.key, required this.role});
  final SignupRole role;

  @override
  State<CreateProfilePage> createState() => _CreateProfilePageState();
}

class _CreateProfilePageState extends State<CreateProfilePage> {
  final SupabaseClient supabase = Supabase.instance.client;
  late final ProfileService service;

  final displayNameCtrl = TextEditingController();

  // Username (se guarda SIN @, UI lo muestra con @)
  String username = '';

  Timer? debounce;
  bool checkingUsername = false;
  bool usernameAvailable = false;
  String? usernameError;

  // UX de validación: solo mostramos el mensaje inferior cuando intenta guardar
  bool triedSubmit = false;

  // Datos
  String country = 'México';
  String? conspiracyId;

  // Avatar
  File? avatarFile;

  bool loading = false;

  List<Map<String, dynamic>> conspiracies = [];

  final countries = const [
    'México',
    'Estados Unidos',
    'Canadá',
    'España',
    'Argentina',
    'Chile',
    'Colombia',
    'Perú',
    'Brasil',
    'Alemania',
    'Francia',
    'Italia',
    'Japón',
    'Corea del Sur',
    'Reino Unido',
  ];

  bool get isCrow => widget.role == SignupRole.crow;

  @override
  void initState() {
    super.initState();
    service = ProfileService(supabase);

    displayNameCtrl.addListener(_onDisplayNameChanged);

    if (isCrow) {
      _loadConspiracies();
    } else {
      conspiracyId = null;
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    displayNameCtrl.removeListener(_onDisplayNameChanged);
    displayNameCtrl.dispose();
    super.dispose();
  }

  void toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ==========
  // Username
  // ==========

  void _onDisplayNameChanged() {
    final raw = displayNameCtrl.text.trim();
    final next = _makeUsernameFromDisplayName(raw);

    if (next == username) return;

    setState(() {
      username = next;
      checkingUsername = false;
      usernameAvailable = false;
      usernameError = null;
    });

    _debouncedCheckUsername(next);
  }

  String _makeUsernameFromDisplayName(String name) {
    if (name.isEmpty) return '';

    var s = name.toLowerCase().trim();

    s = s
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');

    // Solo [a-z0-9 ] y guiones
    s = s.replaceAll(RegExp(r'[^a-z0-9\s-]'), '');

    // Espacios -> guiones, colapsar guiones múltiples
    s = s.replaceAll(RegExp(r'\s+'), '-');
    s = s.replaceAll(RegExp(r'-{2,}'), '-');

    // Recortar guiones extremos
    s = s.replaceAll(RegExp(r'^-+'), '').replaceAll(RegExp(r'-+$'), '');

    if (s.length > 24) s = s.substring(0, 24);
    s = s.replaceAll(RegExp(r'-+$'), '');

    if (s.length < 3) return '';
    return s; // SIN @
  }

  bool _isUsernameFormatValid(String u) {
    // 3-24 y solo [a-z0-9-]
    return RegExp(r'^[a-z0-9-]{3,24}$').hasMatch(u);
  }

  void _debouncedCheckUsername(String u) {
    debounce?.cancel();

    debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;

      if (u.isEmpty) {
        setState(() {
          checkingUsername = false;
          usernameAvailable = false;
          usernameError = null;
        });
        return;
      }

      if (!_isUsernameFormatValid(u)) {
        setState(() {
          checkingUsername = false;
          usernameAvailable = false;
          usernameError = 'Nombre artístico muy corto o inválido.';
        });
        return;
      }

      setState(() {
        checkingUsername = true;
        usernameAvailable = false;
        usernameError = null;
      });

      try {
        // Debe recibir username SIN @
        final ok = await service.isUsernameAvailable(u);
        if (!mounted) return;

        setState(() {
          checkingUsername = false;
          usernameAvailable = ok;
          usernameError = ok ? null : 'Ese username ya existe.';
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          checkingUsername = false;
          usernameAvailable = false;
          usernameError = 'No se pudo validar.';
        });
      }
    });
  }

  String? get footerHint {
    if (!triedSubmit) return null;

    final dn = displayNameCtrl.text.trim();
    if (dn.isEmpty) return 'Completa tu nombre artístico.';

    if (username.isEmpty) return 'Genera un username válido.';
    if (checkingUsername) return 'Verificando disponibilidad…';
    if (!_isUsernameFormatValid(username)) return 'Username inválido.';
    if (!usernameAvailable) return 'Ese username no está disponible.';

    return null;
  }

  bool get canSubmit {
    final dn = displayNameCtrl.text.trim();
    if (dn.isEmpty) return false;

    if (username.isEmpty) return false;
    if (!_isUsernameFormatValid(username)) return false;

    // Si está revisando o no es disponible, no puede
    if (checkingUsername) return false;
    if (!usernameAvailable) return false;

    // IMPORTANTE: NO bloquees por conspiración.
    // Si es crow y no cargó, lo guardas como null.
    if (loading) return false;

    return true;
  }

  // ==================
  // Conspiraciones
  // ==================
  Future<void> _loadConspiracies() async {
    try {
      final list = await service.listConspiracies();
      if (!mounted) return;

      setState(() {
        conspiracies = list;
        if (conspiracyId == null && list.isNotEmpty) {
          final firstId = list.first['id'];
          if (firstId is String) conspiracyId = firstId;
        }
      });
    } catch (_) {
      // No rompe el flujo: conspiración queda opcional
    }
  }

  // ==========
  // Avatar
  // ==========
  Future<void> pickAvatar() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return;

    if (!mounted) return;
    setState(() {
      avatarFile = File(x.path);
    });
  }

  // ==========
  // Submit
  // ==========
  Future<void> submit() async {
    setState(() => triedSubmit = true);

    if (!canSubmit) {
      final msg = footerHint ?? 'Revisa tus datos.';
      toast(msg);
      return;
    }

    setState(() => loading = true);

    try {
      String? avatarUrl;

      // En web: File puede fallar dependiendo de tu setup.
      // Si ya lo tienes funcionando con image_picker en web, ok.
      if (avatarFile != null) {
        avatarUrl = await service.uploadAvatar(avatarFile!);
      }

      final profileType = isCrow ? 'crow' : 'collector';

      await service.createProfile(
        displayName: displayNameCtrl.text.trim(),
        username: username, // SIN @ (recomendado)
        bio: null,
        role: profileType,
        country: country,
        conspiracyId: isCrow ? conspiracyId : null, // opcional si no cargó
        avatarUrl: avatarUrl,
      );

      if (!mounted) return;
      Navigator.pop(context); // AuthGate detecta perfil y manda a Home
    } catch (e) {
      toast('Error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ==================
  // UI
  // ==================
  @override
  Widget build(BuildContext context) {
    final statusText = checkingUsername
        ? 'Validando…'
        : (username.isEmpty ? '' : (usernameAvailable ? 'Disponible' : (usernameError ?? '')));

    final statusColor = usernameAvailable
        ? Colors.greenAccent
        : (checkingUsername ? Colors.white.withValues(alpha: 0.7) : Colors.redAccent);

    return Scaffold(
      appBar: AppBar(title: const Text('Completa tu perfil')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const Text(
                'Identidad',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  GestureDetector(
                    onTap: pickAvatar,
                    child: CircleAvatar(
                      radius: 34,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      backgroundImage: avatarFile != null ? FileImage(avatarFile!) : null,
                      child: avatarFile == null ? const Icon(Icons.person_outline_rounded) : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Avatar (opcional)\nToca para subir imagen.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), height: 1.2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: displayNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre artístico',
                  filled: true,
                ),
              ),
              const SizedBox(height: 12),

              // Username autogenerado (solo lectura)
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Username',
                  helperText: statusText.isEmpty ? null : statusText,
                  helperStyle: TextStyle(color: statusColor),
                  filled: true,
                ),
                child: Text(
                  username.isEmpty ? '—' : '@$username',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),

              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: country,
                items: countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => country = v ?? country),
                decoration: const InputDecoration(labelText: 'País', filled: true),
              ),
              const SizedBox(height: 20),

              if (isCrow) ...[
                const Text(
                  'Conspiración inicial',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                if (conspiracies.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Cargando conspiraciones… (opcional)',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: conspiracyId,
                    items: conspiracies.map((c) {
                      final id = c['id'];
                      final name = c['name'];
                      if (id is! String) return null;
                      return DropdownMenuItem<String>(
                        value: id,
                        child: Text((name ?? 'Conspiración').toString()),
                      );
                    }).whereType<DropdownMenuItem<String>>().toList(),
                    onChanged: (v) => setState(() => conspiracyId = v),
                    decoration: const InputDecoration(
                      labelText: 'Elige tu conspiración',
                      filled: true,
                    ),
                  ),
                const SizedBox(height: 20),
              ],

              // Hint inferior (solo cuando intentó guardar)
              if (footerHint != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    footerHint!,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                  ),
                ),
              ],

              FilledButton(
                onPressed: loading
                    ? null
                    : (canSubmit ? submit : () => setState(() => triedSubmit = true)),
                child: Text(loading ? 'Guardando…' : 'Guardar y continuar'),
              ),

              if (kIsWeb) const SizedBox(height: 8),
              if (kIsWeb)
                Text(
                  'Tip: en web, si el picker de imagen falla, prueba primero sin avatar.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
