import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../logging/app_logger.dart';
import '../widgets/glass_panel.dart';
import '../widgets/section_title.dart';

class LogsScreen extends StatelessWidget {
  LogsScreen({super.key});

  final AppLogger _logger = AppLogger.instance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _logger,
      builder: (context, _) {
        final entries = _logger.entries;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            SectionTitle(
              title: 'Logs (Temporário)',
              subtitle: 'Use para depurar erros de cadastro e envio.',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Copiar logs',
                    onPressed: () async {
                      final text = _logger.exportAll();
                      await Clipboard.setData(ClipboardData(text: text));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Logs copiados para a área de transferência.',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded),
                  ),
                  IconButton(
                    tooltip: 'Limpar logs',
                    onPressed: _logger.clear,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              const GlassPanel(child: Text('Sem logs registrados no momento.'))
            else
              ...entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LogCard(entry: entry),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.entry});

  final AppLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.level) {
      AppLogLevel.info => Colors.blueGrey,
      AppLogLevel.warning => Colors.orange,
      AppLogLevel.error => Colors.red,
    };

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 10, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${entry.source} • ${entry.timestamp.toLocal()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            entry.toLine(),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
