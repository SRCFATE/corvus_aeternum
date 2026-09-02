import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/rpc_error.dart';
import '../../core/theme/app_colors.dart';
import '../../models/picked_image.dart';
import '../../providers/auth_provider.dart';
import '../../services/profile_service.dart';
import '../../services/storage_service.dart';
import '../../shared/layout/corvus_page.dart';
import '../../shared/widgets/corvus_button.dart';
import '../../shared/widgets/corvus_text_field.dart';
import '../../shared/widgets/user_avatar.dart';

const _disciplines = [
  'Pintura',
  'Fotografía',
  'Escultura',
  'Ilustración',
  'Arte Digital',
  'Música',
  'Literatura',
  'Poesía',
  'Cine',
  'Diseño',
  'Grabado',
  'Cerámica',
  'Performance',
  'Otro',
];

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  late TextEditingController _countryController;
  late TextEditingController _websiteController;
  late TextEditingController _instagramController;

  final _profileService = ProfileService();
  final _storageService = StorageService();

  PickedImage? _newAvatar;
  PickedImage? _newBanner;
  late Set<String> _selectedDisciplines;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthProvider>().profile!;
    _displayNameController = TextEditingController(text: profile.displayName);
    _bioController = TextEditingController(text: profile.bio);
    _countryController = TextEditingController(text: profile.country ?? '');
    _websiteController = TextEditingController(text: profile.websiteUrl ?? '');
    _instagramController =
        TextEditingController(text: profile.instagramHandle ?? '');
    _selectedDisciplines = Set.from(profile.disciplines);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _countryController.dispose();
    _websiteController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/profile');
    }
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    final image = await PickedImage.read(picked);
    if (!mounted) return;

    setState(() => _newAvatar = image);
  }

  Future<void> _pickBanner() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    final image = await PickedImage.read(picked);
    if (!mounted) return;

    setState(() => _newBanner = image);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final profile = auth.profile!;
    setState(() => _isSaving = true);

    try {
      String? avatarUrl = profile.avatarUrl;
      String? bannerUrl = profile.bannerUrl;

      if (_newAvatar != null) {
        avatarUrl = await _storageService.uploadAvatar(_newAvatar!, profile.id);
      }
      if (_newBanner != null) {
        bannerUrl = await _storageService.uploadBanner(_newBanner!, profile.id);
      }

      final updated = await _profileService.updateProfile(profile.id, {
        'display_name': _displayNameController.text.trim(),
        'bio': _bioController.text.trim(),
        'country': _countryController.text.trim().isEmpty
            ? null
            : _countryController.text.trim(),
        'website_url': _websiteController.text.trim().isEmpty
            ? null
            : _websiteController.text.trim(),
        'instagram_handle': _instagramController.text.trim().isEmpty
            ? null
            : _instagramController.text.trim(),
        'disciplines': _selectedDisciplines.toList(),
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (bannerUrl != null) 'banner_url': bannerUrl,
      });

      auth.updateProfile(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado')),
        );
        _leave();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar perfil'),
        leading: IconButton(
          icon: const Icon(Icons.close, size: 20),
          onPressed: _leave,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CorvusButton(
              label: 'Guardar',
              isLoading: _isSaving,
              onPressed: _save,
            ),
          ),
        ],
      ),
      body: CorvusFormPage(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            children: [
              _buildAvatarSection(profile),
              const SizedBox(height: 28),
              CorvusTextField(
                controller: _displayNameController,
                label: 'Nombre a mostrar',
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Campo obligatorio' : null,
              ),
              const SizedBox(height: 16),
              CorvusTextField(
                controller: _bioController,
                label: 'Biografía',
                maxLines: 4,
                maxLength: 300,
              ),
              const SizedBox(height: 16),
              CorvusTextField(
                controller: _countryController,
                label: 'País',
                prefixIcon: const Icon(Icons.public_outlined),
              ),
              const SizedBox(height: 16),
              CorvusTextField(
                controller: _websiteController,
                label: 'Sitio web',
                hint: 'https://tuportafolio.com',
                keyboardType: TextInputType.url,
                prefixIcon: const Icon(Icons.link_outlined),
              ),
              const SizedBox(height: 16),
              CorvusTextField(
                controller: _instagramController,
                label: 'Instagram',
                hint: '@tuusuario',
                prefixIcon: const Icon(Icons.camera_alt_outlined),
              ),
              const SizedBox(height: 24),
              const Text(
                'Disciplinas',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _disciplines.map((d) {
                  final selected = _selectedDisciplines.contains(d);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (selected) {
                        _selectedDisciplines.remove(d);
                      } else {
                        _selectedDisciplines.add(d);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primaryMuted
                            : AppColors.overlay,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              selected ? AppColors.primary : AppColors.border,
                          width: selected ? 1.5 : 0.5,
                        ),
                      ),
                      child: Text(
                        d,
                        style: TextStyle(
                          color: selected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
              _UsernameChangeSection(profile: profile),
              const SizedBox(height: 28),
              _DangerZone(onDeleteAccount: _confirmDeleteAccount),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (confirmed != true || !mounted) return;

    final auth = context.read<AuthProvider>();
    final ok = await auth.deleteAccount();
    if (!mounted) return;

    if (ok) {
      context.go('/login');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Error al eliminar la cuenta.'),
          backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildAvatarSection(dynamic profile) {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickAvatar,
          child: Stack(
            children: [
              _newAvatar != null
                  ? CircleAvatar(
                      radius: 50,
                      backgroundImage: MemoryImage(_newAvatar!.bytes))
                  : UserAvatar(
                      imageUrl: profile.avatarUrl,
                      displayName: profile.displayName,
                      radius: 50),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt,
                      color: AppColors.background, size: 14),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _pickBanner,
          icon: const Icon(Icons.image_outlined, size: 16),
          label: Text(
            _newBanner != null ? 'Banner seleccionado ✓' : 'Cambiar banner',
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// USERNAME CHANGE SECTION
// ─────────────────────────────────────────────────────────────

// Validation: 3-30 chars, only lowercase letters/numbers/underscores/dots,
// starts and ends with alphanumeric, no consecutive special chars.
const _reservedUsernames = {
  'corvus',
  'admin',
  'moderator',
  'support',
  'help',
  'official',
  'team',
  'staff',
  'bot',
  'api',
  'system',
  'root',
  'cuervo',
  'crow',
  'null',
};

String? validateUsernameFormat(String value) {
  if (value.length < 3) {
    return 'Mínimo 3 caracteres';
  }
  if (value.length > 30) {
    return 'Máximo 30 caracteres';
  }
  if (!RegExp(r'^[a-z0-9]').hasMatch(value)) {
    return 'Debe comenzar con letra o número';
  }
  if (!RegExp(r'[a-z0-9]$').hasMatch(value)) {
    return 'Debe terminar con letra o número';
  }
  if (!RegExp(r'^[a-z0-9._]+$').hasMatch(value)) {
    return 'Solo letras minúsculas, números, . y _';
  }
  if (value.contains('..') ||
      value.contains('__') ||
      value.contains('._') ||
      value.contains('_.')) {
    return 'No puedes usar dos caracteres especiales seguidos';
  }
  if (_reservedUsernames.contains(value)) return 'Este @ está reservado';
  return null;
}

class _UsernameChangeSection extends StatelessWidget {
  final dynamic profile;
  const _UsernameChangeSection({required this.profile});

  String _formatDate(DateTime d) {
    const months = [
      '',
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic'
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final canChange = profile.canChangeUsername as bool;
    final nextDate = profile.nextUsernameChangeDate as DateTime?;
    final daysLeft =
        nextDate != null ? nextDate.difference(DateTime.now()).inDays + 1 : 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Text(
              '@ IDENTIFICADOR',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.28),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Container(
                    height: 0.5, color: Colors.white.withValues(alpha: 0.07))),
          ]),
          const SizedBox(height: 14),

          // Current username
          Row(children: [
            Text(
              '@${profile.username}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: '@${profile.username}'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('@ copiado')),
                );
              },
              child: Icon(Icons.copy_rounded,
                  size: 14, color: Colors.white.withValues(alpha: 0.25)),
            ),
          ]),
          const SizedBox(height: 14),

          // Status
          if (!canChange) ...[
            Row(
              children: [
                Icon(Icons.schedule_rounded,
                    size: 14, color: Colors.white.withValues(alpha: 0.35)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Disponible el ${_formatDate(nextDate!)} (en $daysLeft días)',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.40),
                        fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ] else ...[
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Disponible para cambiar',
                  style: TextStyle(
                      color: AppColors.success.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.alternate_email_rounded, size: 15),
                label: const Text('Cambiar @'),
                onPressed: () => _openDialog(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          Text(
            'Solo puedes cambiar tu @ una vez por año.',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.25), fontSize: 11),
          ),
        ],
      ),
    );
  }

  void _openDialog(BuildContext context) async {
    final updated = await showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UsernameChangeDialog(profile: profile),
    );
    if (updated != null && context.mounted) {
      context.read<AuthProvider>().updateProfile(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('@ cambiado a @${updated.username}')),
      );
    }
  }
}

// ─── Username change dialog ───────────────────────────────────────────────────

class _UsernameChangeDialog extends StatefulWidget {
  final dynamic profile;
  const _UsernameChangeDialog({required this.profile});

  @override
  State<_UsernameChangeDialog> createState() => _UsernameChangeDialogState();
}

enum _AvailabilityState { idle, checking, available, unavailable, invalid }

class _UsernameChangeDialogState extends State<_UsernameChangeDialog> {
  final _controller = TextEditingController();
  final _profileService = ProfileService();
  Timer? _debounce;

  _AvailabilityState _availability = _AvailabilityState.idle;
  String? _formatError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    final value = _controller.text;

    if (value.isEmpty) {
      setState(() {
        _availability = _AvailabilityState.idle;
        _formatError = null;
      });
      return;
    }

    final formatError = validateUsernameFormat(value);
    if (formatError != null) {
      setState(() {
        _availability = _AvailabilityState.invalid;
        _formatError = formatError;
      });
      return;
    }

    if (value == widget.profile.username) {
      setState(() {
        _availability = _AvailabilityState.invalid;
        _formatError = 'Es el mismo @ que el actual';
      });
      return;
    }

    setState(() {
      _availability = _AvailabilityState.checking;
      _formatError = null;
    });

    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final error = await _profileService.checkUsernameAvailability(value);
      if (!mounted) return;
      setState(() {
        _availability = error == null
            ? _AvailabilityState.available
            : _AvailabilityState.unavailable;
        _formatError = error;
      });
    });
  }

  bool get _canSubmit =>
      _availability == _AvailabilityState.available && !_isSaving;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final newUsername = _controller.text.trim();
    setState(() => _isSaving = true);

    try {
      final updated = await _profileService.changeUsername(newUsername);
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on CorvusRpcException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _formatError = e.message;
        _availability = _AvailabilityState.unavailable;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _formatError = 'No se pudo cambiar el @: $e';
        _availability = _AvailabilityState.unavailable;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _canSubmit;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        const Icon(Icons.alternate_email_rounded,
            color: AppColors.primary, size: 20),
        const SizedBox(width: 10),
        const Text('Cambiar @',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800)),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current username
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Text('Actual: ',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 12)),
              Text(
                '@${widget.profile.username}',
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Input field
          TextField(
            controller: _controller,
            autofocus: true,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700),
            inputFormatters: [
              _LowercaseInputFormatter(),
              FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9._]')),
              LengthLimitingTextInputFormatter(30),
            ],
            decoration: InputDecoration(
              prefixText: '@',
              prefixStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.40),
                  fontSize: 15,
                  fontWeight: FontWeight.w700),
              hintText: 'nuevo_username',
              hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.20), fontSize: 15),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.10)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.10)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _borderColor()),
              ),
              suffixIcon: _buildSuffixIcon(),
            ),
          ),

          // Status / error line
          const SizedBox(height: 8),
          _buildStatusLine(),

          const SizedBox(height: 16),

          // Warning
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.20)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 14, color: Colors.amber.withValues(alpha: 0.70)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Este cambio es definitivo. No podrás recuperar tu @ actual ni cambiarlo de nuevo hasta dentro de un año.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.50),
                        fontSize: 11,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(null),
          child: Text('Cancelar',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontWeight: FontWeight.w600)),
        ),
        TextButton(
          onPressed: canSubmit ? _submit : null,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary))
              : Text(
                  'Confirmar cambio',
                  style: TextStyle(
                    color: canSubmit
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.20),
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ],
    );
  }

  Color _borderColor() {
    switch (_availability) {
      case _AvailabilityState.available:
        return AppColors.success;
      case _AvailabilityState.unavailable:
      case _AvailabilityState.invalid:
        return AppColors.error;
      default:
        return AppColors.borderFocus;
    }
  }

  Widget _buildSuffixIcon() {
    switch (_availability) {
      case _AvailabilityState.checking:
        return const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.textSecondary)),
        );
      case _AvailabilityState.available:
        return Icon(Icons.check_circle_rounded,
            color: AppColors.success, size: 20);
      case _AvailabilityState.unavailable:
      case _AvailabilityState.invalid:
        return Icon(Icons.cancel_rounded, color: AppColors.error, size: 20);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStatusLine() {
    switch (_availability) {
      case _AvailabilityState.available:
        return Row(children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 13, color: AppColors.success),
          const SizedBox(width: 5),
          Text('Disponible',
              style: TextStyle(
                  color: AppColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]);
      case _AvailabilityState.unavailable:
      case _AvailabilityState.invalid:
        return Row(children: [
          Icon(Icons.error_outline_rounded, size: 13, color: AppColors.error),
          const SizedBox(width: 5),
          Expanded(
              child: Text(_formatError ?? 'No disponible',
                  style: TextStyle(color: AppColors.error, fontSize: 12))),
        ]);
      case _AvailabilityState.checking:
        return Text(
          'Verificando disponibilidad…',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.30), fontSize: 12),
        );
      default:
        return Text(
          '3–30 caracteres · solo minúsculas, números, _ y .',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.22), fontSize: 11),
        );
    }
  }
}

