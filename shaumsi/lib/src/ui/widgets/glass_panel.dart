import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(18),
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final colors = context.shaumsiColors;

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.pearlWhite.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colors.seaFoam.withValues(alpha: 0.88),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.deepOcean.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
