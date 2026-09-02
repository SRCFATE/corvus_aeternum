import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/corvus_design.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets/corvus_button.dart';
import '../../shared/widgets/corvus_text_field.dart';
import '../../services/auth_service.dart';
import 'auth_chrome.dart';

/// Recuperación de contraseña en dos pasos.
///
/// No se usa enlace mágico a propósito: Corvus corre en escritorio, donde el
/// enlace del correo abriría el navegador y nunca volvería a la app. En su
/// lugar se canjea el código del correo —o el enlace pegado— por una sesión
/// temporal con la que se fija la nueva contraseña.
class RecoverPasswordPage extends StatefulWidget {
  final String? initialEmail;

  const RecoverPasswordPage({super.key, this.initialEmail});

  @override
  State<RecoverPasswordPage> createState() => _RecoverPasswordPageState();
}

enum _Step { request, verify }

class _RecoverPasswordPageState extends State<RecoverPasswordPage> {
  final _requestFormKey = GlobalKey<FormState>();
  final _verifyFormKey = GlobalKey<FormState>();

  late final _emailController =
      TextEditingController(text: widget.initialEmail ?? '');
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  _Step _step = _Step.request;
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ─── Acciones ───────────────────────────────────────────────────────────────

  Future<void> _requestCode() async {
    if (!_requestFormKey.currentState!.validate()) return;
    setState(() => _busy = true);

    final auth = context.read<AuthProvider>();
    final ok = await auth.requestPasswordReset(_emailController.text);

    if (!mounted) return;
    setState(() {
      _busy = false;
      // Se avanza siempre: confirmar si el correo existe sería una fuga.
      if (ok) _step = _Step.verify;
    });

    if (ok) {
      _message(
        'Si esa dirección está en el archivo, recibirás un código para continuar.',
      );
    } else if (auth.error != null) {
      _message(auth.error!, isError: true);
      auth.clearError();
    }
  }

  Future<void> _completeReset() async {
    if (!_verifyFormKey.currentState!.validate()) return;
    setState(() => _busy = true);

    final auth = context.read<AuthProvider>();
    final router = GoRouter.of(context);

    final ok = await auth.completePasswordReset(
      email: _emailController.text,
      code: _codeController.text,
      newPassword: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      _message('Contraseña actualizada. Bienvenido de vuelta.');
      router.go('/discover');
    } else if (auth.error != null) {
      _message(auth.error!, isError: true);
      auth.clearError();
    }
  }

