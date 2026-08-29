import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'formatted_manuscript_text.dart';

bool containsMarkdownSyntax(String source) {
  if (source.trim().isEmpty) return false;
  return RegExp(
    r'(^|\n)\s{0,3}(#{1,3}\s|>\s|[-*]\s|\d+\.\s|```)|'
    r'(\*\*[^*]+\*\*|\*[^*]+\*|~~[^~]+~~|`[^`]+`|\[\[[^\]]+\]\]|\[[^\]]+\]\([^)]+\))',
    multiLine: true,
  ).hasMatch(source);
}

class CorvusMarkdownFieldPreview extends StatelessWidget {
  final TextEditingController controller;
  final Widget child;
  final bool enabled;

  const CorvusMarkdownFieldPreview({
    super.key,
    required this.controller,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final showPreview = containsMarkdownSyntax(value.text);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            child,
            if (showPreview) ...[
              const SizedBox(height: 10),
              CorvusMarkdownPreview(text: value.text),
            ],
          ],
        );
      },
    );
  }
}

class CorvusMarkdownPreview extends StatelessWidget {
  final String text;
  final String title;
  final bool showWhenEmpty;
  final EdgeInsetsGeometry padding;

  const CorvusMarkdownPreview({
    super.key,
    required this.text,
    this.title = 'Vista previa',
    this.showWhenEmpty = false,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    if (!showWhenEmpty && text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.visibility_outlined,
                size: 15,
                color: AppColors.primaryLight.withValues(alpha: 0.88),
              ),
              const SizedBox(width: 7),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.48),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          if (text.trim().isEmpty)
            Text(
              'El contenido aparecera aqui.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.32),
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            FormattedManuscriptText(
              text: text,
              fontSize: 14,
              lineHeight: 1.65,
            ),
        ],
      ),
    );
  }
}
