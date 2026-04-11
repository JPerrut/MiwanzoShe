import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../data/shaumsi_database.dart';
import '../logging/app_logger.dart';
import '../models/category_entry.dart';
import '../models/important_date.dart';
import '../models/media_entry.dart';
import '../models/note_entry.dart';
import '../models/preference_item.dart';
import '../notifications/shaumsi_notifications.dart';

class DuplicateImportantDateException implements Exception {
  const DuplicateImportantDateException();
}

class ShauMsiState extends ChangeNotifier {
  ShauMsiState({ShauMsiDatabase? database, ShauMsiNotifications? notifications})
    : _database = database ?? ShauMsiDatabase.instance,
      _notifications = notifications ?? ShauMsiNotifications.instance {
    _initialize();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(performBackgroundSync());
    });
  }

  final ShauMsiDatabase _database;
  final ShauMsiNotifications _notifications;
  final AppLogger _logger = AppLogger.instance;
  late final Timer _syncTimer;

  bool _isLoading = true;
  bool _isSyncingInBackground = false;
  String? _errorMessage;

  List<CategoryEntry> _categories = [];
  List<ImportantDate> _importantDates = [];
  List<NoteEntry> _notes = [];
  List<PreferenceItem> _preferenceItems = [];
  List<MediaEntry> _mediaEntries = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  UnmodifiableListView<CategoryEntry> get categories =>
      UnmodifiableListView(_categories);

  List<ImportantDate> get importantDates => List.unmodifiable(_importantDates);

  List<ImportantDate> get upcomingDates {
    final dates = List<ImportantDate>.from(_importantDates)
      ..removeWhere((date) => date.isPastNonRepeating)
      ..sort((a, b) => a.nextOccurrence.compareTo(b.nextOccurrence));
    return dates;
  }

  List<ImportantDate> get allDatesForList {
    final upcoming = _importantDates
        .where((date) => !date.isPastNonRepeating)
        .toList(growable: false);
    final past = _importantDates
        .where((date) => date.isPastNonRepeating)
        .toList(growable: false);

    final upcomingSorted = List<ImportantDate>.from(upcoming)
      ..sort((a, b) => a.nextOccurrence.compareTo(b.nextOccurrence));
    final pastSorted = List<ImportantDate>.from(past)
      ..sort((a, b) => b.date.compareTo(a.date));

    return [...upcomingSorted, ...pastSorted];
  }

  List<NoteEntry> get notes {
    final allNotes = List<NoteEntry>.from(_notes)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return allNotes;
  }

  List<PreferenceItem> get preferenceItems {
    final items = List<PreferenceItem>.from(_preferenceItems)
      ..sort((a, b) => b.id.compareTo(a.id));
    return items;
  }

  List<NoteEntry> get latestNotes => notes.take(3).toList(growable: false);

  List<PreferenceItem> get latestPreferenceItems =>
      preferenceItems.take(3).toList(growable: false);

  List<MediaEntry> get mediaEntries {
    final items = List<MediaEntry>.from(_mediaEntries)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  @override
  void dispose() {
    _syncTimer.cancel();
    super.dispose();
  }

  List<PreferenceItem> itemsByCategory(int categoryId) {
    return preferenceItems
        .where((item) => item.categoryId == categoryId)
        .toList(growable: false);
  }

  Future<void> _initialize() async {
    _logger.info('ShauMsiState', 'Inicialização iniciada.');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _database.ensureReady();
      await _reloadAllData();

      try {
        await _notifications.syncImportantDateNotifications(_importantDates);
      } catch (error, stackTrace) {
        _logger.error(
          'ShauMsiState',
          'Falha ao sincronizar notificações na inicialização.',
          error: error,
          stackTrace: stackTrace,
        );
      }

      unawaited(performBackgroundSync(reloadWhenChanged: true));

      _logger.info(
        'ShauMsiState',
        'Inicialização concluída. Datas: ${_importantDates.length}, Notas: ${_notes.length}, Itens: ${_preferenceItems.length}.',
      );
    } catch (error, stackTrace) {
      _logger.error(
        'ShauMsiState',
        'Falha na inicialização.',
        error: error,
        stackTrace: stackTrace,
      );
      _errorMessage =
          'Não foi possível carregar os dados locais. Feche e abra o app novamente.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAll() async {
    await _initialize();
  }

  Future<void> performBackgroundSync({bool reloadWhenChanged = true}) async {
    if (_isLoading || _isSyncingInBackground) {
      return;
    }

    _isSyncingInBackground = true;

    try {
      final changed = await _database.syncWithCloud();
      if (!changed || !reloadWhenChanged) {
        return;
      }

      await _reloadAllData();
      notifyListeners();

      try {
        await _notifications.syncImportantDateNotifications(_importantDates);
      } catch (error, stackTrace) {
        _logger.error(
          'ShauMsiState',
          'Dados sincronizados, mas houve falha ao atualizar notificações.',
          error: error,
          stackTrace: stackTrace,
        );
      }
    } catch (error, stackTrace) {
      _logger.warning(
        'ShauMsiState',
        'Sincronização em segundo plano não concluída.',
        error: error,
      );
      _logger.error(
        'ShauMsiState',
        'Detalhes da falha na sincronização em segundo plano.',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _isSyncingInBackground = false;
    }
  }

  Future<void> _reloadAllData() async {
    _categories = List<CategoryEntry>.from(await _database.fetchCategories());
    _importantDates = List<ImportantDate>.from(
      await _database.fetchImportantDates(),
    );
    _notes = List<NoteEntry>.from(await _database.fetchNotes());
    _preferenceItems = List<PreferenceItem>.from(
      await _database.fetchPreferenceItems(),
    );
    _mediaEntries = List<MediaEntry>.from(await _database.fetchMediaEntries());
  }

  Future<void> addImportantDate({
    required String title,
    required String description,
    required DateTime date,
    required int notificationHour,
    required int notificationMinute,
    required bool repeatsAnnually,
    required bool notificationsEnabled,
    String notificationSound = ImportantDate.notificationSoundDefault,
    List<DateTime> notifyCustomDates = const [],
  }) async {
    if (_hasDuplicateImportantDate(
      title: title,
      date: date,
      repeatsAnnually: repeatsAnnually,
    )) {
      _logger.warning(
        'ShauMsiState',
        'Tentativa de cadastro duplicado de data importante.',
      );
      throw const DuplicateImportantDateException();
    }

    final item = ImportantDate(
      id: 0,
      title: title,
      description: description,
      date: date,
      notificationHour: notificationHour,
      notificationMinute: notificationMinute,
      repeatsAnnually: repeatsAnnually,
      notify3Months: notificationsEnabled,
      notify1Month: notificationsEnabled,
      notify1Week: notificationsEnabled,
      notify1Day: notificationsEnabled,
      notifyOnDay: false,
      notificationSound: notificationSound,
      notifyCustomDates: notificationsEnabled ? notifyCustomDates : const [],
    );

    _logger.info(
      'ShauMsiState',
      'Salvando data importante: "$title" em ${date.toIso8601String()}.',
    );

    try {
      final insertedId = await _database.insertImportantDate(item);
      final inserted = item.copyWith(id: insertedId);

      _importantDates.add(inserted);
      notifyListeners();

      try {
        await _notifications.scheduleForImportantDate(inserted);
      } catch (error, stackTrace) {
        _logger.error(
          'ShauMsiState',
          'Data salva, mas falhou ao agendar notificação.',
          error: error,
          stackTrace: stackTrace,
        );
      }

      _logger.info(
        'ShauMsiState',
        'Data importante salva com sucesso (id=$insertedId).',
      );
    } catch (error, stackTrace) {
      _logger.error(
        'ShauMsiState',
        'Falha ao salvar data importante.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> updateImportantDate(ImportantDate date) async {
    if (_hasDuplicateImportantDate(
      title: date.title,
      date: date.date,
      repeatsAnnually: date.repeatsAnnually,
      excludeId: date.id,
    )) {
      _logger.warning(
        'ShauMsiState',
        'Tentativa de atualização duplicada de data importante (id=${date.id}).',
      );
      throw const DuplicateImportantDateException();
    }

    _logger.info(
      'ShauMsiState',
      'Atualizando data importante (id=${date.id}).',
    );

    try {
      await _database.updateImportantDate(date);

      final index = _importantDates.indexWhere((item) => item.id == date.id);
      if (index == -1) {
        _logger.warning(
          'ShauMsiState',
          'Data atualizada no banco, mas não encontrada em memória (id=${date.id}).',
        );
        return;
      }

      _importantDates[index] = date;
      notifyListeners();

      try {
        await _notifications.scheduleForImportantDate(date);
      } catch (error, stackTrace) {
        _logger.error(
          'ShauMsiState',
          'Data atualizada, mas falhou ao reagendar notificação (id=${date.id}).',
          error: error,
          stackTrace: stackTrace,
        );
      }

      _logger.info(
        'ShauMsiState',
        'Data importante atualizada (id=${date.id}).',
      );
    } catch (error, stackTrace) {
      _logger.error(
        'ShauMsiState',
        'Falha ao atualizar data importante (id=${date.id}).',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> deleteImportantDate(int id) async {
    _logger.info('ShauMsiState', 'Excluindo data importante (id=$id).');

    try {
      await _database.deleteImportantDate(id);
      _importantDates.removeWhere((item) => item.id == id);
      notifyListeners();

      try {
        await _notifications.cancelForImportantDate(id);
      } catch (error, stackTrace) {
        _logger.error(
          'ShauMsiState',
          'Data excluída, mas falhou ao cancelar notificações (id=$id).',
          error: error,
          stackTrace: stackTrace,
        );
      }

      _logger.info('ShauMsiState', 'Data importante excluída (id=$id).');
    } catch (error, stackTrace) {
      _logger.error(
        'ShauMsiState',
        'Falha ao excluir data importante (id=$id).',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> addNote({
    required String title,
    required String description,
    required String tag,
  }) async {
    final note = NoteEntry(
      id: 0,
      title: title,
      description: description,
      tag: tag,
      createdAt: DateTime.now(),
    );

    _logger.info('ShauMsiState', 'Salvando nota "$title".');

    try {
      final insertedId = await _database.insertNote(note);
      _notes.insert(0, note.copyWith(id: insertedId));
      notifyListeners();
      _logger.info('ShauMsiState', 'Nota salva com sucesso (id=$insertedId).');
    } catch (error, stackTrace) {
      _logger.error(
        'ShauMsiState',
        'Falha ao salvar nota.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> updateNote(NoteEntry note) async {
    _logger.info('ShauMsiState', 'Atualizando nota (id=${note.id}).');

    try {
      await _database.updateNote(note);

      final index = _notes.indexWhere((item) => item.id == note.id);
      if (index == -1) {
        _logger.warning(
          'ShauMsiState',
          'Nota atualizada no banco, mas não encontrada em memória (id=${note.id}).',
        );
        return;
      }

      _notes[index] = note;
      notifyListeners();
      _logger.info('ShauMsiState', 'Nota atualizada (id=${note.id}).');
    } catch (error, stackTrace) {
      _logger.error(
        'ShauMsiState',
        'Falha ao atualizar nota (id=${note.id}).',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> deleteNote(int id) async {
    _logger.info('ShauMsiState', 'Excluindo nota (id=$id).');

    try {
      await _database.deleteNote(id);
      _notes.removeWhere((item) => item.id == id);
      notifyListeners();
      _logger.info('ShauMsiState', 'Nota excluída (id=$id).');
    } catch (error, stackTrace) {
      _logger.error(
        'ShauMsiState',
        'Falha ao excluir nota (id=$id).',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> addPreferenceItem({
    required int categoryId,
    required String category,
    required String name,
    required PreferenceStatus status,
    required String observation,
  }) async {
    final item = PreferenceItem(
      id: 0,
      categoryId: categoryId,
      category: category,
      name: name,
      status: status,
      observation: observation,
    );

    _logger.info(
      'ShauMsiState',
      'Salvando item de preferência "$name" (categoria="$category").',
    );

    try {
      final insertedId = await _database.insertPreferenceItem(item);
      _preferenceItems.insert(0, item.copyWith(id: insertedId));
      notifyListeners();
      _logger.info(
        'ShauMsiState',
        'Item de preferência salvo com sucesso (id=$insertedId).',
      );
    } catch (error, stackTrace) {
      _logger.error(
        'ShauMsiState',
        'Falha ao salvar item de preferência.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> updatePreferenceItem(PreferenceItem item) async {
    _logger.info(
      'ShauMsiState',
      'Atualizando item de preferência (id=${item.id}).',
    );

    try {
      await _database.updatePreferenceItem(item);

      final index = _preferenceItems.indexWhere(
        (current) => current.id == item.id,
      );
      if (index == -1) {
        _logger.warning(
          'ShauMsiState',
          'Item atualizado no banco, mas não encontrado em memória (id=${item.id}).',
        );
        return;
      }

      _preferenceItems[index] = item;
      notifyListeners();
      _logger.info(
        'ShauMsiState',
        'Item de preferência atualizado (id=${item.id}).',
      );
    } catch (error, stackTrace) {
      _logger.error(
        'ShauMsiState',
        'Falha ao atualizar item de preferência (id=${item.id}).',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> deletePreferenceItem(int id) async {
    _logger.info('ShauMsiState', 'Excluindo item de preferência (id=$id).');

    try {
      await _database.deletePreferenceItem(id);
      _preferenceItems.removeWhere((item) => item.id == id);
      notifyListeners();
      _logger.info('ShauMsiState', 'Item de preferência excluído (id=$id).');
    } catch (error, stackTrace) {
      _logger.error(
        'ShauMsiState',
        'Falha ao excluir item de preferência (id=$id).',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> addMediaEntry({
    required String path,
    required MediaType type,
  }) async {
    final entry = MediaEntry(
      id: 0,
      path: path,
      type: type,
      createdAt: DateTime.now(),
    );

    _logger.info('ShauMsiState', 'Salvando arquivo de mídia "$path".');

    try {
      final insertedId = await _database.insertMediaEntry(entry);
      _mediaEntries.insert(0, entry.copyWith(id: insertedId));
      notifyListeners();
      _logger.info('ShauMsiState', 'Arquivo de mídia salvo (id=$insertedId).');
    } catch (error, stackTrace) {
      _logger.error(
        'ShauMsiState',
        'Falha ao salvar arquivo de mídia.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> deleteMediaEntry(int id) async {
    _logger.info('ShauMsiState', 'Excluindo arquivo de mídia (id=$id).');

    try {
      await _database.deleteMediaEntry(id);
      _mediaEntries.removeWhere((item) => item.id == id);
      notifyListeners();
      _logger.info('ShauMsiState', 'Arquivo de mídia excluído (id=$id).');
    } catch (error, stackTrace) {
      _logger.error(
        'ShauMsiState',
        'Falha ao excluir arquivo de mídia (id=$id).',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  bool _hasDuplicateImportantDate({
    required String title,
    required DateTime date,
    required bool repeatsAnnually,
    int? excludeId,
  }) {
    final normalizedTitle = title.trim();

    return _importantDates.any((existing) {
      if (excludeId != null && existing.id == excludeId) {
        return false;
      }

      if (existing.title.trim() != normalizedTitle ||
          existing.repeatsAnnually != repeatsAnnually) {
        return false;
      }

      if (repeatsAnnually) {
        return existing.date.month == date.month &&
            existing.date.day == date.day;
      }

      final existingDate = DateTime(
        existing.date.year,
        existing.date.month,
        existing.date.day,
      );
      final targetDate = DateTime(date.year, date.month, date.day);
      return existingDate == targetDate;
    });
  }
}
