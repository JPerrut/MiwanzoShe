import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../data/miwanzo_database.dart';
import '../logging/app_logger.dart';
import '../models/category_entry.dart';
import '../models/important_date.dart';
import '../models/media_entry.dart';
import '../models/note_entry.dart';
import '../models/preference_item.dart';
import '../notifications/miwanzo_notifications.dart';

class DuplicateImportantDateException implements Exception {
  const DuplicateImportantDateException();
}

class MiwanzoState extends ChangeNotifier {
  MiwanzoState({MiwanzoDatabase? database, MiwanzoNotifications? notifications})
    : _database = database ?? MiwanzoDatabase.instance,
      _notifications = notifications ?? MiwanzoNotifications.instance {
    _initialize();
  }

  final MiwanzoDatabase _database;
  final MiwanzoNotifications _notifications;
  final AppLogger _logger = AppLogger.instance;

  bool _isLoading = true;
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
      ..sort((a, b) => a.nextOccurrence.compareTo(b.nextOccurrence));
    return dates;
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

  List<PreferenceItem> itemsByCategory(int categoryId) {
    return preferenceItems
        .where((item) => item.categoryId == categoryId)
        .toList(growable: false);
  }

  Future<void> _initialize() async {
    _logger.info('MiwanzoState', 'Inicialização iniciada.');
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
          'MiwanzoState',
          'Falha ao sincronizar notificações na inicialização.',
          error: error,
          stackTrace: stackTrace,
        );
      }

      _logger.info(
        'MiwanzoState',
        'Inicialização concluída. Datas: ${_importantDates.length}, Notas: ${_notes.length}, Itens: ${_preferenceItems.length}.',
      );
    } catch (error, stackTrace) {
      _logger.error(
        'MiwanzoState',
        'Falha na inicialização.',
        error: error,
        stackTrace: stackTrace,
      );
      _errorMessage =
          'Não foi possível carregar os dados locais. Verifique o armazenamento do dispositivo.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAll() async {
    await _initialize();
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
    required bool notify3Months,
    required bool notify1Month,
    required bool notify1Week,
    required bool notify1Day,
    required bool notifyOnDay,
    int? notifyCustomDays,
  }) async {
    if (_hasDuplicateImportantDate(title: title, date: date)) {
      _logger.warning(
        'MiwanzoState',
        'Tentativa de cadastro duplicado de data importante.',
      );
      throw const DuplicateImportantDateException();
    }

    final item = ImportantDate(
      id: 0,
      title: title,
      description: description,
      date: date,
      notify3Months: notify3Months,
      notify1Month: notify1Month,
      notify1Week: notify1Week,
      notify1Day: notify1Day,
      notifyOnDay: notifyOnDay,
      notifyCustomDays: notifyCustomDays,
    );

    _logger.info(
      'MiwanzoState',
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
          'MiwanzoState',
          'Data salva, mas falhou ao agendar notificação.',
          error: error,
          stackTrace: stackTrace,
        );
      }

      _logger.info(
        'MiwanzoState',
        'Data importante salva com sucesso (id=$insertedId).',
      );
    } catch (error, stackTrace) {
      _logger.error(
        'MiwanzoState',
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
      excludeId: date.id,
    )) {
      _logger.warning(
        'MiwanzoState',
        'Tentativa de atualização duplicada de data importante (id=${date.id}).',
      );
      throw const DuplicateImportantDateException();
    }

    _logger.info(
      'MiwanzoState',
      'Atualizando data importante (id=${date.id}).',
    );

    try {
      await _database.updateImportantDate(date);

      final index = _importantDates.indexWhere((item) => item.id == date.id);
      if (index == -1) {
        _logger.warning(
          'MiwanzoState',
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
          'MiwanzoState',
          'Data atualizada, mas falhou ao reagendar notificação (id=${date.id}).',
          error: error,
          stackTrace: stackTrace,
        );
      }

      _logger.info(
        'MiwanzoState',
        'Data importante atualizada (id=${date.id}).',
      );
    } catch (error, stackTrace) {
      _logger.error(
        'MiwanzoState',
        'Falha ao atualizar data importante (id=${date.id}).',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> deleteImportantDate(int id) async {
    _logger.info('MiwanzoState', 'Excluindo data importante (id=$id).');

    try {
      await _database.deleteImportantDate(id);
      _importantDates.removeWhere((item) => item.id == id);
      notifyListeners();

      try {
        await _notifications.cancelForImportantDate(id);
      } catch (error, stackTrace) {
        _logger.error(
          'MiwanzoState',
          'Data excluída, mas falhou ao cancelar notificações (id=$id).',
          error: error,
          stackTrace: stackTrace,
        );
      }

      _logger.info('MiwanzoState', 'Data importante excluída (id=$id).');
    } catch (error, stackTrace) {
      _logger.error(
        'MiwanzoState',
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

    _logger.info('MiwanzoState', 'Salvando nota "$title".');

    try {
      final insertedId = await _database.insertNote(note);
      _notes.insert(0, note.copyWith(id: insertedId));
      notifyListeners();
      _logger.info('MiwanzoState', 'Nota salva com sucesso (id=$insertedId).');
    } catch (error, stackTrace) {
      _logger.error(
        'MiwanzoState',
        'Falha ao salvar nota.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> updateNote(NoteEntry note) async {
    _logger.info('MiwanzoState', 'Atualizando nota (id=${note.id}).');

    try {
      await _database.updateNote(note);

      final index = _notes.indexWhere((item) => item.id == note.id);
      if (index == -1) {
        _logger.warning(
          'MiwanzoState',
          'Nota atualizada no banco, mas não encontrada em memória (id=${note.id}).',
        );
        return;
      }

      _notes[index] = note;
      notifyListeners();
      _logger.info('MiwanzoState', 'Nota atualizada (id=${note.id}).');
    } catch (error, stackTrace) {
      _logger.error(
        'MiwanzoState',
        'Falha ao atualizar nota (id=${note.id}).',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> deleteNote(int id) async {
    _logger.info('MiwanzoState', 'Excluindo nota (id=$id).');

    try {
      await _database.deleteNote(id);
      _notes.removeWhere((item) => item.id == id);
      notifyListeners();
      _logger.info('MiwanzoState', 'Nota excluída (id=$id).');
    } catch (error, stackTrace) {
      _logger.error(
        'MiwanzoState',
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
      'MiwanzoState',
      'Salvando item de preferência "$name" (categoria="$category").',
    );

    try {
      final insertedId = await _database.insertPreferenceItem(item);
      _preferenceItems.insert(0, item.copyWith(id: insertedId));
      notifyListeners();
      _logger.info(
        'MiwanzoState',
        'Item de preferência salvo com sucesso (id=$insertedId).',
      );
    } catch (error, stackTrace) {
      _logger.error(
        'MiwanzoState',
        'Falha ao salvar item de preferência.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> updatePreferenceItem(PreferenceItem item) async {
    _logger.info(
      'MiwanzoState',
      'Atualizando item de preferência (id=${item.id}).',
    );

    try {
      await _database.updatePreferenceItem(item);

      final index = _preferenceItems.indexWhere(
        (current) => current.id == item.id,
      );
      if (index == -1) {
        _logger.warning(
          'MiwanzoState',
          'Item atualizado no banco, mas não encontrado em memória (id=${item.id}).',
        );
        return;
      }

      _preferenceItems[index] = item;
      notifyListeners();
      _logger.info(
        'MiwanzoState',
        'Item de preferência atualizado (id=${item.id}).',
      );
    } catch (error, stackTrace) {
      _logger.error(
        'MiwanzoState',
        'Falha ao atualizar item de preferência (id=${item.id}).',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> deletePreferenceItem(int id) async {
    _logger.info('MiwanzoState', 'Excluindo item de preferência (id=$id).');

    try {
      await _database.deletePreferenceItem(id);
      _preferenceItems.removeWhere((item) => item.id == id);
      notifyListeners();
      _logger.info('MiwanzoState', 'Item de preferência excluído (id=$id).');
    } catch (error, stackTrace) {
      _logger.error(
        'MiwanzoState',
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

    _logger.info('MiwanzoState', 'Salvando arquivo de midia "$path".');

    try {
      final insertedId = await _database.insertMediaEntry(entry);
      _mediaEntries.insert(0, entry.copyWith(id: insertedId));
      notifyListeners();
      _logger.info('MiwanzoState', 'Arquivo de midia salvo (id=$insertedId).');
    } catch (error, stackTrace) {
      _logger.error(
        'MiwanzoState',
        'Falha ao salvar arquivo de midia.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> deleteMediaEntry(int id) async {
    _logger.info('MiwanzoState', 'Excluindo arquivo de midia (id=$id).');

    try {
      await _database.deleteMediaEntry(id);
      _mediaEntries.removeWhere((item) => item.id == id);
      notifyListeners();
      _logger.info('MiwanzoState', 'Arquivo de midia excluido (id=$id).');
    } catch (error, stackTrace) {
      _logger.error(
        'MiwanzoState',
        'Falha ao excluir arquivo de midia (id=$id).',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  bool _hasDuplicateImportantDate({
    required String title,
    required DateTime date,
    int? excludeId,
  }) {
    final normalizedTitle = title.trim();
    final targetDate = DateTime(date.year, date.month, date.day);

    return _importantDates.any((existing) {
      if (excludeId != null && existing.id == excludeId) {
        return false;
      }

      final existingDate = DateTime(
        existing.date.year,
        existing.date.month,
        existing.date.day,
      );

      return existing.title.trim() == normalizedTitle &&
          existingDate == targetDate;
    });
  }
}
