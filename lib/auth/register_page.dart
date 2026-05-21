// lib/auth/register_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'signup_role.dart';
import 'create_profile_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.role});
  final SignupRole role;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final pass2Ctrl = TextEditingController();

  bool loading = false;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    pass2Ctrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _signup() async {
    final email = emailCtrl.text.trim();
    final pass = passCtrl.text;
    final pass2 = pass2Ctrl.text;

    if (email.isEmpty || pass.isEmpty) {
      _toast('Completa correo y contraseña.');
      return;
    }
    if (pass.length < 8) {
      _toast('La contraseña debe tener al menos 8 caracteres.');
      return;
    }
    if (pass != pass2) {
      _toast('Las contraseñas no coinciden.');
      return;
    }

    setState(() => loading = true);
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: pass,
        data: {
          // ✅ guardado en auth.users.user_metadata
          'signup_role': widget.role.name, // siempre 'crow'
        },
      );

      if (!mounted) return;

      if (res.user == null) {
        _toast('No se pudo crear usuario.');
        return;
      }

      // Nota: si tienes confirmación por email activada, `res.session` puede ser null.
      // Aun así, AuthGate decidirá qué mostrar cuando la sesión exista.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CreateProfilePage(role: widget.role),
        ),
      );
    } on AuthException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('Error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Únete como Cuervo')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Text(
                'Corvus Aeternum es un santuario para artistas.\n'
                'Al unirte despiertas como Cuervo: publicas, archivas y convocas obra.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo',
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  helperText: 'Mínimo 8 caracteres',
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: pass2Ctrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmar contraseña',
                ),
              ),
              const SizedBox(height: 18),

              FilledButton(
                onPressed: loading ? null : _signup,
                child: Text(loading ? 'Creando...' : 'Crear cuenta'),
              ),

              const SizedBox(height: 12),
              Text(
                'Al crear tu cuenta aceptas los Términos y la Política de Privacidad.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
