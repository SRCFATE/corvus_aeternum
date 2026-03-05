import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/profile_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;
  late final ProfileService service;

  Map<String, dynamic>? profile;
  Map<String, dynamic>? verification;

  bool loading = true;
  bool saving = false;

  final displayNameCtrl = TextEditingController();
  final bioCtrl = TextEditingController();

  String country = 'México';
  String role = 'collector'; // solo lectura aquí
  String? conspiracyId;

  List<Map<String, dynamic>> conspiracies = [];

  File? newAvatar;

  final portfolioCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    service = ProfileService(supabase);
    loadAll();
  }

  @override
  void dispose() {
    displayNameCtrl.dispose();
    bioCtrl.dispose();
    portfolioCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  void toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> loadAll() async {
    setState(() => loading = true);
    try {
      final p = await service.getMyProfile();

      // OJO: listConstellations() es alias que retorna conspiraciones
      final c = await service.listConstellations();
      final v = await service.myVerificationRequest();

      profile = p;
      conspiracies = c;
      verification = v;

      if (p != null) {
        displayNameCtrl.text = (p['display_name'] ?? '') as String;
        bioCtrl.text = (p['bio'] ?? '') as String;
        role = (p['role'] ?? 'collector') as String;
        country = (p['country'] ?? 'México') as String;

        // antes: constellation_id
        conspiracyId = p['conspiracy_id'] as String?;
      }

      conspiracyId ??= (conspiracies.isNotEmpty ? (conspiracies.first['id'] as String) : null);
    } catch (e) {
      toast('Error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> pickAvatar() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return;
    setState(() => newAvatar = File(x.path));
  }

  Future<void> saveProfile() async {
    setState(() => saving = true);
    try {
      String? avatarUrl;
      if (newAvatar != null) {
        avatarUrl = await service.uploadAvatar(newAvatar!);
      }

      await service.updateProfile(
        displayName: displayNameCtrl.text,
        bio: bioCtrl.text,
        country: country,
        conspiracyId: conspiracyId,
        avatarUrl: avatarUrl,
      );

      toast('Perfil actualizado.');
      await loadAll();
      if (mounted) setState(() => newAvatar = null);
    } catch (e) {
      toast('Error: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> requestVerification() async {
    final url = portfolioCtrl.text.trim();
    if (url.isEmpty) {
      toast('Pon tu link de portafolio.');
      return;
    }

    try {
      await service.submitVerificationRequest(
        links: [url],
        message: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      );

      toast('Solicitud enviada.');
      await loadAll();
    } catch (e) {
      toast('Error: $e');
    }
  }

  String _roleLabel(String r) {
    switch (r) {
      case 'crow':
      case 'artist':
        return 'Cuervo (Artista)';
      case 'collector':
        return 'Coleccionista';
      default:
        return r;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (profile == null) {
      return const Scaffold(body: Center(child: Text('No hay perfil.')));
    }

    final avatarUrl = profile!['avatar_url'] as String?;
    final username = profile!['username'] as String? ?? '';
    final verified = (profile!['is_artist_verified'] as bool?) ?? false;

    final verificationStatus = verification?['status'] as String?;
    final hasPending = verificationStatus == 'pending';

    ImageProvider? avatarProvider;
    if (newAvatar != null) {
      avatarProvider = FileImage(newAvatar!);
    } else if (avatarUrl != null && avatarUrl.isNotEmpty) {
      avatarProvider = NetworkImage(avatarUrl);
    } else {
      avatarProvider = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          TextButton(
            onPressed: () async => supabase.auth.signOut(),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: pickAvatar,
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      backgroundImage: avatarProvider,
                      child: avatarProvider == null ? const Icon(Icons.person_outline_rounded) : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('@$username', style: TextStyle(color: Colors.white.withValues(alpha: 0.75))),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              verified ? 'Artista verificado' : 'No verificado',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: verified ? Colors.greenAccent : Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (verified) const Icon(Icons.verified, size: 18),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Rol: ${_roleLabel(role)}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Toca el avatar para cambiarlo.',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              TextField(
                controller: displayNameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre artístico', filled: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bioCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Bio', filled: true),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: country,
                items: const [
                  DropdownMenuItem(value: 'México', child: Text('México')),
                  DropdownMenuItem(value: 'Estados Unidos', child: Text('Estados Unidos')),
                  DropdownMenuItem(value: 'España', child: Text('España')),
                  DropdownMenuItem(value: 'Argentina', child: Text('Argentina')),
                  DropdownMenuItem(value: 'Chile', child: Text('Chile')),
                  DropdownMenuItem(value: 'Colombia', child: Text('Colombia')),
                  DropdownMenuItem(value: 'Perú', child: Text('Perú')),
                  DropdownMenuItem(value: 'Brasil', child: Text('Brasil')),
                  DropdownMenuItem(value: 'Alemania', child: Text('Alemania')),
                  DropdownMenuItem(value: 'Japón', child: Text('Japón')),
                ],
                onChanged: (v) => setState(() => country = v ?? country),
                decoration: const InputDecoration(labelText: 'País', filled: true),
              ),

              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: conspiracyId,
                items: conspiracies
                    .map((c) => DropdownMenuItem(
                  value: c['id'] as String,
                  child: Text(c['name'] as String),
                ))
                    .toList(),
                onChanged: (v) => setState(() => conspiracyId = v),
                decoration: const InputDecoration(labelText: 'Conspiración', filled: true),
              ),

              const SizedBox(height: 18),
              FilledButton(
                onPressed: saving ? null : saveProfile,
                child: Text(saving ? 'Guardando…' : 'Guardar cambios'),
              ),

              const SizedBox(height: 26),
              const Divider(),
              const SizedBox(height: 10),

              const Text('Verificación de artista', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),

              if (verified)
                Text('✅ Ya estás verificado.', style: TextStyle(color: Colors.greenAccent.withValues(alpha: 0.9)))
              else if (hasPending)
                Text('⏳ Solicitud pendiente. Te avisaremos.', style: TextStyle(color: Colors.white.withValues(alpha: 0.75)))
              else ...[
                  TextField(
                    controller: portfolioCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Link de portafolio (Behance/ArtStation/Drive/etc.)',
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notas (opcional)',
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: requestVerification,
                    child: const Text('Solicitar verificación'),
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }
}
