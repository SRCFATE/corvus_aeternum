import 'package:flutter/material.dart';

/// Pantallas principales — Explorar, Artistas, Colecciones, Subastas
/// maxWidth: 1400 · horizontal: 40
class CorvusPage extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const CorvusPage({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 40),
  });

  static const double maxWidth = 1400;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Páginas de lectura — Perfil, Obra, Colección
/// maxWidth: 1000 · horizontal: 48 · vertical: 32
class CorvusReadingPage extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const CorvusReadingPage({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
  });

  static const double maxWidth = 1000;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Páginas de formulario — Publicar obra, Crear colección, Editar perfil
/// maxWidth: 1200 · horizontal: 32
class CorvusFormPage extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const CorvusFormPage({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 32),
  });

  static const double maxWidth = 1200;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
