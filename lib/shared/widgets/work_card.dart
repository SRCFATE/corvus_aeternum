import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'add_to_collection_sheet.dart';
import '../../core/theme/app_colors.dart';
import '../../models/work.dart';
import '../../core/theme/corvus_design.dart';
import 'corvus_motion.dart';
import 'user_avatar.dart';

/// Tarjeta de obra en modo grid — imagen dominante con overlay.
///
/// La lámina manda: la tarjeta es una portada con un pie de foto, no un panel
/// con controles encima. El título va en serif —como en un catálogo— y todo
/// lo que no es la obra baja de contraste hasta que se pasa el cursor.
class WorkCard extends StatefulWidget {
  final Work work;
  final VoidCallback? onLike;
  final bool isLiked;
  final bool isNew;

  const WorkCard({
    super.key,
    required this.work,
    this.onLike,
    this.isLiked = false,
    this.isNew = false,
  });

  @override
  State<WorkCard> createState() => _WorkCardState();
}

class _WorkCardState extends State<WorkCard> {
  bool _hovered = false;
  bool _openingCollection = false;

  Work get work => widget.work;
  VoidCallback? get onLike => widget.onLike;
  bool get isLiked => widget.isLiked;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: CorvusPressable(
        onTap: () => context.push('/work/${work.id}'),
        hoverScale: 1.015,
        hoverLift: 4,
        pressedScale: 0.985,
        child: AnimatedContainer(
          duration: CorvusMotion.fast,
          curve: CorvusMotion.standard,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CorvusRadius.md),
            color: AppColors.card,
            border: Border.all(
              color: _hovered
                  ? accent.withValues(alpha: 0.42)
                  : Colors.white.withValues(alpha: 0.07),
            ),
            boxShadow: _hovered
                ? [
                    ...CorvusElevation.medium,
                    ...CorvusElevation.glow(accent, strength: 0.7),
                  ]
                : CorvusElevation.low,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Imagen de fondo
              Positioned.fill(child: _buildImage(context)),
              // Gradiente doble: sutil top + fuerte bottom
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.28),
                        Colors.transparent,
                        Colors.transparent,
                        const Color(0xFF0A0908).withValues(alpha: 0.92),
                      ],
                      stops: const [0.0, 0.22, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
              // Badge disciplina (top-left)
              if (work.discipline.isNotEmpty)
                Positioned(
                  top: 10,
                  left: 10,
                  child: _disciplineChip(),
                ),
              // Badge precio (top-right)
              if (work.isForSale && work.price != null)
                Positioned(
                  top: 10,
                  right: 10,
                  child: _priceChip(),
                ),
              // Botón like (top-right si no hay precio)
              if (onLike != null && !(work.isForSale && work.price != null))
                Positioned(
                  top: 8,
                  right: 8,
                  child: _likeButton(),
                ),
              // Info overlay (bottom)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _bottomInfo(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    if (!work.hasImage) return _imagePlaceholder();

    // `memCacheWidth` decodifica al tamaño en que se va a pintar. Sin él, una
    // fotografía de 4000 px se descomprime entera en memoria para ocupar una
    // tarjeta de 300: unos sesenta megabytes por imagen frente a menos de uno.
    // Con veinte tarjetas en pantalla, ésa es la diferencia entre desplazarse
    // y que el teléfono expulse la pestaña.
    final ratio = MediaQuery.devicePixelRatioOf(context);

    return AnimatedScale(
      scale: _hovered ? 1.035 : 1,
      duration: CorvusMotion.medium,
      curve: CorvusMotion.standard,
      child: CachedNetworkImage(
        imageUrl: work.displayImage,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        memCacheWidth: (480 * ratio).round(),
        fadeInDuration: CorvusMotion.medium,
        placeholder: (_, __) => _imagePlaceholder(),
        errorWidget: (_, __, ___) => _imagePlaceholder(),
      ),
    );
  }

  /// Sin portada, la tarjeta es una página: papel oscuro con una comilla
  /// serif enorme, como la apertura de un capítulo. Un icono de "imagen rota"
  /// diría que falta algo; aquí no falta nada, la obra es texto o sonido.
  Widget _imagePlaceholder() {
    final isText = work.workType == 'text' ||
        work.textBody?.trim().isNotEmpty == true;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        gradient: CorvusSurfaces.sheen(strength: 1.4),
      ),
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 72),
      alignment: Alignment.topLeft,
      child: isText
          ? Text(
              '“',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.16),
                fontFamily: CorvusType.serif,
                fontSize: 96,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                height: 0.8,
              ),
            )
          : Center(
              child: Icon(
                _iconForType(work.workType),
                color: Colors.white.withValues(alpha: 0.18),
                size: 34,
              ),
            ),
    );
  }

  IconData _iconForType(String type) => switch (type) {
        'audio' => Icons.graphic_eq_rounded,
        'video' => Icons.movie_outlined,
        'pdf' => Icons.description_outlined,
        _ => Icons.image_outlined,
      };

  Widget _disciplineChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(CorvusRadius.sm),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 0.5,
        ),
      ),
      child: Text(
        work.discipline.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.86),
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
        ),
      ),
    );
  }

  Widget _priceChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(CorvusRadius.sm),
      ),
      child: Text(
        '\$${work.price!.toStringAsFixed(0)}',
        style: const TextStyle(
          color: AppColors.background,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _likeButton() {
    return CorvusPressable(
      onTap: onLike,
      haptics: true,
      hoverScale: 1.14,
      hoverLift: 0,
      pressedScale: 0.86,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 0.5,
          ),
        ),
        // El corazón entra creciendo desde el centro: es la confirmación de
        // que el gesto llegó, y llega antes que la respuesta del servidor.
        child: AnimatedSwitcher(
          duration: CorvusMotion.medium,
          switchInCurve: Curves.easeOutBack,
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            key: ValueKey(isLiked),
            size: 16,
            color: isLiked ? AppColors.accentLight : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _bottomInfo(BuildContext context) {
    final isReadable =
        work.workType == 'text' || work.textBody?.trim().isNotEmpty == true;
    final status = widget.isNew
        ? 'Nuevo'
        : work.status == 'published'
            ? 'Publicado'
            : 'Borrador';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            work.title,
            style: TextStyle(
              color: Colors.white,
              fontFamily: CorvusType.serif,
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              height: 1.22,
              shadows: [
                Shadow(
                    color: Colors.black.withValues(alpha: 0.7), blurRadius: 10)
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (work.authorUsername != null) {
                    context.push('/profile/${work.authorUsername}');
                  }
                },
                child: UserAvatar(
                  imageUrl: work.authorAvatarUrl,
                  displayName: work.authorDisplayName,
                  radius: 10,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  work.authorDisplayName ?? work.authorUsername ?? 'Artista',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.80),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (work.likesCount > 0) ...[
                Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 12,
                  color: isLiked
                      ? AppColors.accentLight
                      : Colors.white.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 3),
                Text(
                  _fmt(work.likesCount),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  status.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.isNew
                        ? AppColors.gold
                        : Colors.white.withValues(alpha: 0.42),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              if (isReadable)
                _OverlayAction(
                  tooltip: 'Leer o continuar',
                  icon: Icons.menu_book_outlined,
                  onPressed: () =>
                      context.push('/work/${work.id}/chapter/0?resume=true'),
                ),
              _OverlayAction(
                tooltip: 'Guardar en una colección',
                icon: Icons.bookmark_add_outlined,
                onPressed: _openingCollection
                    ? null
                    : () async {
                        setState(() => _openingCollection = true);
                        await showAddToCollection(context,
                            work: work,
                            profileId:
                                context.read<AuthProvider?>()?.profile?.id);
                        if (mounted) {
                          setState(() => _openingCollection = false);
                        }
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

/// Acción secundaria sobre la lámina. Pequeña y translúcida: está para quien
/// la busca, no para competir con la obra.
class _OverlayAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const _OverlayAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.38),
        foregroundColor: Colors.white.withValues(alpha: 0.86),
        shape: const CircleBorder(),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.12), width: 0.5),
      ),
      icon: Icon(icon, size: 15),
    );
  }
}

/// Tarjeta hero/destacada — formato banner horizontal.
class WorkHeroCard extends StatelessWidget {
  final Work work;
  final VoidCallback? onLike;
  final bool isLiked;

  const WorkHeroCard({
    super.key,
    required this.work,
    this.onLike,
    this.isLiked = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () => context.push('/work/${work.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CorvusRadius.lg),
          color: AppColors.card,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: CorvusElevation.medium,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Imagen
            Positioned.fill(
              child: work.hasImage
                  ? CachedNetworkImage(
                      imageUrl: work.displayImage,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppColors.overlay),
                      errorWidget: (_, __, ___) =>
                          Container(color: AppColors.overlay),
                    )
                  : Container(color: AppColors.overlay),
            ),
            // Gradiente
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF0A0908).withValues(alpha: 0.94),
                    ],
                    stops: const [0.2, 1.0],
                  ),
                ),
              ),
            ),
            // Badge DESTACADO (top-left)
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(CorvusRadius.sm),
                ),
                child: const Text(
                  'DESTACADO',
                  style: TextStyle(
                    color: AppColors.background,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
            ),
            // Like button (top-right)
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: onLike,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 0.5,
                    ),
                  ),
                  child: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    size: 18,
                    color: isLiked ? AppColors.accentLight : Colors.white,
                  ),
                ),
              ),
            ),
            // Info bottom-left
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (work.discipline.isNotEmpty)
                      Text(
                        work.discipline.toUpperCase(),
                        style: CorvusType.eyebrow(accent, alpha: 0.95),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      work.title,
                      style: CorvusType.headline.copyWith(
                        color: Colors.white,
                        fontSize: 26,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        UserAvatar(
                          imageUrl: work.authorAvatarUrl,
                          displayName: work.authorDisplayName,
                          radius: 14,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              work.authorDisplayName ?? 'Artista',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (work.authorUsername != null)
                              Text(
                                '@${work.authorUsername}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(Icons.visibility_outlined,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.55)),
                            const SizedBox(width: 4),
                            Text(
                              _fmt(work.viewsCount),
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
