import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets/corvus_button.dart';
import '../../shared/widgets/corvus_text_field.dart';

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

class CreateProfilePage extends StatefulWidget {
  /// Último tramo del destino que arrastraba el visitante desde el login.
  final String? redirectTo;

  const CreateProfilePage({super.key, this.redirectTo});

  @override
  State<CreateProfilePage> createState() => _CreateProfilePageState();
}

class _CreateProfilePageState extends State<CreateProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _countryController = TextEditingController();

  final Set<String> _selectedDisciplines = {};

  int _step = 0;

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final isValid = _formKey.currentState?.validate()??false;
    if (!isValid) return;

    final auth = context.read<AuthProvider>();

    final ok = await auth.createProfile(
      username: _usernameController.text.trim().toLowerCase(),
      displayName: _displayNameController.text.trim(),
      bio: _bioController.text.trim(),
      disciplines: _selectedDisciplines.toList(),
      country: _countryController.text.trim().isEmpty
          ? null
          : _countryController.text.trim(),
    );

    if (!mounted) return;

    if (ok) {
      context.go(widget.redirectTo ?? '/discover');
    } else if (auth.error != null) {
      _showError(auth.error!);
      auth.clearError();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.card,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _validateStep0() {
    return _formKey.currentState?.validate() ?? false;
  }

  bool _validateStep1() {
    if (_selectedDisciplines.isEmpty) {
      _showError('Selecciona al menos una disciplina');
      return false;
    }

    if (_selectedDisciplines.length > 5) {
      _showError('Selecciona máximo 5 disciplinas principales');
      return false;
    }

    return _formKey.currentState?.validate() ?? false;
  }

  void _next() {
    if (_step == 0 && _validateStep0()) {
      setState(() => _step = 1);
    } else if (_step == 1 && _validateStep1()) {
      _finish();
    }
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 920;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const _ProfileBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: isWide
                      ? Row(
                          children: [
                            Expanded(
                              child: _SidePanel(
                                step: _step,
                                selectedDisciplines: _selectedDisciplines,
                                displayName: _displayNameController.text,
                                username: _usernameController.text,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _ProfileCard(
                                child: _buildForm(),
                              ),
                            ),
                          ],
                        )
                      : _ProfileCard(
                          child: _buildForm(),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Consumer<AuthProvider>(
        builder: (_, auth, __) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProgressHeader(step: _step),
              const SizedBox(height: 30),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: _step == 0 ? _buildStep0() : _buildStep1(),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  if (_step > 0) ...[
                    Expanded(
                      child: CorvusButton(
                        label: 'Atrás',
                        outlined: true,
                        onPressed: auth.isLoading ? null : _back,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: CorvusButton(
                      label: _step == 0 ? 'Continuar' : 'Ingresar al archivo',
                      isLoading: auth.isLoading,
                      onPressed: auth.isLoading ? null : _next,
                      width: double.infinity,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStep0() {
    return Column(
      key: const ValueKey('step0'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tu identidad\nen Corvus',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            height: 1.05,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Elige cómo quieres aparecer dentro del archivo.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.46),
            fontSize: 15,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 34),
        CorvusTextField(
          controller: _usernameController,
          label: 'Nombre de usuario',
          hint: 'tuusuario',
          prefixIcon: const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              '@',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
          validator: (v) {
            final value = v?.trim().toLowerCase() ?? '';

            if (value.isEmpty) return 'Elige un nombre de usuario';
            if (value.length < 3) return 'Mínimo 3 caracteres';
            if (value.length > 30) return 'Máximo 30 caracteres';

            if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(value)) {
              return 'Solo letras, números, guiones y guiones bajos';
            }

            return null;
          },
        ),
        const SizedBox(height: 16),
        CorvusTextField(
          controller: _displayNameController,
          label: 'Nombre a mostrar',
          hint: 'Tu nombre artístico',
          prefixIcon: const Icon(Icons.person_outline_rounded),
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
          validator: (v) {
            final value = v?.trim() ?? '';

            if (value.isEmpty) return 'Ingresa tu nombre';
            if (value.length < 2) return 'Mínimo 2 caracteres';

            return null;
          },
        ),
        const SizedBox(height: 16),
        CorvusTextField(
          controller: _countryController,
          label: 'País',
          hint: 'México, España...',
          prefixIcon: const Icon(Icons.public_outlined),
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      key: const ValueKey('step1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tu práctica\nartística',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            height: 1.05,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Cuéntanos qué creas. Puedes elegir hasta 5 disciplinas principales.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.46),
            fontSize: 15,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 34),
        CorvusTextField(
          controller: _bioController,
          label: 'Biografía',
          hint: 'Cuéntanos sobre tu obra, tu estilo o tu visión...',
          maxLines: 4,
          maxLength: 300,
          validator: (v) {
            final value = v?.trim() ?? '';

            if (value.length > 300) return 'Máximo 300 caracteres';

            return null;
          },
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Text(
              'Disciplinas',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              '${_selectedDisciplines.length}/5',
              style: TextStyle(
                color: _selectedDisciplines.length > 5
                    ? Colors.redAccent
                    : Colors.white.withValues(alpha: 0.44),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: _disciplines.map((d) {
            final selected = _selectedDisciplines.contains(d);

            return _DisciplineChip(
              label: d,
              selected: selected,
              onTap: () {
                setState(() {
                  if (selected) {
                    _selectedDisciplines.remove(d);
                  } else {
                    _selectedDisciplines.add(d);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final int step;

  const _ProgressHeader({
    required this.step,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _LogoBlock(),
        const SizedBox(height: 28),
        Row(
          children: List.generate(2, (i) {
            final active = i <= step;

            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                height: 4,
                margin: EdgeInsets.only(right: i == 0 ? 8 : 0),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.30),
                            blurRadius: 12,
                          ),
                        ]
                      : [],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Text(
          'Paso ${step + 1} de 2',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.40),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final Widget child;

  const _ProfileCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SidePanel extends StatelessWidget {
  final int step;
  final Set<String> selectedDisciplines;
  final String displayName;
  final String username;

  const _SidePanel({
    required this.step,
    required this.selectedDisciplines,
    required this.displayName,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    final cleanName = displayName.trim().isEmpty ? 'Nuevo artista' : displayName.trim();
    final cleanUsername = username.trim().isEmpty ? 'usuario' : username.trim();

    return Container(
      height: 620,
      padding: const EdgeInsets.all(34),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.20),
            AppColors.card,
            AppColors.surface,
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _LogoBlock(),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.16),
                  child: Text(
                    cleanName[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  cleanName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@$cleanUsername',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                if (selectedDisciplines.isEmpty)
                  Text(
                    'Tus disciplinas aparecerán aquí.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.34),
                      fontSize: 12,
                    ),
                  )
                else
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: selectedDisciplines.take(5).map((d) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Text(
                          d,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Text(
            step == 0
                ? 'Primero definimos tu identidad pública.'
                : 'Ahora definimos tu territorio creativo.',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.08,
              letterSpacing: -0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _DisciplineChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DisciplineChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_DisciplineChip> createState() => _DisciplineChipState();
}

class _DisciplineChipState extends State<_DisciplineChip> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || hovered;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.primary
                : Colors.white.withValues(alpha: hovered ? 0.08 : 0.045),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: widget.selected
                  ? AppColors.primary
                  : Colors.white.withValues(alpha: active ? 0.16 : 0.08),
            ),
            boxShadow: widget.selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.selected) ...[
                const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: AppColors.background,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.selected
                      ? AppColors.background
                      : Colors.white.withValues(alpha: 0.66),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoBlock extends StatelessWidget {
  const _LogoBlock();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.30),
            ),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.primary,
            size: 23,
          ),
        ),
        const SizedBox(width: 13),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CORVUS',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 3.2,
                height: 1,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'AETERNUM',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 3.8,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileBackground extends StatelessWidget {
  const _ProfileBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -140,
          right: -110,
          child: _Glow(
            size: 380,
            color: AppColors.primary.withValues(alpha: 0.12),
          ),
        ),
        Positioned(
          bottom: -120,
          left: -90,
          child: _Glow(
            size: 320,
            color: AppColors.secondary.withValues(alpha: 0.09),
          ),
        ),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final Color color;

  const _Glow({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
        ),
      ),
    );
  }
}
