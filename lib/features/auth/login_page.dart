import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets/corvus_button.dart';
import '../../shared/widgets/corvus_text_field.dart';
import 'auth_chrome.dart';
import 'recover_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();

    final ok = await auth.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (ok) {
      context.go('/feed');
    } else if (auth.error != null) {
      _showError(auth.error!);
      auth.clearError();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: isWide ? _wideLayout() : _compactLayout(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Center(
            child: AuthBrandPanel(
              title: 'CORVUS\nAETERNUM',
              subtitle: 'El archivo vivo de artistas, obras y legado.',
            ),
          ),
        ),
        const SizedBox(width: 28),
        Expanded(
          child: _LoginCard(
            formKey: _formKey,
            emailController: _emailController,
            passwordController: _passwordController,
            obscurePassword: _obscurePassword,
            onTogglePassword: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
            onLogin: _login,
          ),
        ),
      ],
    );
  }

  Widget _compactLayout() {
    return _LoginCard(
      formKey: _formKey,
      emailController: _emailController,
      passwordController: _passwordController,
      obscurePassword: _obscurePassword,
      onTogglePassword: () {
        setState(() => _obscurePassword = !_obscurePassword);
      },
      onLogin: _login,
      showLogo: true,
    );
  }
}

class _LoginCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;
  final bool showLogo;

  const _LoginCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.onLogin,
    this.showLogo = false,
  });

  @override
  Widget build(BuildContext context) {
    return AuthGlassCard(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showLogo) ...[
              const AuthMiniLogo(),
              const SizedBox(height: 34),
            ],
            const Text(
              'Acceder',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Entra al archivo. Tu obra te espera.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.48),
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 34),
            CorvusTextField(
              controller: emailController,
              label: 'Correo electrónico',
              hint: 'tu@correo.com',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: const Icon(Icons.mail_outline_rounded),
              textInputAction: TextInputAction.next,
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return 'Ingresa tu correo';
                final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
                if (!valid) return 'Ingresa un correo válido';
                return null;
              },
            ),
            const SizedBox(height: 16),
            CorvusTextField(
              controller: passwordController,
              label: 'Contraseña',
              obscureText: obscurePassword,
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onLogin(),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: onTogglePassword,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
                return null;
              },
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                // Arrastra el correo ya escrito para no pedirlo dos veces.
                onPressed: () => goToPasswordRecovery(
                  context,
                  email: emailController.text,
                ),
                child: Text(
                  '¿Olvidaste tu contraseña?',
                  style: TextStyle(
                    color: AppColors.primary.withValues(alpha: 0.82),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Consumer<AuthProvider>(
              builder: (_, auth, __) => CorvusButton(
                label: 'Entrar',
                isLoading: auth.isLoading,
                onPressed: auth.isLoading ? null : onLogin,
                width: double.infinity,
              ),
            ),
            const SizedBox(height: 22),
            Center(
              child: TextButton(
                onPressed: () => context.push('/register'),
                child: const Text.rich(
                  TextSpan(
                    text: '¿No tienes cuenta? ',
                    style: TextStyle(color: AppColors.textSecondary),
                    children: [
                      TextSpan(
                        text: 'Regístrate',
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
        ),
      ),
    );
  }
}