class _LowercaseInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
          TextEditingValue _, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toLowerCase());
}

// ─────────────────────────────────────────────────────────────
// DANGER ZONE
// ─────────────────────────────────────────────────────────────

class _DangerZone extends StatelessWidget {
  final VoidCallback onDeleteAccount;
  const _DangerZone({required this.onDeleteAccount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.redAccent.withValues(alpha: 0.80), size: 18),
              const SizedBox(width: 8),
              Text(
                'Zona de peligro',
                style: TextStyle(
                  color: Colors.redAccent.withValues(alpha: 0.90),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Eliminar tu cuenta borrará permanentemente tu perfil, obras y datos. Esta acción no se puede deshacer.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.52),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onDeleteAccount,
              icon: const Icon(Icons.delete_forever_rounded, size: 16),
              label: const Text('Eliminar cuenta'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side:
                    BorderSide(color: Colors.redAccent.withValues(alpha: 0.50)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DIÁLOGO DE CONFIRMACIÓN
// ─────────────────────────────────────────────────────────────

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();
  bool _canConfirm = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final ok = _controller.text.trim() == 'ELIMINAR';
      if (ok != _canConfirm) setState(() => _canConfirm = ok);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.delete_forever_rounded,
              color: Colors.redAccent.withValues(alpha: 0.85), size: 22),
          const SizedBox(width: 10),
          const Text(
            '¿Eliminar cuenta?',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Esta acción es irreversible. Se eliminarán tu perfil, obras y todos tus datos de Corvus.',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.60),
                fontSize: 13,
                height: 1.5),
          ),
          const SizedBox(height: 20),
          Text(
            'Escribe ELIMINAR para confirmar:',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.70),
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: 'ELIMINAR',
              hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25), fontSize: 14),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.10)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.10)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: Colors.redAccent.withValues(alpha: 0.50)),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancelar',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w600)),
        ),
        TextButton(
          onPressed: _canConfirm ? () => Navigator.of(context).pop(true) : null,
          child: Text(
            'Eliminar cuenta',
            style: TextStyle(
              color: _canConfirm
                  ? Colors.redAccent
                  : Colors.white.withValues(alpha: 0.20),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
