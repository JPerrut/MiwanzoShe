import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../logging/app_logger.dart';
import '../../models/note_entry.dart';
import '../../state/shaumsi_state.dart';
import '../../utils/date_formatters.dart';
import '../widgets/glass_panel.dart';
import '../widgets/section_title.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({required this.state, super.key});

  final ShauMsiState state;
  static final AppLogger _logger = AppLogger.instance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final notes = state.notes;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            SectionTitle(
              title: 'Anotações',
              subtitle: 'Registre detalhes, ideias e lembretes úteis.',
              trailing: FilledButton.icon(
                onPressed: () => _openNoteForm(context),
                icon: const Icon(Icons.add),
                label: const Text('Nova nota'),
              ),
            ),
            const SizedBox(height: 16),
            if (notes.isEmpty)
              const GlassPanel(child: Text('Você ainda não criou notas.'))
            else
              ...notes.map(
                (note) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _NoteCard(
                    note: note,
                    onEdit: () => _openNoteForm(context, existing: note),
                    onDelete: () => _confirmDelete(context, note),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext pageContext, NoteEntry note) async {
    final shouldDelete = await showDialog<bool>(
      context: pageContext,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir nota?'),
          content: Text('Deseja realmente excluir "${note.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (shouldDelete ?? false) {
      await state.deleteNote(note.id);
    }
  }

  Future<void> _openNoteForm(
    BuildContext pageContext, {
    NoteEntry? existing,
  }) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    final tagController = TextEditingController(text: existing?.tag ?? '');
    final formKey = GlobalKey<FormState>();
    var isSaving = false;

    await showModalBottomSheet<void>(
      context: pageContext,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            final bottom = MediaQuery.viewInsetsOf(sheetContext).bottom;

            return Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 18),
              child: GlassPanel(
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          existing == null ? 'Nova Nota' : 'Editar Nota',
                          style: Theme.of(sheetContext).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: titleController,
                          enabled: !isSaving,
                          decoration: const InputDecoration(
                            labelText: 'Título',
                            hintText: 'Ex: Ideias para presente',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Informe o título da nota';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: descriptionController,
                          enabled: !isSaving,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Descrição',
                            hintText: 'Escreva os detalhes importantes...',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Informe a descrição';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: tagController,
                          enabled: !isSaving,
                          decoration: const InputDecoration(
                            labelText: 'Tag',
                            hintText: 'Ex: tpm, presente, encontro',
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: isSaving
                                    ? null
                                    : () => Navigator.of(sheetContext).pop(),
                                child: const Text('Cancelar'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        if (!(formKey.currentState
                                                ?.validate() ??
                                            false)) {
                                          return;
                                        }

                                        final normalizedTag =
                                            tagController.text.trim().isEmpty
                                            ? 'sem_tag'
                                            : tagController.text.trim();

                                        setModalState(() => isSaving = true);

                                        try {
                                          if (existing == null) {
                                            await state.addNote(
                                              title: titleController.text
                                                  .trim(),
                                              description: descriptionController
                                                  .text
                                                  .trim(),
                                              tag: normalizedTag,
                                            );
                                          } else {
                                            await state.updateNote(
                                              existing.copyWith(
                                                title: titleController.text
                                                    .trim(),
                                                description:
                                                    descriptionController.text
                                                        .trim(),
                                                tag: normalizedTag,
                                              ),
                                            );
                                          }

                                          if (sheetContext.mounted) {
                                            Navigator.of(sheetContext).pop();
                                            return;
                                          }
                                        } catch (error, stackTrace) {
                                          _logger.error(
                                            'NotesScreen',
                                            'Falha ao salvar nota via formulário.',
                                            error: error,
                                            stackTrace: stackTrace,
                                          );
                                          if (pageContext.mounted) {
                                            ScaffoldMessenger.of(
                                              pageContext,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Não foi possível salvar a nota agora. Tente novamente.',
                                                ),
                                              ),
                                            );
                                          }
                                        }

                                        if (sheetContext.mounted) {
                                          setModalState(() => isSaving = false);
                                        }
                                      },
                                child: isSaving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        existing == null
                                            ? 'Salvar'
                                            : 'Atualizar',
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));
    titleController.dispose();
    descriptionController.dispose();
    tagController.dispose();
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.onEdit,
    required this.onDelete,
  });

  final NoteEntry note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  note.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else {
                    onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'delete', child: Text('Excluir')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '#${note.tag} · ${DateFormatters.fullDate(note.createdAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          _LinkAwareText(text: note.description),
        ],
      ),
    );
  }
}

class _LinkAwareText extends StatelessWidget {
  const _LinkAwareText({required this.text});

  final String text;

  static final RegExp _urlRegex = RegExp(
    r'((?:https?:\/\/|www\.)[^\s]+)',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    final raw = text.trim();
    if (raw.isEmpty) return const SizedBox.shrink();

    final links = _extractLinks(raw);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(raw),
        if (links.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: links
                .map(
                  (link) => ActionChip(
                    avatar: const Icon(Icons.link, size: 16),
                    label: Text(_chipLabel(link)),
                    onPressed: () => _openLink(context, link),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ],
    );
  }

  List<String> _extractLinks(String rawText) {
    final found = <String>{};
    for (final match in _urlRegex.allMatches(rawText)) {
      final rawLink = match.group(0)?.trim();
      if (rawLink == null || rawLink.isEmpty) continue;
      found.add(_sanitizeLink(rawLink));
    }
    return found.toList(growable: false);
  }

  String _sanitizeLink(String link) {
    return link.replaceAll(RegExp(r'[.,;:!?)\]}]+$'), '');
  }

  String _chipLabel(String link) {
    const maxLength = 36;
    if (link.length <= maxLength) return link;
    return '${link.substring(0, maxLength - 3)}...';
  }

  Future<void> _openLink(BuildContext context, String link) async {
    final withScheme = link.startsWith('http://') || link.startsWith('https://')
        ? link
        : 'https://$link';
    final uri = Uri.tryParse(withScheme);

    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Link inválido.')));
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o link.')),
      );
    }
  }
}
