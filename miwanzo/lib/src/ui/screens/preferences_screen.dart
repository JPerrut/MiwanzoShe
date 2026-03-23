import 'package:flutter/material.dart';

import '../../models/category_entry.dart';
import '../../models/preference_item.dart';
import '../../state/miwanzo_state.dart';
import '../widgets/glass_panel.dart';
import '../widgets/section_title.dart';

class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({required this.state, super.key});

  final MiwanzoState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final categories = state.categories;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            SectionTitle(
              title: 'Gostos e Não Gostos',
              subtitle: 'Organize preferências por categoria.',
              trailing: FilledButton.icon(
                onPressed: categories.isEmpty
                    ? null
                    : () => _openItemForm(context),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar'),
              ),
            ),
            const SizedBox(height: 16),
            if (categories.isEmpty)
              const GlassPanel(
                child: Text('As categorias ainda não foram carregadas.'),
              )
            else
              ...categories.map((category) {
                final items = state.itemsByCategory(category.id);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassPanel(
                    child: Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          category.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: Text(
                          items.isEmpty
                              ? 'Sem itens cadastrados'
                              : '${items.length} ${items.length == 1 ? 'item' : 'itens'}',
                        ),
                        children: [
                          if (items.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Nenhum item nesta categoria ainda.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            )
                          else
                            ...items.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _PreferenceItemTile(
                                  item: item,
                                  onEdit: () =>
                                      _openItemForm(context, existing: item),
                                  onDelete: () => _confirmDelete(context, item),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, PreferenceItem item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir item?'),
          content: Text('Deseja excluir "${item.name}"?'),
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
      await state.deletePreferenceItem(item.id);
    }
  }

  Future<void> _openItemForm(
    BuildContext context, {
    PreferenceItem? existing,
  }) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: existing?.name ?? '');
    final observationController = TextEditingController(
      text: existing?.observation ?? '',
    );

    final categories = state.categories;
    if (categories.isEmpty) {
      return;
    }

    CategoryEntry selectedCategory = existing == null
        ? categories.first
        : categories.firstWhere(
            (category) => category.id == existing.categoryId,
            orElse: () => categories.first,
          );

    var status = existing?.status ?? PreferenceStatus.likes;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                          existing == null ? 'Novo Item' : 'Editar Item',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<int>(
                          initialValue: selectedCategory.id,
                          decoration: const InputDecoration(
                            labelText: 'Categoria',
                          ),
                          items: categories
                              .map(
                                (category) => DropdownMenuItem(
                                  value: category.id,
                                  child: Text(category.name),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value == null) return;
                            final category = categories.firstWhere(
                              (current) => current.id == value,
                            );
                            setModalState(() => selectedCategory = category);
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Item',
                            hintText: 'Ex: KitKat Dark',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Informe o nome do item';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Status',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<PreferenceStatus>(
                          segments: const [
                            ButtonSegment(
                              value: PreferenceStatus.likes,
                              icon: Icon(Icons.favorite),
                              label: Text('Gosta'),
                            ),
                            ButtonSegment(
                              value: PreferenceStatus.dislikes,
                              icon: Icon(Icons.heart_broken),
                              label: Text('Não gosta'),
                            ),
                          ],
                          selected: {status},
                          onSelectionChanged: (values) {
                            setModalState(() => status = values.first);
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: observationController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Observação',
                            hintText: 'Ex: Prefere chocolate meio amargo',
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

                                  if (existing == null) {
                                    await state.addPreferenceItem(
                                      categoryId: selectedCategory.id,
                                      category: selectedCategory.name,
                                      name: nameController.text.trim(),
                                      status: status,
                                      observation: observationController.text
                                          .trim(),
                                    );
                                  } else {
                                    await state.updatePreferenceItem(
                                      existing.copyWith(
                                        categoryId: selectedCategory.id,
                                        category: selectedCategory.name,
                                        name: nameController.text.trim(),
                                        status: status,
                                        observation: observationController.text
                                            .trim(),
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
      },
    );

    nameController.dispose();
    observationController.dispose();
  }
}

class _PreferenceItemTile extends StatelessWidget {
  const _PreferenceItemTile({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final PreferenceItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isLike = item.status == PreferenceStatus.likes;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isLike ? Icons.favorite : Icons.heart_broken,
            color: isLike ? Colors.redAccent : Colors.blueGrey,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: Theme.of(context).textTheme.labelLarge),
                Text(
                  item.category,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  isLike ? 'Gosta' : 'Não gosta',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (item.observation.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(item.observation),
                ],
              ],
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
    );
  }
}
