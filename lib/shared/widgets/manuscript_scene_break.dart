import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ManuscriptSceneBreak extends StatelessWidget {
  final double fontSize;
  const ManuscriptSceneBreak({super.key, this.fontSize = 18});
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Separador de escena',
        child: Center(
            child: Container(
          width: 56,
          height: 2,
          margin: EdgeInsets.symmetric(vertical: fontSize * .8),
          decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .42),
              borderRadius: BorderRadius.circular(99)),
        )),
      );
}
