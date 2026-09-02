import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets/corvus_button.dart';
import '../../shared/widgets/corvus_text_field.dart';
import 'auth_chrome.dart';

class RegisterPage extends StatefulWidget {
  /// Destino que arrastra el visitante desde el login, para volver ahí una vez
  /// creado el perfil.
  final String? redirectTo;

  const RegisterPage({super.key, this.redirectTo});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();

    final ok = await auth.signUp(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (ok) {
      final target = widget.redirectTo;
      context.go(
        target == null
            ? '/create-profile'
            : '/create-profile?redirect=${Uri.encodeComponent(target)}',
      );
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

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';

    if (v.isEmpty) return 'Ingresa tu correo';

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!emailRegex.hasMatch(v)) return 'Correo inválido';

    return null;
  }

  int _passwordStrength(String value) {
    int score = 0;

    if (value.length >= 6) score++;
    if (value.length >= 10) score++;
    if (RegExp(r'[A-Z]').hasMatch(value)) score++;
    if (RegExp(r'[0-9]').hasMatch(value)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=]').hasMatch(value)) score++;

    return score.clamp(0, 5);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 860;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const AuthBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: isWide
                      ? Row(
                          children: [
                            const Expanded(
                              child: AuthBrandPanel(
                                title: 'ÚNETE AL\nARCHIVO',
                                subtitle:
                                    'Registra tu obra, elige tu conspiración y deja huella en el legado.',
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(child: _RegisterCard(form: _buildForm())),
                          ],
                        )
                      : _RegisterCard(form: _buildForm()),
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
          final password = _passwordController.text;
          final strength = _passwordStrength(password);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: auth.isLoading ? null : () => context.go('/login'),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 18),
              const _MobileLogo(),
              const SizedBox(height: 28),
              const Text(
                'Crear cuenta',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'El primer paso hacia el legado.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.46),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 34),
              CorvusTextField(
                controller: _emailController,
                label: 'Correo electrónico',
                hint: 'tu@correo.com',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.mail_outline_rounded),
                textInputAction: TextInputAction.next,
                validator: _validateEmail,
              ),
              const SizedBox(height: 16),
              CorvusTextField(
                controller: _passwordController,
                label: 'Contraseña',
                hint: 'Mínimo 6 caracteres',
                obscureText: _obscurePassword,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Ingresa una contraseña';
                  if (v.length < 6) return 'Mínimo 6 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              _PasswordStrength(score: strength),
              const SizedBox(height: 16),
              CorvusTextField(
                controller: _confirmController,
                label: 'Confirmar contraseña',
                hint: 'Repite tu contraseña',
                obscureText: _obscureConfirm,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _register(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() => _obscureConfirm = !_obscureConfirm);
                  },
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Confirma tu contraseña';
                  if (v != _passwordController.text) {
                    return 'Las contraseñas no coinciden';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),
              CorvusButton(
                label: 'Crear cuenta',
                isLoading: auth.isLoading,
                onPressed: auth.isLoading ? null : _register,
                width: double.infinity,
              ),
              const SizedBox(height: 22),
              Center(
                child: TextButton(
                  onPressed: auth.isLoading ? null : () => context.go('/login'),
                  child: const Text.rich(
                    TextSpan(
                      text: '¿Ya tienes cuenta? ',
                      style: TextStyle(color: AppColors.textSecondary),
                      children: [
                        TextSpan(
                          text: 'Acceder',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PasswordStrength extends StatelessWidget {
  final int score;

  const _PasswordStrength({
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    final label = switch (score) {
      0 || 1 => 'Débil',
      2 || 3 => 'Media',
      _ => 'Fuerte',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(5, (i) {
            final active = i < score;

            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 4,
                margin: EdgeInsets.only(right: i < 4 ? 5 : 0),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          'Seguridad: $label',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.38),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _RegisterCard extends StatelessWidget {
  final Widget form;

  const _RegisterCard({required this.form});

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
          child: form,
        ),
      ),
    );
  }
}

class _MobileLogo extends StatelessWidget {
  const _MobileLogo();

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 860;
    if (isWide) return const SizedBox.shrink();

    return const _LogoBlock(compact: true);
  }
}

class _LogoBlock extends StatelessWidget {
  final bool compact;

  const _LogoBlock({this.compact = false});

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
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.30)),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CORVUS',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.2,
              ),
            ),
            Text(
              'AETERNUM',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                letterSpacing: 3.4,
              ),
            ),
          ],
        ),
      ],
    );
  }
}


