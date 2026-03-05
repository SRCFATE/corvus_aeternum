import 'package:flutter/material.dart';

import 'signup_role.dart';
import 'register_page.dart';

class RoleSelectPage extends StatelessWidget {
  const RoleSelectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear cuenta'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 12),

              const Text(
                'Elige tu rol',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Esto define tu experiencia inicial dentro de Corvus Aeternum.\n'
                    'Podrás evolucionar más adelante.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 28),

              // 🐦 CUERVO
              _RoleCard(
                icon: Icons.auto_awesome,
                title: '🐦 Cuervo (Artista)',
                subtitle: 'Publica. Construye legado. Despierta una Conspiración.',
                description:
                '• Publicar obras\n'
                    '• Editar portafolio\n'
                    '• Participar en subastas\n'
                    '• Activar piezas limitadas\n'
                    '• Ver métricas internas\n\n'
                    'No puedes votar por ti mismo ni comprar tu propia obra.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegisterPage(
                        role: SignupRole.crow,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 18),

              // 🪶 COLECCIONISTA
              _RoleCard(
                icon: Icons.collections_bookmark_rounded,
                title: '🪶 Coleccionista',
                subtitle: 'Descubre. Apoya. Conserva.',
                description:
                '• Guardar obras\n'
                    '• Crear Colecciones Curadas\n'
                    '• Seguir artistas\n'
                    '• Comentar y votar\n'
                    '• Participar en subastas\n'
                    '• Historial de compras\n\n'
                    'Sostiene el ecosistema cultural.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegisterPage(
                        role: SignupRole.collector,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF151821),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 14),

            Text(
              description,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
