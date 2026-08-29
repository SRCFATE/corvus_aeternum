import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../models/work.dart';
import 'user_avatar.dart';

/// Tarjeta de obra en modo grid — imagen dominante con overlay.
class WorkCard extends StatelessWidget {
  final Work work;
  final VoidCallback? onLike;
  final bool isLiked;

  const WorkCard({
    super.key,
    required this.work,
    this.onLike,
    this.isLiked = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/work/${work.id}'),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppColors.card,
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Imagen de fondo
            Positioned.fill(child: _buildImage()),
            // Gradiente doble: sutil top + fuerte bottom
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.20),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.88),
                    ],
                    stops: const [0.0, 0.25, 0.45, 1.0],
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
            if (!(work.isForSale && work.price != null))
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
    );
  }

  Widget _buildImage() {
    if (work.hasImage) {
      return CachedNetworkImage(
        imageUrl: work.displayImage,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => _imagePlaceholder(),
        errorWidget: (_, __, ___) => _imagePlaceholder(),
      );
    }
    return _imagePlaceholder();
  }

  Widget _imagePlaceholder() {
    return Container(
      color: AppColors.card,
      child: const Center(
        child: Icon(Icons.image_outlined, color: AppColors.textMuted, size: 36),
      ),
    );
  }

  Widget _disciplineChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Text(
        work.discipline,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _priceChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '\$${work.price!.toStringAsFixed(0)}',
        style: const TextStyle(
          color: AppColors.background,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _likeButton() {
    return GestureDetector(
      onTap: onLike,
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
        child: Icon(
          isLiked ? Icons.favorite : Icons.favorite_border,
          size: 16,
          color: isLiked ? AppColors.accentLight : Colors.white,
        ),
      ),
    );
  }

  Widget _bottomInfo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            work.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
              shadows: [Shadow(color: Colors.black, blurRadius: 8)],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 7),
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
                  radius: 11,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  work.authorDisplayName ?? work.authorUsername ?? 'Artista',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
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
                  color: isLiked ? AppColors.accentLight : Colors.white70,
                ),
                const SizedBox(width: 3),
                Text(
                  _fmt(work.likesCount),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
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
    return GestureDetector(
      onTap: () => context.push('/work/${work.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppColors.card,
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
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
                      Colors.black.withValues(alpha: 0.92),
                    ],
                    stops: const [0.25, 1.0],
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
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 10, color: AppColors.background),
                    SizedBox(width: 4),
                    Text(
                      'DESTACADO',
                      style: TextStyle(
                        color: AppColors.background,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
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
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (work.discipline.isNotEmpty)
                      Text(
                        work.discipline.toUpperCase(),
                        style: TextStyle(
                          color: AppColors.primary.withValues(alpha: 0.9),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      work.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        UserAvatar(
                          imageUrl: work.authorAvatarUrl,
                          displayName: work.authorDisplayName,
                          radius: 14,
                        ),
                        const SizedBox(width: 8),
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
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            const Icon(Icons.visibility_outlined,
                                size: 14, color: Colors.white60),
                            const SizedBox(width: 4),
                            Text(
                              _fmt(work.viewsCount),
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 12),
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
