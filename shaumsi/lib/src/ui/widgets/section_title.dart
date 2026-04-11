import 'package:flutter/material.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final trailingWidgets = trailing == null ? null : <Widget>[trailing!];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.titleLarge),
              if (subtitle case final subtitleText?) ...[
                const SizedBox(height: 4),
                Text(subtitleText, style: textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        ...?trailingWidgets,
      ],
    );
  }
}