  void _message(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: isError
          ? Colors.redAccent.withValues(alpha: 0.9)
          : AppColors.cardElevated,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 820;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const AuthBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(CorvusSpacing.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: isWide
                      ? Row(
                          children: [
                            const Expanded(
                              child: Center(
                                child: AuthBrandPanel(
                                  title: 'RECUPERA\nTU ACCESO',
                                  subtitle:
                                      'El archivo no olvida a los suyos. Verifica tu correo y vuelve a entrar.',
                                ),
                              ),
                            ),
                            const SizedBox(width: 28),
                            Expanded(child: _buildCard()),
                          ],
                        )
                      : _buildCard(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return AuthGlassCard(
      child: AnimatedSize(
        duration: CorvusMotion.medium,
        curve: CorvusMotion.standard,
        alignment: Alignment.topCenter,
        child: _step == _Step.request ? _buildRequestStep() : _buildVerifyStep(),
      ),
    );
  }

  // Paso 1 — pedir el código
  Widget _buildRequestStep() {
    return Form(
      key: _requestFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(
            eyebrow: 'PASO 1 DE 2',
            title: '¿Olvidaste tu contraseña?',
            subtitle:
                'Escribe el correo con el que entraste al archivo y te enviaremos un código para recuperarlo.',
          ),
          const SizedBox(height: CorvusSpacing.xl),
          CorvusTextField(
            controller: _emailController,
            label: 'Correo',
            hint: 'tu@correo.com',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.mail_outline_rounded),
            validator: _validateEmail,
          ),
          const SizedBox(height: CorvusSpacing.xl),
          CorvusButton(
            label: 'Enviar código',
            isLoading: _busy,
            onPressed: _busy ? null : _requestCode,
            width: double.infinity,
          ),
          const SizedBox(height: CorvusSpacing.md),
          Center(
            child: TextButton(
              onPressed: () => _step == _Step.request && !_busy
                  ? (context.canPop() ? context.pop() : context.go('/login'))
                  : null,
              child: const Text('Volver a iniciar sesión'),
            ),
          ),
          const SizedBox(height: CorvusSpacing.sm),
          Center(
            child: TextButton(
              onPressed:
                  _busy ? null : () => setState(() => _step = _Step.verify),
              child: Text(
                'Ya tengo un código',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Paso 2 — canjear el código y fijar la nueva contraseña
  Widget _buildVerifyStep() {
    return Form(
      key: _verifyFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(
            eyebrow: 'PASO 2 DE 2',
            title: 'Escribe tu nueva contraseña',
            subtitle:
                'Revisa tu correo: escribe el código de 8 caracteres que te enviamos. Caduca en 15 minutos.',
          ),
          const SizedBox(height: CorvusSpacing.lg),
          Container(
            padding: const EdgeInsets.all(CorvusSpacing.md),
            decoration: BoxDecoration(
              color: CorvusSurfaces.fill(CorvusSurfaces.fillBase),
              borderRadius: BorderRadius.circular(CorvusRadius.md),
              border: Border.all(
                  color: CorvusSurfaces.fill(CorvusSurfaces.borderBase)),
            ),
            child: Row(
              children: [
                Icon(Icons.mark_email_read_outlined,
                    size: 16, color: Colors.white.withValues(alpha: 0.40)),
                const SizedBox(width: CorvusSpacing.sm),
                Expanded(
                  child: Text(
                    _emailController.text.trim().isEmpty
                        ? 'Correo sin especificar'
                        : _emailController.text.trim(),
                    style: CorvusType.muted,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed:
                      _busy ? null : () => setState(() => _step = _Step.request),
                  child: const Text('Cambiar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: CorvusSpacing.lg),
          CorvusTextField(
            controller: _codeController,
            label: 'Código de recuperación',
            hint: 'ABCD2345',
            prefixIcon: const Icon(Icons.key_outlined),
            textCapitalization: TextCapitalization.characters,
            validator: (v) {
              final clean = AuthService.normalizeRecoveryCode(v ?? '');
              if (clean.isEmpty) return 'Escribe el código que recibiste';
              if (clean.length != 8) return 'El código tiene 8 caracteres';
              return null;
            },
          ),
          const SizedBox(height: CorvusSpacing.lg),
          CorvusTextField(
            controller: _passwordController,
            label: 'Nueva contraseña',
            obscureText: _obscure,
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(_obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            validator: (v) => (v == null || v.length < 6)
                ? 'Usa al menos 6 caracteres'
                : null,
          ),
          const SizedBox(height: CorvusSpacing.lg),
          CorvusTextField(
            controller: _confirmController,
            label: 'Repite la contraseña',
            obscureText: _obscure,
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            validator: (v) => v != _passwordController.text
                ? 'Las contraseñas no coinciden'
                : null,
          ),
          const SizedBox(height: CorvusSpacing.xl),
          CorvusButton(
            label: 'Cambiar contraseña',
            isLoading: _busy,
            onPressed: _busy ? null : _completeReset,
            width: double.infinity,
          ),
          const SizedBox(height: CorvusSpacing.md),
          Center(
            child: TextButton(
              onPressed: _busy ? null : _requestCode,
              child: const Text('Enviar otro código'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header({
    required String eyebrow,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(eyebrow, style: CorvusType.eyebrow(AppColors.primary)),
        const SizedBox(height: CorvusSpacing.sm),
        Text(title, style: CorvusType.title),
        const SizedBox(height: CorvusSpacing.sm),
        Text(subtitle, style: CorvusType.body),
      ],
    );
  }

  static String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa tu correo';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
      return 'Ese correo no parece válido';
    }
    return null;
  }
}

/// Atajo para abrir la recuperación arrastrando el correo ya escrito.
void goToPasswordRecovery(BuildContext context, {String? email}) {
  final trimmed = email?.trim() ?? '';
  context.push(
    trimmed.isEmpty
        ? '/recover'
        : '/recover?email=${Uri.encodeQueryComponent(trimmed)}',
  );
}
