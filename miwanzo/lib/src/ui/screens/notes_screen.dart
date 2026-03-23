import 'package:flutter/material.dart';

import '../../models/note_entry.dart';
import '../../state/miwanzo_state.dart';
import '../../utils/date_formatters.dart';
import '../widgets/glass_panel.dart';
import '../widgets/section_title.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({required this.state, super.key});

  final MiwanzoState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final notes = state.notes;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
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

  Future<void> _confirmDelete(BuildContext context, NoteEntry note) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir nota?'),
          content: Text('Deseja realmente excluir "${note.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
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
    BuildContext context, {
    NoteEntry? existing,
  }) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    final tagController = TextEditingController(text: existing?.tag ?? '');
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottom = MediaQuery.viewInsetsOf(context).bottom;

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
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: titleController,
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
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              if (!(formKey.currentState?.validate() ??
                                  false)) {
                                return;
                              }

                              final normalizedTag =
                                  tagController.text.trim().isEmpty
                                  ? 'sem_tag'
                                  : tagController.text.trim();

                              if (existing == null) {
                                await state.addNote(
                                  title: titleController.text.trim(),
                                  description: descriptionController.text
                                      .trim(),
                                  tag: normalizedTag,
                                );
                              } else {
                                await state.updateNote(
                                  existing.copyWith(
                                    title: titleController.text.trim(),
                                    description: descriptionController.text
                                        .trim(),
                                    tag: normalizedTag,
                                  ),
                                );
                              }

                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                            child: Text(
                              existing == null ? 'Salvar' : 'Atualizar',
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
          Text(note.description),
        ],
      ),
    );
  }
}
