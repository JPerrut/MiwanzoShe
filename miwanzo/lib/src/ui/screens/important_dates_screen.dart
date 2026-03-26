import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../logging/app_logger.dart';
import '../../models/important_date.dart';
import '../../state/miwanzo_state.dart';
import '../../utils/date_formatters.dart';
import '../widgets/glass_panel.dart';
import '../widgets/section_title.dart';

class ImportantDatesScreen extends StatelessWidget {
  const ImportantDatesScreen({required this.state, super.key});

  final MiwanzoState state;
  static final AppLogger _logger = AppLogger.instance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final dates = state.upcomingDates;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            SectionTitle(
              title: 'Datas Importantes',
              subtitle: 'Cadastre momentos que voce nao quer esquecer.',
              trailing: FilledButton.icon(
                onPressed: () => _openDateForm(context),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar'),
              ),
            ),
            const SizedBox(height: 16),
            if (dates.isEmpty)
              const GlassPanel(
                child: Text(
                  'Nenhuma data cadastrada ainda. Toque em "Adicionar" para comecar.',
                ),
              )
            else
              ...dates.map(
                (date) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ImportantDateCard(
                    date: date,
                    onEdit: () => _openDateForm(context, existing: date),
                    onDelete: () => _confirmDelete(context, date),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext pageContext,
    ImportantDate date,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: pageContext,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir data?'),
          content: Text('Tem certeza que deseja excluir "${date.title}"?'),
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
      await state.deleteImportantDate(date.id);
    }
  }

