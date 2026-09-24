import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/corvus_design.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? displayName;
  final double radius;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.imageUrl,
    this.displayName,
    this.radius = 20,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatar;

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      avatar = CachedNetworkImage(
        imageUrl: imageUrl!,
        imageBuilder: (_, provider) => _ring(
          CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.card,
            backgroundImage: provider,
          ),
        ),
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) => _placeholder(),
      );
    } else {
      avatar = _placeholder();
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatar);
    }
    return avatar;
  }

  /// Un anillo de un píxel separa el retrato del fondo. Sin él, una foto
  /// oscura se funde con la tarjeta y el avatar parece un agujero.
  Widget _ring(Widget child) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
            width: 1,
          ),
        ),
        child: child,
      );

  Widget _placeholder() {
    final initial = (displayName?.isNotEmpty == true)
        ? displayName![0].toUpperCase()
        : '?';
    return _ring(
      CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.secondaryMuted,
        child: Text(
          initial,
          style: TextStyle(
            color: AppColors.secondaryLight,
            fontFamily: CorvusType.serif,
            fontSize: radius * 0.9,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ),
    );
  }
}
