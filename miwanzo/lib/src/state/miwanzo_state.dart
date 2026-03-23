import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../data/miwanzo_database.dart';
import '../models/category_entry.dart';
import '../models/important_date.dart';
import '../models/note_entry.dart';
import '../models/preference_item.dart';
import '../notifications/miwanzo_notifications.dart';

class MiwanzoState extends ChangeNotifier {
  MiwanzoState({MiwanzoDatabase? database, MiwanzoNotifications? notifications})
    : _database = database ?? MiwanzoDatabase.instance,
      _notifications = notifications ?? MiwanzoNotifications.instance {
    _initialize();
  }

  final MiwanzoDatabase _database;
  final MiwanzoNotifications _notifications;

  bool _isLoading = true;
  String? _errorMessage;

  List<CategoryEntry> _categories = [];
  List<ImportantDate> _importantDates = [];
  List<NoteEntry> _notes = [];
  List<PreferenceItem> _preferenceItems = [];

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

  List<PreferenceItem> itemsByCategory(int categoryId) {
    return preferenceItems
        .where((item) => item.categoryId == categoryId)
        .toList(growable: false);
  }

  Future<void> _initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _database.ensureReady();
      await _reloadAllData();
      await _notifications.syncImportantDateNotifications(_importantDates);
    } catch (_) {
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
    _categories = await _database.fetchCategories();
    _importantDates = await _database.fetchImportantDates();
    _notes = await _database.fetchNotes();
    _preferenceItems = await _database.fetchPreferenceItems();
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

    final insertedId = await _database.insertImportantDate(item);
    final inserted = item.copyWith(id: insertedId);

    _importantDates.add(inserted);
    await _notifications.scheduleForImportantDate(inserted);
    notifyListeners();
  }

  Future<void> updateImportantDate(ImportantDate date) async {
    await _database.updateImportantDate(date);

    final index = _importantDates.indexWhere((item) => item.id == date.id);
    if (index == -1) return;

    _importantDates[index] = date;
    await _notifications.scheduleForImportantDate(date);
    notifyListeners();
  }

  Future<void> deleteImportantDate(int id) async {
    await _database.deleteImportantDate(id);
    _importantDates.removeWhere((item) => item.id == id);
    await _notifications.cancelForImportantDate(id);
    notifyListeners();
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

    final insertedId = await _database.insertNote(note);
    _notes.insert(0, note.copyWith(id: insertedId));
    notifyListeners();
  }

  Future<void> updateNote(NoteEntry note) async {
    await _database.updateNote(note);

    final index = _notes.indexWhere((item) => item.id == note.id);
    if (index == -1) return;

    _notes[index] = note;
    notifyListeners();
  }

  Future<void> deleteNote(int id) async {
    await _database.deleteNote(id);
    _notes.removeWhere((item) => item.id == id);
    notifyListeners();
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

    final insertedId = await _database.insertPreferenceItem(item);
    _preferenceItems.insert(0, item.copyWith(id: insertedId));
    notifyListeners();
  }

  Future<void> updatePreferenceItem(PreferenceItem item) async {
    await _database.updatePreferenceItem(item);

    final index = _preferenceItems.indexWhere(
      (current) => current.id == item.id,
    );
    if (index == -1) return;

    _preferenceItems[index] = item;
    notifyListeners();
  }

  Future<void> deletePreferenceItem(int id) async {
    await _database.deletePreferenceItem(id);
    _preferenceItems.removeWhere((item) => item.id == id);
    notifyListeners();
  }
}
