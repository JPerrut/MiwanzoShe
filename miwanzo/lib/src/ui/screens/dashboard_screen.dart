import 'package:flutter/material.dart';

import '../../models/important_date.dart';
import '../../models/note_entry.dart';
import '../../models/preference_item.dart';
import '../../state/miwanzo_state.dart';
import '../../utils/date_formatters.dart';
import '../widgets/glass_panel.dart';
import '../widgets/section_title.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    required this.state,
    required this.onOpenSection,
    super.key,
  });

  final MiwanzoState state;
  final ValueChanged<int> onOpenSection;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final dates = state.upcomingDates.take(3).toList();
        final notes = state.latestNotes;
        final items = state.latestPreferenceItems;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            Text('Miwanzo', style: textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Organize lembranças, gostos e ideias em um só lugar.',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(
                    title: 'Acessos Rápidos',
                    subtitle: 'Navegue para cada área do aplicativo',
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _QuickAction(
                        label: 'Datas',
                        icon: Icons.event,
                        onTap: () => onOpenSection(1),
                      ),
                      _QuickAction(
                        label: 'Notas',
                        icon: Icons.note,
                        onTap: () => onOpenSection(2),
                      ),
                      _QuickAction(
                        label: 'Gostos',
                        icon: Icons.favorite,
                        onTap: () => onOpenSection(3),
                      ),
                      _QuickAction(
                        label: 'Resumo',
                        icon: Icons.dashboard,
                        onTap: () => onOpenSection(0),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _DashboardSection(
              title: 'Próximas Datas Importantes',
              icon: Icons.event_available,
              child: dates.isEmpty
                  ? const _EmptySectionHint(
                      message: 'Nenhuma data cadastrada ainda.',
                    )
                  : Column(
                      children: dates
                          .map((date) => _DatePreviewTile(date: date))
                          .toList(),
                    ),
            ),
            const SizedBox(height: 16),
            _DashboardSection(
              title: 'Últimas Anotações',
              icon: Icons.sticky_note_2,
              child: notes.isEmpty
                  ? const _EmptySectionHint(
                      message: 'Sem anotações no momento.',
                    )
                  : Column(
                      children: notes
                          .map((note) => _NotePreviewTile(note: note))
                          .toList(),
                    ),
            ),
            const SizedBox(height: 16),
            _DashboardSection(
              title: 'Itens Adicionados Recentemente',
              icon: Icons.favorite,
              child: items.isEmpty
                  ? const _EmptySectionHint(
                      message: 'Adicione itens de gostos e não gostos.',
                    )
                  : Column(
                      children: items
                          .map((item) => _PreferencePreviewTile(item: item))
                          .toList(),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 148,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: colors.primary),
                const SizedBox(width: 8),
                Text(label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DatePreviewTile extends StatelessWidget {
  const _DatePreviewTile({required this.date});

  final ImportantDate date;

  @override
  Widget build(BuildContext context) {
    final suffix = switch (date.daysUntilNextOccurrence) {
      0 => 'Hoje',
      1 => 'Amanhã',
      final days when days > 1 => 'Em $days dias',
      _ => 'Chegando',
    };

    return _PreviewTile(
      leading: const Icon(Icons.cake_outlined),
      title: date.title,
      subtitle: DateFormatters.friendlyDateWithYear(date.nextOccurrence),
      trailingText: suffix,
    );
  }
}

class _NotePreviewTile extends StatelessWidget {
  const _NotePreviewTile({required this.note});

  final NoteEntry note;

  @override
  Widget build(BuildContext context) {
    return _PreviewTile(
      leading: const Icon(Icons.note_alt_outlined),
      title: note.title,
      subtitle: '#${note.tag} · ${DateFormatters.fullDate(note.createdAt)}',
      trailingText: '',
    );
  }
}

class _PreferencePreviewTile extends StatelessWidget {
  const _PreferencePreviewTile({required this.item});

  final PreferenceItem item;

  @override
  Widget build(BuildContext context) {
    final isLike = item.status == PreferenceStatus.likes;

    return _PreviewTile(
      leading: Icon(
        isLike ? Icons.favorite : Icons.heart_broken,
        color: isLike ? Colors.redAccent : Colors.blueGrey,
      ),
      title: item.name,
      subtitle: item.category,
      trailingText: isLike ? 'Gosta' : 'Não gosta',
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailingText,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final String trailingText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (trailingText.isNotEmpty)
              Text(
                trailingText,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptySectionHint extends StatelessWidget {
  const _EmptySectionHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(message, style: Theme.of(context).textTheme.bodyMedium);
  }
}