  Future<void> _openDateForm(
    BuildContext pageContext, {
    ImportantDate? existing,
  }) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    final customDaysController = TextEditingController(
      text: existing?.notifyCustomDays?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();

    var selectedDate =
        existing?.date ?? DateTime.now().add(const Duration(days: 7));
    var repeatsAnnually = existing?.repeatsAnnually ?? true;
    if (repeatsAnnually) {
      selectedDate = DateTime(
        DateTime.now().year,
        selectedDate.month,
        selectedDate.day,
      );
    }
    var notify3Months = existing?.notify3Months ?? false;
    var notify1Month = existing?.notify1Month ?? true;
    var notify1Week = existing?.notify1Week ?? true;
    var notify1Day = existing?.notify1Day ?? true;
    var notifyOnDay = existing?.notifyOnDay ?? true;
    var customEnabled = existing?.notifyCustomDays != null;
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
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          existing == null ? 'Nova Data' : 'Editar Data',
                          style: Theme.of(sheetContext).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: titleController,
                          enabled: !isSaving,
                          decoration: const InputDecoration(
                            labelText: 'Nome da data',
                            hintText: 'Ex: Aniversario',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Informe o nome da data';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: descriptionController,
                          enabled: !isSaving,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Anotacoes',
                            hintText:
                                'Detalhes importantes e links para lembrar depois',
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: isSaving
                              ? null
                              : () async {
                                  final pickedDate = await showDatePicker(
                                    context: sheetContext,
                                    initialDate: selectedDate,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );

                                  if (pickedDate != null) {
                                    setModalState(() {
                                      selectedDate = repeatsAnnually
                                          ? DateTime(
                                              DateTime.now().year,
                                              pickedDate.month,
                                              pickedDate.day,
                                            )
                                          : pickedDate;
                                    });
                                  }
                                },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month),
                                const SizedBox(width: 10),
                                Text(
                                  repeatsAnnually
                                      ? '${DateFormatters.friendlyDate(selectedDate)} (repete todo ano)'
                                      : DateFormatters.friendlyDateWithYear(
                                          selectedDate,
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        CheckboxListTile(
                          value: repeatsAnnually,
                          onChanged: isSaving
                              ? null
                              : (value) => setModalState(() {
                                  repeatsAnnually = value ?? true;
                                  if (repeatsAnnually) {
                                    selectedDate = DateTime(
                                      DateTime.now().year,
                                      selectedDate.month,
                                      selectedDate.day,
                                    );
                                  }
                                }),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Repetir todos os anos'),
                          subtitle: const Text('Usa somente dia e mes'),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Notificacoes',
                          style: Theme.of(sheetContext).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          value: notify3Months,
                          onChanged: isSaving
                              ? null
                              : (value) => setModalState(
                                  () => notify3Months = value ?? false,
                                ),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('3 meses antes'),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        CheckboxListTile(
                          value: notify1Month,
                          onChanged: isSaving
                              ? null
                              : (value) => setModalState(
                                  () => notify1Month = value ?? false,
                                ),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('1 mes antes'),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        CheckboxListTile(
                          value: notify1Week,
                          onChanged: isSaving
                              ? null
                              : (value) => setModalState(
                                  () => notify1Week = value ?? false,
                                ),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('1 semana antes'),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        CheckboxListTile(
                          value: notify1Day,
                          onChanged: isSaving
                              ? null
                              : (value) => setModalState(
                                  () => notify1Day = value ?? false,
                                ),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('1 dia antes'),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        CheckboxListTile(
                          value: notifyOnDay,
                          onChanged: isSaving
                              ? null
                              : (value) => setModalState(
                                  () => notifyOnDay = value ?? false,
                                ),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('No dia'),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        CheckboxListTile(
                          value: customEnabled,
                          onChanged: isSaving
                              ? null
                              : (value) => setModalState(
                                  () => customEnabled = value ?? false,
                                ),
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Definir dias personalizados antes',
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        if (customEnabled)
                          TextFormField(
                            controller: customDaysController,
                            enabled: !isSaving,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Dias antes',
                              hintText: 'Ex: 14',
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

                                        final customDays = customEnabled
                                            ? int.tryParse(
                                                customDaysController.text
                                                    .trim(),
                                              )
                                            : null;

                                        if (customEnabled &&
                                            (customDays == null ||
                                                customDays <= 0)) {
                                          ScaffoldMessenger.of(
                                            pageContext,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Informe um numero valido de dias para notificacao personalizada.',
                                              ),
                                            ),
                                          );
                                          return;
                                        }

                                        final hasNotification =
                                            notify3Months ||
                                            notify1Month ||
                                            notify1Week ||
                                            notify1Day ||
                                            notifyOnDay ||
                                            customDays != null;

                                        if (!hasNotification) {
                                          ScaffoldMessenger.of(
                                            pageContext,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Selecione pelo menos uma regra de notificacao.',
                                              ),
                                            ),
                                          );
                                          return;
                                        }

                                        setModalState(() => isSaving = true);

                                        try {
                                          if (existing == null) {
                                            await state.addImportantDate(
                                              title: titleController.text
                                                  .trim(),
                                              description: descriptionController
                                                  .text
                                                  .trim(),
                                              date: selectedDate,
                                              repeatsAnnually: repeatsAnnually,
                                              notify3Months: notify3Months,
                                              notify1Month: notify1Month,
                                              notify1Week: notify1Week,
                                              notify1Day: notify1Day,
                                              notifyOnDay: notifyOnDay,
                                              notifyCustomDays: customDays,
                                            );
                                          } else {
                                            await state.updateImportantDate(
                                              existing.copyWith(
                                                title: titleController.text
                                                    .trim(),
                                                description:
                                                    descriptionController.text
                                                        .trim(),
                                                date: selectedDate,
                                                repeatsAnnually:
                                                    repeatsAnnually,
                                                notify3Months: notify3Months,
                                                notify1Month: notify1Month,
                                                notify1Week: notify1Week,
                                                notify1Day: notify1Day,
                                                notifyOnDay: notifyOnDay,
                                                notifyCustomDays: customDays,
                                                clearCustomDays: !customEnabled,
                                              ),
                                            );
                                          }

                                          if (sheetContext.mounted) {
                                            Navigator.of(sheetContext).pop();
                                            return;
                                          }
                                        } on DuplicateImportantDateException {
                                          _logger.warning(
                                            'ImportantDatesScreen',
                                            'Cadastro/edicao bloqueado por duplicidade de titulo + data.',
                                          );
                                          if (pageContext.mounted) {
                                            ScaffoldMessenger.of(
                                              pageContext,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Ja existe uma data importante com o mesmo nome e a mesma data.',
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (error, stackTrace) {
                                          _logger.error(
                                            'ImportantDatesScreen',
                                            'Falha ao salvar data importante via formulario.',
                                            error: error,
                                            stackTrace: stackTrace,
                                          );
                                          if (pageContext.mounted) {
                                            ScaffoldMessenger.of(
                                              pageContext,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Nao foi possivel salvar a data agora. Tente novamente.',
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
    customDaysController.dispose();
  }
}

class _ImportantDateCard extends StatelessWidget {
  const _ImportantDateCard({
    required this.date,
    required this.onEdit,
    required this.onDelete,
  });

  final ImportantDate date;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final labels = _notificationLabels(date);
    final days = date.daysUntilNextOccurrence;

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormatters.friendlyDateWithYear(date.nextOccurrence),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (date.repeatsAnnually)
                      Text(
                        'Repete todo ano',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (date.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _LinkAwareText(text: date.description),
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.schedule, size: 16),
                label: Text(_daysLabel(days)),
              ),
              ...labels.map((label) => Chip(label: Text(label))),
            ],
          ),
        ],
      ),
    );
  }

  String _daysLabel(int days) {
    if (days == 0) return 'Hoje';
    if (days == 1) return 'Amanha';
    if (days < 0) return 'Ha ${days.abs()} dias';
    return 'Em $days dias';
  }

  List<String> _notificationLabels(ImportantDate date) {
    final labels = <String>[];

    if (date.notify3Months) labels.add('3 meses antes');
    if (date.notify1Month) labels.add('1 mes antes');
    if (date.notify1Week) labels.add('1 semana antes');
    if (date.notify1Day) labels.add('1 dia antes');
    if (date.notifyOnDay) labels.add('No dia');
    if (date.notifyCustomDays != null) {
      labels.add('${date.notifyCustomDays} dias antes');
    }

    return labels;
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
      ).showSnackBar(const SnackBar(content: Text('Link invalido.')));
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel abrir o link.')),
      );
    }
  }
}
