import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../logging/app_logger.dart';
import '../../models/important_date.dart';
import '../../state/shaumsi_state.dart';
import '../../utils/date_formatters.dart';
import '../widgets/glass_panel.dart';
import '../widgets/section_title.dart';

class ImportantDatesScreen extends StatelessWidget {
  const ImportantDatesScreen({required this.state, super.key});

  final ShauMsiState state;
  static final AppLogger _logger = AppLogger.instance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final dates = state.allDatesForList;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            SectionTitle(
              title: 'Datas Importantes',
              subtitle: 'Cadastre momentos que você não quer esquecer.',
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
                  'Nenhuma data cadastrada ainda. Toque em "Adicionar" para começar.',
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
      builder: (dialogContext) => AlertDialog(
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
      ),
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

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var notificationsEnabled =
        existing?.hasAnyNotification ?? !selectedDate.isBefore(today);
    var selectedNotificationTime = TimeOfDay(
      hour: existing?.notificationHour ?? 9,
      minute: existing?.notificationMinute ?? 0,
    );
    var selectedNotificationSound =
        existing?.notificationSound ?? ImportantDate.notificationSoundDefault;

    final defaultCustomDate = DateTime.now().add(const Duration(days: 1));
    var customEnabled = existing?.notifyCustomDates.isNotEmpty ?? false;
    var customNotificationDates = existing == null
        ? <DateTime>[]
        : List<DateTime>.from(existing.notifyCustomDates);
    if (customEnabled && customNotificationDates.isEmpty) {
      customNotificationDates.add(
        DateTime(
          defaultCustomDate.year,
          defaultCustomDate.month,
          defaultCustomDate.day,
          selectedNotificationTime.hour,
          selectedNotificationTime.minute,
        ),
      );
    }

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
                            hintText: 'Ex: Aniversário',
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                              ? 'Informe o nome da data'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: descriptionController,
                          enabled: !isSaving,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Anotações',
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
                                    firstDate: DateTime(1900),
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
                          child: _pickerRow(
                            Icons.calendar_month,
                            repeatsAnnually
                                ? '${DateFormatters.friendlyDate(selectedDate)} (repete todo ano)'
                                : DateFormatters.friendlyDateWithYear(
                                    selectedDate,
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
                          subtitle: const Text('Usa somente dia e mês'),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Notificacoes',
                          style: Theme.of(sheetContext).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          value: notificationsEnabled,
                          onChanged: isSaving
                              ? null
                              : (v) => setModalState(
                                  () => notificationsEnabled = v,
                                ),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Ativar notificações'),
                          subtitle: const Text(
                            'Padrão: 3 meses, 1 mês, 1 semana e 1 dia antes',
                          ),
                        ),
                        if (notificationsEnabled) ...[
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: isSaving
                                ? null
                                : () async {
                                    final pickedTime = await showTimePicker(
                                      context: sheetContext,
                                      initialTime: selectedNotificationTime,
                                    );
                                    if (pickedTime != null) {
                                      setModalState(
                                        () => selectedNotificationTime =
                                            pickedTime,
                                      );
                                    }
                                  },
                            child: _pickerRow(
                              Icons.access_time,
                              'Hora das notificações: ${DateFormatters.hourMinute(selectedNotificationTime.hour, selectedNotificationTime.minute)}',
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: selectedNotificationSound,
                            decoration: const InputDecoration(
                              labelText: 'Som da notificação',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: ImportantDate.notificationSoundDefault,
                                child: Text('Padrão do sistema'),
                              ),
                              DropdownMenuItem(
                                value: ImportantDate.notificationSoundShauMsi,
                                child: Text('Som ShauMsi'),
                              ),
                            ],
                            onChanged: isSaving
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    setModalState(
                                      () => selectedNotificationSound = value,
                                    );
                                  },
                          ),
                          CheckboxListTile(
                            value: customEnabled,
                            onChanged: isSaving
                                ? null
                                : (v) => setModalState(() {
                                    customEnabled = v ?? false;
                                    if (customEnabled &&
                                        customNotificationDates.isEmpty) {
                                      customNotificationDates.add(
                                        DateTime(
                                          defaultCustomDate.year,
                                          defaultCustomDate.month,
                                          defaultCustomDate.day,
                                          selectedNotificationTime.hour,
                                          selectedNotificationTime.minute,
                                        ),
                                      );
                                    }
                                  }),
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Definir datas personalizadas para notificar',
                            ),
                            subtitle: const Text(
                              'Você pode adicionar mais de uma data',
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          if (customEnabled) ...[
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: isSaving
                                    ? null
                                    : () => setModalState(() {
                                        customNotificationDates.add(
                                          DateTime(
                                            defaultCustomDate.year,
                                            defaultCustomDate.month,
                                            defaultCustomDate.day,
                                            selectedNotificationTime.hour,
                                            selectedNotificationTime.minute,
                                          ),
                                        );
                                        customNotificationDates =
                                            _normalizeCustomNotificationDates(
                                              customNotificationDates,
                                            );
                                      }),
                                icon: const Icon(Icons.add_alert),
                                label: const Text(
                                  'Adicionar outra data personalizada',
                                ),
                              ),
                            ),
                            ...List.generate(customNotificationDates.length, (
                              index,
                            ) {
                              final customAt = customNotificationDates[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Notificação personalizada ${index + 1}',
                                      style: Theme.of(
                                        sheetContext,
                                      ).textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: isSaving
                                          ? null
                                          : () async {
                                              final pickedDate =
                                                  await showDatePicker(
                                                    context: sheetContext,
                                                    initialDate: customAt,
                                                    firstDate: DateTime(1900),
                                                    lastDate: DateTime(2100),
                                                  );
                                              if (pickedDate != null) {
                                                setModalState(() {
                                                  customNotificationDates[index] =
                                                      DateTime(
                                                        pickedDate.year,
                                                        pickedDate.month,
                                                        pickedDate.day,
                                                        customAt.hour,
                                                        customAt.minute,
                                                      );
                                                  customNotificationDates =
                                                      _normalizeCustomNotificationDates(
                                                        customNotificationDates,
                                                      );
                                                });
                                              }
                                            },
                                      child: _pickerRow(
                                        Icons.event,
                                        'Data: ${DateFormatters.friendlyDateWithYear(customAt)}',
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: isSaving
                                          ? null
                                          : () async {
                                              final pickedTime =
                                                  await showTimePicker(
                                                    context: sheetContext,
                                                    initialTime: TimeOfDay(
                                                      hour: customAt.hour,
                                                      minute: customAt.minute,
                                                    ),
                                                  );
                                              if (pickedTime != null) {
                                                setModalState(() {
                                                  customNotificationDates[index] =
                                                      DateTime(
                                                        customAt.year,
                                                        customAt.month,
                                                        customAt.day,
                                                        pickedTime.hour,
                                                        pickedTime.minute,
                                                      );
                                                  customNotificationDates =
                                                      _normalizeCustomNotificationDates(
                                                        customNotificationDates,
                                                      );
                                                });
                                              }
                                            },
                                      child: _pickerRow(
                                        Icons.schedule,
                                        'Hora: ${DateFormatters.hourMinute(customAt.hour, customAt.minute)}',
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: isSaving
                                            ? null
                                            : () => setModalState(() {
                                                customNotificationDates
                                                    .removeAt(index);
                                                if (customNotificationDates
                                                    .isEmpty) {
                                                  customEnabled = false;
                                                }
                                              }),
                                        icon: const Icon(Icons.delete_outline),
                                        label: const Text('Remover'),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
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
                                        setModalState(() => isSaving = true);

                                        final customNotifyDates =
                                            notificationsEnabled &&
                                                customEnabled
                                            ? _normalizeCustomNotificationDates(
                                                customNotificationDates,
                                              )
                                            : const <DateTime>[];

                                        try {
                                          if (existing == null) {
                                            await state.addImportantDate(
                                              title: titleController.text
                                                  .trim(),
                                              description: descriptionController
                                                  .text
                                                  .trim(),
                                              date: selectedDate,
                                              notificationHour:
                                                  selectedNotificationTime.hour,
                                              notificationMinute:
                                                  selectedNotificationTime
                                                      .minute,
                                              repeatsAnnually: repeatsAnnually,
                                              notificationsEnabled:
                                                  notificationsEnabled,
                                              notificationSound:
                                                  selectedNotificationSound,
                                              notifyCustomDates:
                                                  customNotifyDates,
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
                                                notificationHour:
                                                    selectedNotificationTime
                                                        .hour,
                                                notificationMinute:
                                                    selectedNotificationTime
                                                        .minute,
                                                repeatsAnnually:
                                                    repeatsAnnually,
                                                notify3Months:
                                                    notificationsEnabled,
                                                notify1Month:
                                                    notificationsEnabled,
                                                notify1Week:
                                                    notificationsEnabled,
                                                notify1Day:
                                                    notificationsEnabled,
                                                notifyOnDay: false,
                                                notificationSound:
                                                    selectedNotificationSound,
                                                notifyCustomDates:
                                                    customNotifyDates,
                                                clearCustomDates:
                                                    !notificationsEnabled ||
                                                    !customEnabled,
                                              ),
                                            );
                                          }
                                          if (sheetContext.mounted) {
                                            Navigator.of(sheetContext).pop();
                                          }
                                        } on DuplicateImportantDateException {
                                          _logger.warning(
                                            'ImportantDatesScreen',
                                            'Cadastro/edição bloqueado por duplicidade de título + data.',
                                          );
                                          if (pageContext.mounted) {
                                            ScaffoldMessenger.of(
                                              pageContext,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Já existe uma data importante com o mesmo nome e a mesma data.',
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
                                                  'Não foi possível salvar a data agora. Tente novamente.',
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
  }

  List<DateTime> _normalizeCustomNotificationDates(Iterable<DateTime> values) {
    final unique = <int, DateTime>{};
    for (final value in values) {
      final normalized = value.isUtc ? value.toLocal() : value;
      unique[normalized.millisecondsSinceEpoch] = normalized;
    }

    final sorted = unique.values.toList(growable: false)
      ..sort((a, b) => a.compareTo(b));
    return sorted;
  }

  Widget _pickerRow(IconData icon, String text, {EdgeInsets? margin}) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
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
    final nextNotification = _nextNotification(date);

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
                onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
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
                label: Text(_daysLabel(date)),
              ),
              if (nextNotification != null)
                Chip(
                  avatar: const Icon(Icons.notifications_active, size: 16),
                  label: Text(
                    'Próxima notificação: ${DateFormatters.fullDateTime(nextNotification)}',
                  ),
                )
              else
                const Chip(
                  avatar: Icon(Icons.notifications_off, size: 16),
                  label: Text('Sem notificações futuras'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _daysLabel(ImportantDate date) {
    if (date.isPastNonRepeating) return 'Data passada';
    final days = date.daysUntilNextOccurrence;
    if (days == 0) return 'Hoje';
    if (days == 1) return 'Amanhã';
    if (days < 0) return 'Há ${days.abs()} dias';
    return 'Em $days dias';
  }

  DateTime? _nextNotification(ImportantDate date) {
    final now = DateTime.now();
    final minTrigger = now.add(const Duration(seconds: 5));
    final candidates = <DateTime>[];

    void addRelative({required int months, required int days}) {
      if (!date.repeatsAnnually) {
        final occurrence = DateTime(
          date.date.year,
          date.date.month,
          date.date.day,
          date.notificationHour,
          date.notificationMinute,
        );
        final trigger = _applyOffset(occurrence, months: months, days: days);
        if (trigger.isAfter(minTrigger)) candidates.add(trigger);
        return;
      }

      for (var delta = 0; delta <= 3; delta++) {
        final year = now.year + delta;
        final occurrence = _safeDate(
          year,
          date.date.month,
          date.date.day,
          date.notificationHour,
          date.notificationMinute,
        );
        final trigger = _applyOffset(occurrence, months: months, days: days);
        if (trigger.isAfter(minTrigger)) {
          candidates.add(trigger);
          break;
        }
      }
    }

    if (date.notify3Months) addRelative(months: 3, days: 0);
    if (date.notify1Month) addRelative(months: 1, days: 0);
    if (date.notify1Week) addRelative(months: 0, days: 7);
    if (date.notify1Day) addRelative(months: 0, days: 1);
    if (date.notifyOnDay) addRelative(months: 0, days: 0);

    for (final customAt in date.notifyCustomDates) {
      final normalizedCustomAt = customAt.isUtc ? customAt.toLocal() : customAt;
      if (normalizedCustomAt.isAfter(minTrigger)) {
        candidates.add(normalizedCustomAt);
      }
    }

    if (candidates.isEmpty) return null;
    candidates.sort();
    return candidates.first;
  }

  DateTime _applyOffset(
    DateTime occurrence, {
    required int months,
    required int days,
  }) {
    if (months > 0) {
      final totalMonths =
          (occurrence.year * 12 + (occurrence.month - 1)) - months;
      final targetYear = totalMonths ~/ 12;
      final targetMonth = totalMonths % 12 + 1;
      final maxDay = DateTime(targetYear, targetMonth + 1, 0).day;
      final targetDay = occurrence.day > maxDay ? maxDay : occurrence.day;
      return DateTime(
        targetYear,
        targetMonth,
        targetDay,
        occurrence.hour,
        occurrence.minute,
      );
    }
    return occurrence.subtract(Duration(days: days));
  }

  DateTime _safeDate(int year, int month, int day, int hour, int minute) {
    final maxDay = DateTime(year, month + 1, 0).day;
    final safeDay = day > maxDay ? maxDay : day;
    return DateTime(year, month, safeDay, hour, minute);
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

  String _sanitizeLink(String link) =>
      link.replaceAll(RegExp(r'[.,;:!?)\]}]+$'), '');

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
