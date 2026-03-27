import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/category_entry.dart';
import '../models/important_date.dart';
import '../models/media_entry.dart';
import '../models/note_entry.dart';
import '../models/preference_item.dart';

class MiwanzoDatabase {
  MiwanzoDatabase._();

  static final MiwanzoDatabase instance = MiwanzoDatabase._();

  static const String _databaseName = 'miwanzo.db';
  static const int _databaseVersion = 6;

  static const List<String> _defaultCategories = [
    'Comidas',
    'Doces',
    'Filmes',
    'Lugares',
    'Presentes',
    'Objetos',
    'Música',
    'Cheiros',
    'Roupas',
    'Cores',
    'Outros',
  ];

  Database? _database;

  Future<Database> get database async {
    final current = _database;
    if (current != null) return current;

    final created = await _openDatabase();
    _database = created;
    return created;
  }

  bool get _useFfi {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  Future<Database> _openDatabase() async {
    final databasePath = await _buildDatabasePath();

    if (_useFfi) {
      sqfliteFfiInit();
      return databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: _databaseVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
          onOpen: _onOpen,
        ),
      );
    }

    return openDatabase(
      databasePath,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  Future<String> _buildDatabasePath() async {
    if (_useFfi) {
      final basePath = await databaseFactoryFfi.getDatabasesPath();
      return path.join(basePath, _databaseName);
    }

    final basePath = await getDatabasesPath();
    return path.join(basePath, _databaseName);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE datas_importantes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        titulo TEXT NOT NULL,
        descricao TEXT,
        data TEXT NOT NULL,
        notificacao_hora INTEGER NOT NULL DEFAULT 9,
        notificacao_minuto INTEGER NOT NULL DEFAULT 0,
        repetir_anualmente INTEGER NOT NULL DEFAULT 1,
        notificacao_3_meses INTEGER NOT NULL DEFAULT 0,
        notificacao_1_mes INTEGER NOT NULL DEFAULT 0,
        notificacao_1_semana INTEGER NOT NULL DEFAULT 0,
        notificacao_1_dia INTEGER NOT NULL DEFAULT 0,
        notificacao_no_dia INTEGER NOT NULL DEFAULT 0,
        notificacao_personalizada_dias INTEGER,
        notificacao_personalizada_data TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE notas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        titulo TEXT NOT NULL,
        descricao TEXT NOT NULL,
        tag TEXT NOT NULL,
        data_criacao TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE categorias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE itens (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        categoria_id INTEGER NOT NULL,
        nome TEXT NOT NULL,
        gosta INTEGER NOT NULL DEFAULT 0,
        nao_gosta INTEGER NOT NULL DEFAULT 0,
        observacao TEXT,
        FOREIGN KEY(categoria_id) REFERENCES categorias(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX idx_datas_importantes_unique_titulo_data
      ON datas_importantes(titulo, data)
    ''');

    await db.execute('''
      CREATE TABLE arquivos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        caminho TEXT NOT NULL,
        tipo TEXT NOT NULL,
        data_criacao TEXT NOT NULL
      )
    ''');

    await _seedDefaultCategories(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        DELETE FROM datas_importantes
        WHERE id NOT IN (
          SELECT MIN(id)
          FROM datas_importantes
          GROUP BY titulo, data
        )
      ''');

      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_datas_importantes_unique_titulo_data
        ON datas_importantes(titulo, data)
      ''');
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS arquivos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          caminho TEXT NOT NULL,
          tipo TEXT NOT NULL,
          data_criacao TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 4) {
      await db.execute('''
        ALTER TABLE datas_importantes
        ADD COLUMN repetir_anualmente INTEGER NOT NULL DEFAULT 1
      ''');
    }

    if (oldVersion < 5) {
      await db.execute('''
        ALTER TABLE datas_importantes
        ADD COLUMN notificacao_hora INTEGER NOT NULL DEFAULT 9
      ''');
      await db.execute('''
        ALTER TABLE datas_importantes
        ADD COLUMN notificacao_minuto INTEGER NOT NULL DEFAULT 0
      ''');
    }

    if (oldVersion < 6) {
      await db.execute('''
        ALTER TABLE datas_importantes
        ADD COLUMN notificacao_personalizada_data TEXT
      ''');
    }
  }

  Future<void> _onOpen(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _seedDefaultCategories(Database db) async {
    final batch = db.batch();

    for (final category in _defaultCategories) {
      batch.insert('categorias', {
        'nome': category,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    await batch.commit(noResult: true);
  }

  Future<void> ensureReady() async {
    await database;
    await ensureDefaultCategories();
  }

  Future<void> ensureDefaultCategories() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM categorias'),
    );

    if ((count ?? 0) > 0) return;

    await _seedDefaultCategories(db);
  }

  Future<List<CategoryEntry>> fetchCategories() async {
    final db = await database;
    final maps = await db.query('categorias', orderBy: 'id ASC');
    return maps.map(CategoryEntry.fromMap).toList(growable: false);
  }

  Future<List<ImportantDate>> fetchImportantDates() async {
    final db = await database;
    final maps = await db.query('datas_importantes', orderBy: 'data ASC');
    return maps.map(ImportantDate.fromMap).toList(growable: false);
  }

  Future<int> insertImportantDate(ImportantDate date) async {
    final db = await database;
    return db.insert('datas_importantes', date.toMap());
  }

  Future<void> updateImportantDate(ImportantDate date) async {
    final db = await database;
    await db.update(
      'datas_importantes',
      date.toMap(),
      where: 'id = ?',
      whereArgs: [date.id],
    );
  }

  Future<void> deleteImportantDate(int id) async {
    final db = await database;
    await db.delete('datas_importantes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<NoteEntry>> fetchNotes() async {
    final db = await database;
    final maps = await db.query('notas', orderBy: 'data_criacao DESC, id DESC');
    return maps.map(NoteEntry.fromMap).toList(growable: false);
  }

  Future<int> insertNote(NoteEntry note) async {
    final db = await database;
    return db.insert('notas', note.toMap());
  }

  Future<void> updateNote(NoteEntry note) async {
    final db = await database;
    await db.update(
      'notas',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<void> deleteNote(int id) async {
    final db = await database;
    await db.delete('notas', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<PreferenceItem>> fetchPreferenceItems() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT
        itens.id,
        itens.categoria_id,
        itens.nome,
        itens.gosta,
        itens.nao_gosta,
        itens.observacao,
        categorias.nome AS categoria_nome
      FROM itens
      INNER JOIN categorias ON categorias.id = itens.categoria_id
      ORDER BY itens.id DESC
    ''');

    return maps.map(PreferenceItem.fromMap).toList(growable: false);
  }

  Future<int> insertPreferenceItem(PreferenceItem item) async {
    final db = await database;
    return db.insert('itens', item.toMap());
  }

  Future<void> updatePreferenceItem(PreferenceItem item) async {
    final db = await database;
    await db.update(
      'itens',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> deletePreferenceItem(int id) async {
    final db = await database;
    await db.delete('itens', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<MediaEntry>> fetchMediaEntries() async {
    final db = await database;
    final maps = await db.query(
      'arquivos',
      orderBy: 'data_criacao DESC, id DESC',
    );
    return maps.map(MediaEntry.fromMap).toList(growable: false);
  }

  Future<int> insertMediaEntry(MediaEntry entry) async {
    final db = await database;
    return db.insert('arquivos', entry.toMap());
  }

  Future<void> deleteMediaEntry(int id) async {
    final db = await database;
    await db.delete('arquivos', where: 'id = ?', whereArgs: [id]);
  }
}
