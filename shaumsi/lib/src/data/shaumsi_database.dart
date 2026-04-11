import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:postgres/postgres.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../logging/app_logger.dart';
import '../models/category_entry.dart';
import '../models/important_date.dart';
import '../models/media_entry.dart';
import '../models/note_entry.dart';
import '../models/preference_item.dart';

class ShauMsiDatabase {
  ShauMsiDatabase._({
    String? databaseUrlOverride,
    String? localDatabasePathOverride,
    DatabaseFactory? databaseFactoryOverride,
  }) : _databaseUrlOverride = databaseUrlOverride,
       _localDatabasePathOverride = localDatabasePathOverride,
       _databaseFactoryOverride = databaseFactoryOverride;

  static final ShauMsiDatabase instance = ShauMsiDatabase._();

  @visibleForTesting
  factory ShauMsiDatabase.test({
    String? databaseUrl,
    required String localDatabasePath,
    DatabaseFactory? databaseFactory,
  }) {
    return ShauMsiDatabase._(
      databaseUrlOverride: databaseUrl,
      localDatabasePathOverride: localDatabasePath,
      databaseFactoryOverride: databaseFactory,
    );
  }

  static const String _localDatabaseName = 'shaumsi_offline.db';
  static const String _legacyDatabaseName = 'shaumsi.db';
  static const int _localSchemaVersion = 1;
  static const String _databaseUrlDefine = 'DATABASE_URL';
  static const String _databaseUrlUnpooledDefine = 'DATABASE_URL_UNPOOLED';
  static const String _legacyImportMetaKey =
      'legacy_sqlite_import_completed_v2';
  static const String _lastSuccessfulSyncMetaKey = 'last_successful_sync_at';
  static const String _syncStatePendingUpsert = 'pending_upsert';
  static const String _syncStatePendingDelete = 'pending_delete';
  static const String _syncStateSynced = 'synced';
  static const Duration _remoteConnectTimeout = Duration(seconds: 2);
  static const Set<String> _supportedConnectionQueryParameters = {
    'application_name',
    'client_encoding',
    'connect_timeout',
    'database',
    'host',
    'password',
    'port',
    'query_timeout',
    'replication',
    'sslcert',
    'sslkey',
    'sslmode',
    'sslrootcert',
    'user',
    'username',
  };

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

  static const List<_SeedPreferenceItem> _starterPreferenceItems = [
    _SeedPreferenceItem(
      categoryName: 'Doces',
      name: 'Kitkat Dark',
      status: PreferenceStatus.likes,
      observation: '',
    ),
    _SeedPreferenceItem(
      categoryName: 'Doces',
      name: 'chocolate 40% Menta',
      status: PreferenceStatus.likes,
      observation: '',
    ),
    _SeedPreferenceItem(
      categoryName: 'Objetos',
      name: 'conchas',
      status: PreferenceStatus.likes,
      observation: '',
    ),
  ];

  static const List<_SeedImportantDate> _starterImportantDates = [
    _SeedImportantDate(
      title: 'Aniversário',
      description: 'teste',
      year: 2026,
      month: 7,
      day: 2,
      repeatsAnnually: true,
      notificationsEnabled: true,
      notificationHour: 9,
      notificationMinute: 0,
      notificationSound: ImportantDate.notificationSoundDefault,
    ),
    _SeedImportantDate(
      title: 'Dia do Taekwondo',
      description: '',
      year: 2026,
      month: 9,
      day: 4,
      repeatsAnnually: true,
      notificationsEnabled: true,
      notificationHour: 9,
      notificationMinute: 0,
      notificationSound: ImportantDate.notificationSoundDefault,
    ),
    _SeedImportantDate(
      title: 'Primeiro encontro',
      description: '',
      year: 2026,
      month: 3,
      day: 21,
      repeatsAnnually: false,
      notificationsEnabled: false,
      notificationHour: 9,
      notificationMinute: 0,
      notificationSound: ImportantDate.notificationSoundDefault,
    ),
  ];

  final AppLogger _logger = AppLogger.instance;
  final String? _databaseUrlOverride;
  final String? _localDatabasePathOverride;
  final DatabaseFactory? _databaseFactoryOverride;
  final Random _random = Random.secure();

  Database? _localDatabase;
  Future<void>? _ensureReadyFuture;
  Future<bool>? _activeSyncFuture;

  bool get _useFfi {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  DatabaseFactory get _databaseFactory {
    final override = _databaseFactoryOverride;
    if (override != null) {
      return override;
    }

    if (_useFfi) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }

    return databaseFactory;
  }

  String get _compiledDatabaseUrl =>
      const String.fromEnvironment(_databaseUrlDefine);
  String get _compiledDatabaseUrlUnpooled =>
      const String.fromEnvironment(_databaseUrlUnpooledDefine);

  String? get _databaseUrl {
    final override = _databaseUrlOverride;
    if (override != null && override.trim().isNotEmpty) {
      return normalizeDatabaseUrl(override);
    }

    if (_compiledDatabaseUrl.isNotEmpty) {
      return normalizeDatabaseUrl(_compiledDatabaseUrl);
    }
    if (_compiledDatabaseUrlUnpooled.isNotEmpty) {
      return normalizeDatabaseUrl(_compiledDatabaseUrlUnpooled);
    }

    final env = Platform.environment[_databaseUrlDefine];
    if (env != null && env.trim().isNotEmpty) {
      return normalizeDatabaseUrl(env);
    }

    final envUnpooled = Platform.environment[_databaseUrlUnpooledDefine];
    if (envUnpooled != null && envUnpooled.trim().isNotEmpty) {
      return normalizeDatabaseUrl(envUnpooled);
    }

    return null;
  }

  @visibleForTesting
  static String normalizeDatabaseUrl(String rawUrl) {
    final trimmed = _stripWrappingQuotes(rawUrl.trim());
    if (trimmed.isEmpty) {
      return trimmed;
    }

    final uri = Uri.parse(trimmed);
    final parameters = <String, List<String>>{};

    for (final entry in uri.queryParametersAll.entries) {
      if (_supportedConnectionQueryParameters.contains(entry.key)) {
        parameters[entry.key] = List<String>.from(entry.value);
      }
    }

    parameters.putIfAbsent(
      'connect_timeout',
      () => ['${_remoteConnectTimeout.inSeconds}'],
    );

    final query = <String>[];
    for (final entry in parameters.entries) {
      for (final value in entry.value) {
        query.add(
          '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(value)}',
        );
      }
    }

    return uri.replace(query: query.join('&')).toString();
  }

  static String _stripWrappingQuotes(String value) {
    if (value.length < 2) {
      return value;
    }

    final startsWithDoubleQuote = value.startsWith('"');
    final endsWithDoubleQuote = value.endsWith('"');
    if (startsWithDoubleQuote && endsWithDoubleQuote) {
      return value.substring(1, value.length - 1);
    }

    final startsWithSingleQuote = value.startsWith("'");
    final endsWithSingleQuote = value.endsWith("'");
    if (startsWithSingleQuote && endsWithSingleQuote) {
      return value.substring(1, value.length - 1);
    }

    return value;
  }

  Future<Database> get _local async {
    final current = _localDatabase;
    if (current != null && current.isOpen) {
      return current;
    }

    final databasePath = await _buildLocalDatabasePath();
    final opened = await _databaseFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: _localSchemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, _) => _initializeLocalSchema(db),
        onUpgrade: (db, _, _) => _initializeLocalSchema(db),
      ),
    );

    _localDatabase = opened;
    return opened;
  }

  Future<void> close() async {
    final db = _localDatabase;
    _localDatabase = null;
    _ensureReadyFuture = null;
    if (db != null && db.isOpen) {
      await db.close();
    }
  }

  Future<void> ensureReady() {
    return _ensureReadyFuture ??= _ensureReadyInternal();
  }

  Future<void> _ensureReadyInternal() async {
    try {
      final db = await _local;
      await _seedDefaultCategories(db);
      await _importLegacySqliteIfNeeded(db);
      await _seedStarterData(db);
    } catch (_) {
      _ensureReadyFuture = null;
      rethrow;
    }
  }

  Future<bool> syncWithCloud() async {
    final existing = _activeSyncFuture;
    if (existing != null) {
      return existing;
    }

    final future = _syncWithCloudInternal();
    _activeSyncFuture = future;
    future.whenComplete(() {
      if (identical(_activeSyncFuture, future)) {
        _activeSyncFuture = null;
      }
    });
    return future;
  }

  Future<bool> _syncWithCloudInternal() async {
    await ensureReady();

    final databaseUrl = _databaseUrl;
    if (databaseUrl == null || databaseUrl.isEmpty) {
      return false;
    }

    final localDb = await _local;
    Connection? remote;

    try {
      remote = await Connection.openFromUrl(databaseUrl);
      await _initializeRemoteSchema(remote);
      await _syncCategories(localDb, remote);
      await _pushPendingChanges(localDb, remote);
      final localChanged = await _pullRemoteSnapshot(localDb, remote);
      await _setLocalMetaValue(
        localDb,
        key: _lastSuccessfulSyncMetaKey,
        value: _nowIso(),
      );
      return localChanged;
    } catch (error, stackTrace) {
      _logger.warning(
        'ShauMsiDatabase',
        'Sincronização com o Neon indisponível; mantendo cache local.',
        error: error,
      );
      _logger.error(
        'ShauMsiDatabase',
        'Detalhes da falha de sincronização.',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    } finally {
      if (remote != null) {
        await remote.close(force: true);
      }
    }
  }

  Future<void> _initializeLocalSchema(Database db) async {
    for (final statement in _localSchemaStatements) {
      await db.execute(statement);
    }
  }

  Future<void> _initializeRemoteSchema(SessionExecutor executor) async {
    await executor.runTx((session) async {
      for (final statement in _remoteSchemaStatements) {
        await session.execute(statement, ignoreRows: true);
      }
    });
  }

  Future<void> _syncCategories(Database localDb, Connection remote) async {
    final localCategories = await localDb.query(
      'categorias',
      orderBy: 'id ASC',
    );

    await remote.runTx((session) async {
      for (final category in localCategories) {
        final name = (category['nome'] as String?) ?? '';
        if (name.trim().isEmpty) {
          continue;
        }

        await session.execute(
          Sql.named('''
            INSERT INTO categorias (nome)
            VALUES (@nome)
            ON CONFLICT (nome) DO NOTHING
            '''),
          parameters: {'nome': name},
          ignoreRows: true,
        );
      }
    });

    final remoteCategoryIds = await _fetchRemoteCategoryIdsByName(remote);
    await localDb.transaction((txn) async {
      for (final entry in remoteCategoryIds.entries) {
        await txn.update(
          'categorias',
          {'remote_id': entry.value},
          where: 'nome = ?',
          whereArgs: [entry.key],
        );

        final existing = await txn.query(
          'categorias',
          columns: ['id'],
          where: 'nome = ?',
          whereArgs: [entry.key],
          limit: 1,
        );

        if (existing.isEmpty) {
          await txn.insert('categorias', {
            'nome': entry.key,
            'remote_id': entry.value,
          });
        }
      }
    });
  }

  Future<void> _seedDefaultCategories(Database db) async {
    await db.transaction((txn) async {
      for (final category in _defaultCategories) {
        await txn.insert('categorias', {
          'nome': category,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<void> _seedStarterData(Database db) async {
    await db.transaction((txn) async {
      final categoryIdsByName = await _fetchLocalCategoryIdsByName(txn);
      final existingDateKeys = await _fetchExistingImportantDateKeys(txn);
      final existingPreferenceKeys = await _fetchExistingPreferenceKeys(txn);

      for (final seed in _starterImportantDates) {
        final date = seed.toImportantDate();
        final key = _buildImportantDateSeedKey(
          title: date.title,
          isoDate: date.date.toIso8601String(),
        );
        if (!existingDateKeys.add(key)) {
          continue;
        }

        await _insertLocalImportantDate(
          txn,
          date,
          clientId: _generateClientId('date'),
          updatedAt: _nowIso(),
          syncState: _syncStatePendingUpsert,
        );
      }

      for (final seed in _starterPreferenceItems) {
        final categoryId = categoryIdsByName[_normalizeKey(seed.categoryName)];
        if (categoryId == null) {
          continue;
        }

        final item = seed.toPreferenceItem(categoryId);
        final key = _buildPreferenceSeedKey(item);
        if (!existingPreferenceKeys.add(key)) {
          continue;
        }

        await _insertLocalPreferenceItem(
          txn,
          item,
          clientId: _generateClientId('item'),
          updatedAt: _nowIso(),
          syncState: _syncStatePendingUpsert,
        );
      }
    });
  }

  Future<void> _importLegacySqliteIfNeeded(Database localDb) async {
    final legacyDatabase = await _openLegacySqliteIfExists();
    if (legacyDatabase == null) {
      return;
    }

    try {
      final alreadyImported = await _isLegacyImportCompleted(localDb);
      if (alreadyImported) {
        return;
      }

      final snapshot = await _readLegacySnapshot(legacyDatabase);

      await localDb.transaction((txn) async {
        final categoryIdsByName = await _fetchLocalCategoryIdsByName(txn);
        final existingDateKeys = await _fetchExistingImportantDateKeys(txn);
        final existingPreferenceKeys = await _fetchExistingPreferenceKeys(txn);
        final existingNoteKeys = await _fetchExistingNoteKeys(txn);
        final existingMediaKeys = await _fetchExistingMediaKeys(txn);

        for (final category in snapshot.categories) {
          await txn.insert('categorias', {
            'nome': category.name,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }

        categoryIdsByName
          ..clear()
          ..addAll(await _fetchLocalCategoryIdsByName(txn));

        for (final date in snapshot.importantDates) {
          final key = _buildImportantDateSeedKey(
            title: date.title,
            isoDate: date.date.toIso8601String(),
          );
          if (!existingDateKeys.add(key)) {
            continue;
          }

          await _insertLocalImportantDate(
            txn,
            date,
            clientId: _generateClientId('date'),
            updatedAt: _nowIso(),
            syncState: _syncStatePendingUpsert,
          );
        }

        for (final note in snapshot.notes) {
          final key = _buildNoteKey(note);
          if (!existingNoteKeys.add(key)) {
            continue;
          }

          await _insertLocalNote(
            txn,
            note,
            clientId: _generateClientId('note'),
            updatedAt: _nowIso(),
            syncState: _syncStatePendingUpsert,
          );
        }

        for (final item in snapshot.preferenceItems) {
          final categoryId = categoryIdsByName[_normalizeKey(item.category)];
          if (categoryId == null) {
            continue;
          }

          final normalized = item.copyWith(categoryId: categoryId);
          final key = _buildPreferenceSeedKey(normalized);
          if (!existingPreferenceKeys.add(key)) {
            continue;
          }

          await _insertLocalPreferenceItem(
            txn,
            normalized,
            clientId: _generateClientId('item'),
            updatedAt: _nowIso(),
            syncState: _syncStatePendingUpsert,
          );
        }

        for (final entry in snapshot.mediaEntries) {
          final key = _buildMediaKey(entry);
          if (!existingMediaKeys.add(key)) {
            continue;
          }

          await _insertLocalMediaEntry(
            txn,
            entry,
            clientId: _generateClientId('media'),
            updatedAt: _nowIso(),
            syncState: _syncStatePendingUpsert,
          );
        }

        await _setLocalMetaValue(txn, key: _legacyImportMetaKey, value: '1');
      });
    } finally {
      await legacyDatabase.close();
    }
  }

  Future<bool> _isLegacyImportCompleted(DatabaseExecutor executor) async {
    final result = await executor.query(
      'app_meta',
      columns: ['valor'],
      where: 'chave = ?',
      whereArgs: [_legacyImportMetaKey],
      limit: 1,
    );

    if (result.isEmpty) {
      return false;
    }

    return (result.first['valor'] as String?) == '1';
  }

  Future<void> _setLocalMetaValue(
    DatabaseExecutor executor, {
    required String key,
    required String value,
  }) async {
    await executor.insert('app_meta', {
      'chave': key,
      'valor': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, int>> _fetchLocalCategoryIdsByName(
    DatabaseExecutor executor,
  ) async {
    final result = await executor.query(
      'categorias',
      columns: ['id', 'nome'],
      orderBy: 'id ASC',
    );

    return {
      for (final row in result)
        _normalizeKey((row['nome'] as String?) ?? ''):
            ((row['id'] as num?) ?? 0).toInt(),
    };
  }

  Future<Map<String, int>> _fetchRemoteCategoryIdsByName(
    Session session,
  ) async {
    final result = await session.execute(
      'SELECT id, nome FROM categorias ORDER BY id ASC',
    );

    return {
      for (final row in result)
        ((row[1] as String?) ?? ''): ((row[0] as num?) ?? 0).toInt(),
    };
  }

  Future<Set<String>> _fetchExistingImportantDateKeys(
    DatabaseExecutor executor,
  ) async {
    final result = await executor.query(
      'datas_importantes',
      columns: ['titulo', 'data'],
      where: 'removido = 0',
    );

    return result
        .map(
          (row) => _buildImportantDateSeedKey(
            title: (row['titulo'] as String?) ?? '',
            isoDate: (row['data'] as String?) ?? '',
          ),
        )
        .toSet();
  }

  Future<Set<String>> _fetchExistingPreferenceKeys(
    DatabaseExecutor executor,
  ) async {
    final result = await executor.rawQuery('''
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
      WHERE itens.removido = 0
      ''');

    return result
        .map(PreferenceItem.fromMap)
        .map(_buildPreferenceSeedKey)
        .toSet();
  }

  Future<Set<String>> _fetchExistingNoteKeys(DatabaseExecutor executor) async {
    final result = await executor.query(
      'notas',
      columns: ['id', 'titulo', 'descricao', 'tag', 'data_criacao'],
      where: 'removido = 0',
    );

    return result.map(NoteEntry.fromMap).map(_buildNoteKey).toSet();
  }

  Future<Set<String>> _fetchExistingMediaKeys(DatabaseExecutor executor) async {
    final result = await executor.query(
      'arquivos',
      columns: ['id', 'caminho', 'tipo', 'data_criacao'],
      where: 'removido = 0',
    );

    return result.map(MediaEntry.fromMap).map(_buildMediaKey).toSet();
  }

  Future<Database?> _openLegacySqliteIfExists() async {
    final databasePath = await _buildLegacyDatabasePath();
    if (!await File(databasePath).exists()) {
      return null;
    }

    if (_useFfi) {
      return databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(readOnly: true),
      );
    }

    return openDatabase(databasePath, readOnly: true);
  }

  Future<String> _buildLocalDatabasePath() async {
    final override = _localDatabasePathOverride;
    if (override != null && override.trim().isNotEmpty) {
      return override;
    }

    final basePath = _useFfi
        ? await databaseFactoryFfi.getDatabasesPath()
        : await getDatabasesPath();
    return path.join(basePath, _localDatabaseName);
  }

  Future<String> _buildLegacyDatabasePath() async {
    final basePath = _useFfi
        ? await databaseFactoryFfi.getDatabasesPath()
        : await getDatabasesPath();
    return path.join(basePath, _legacyDatabaseName);
  }

  Future<_LegacySqliteSnapshot> _readLegacySnapshot(Database db) async {
    final categoryMaps = await db.query('categorias', orderBy: 'id ASC');
    final dateMaps = await db.query('datas_importantes', orderBy: 'data ASC');
    final noteMaps = await db.query(
      'notas',
      orderBy: 'data_criacao DESC, id DESC',
    );
    final itemMaps = await db.rawQuery('''
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
    final mediaMaps = await db.query(
      'arquivos',
      orderBy: 'data_criacao DESC, id DESC',
    );

    return _LegacySqliteSnapshot(
      categories: categoryMaps
          .map(CategoryEntry.fromMap)
          .toList(growable: false),
      importantDates: dateMaps
          .map(ImportantDate.fromMap)
          .toList(growable: false),
      notes: noteMaps.map(NoteEntry.fromMap).toList(growable: false),
      preferenceItems: itemMaps
          .map(PreferenceItem.fromMap)
          .toList(growable: false),
      mediaEntries: mediaMaps.map(MediaEntry.fromMap).toList(growable: false),
    );
  }

  Future<List<CategoryEntry>> fetchCategories() async {
    await ensureReady();
    final db = await _local;
    final result = await db.query(
      'categorias',
      columns: ['id', 'nome'],
      orderBy: 'id ASC',
    );
    return result.map(CategoryEntry.fromMap).toList(growable: false);
  }

  Future<List<ImportantDate>> fetchImportantDates() async {
    await ensureReady();
    final db = await _local;
    final result = await db.query(
      'datas_importantes',
      columns: _importantDateColumns,
      where: 'removido = 0',
      orderBy: 'data ASC',
    );
    return result.map(ImportantDate.fromMap).toList(growable: false);
  }

  Future<int> insertImportantDate(ImportantDate date) async {
    await ensureReady();
    final db = await _local;
    final insertedId = await db.transaction((txn) async {
      return _insertLocalImportantDate(
        txn,
        date,
        clientId: _generateClientId('date'),
        updatedAt: _nowIso(),
        syncState: _syncStatePendingUpsert,
      );
    });
    unawaited(syncWithCloud());
    return insertedId;
  }

  Future<int> _insertLocalImportantDate(
    DatabaseExecutor executor,
    ImportantDate date, {
    required String clientId,
    required String updatedAt,
    required String syncState,
    int? remoteId,
    String? syncedAt,
    bool removed = false,
  }) {
    return executor.insert('datas_importantes', {
      ...date.toMap(),
      'remote_id': remoteId,
      'client_id': clientId,
      'atualizado_em': updatedAt,
      'sincronizado_em': syncedAt,
      'pendencia': syncState,
      'removido': removed ? 1 : 0,
    });
  }

  Future<void> updateImportantDate(ImportantDate date) async {
    await ensureReady();
    final db = await _local;
    await db.update(
      'datas_importantes',
      {
        ...date.toMap(),
        'atualizado_em': _nowIso(),
        'pendencia': _syncStatePendingUpsert,
        'removido': 0,
      },
      where: 'id = ?',
      whereArgs: [date.id],
    );
    unawaited(syncWithCloud());
  }

  Future<void> deleteImportantDate(int id) async {
    await ensureReady();
    final db = await _local;
    final current = await db.query(
      'datas_importantes',
      columns: ['remote_id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (current.isEmpty) {
      return;
    }

    final remoteId = (current.first['remote_id'] as num?)?.toInt();
    if (remoteId == null) {
      await db.delete('datas_importantes', where: 'id = ?', whereArgs: [id]);
    } else {
      await db.update(
        'datas_importantes',
        {
          'removido': 1,
          'pendencia': _syncStatePendingDelete,
          'atualizado_em': _nowIso(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    unawaited(syncWithCloud());
  }

  Future<List<NoteEntry>> fetchNotes() async {
    await ensureReady();
    final db = await _local;
    final result = await db.query(
      'notas',
      columns: _noteColumns,
      where: 'removido = 0',
      orderBy: 'data_criacao DESC, id DESC',
    );
    return result.map(NoteEntry.fromMap).toList(growable: false);
  }

  Future<int> insertNote(NoteEntry note) async {
    await ensureReady();
    final db = await _local;
    final insertedId = await db.transaction((txn) async {
      return _insertLocalNote(
        txn,
        note,
        clientId: _generateClientId('note'),
        updatedAt: _nowIso(),
        syncState: _syncStatePendingUpsert,
      );
    });
    unawaited(syncWithCloud());
    return insertedId;
  }

  Future<int> _insertLocalNote(
    DatabaseExecutor executor,
    NoteEntry note, {
    required String clientId,
    required String updatedAt,
    required String syncState,
    int? remoteId,
    String? syncedAt,
    bool removed = false,
  }) {
    return executor.insert('notas', {
      ...note.toMap(),
      'remote_id': remoteId,
      'client_id': clientId,
      'atualizado_em': updatedAt,
      'sincronizado_em': syncedAt,
      'pendencia': syncState,
      'removido': removed ? 1 : 0,
    });
  }

  Future<void> updateNote(NoteEntry note) async {
    await ensureReady();
    final db = await _local;
    await db.update(
      'notas',
      {
        ...note.toMap(),
        'atualizado_em': _nowIso(),
        'pendencia': _syncStatePendingUpsert,
        'removido': 0,
      },
      where: 'id = ?',
      whereArgs: [note.id],
    );
    unawaited(syncWithCloud());
  }

  Future<void> deleteNote(int id) async {
    await ensureReady();
    final db = await _local;
    final current = await db.query(
      'notas',
      columns: ['remote_id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (current.isEmpty) {
      return;
    }

    final remoteId = (current.first['remote_id'] as num?)?.toInt();
    if (remoteId == null) {
      await db.delete('notas', where: 'id = ?', whereArgs: [id]);
    } else {
      await db.update(
        'notas',
        {
          'removido': 1,
          'pendencia': _syncStatePendingDelete,
          'atualizado_em': _nowIso(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    unawaited(syncWithCloud());
  }

  Future<List<PreferenceItem>> fetchPreferenceItems() async {
    await ensureReady();
    final db = await _local;
    final result = await db.rawQuery('''
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
      WHERE itens.removido = 0
      ORDER BY itens.id DESC
      ''');

    return result.map(PreferenceItem.fromMap).toList(growable: false);
  }

  Future<int> insertPreferenceItem(PreferenceItem item) async {
    await ensureReady();
    final db = await _local;
    final insertedId = await db.transaction((txn) async {
      return _insertLocalPreferenceItem(
        txn,
        item,
        clientId: _generateClientId('item'),
        updatedAt: _nowIso(),
        syncState: _syncStatePendingUpsert,
      );
    });
    unawaited(syncWithCloud());
    return insertedId;
  }

  Future<int> _insertLocalPreferenceItem(
    DatabaseExecutor executor,
    PreferenceItem item, {
    required String clientId,
    required String updatedAt,
    required String syncState,
    int? remoteId,
    String? syncedAt,
    bool removed = false,
  }) {
    return executor.insert('itens', {
      ...item.toMap(),
      'remote_id': remoteId,
      'client_id': clientId,
      'atualizado_em': updatedAt,
      'sincronizado_em': syncedAt,
      'pendencia': syncState,
      'removido': removed ? 1 : 0,
    });
  }

  Future<void> updatePreferenceItem(PreferenceItem item) async {
    await ensureReady();
    final db = await _local;
    await db.update(
      'itens',
      {
        ...item.toMap(),
        'atualizado_em': _nowIso(),
        'pendencia': _syncStatePendingUpsert,
        'removido': 0,
      },
      where: 'id = ?',
      whereArgs: [item.id],
    );
    unawaited(syncWithCloud());
  }

  Future<void> deletePreferenceItem(int id) async {
    await ensureReady();
    final db = await _local;
    final current = await db.query(
      'itens',
      columns: ['remote_id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (current.isEmpty) {
      return;
    }

    final remoteId = (current.first['remote_id'] as num?)?.toInt();
    if (remoteId == null) {
      await db.delete('itens', where: 'id = ?', whereArgs: [id]);
    } else {
      await db.update(
        'itens',
        {
          'removido': 1,
          'pendencia': _syncStatePendingDelete,
          'atualizado_em': _nowIso(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    unawaited(syncWithCloud());
  }

  Future<List<MediaEntry>> fetchMediaEntries() async {
    await ensureReady();
    final db = await _local;
    final result = await db.query(
      'arquivos',
      columns: _mediaColumns,
      where: 'removido = 0',
      orderBy: 'data_criacao DESC, id DESC',
    );
    return result.map(MediaEntry.fromMap).toList(growable: false);
  }

  Future<int> insertMediaEntry(MediaEntry entry) async {
    await ensureReady();
    final db = await _local;
    final insertedId = await db.transaction((txn) async {
      return _insertLocalMediaEntry(
        txn,
        entry,
        clientId: _generateClientId('media'),
        updatedAt: _nowIso(),
        syncState: _syncStatePendingUpsert,
      );
    });
    unawaited(syncWithCloud());
    return insertedId;
  }

  Future<int> _insertLocalMediaEntry(
    DatabaseExecutor executor,
    MediaEntry entry, {
    required String clientId,
    required String updatedAt,
    required String syncState,
    int? remoteId,
    String? syncedAt,
    bool removed = false,
  }) {
    return executor.insert('arquivos', {
      ...entry.toMap(),
      'remote_id': remoteId,
      'client_id': clientId,
      'atualizado_em': updatedAt,
      'sincronizado_em': syncedAt,
      'pendencia': syncState,
      'removido': removed ? 1 : 0,
    });
  }

  Future<void> deleteMediaEntry(int id) async {
    await ensureReady();
    final db = await _local;
    final current = await db.query(
      'arquivos',
      columns: ['remote_id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (current.isEmpty) {
      return;
    }

    final remoteId = (current.first['remote_id'] as num?)?.toInt();
    if (remoteId == null) {
      await db.delete('arquivos', where: 'id = ?', whereArgs: [id]);
    } else {
      await db.update(
        'arquivos',
        {
          'removido': 1,
          'pendencia': _syncStatePendingDelete,
          'atualizado_em': _nowIso(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    unawaited(syncWithCloud());
  }

  Future<void> _pushPendingChanges(Database localDb, Connection remote) async {
    final remoteCategoryIds = await _fetchRemoteCategoryIdsByName(remote);
    await _pushPendingImportantDates(localDb, remote);
    await _pushPendingNotes(localDb, remote);
    await _pushPendingPreferenceItems(localDb, remote, remoteCategoryIds);
    await _pushPendingMediaEntries(localDb, remote);
  }

  Future<void> _pushPendingImportantDates(
    Database localDb,
    Connection remote,
  ) async {
    final pendingRows = await localDb.query(
      'datas_importantes',
      where: 'pendencia != ?',
      whereArgs: [_syncStateSynced],
      orderBy: 'atualizado_em ASC, id ASC',
    );

    for (final row in pendingRows) {
      if (_isRemovedRow(row)) {
        await _pushDeletedRow(
          localDb,
          remote,
          tableName: 'datas_importantes',
          row: row,
        );
        continue;
      }

      await _pushImportantDateUpsert(localDb, remote, row);
    }
  }

  Future<void> _pushPendingNotes(Database localDb, Connection remote) async {
    final pendingRows = await localDb.query(
      'notas',
      where: 'pendencia != ?',
      whereArgs: [_syncStateSynced],
      orderBy: 'atualizado_em ASC, id ASC',
    );

    for (final row in pendingRows) {
      if (_isRemovedRow(row)) {
        await _pushDeletedRow(localDb, remote, tableName: 'notas', row: row);
        continue;
      }

      await _pushNoteUpsert(localDb, remote, row);
    }
  }

  Future<void> _pushPendingPreferenceItems(
    Database localDb,
    Connection remote,
    Map<String, int> remoteCategoryIds,
  ) async {
    final pendingRows = await localDb.rawQuery(
      '''
      SELECT
        itens.*,
        categorias.nome AS categoria_nome
      FROM itens
      INNER JOIN categorias ON categorias.id = itens.categoria_id
      WHERE itens.pendencia != ?
      ORDER BY itens.atualizado_em ASC, itens.id ASC
    ''',
      [_syncStateSynced],
    );

    for (final row in pendingRows) {
      if (_isRemovedRow(row)) {
        await _pushDeletedRow(localDb, remote, tableName: 'itens', row: row);
        continue;
      }

      final categoryName = (row['categoria_nome'] as String?) ?? '';
      var remoteCategoryId = remoteCategoryIds[categoryName];
      if (remoteCategoryId == null) {
        final inserted = await remote.execute(
          Sql.named('''
            INSERT INTO categorias (nome)
            VALUES (@nome)
            ON CONFLICT (nome)
            DO UPDATE SET nome = EXCLUDED.nome
            RETURNING id
            '''),
          parameters: {'nome': categoryName},
        );
        remoteCategoryId = ((inserted.first[0] as num?) ?? 0).toInt();
        remoteCategoryIds[categoryName] = remoteCategoryId;
      }

      await _pushPreferenceItemUpsert(
        localDb,
        remote,
        row,
        remoteCategoryId: remoteCategoryId,
      );
    }
  }

  Future<void> _pushPendingMediaEntries(
    Database localDb,
    Connection remote,
  ) async {
    final pendingRows = await localDb.query(
      'arquivos',
      where: 'pendencia != ?',
      whereArgs: [_syncStateSynced],
      orderBy: 'atualizado_em ASC, id ASC',
    );

    for (final row in pendingRows) {
      if (_isRemovedRow(row)) {
        await _pushDeletedRow(localDb, remote, tableName: 'arquivos', row: row);
        continue;
      }

      await _pushMediaEntryUpsert(localDb, remote, row);
    }
  }

  Future<void> _pushDeletedRow(
    Database localDb,
    Connection remote, {
    required String tableName,
    required Map<String, Object?> row,
  }) async {
    final remoteId = (row['remote_id'] as num?)?.toInt();
    final clientId = (row['client_id'] as String?) ?? '';

    if (remoteId != null) {
      await remote.execute(
        Sql.named('DELETE FROM $tableName WHERE id = @id'),
        parameters: {'id': remoteId},
        ignoreRows: true,
      );
    } else if (clientId.isNotEmpty) {
      await remote.execute(
        Sql.named('DELETE FROM $tableName WHERE client_id = @client_id'),
        parameters: {'client_id': clientId},
        ignoreRows: true,
      );
    }

    await localDb.delete(tableName, where: 'id = ?', whereArgs: [row['id']]);
  }

  Future<void> _pushImportantDateUpsert(
    Database localDb,
    Connection remote,
    Map<String, Object?> row,
  ) async {
    final date = ImportantDate.fromMap(row);
    final clientId = (row['client_id'] as String?) ?? _generateClientId('date');
    final updatedAt = (row['atualizado_em'] as String?) ?? _nowIso();

    final match = await _findRemoteImportantDate(remote, row);
    final remoteId = (match?['id'] as num?)?.toInt();
    final resolvedClientId = (match?['client_id'] as String?) ?? clientId;

    if (remoteId != null) {
      await remote.execute(
        Sql.named('''
          UPDATE datas_importantes
          SET
            client_id = @client_id,
            titulo = @titulo,
            descricao = @descricao,
            data = @data,
            notificacao_hora = @notificacao_hora,
            notificacao_minuto = @notificacao_minuto,
            repetir_anualmente = @repetir_anualmente,
            notificacao_3_meses = @notificacao_3_meses,
            notificacao_1_mes = @notificacao_1_mes,
            notificacao_1_semana = @notificacao_1_semana,
            notificacao_1_dia = @notificacao_1_dia,
            notificacao_no_dia = @notificacao_no_dia,
            notificacao_som = @notificacao_som,
            notificacao_personalizada_data = @notificacao_personalizada_data,
            updated_at = @updated_at
          WHERE id = @id
          '''),
        parameters: {
          ...date.toMap(),
          'client_id': resolvedClientId,
          'updated_at': updatedAt,
          'id': remoteId,
        },
        ignoreRows: true,
      );
    } else {
      final inserted = await remote.execute(
        Sql.named('''
          INSERT INTO datas_importantes (
            client_id,
            titulo,
            descricao,
            data,
            notificacao_hora,
            notificacao_minuto,
            repetir_anualmente,
            notificacao_3_meses,
            notificacao_1_mes,
            notificacao_1_semana,
            notificacao_1_dia,
            notificacao_no_dia,
            notificacao_som,
            notificacao_personalizada_data,
            updated_at
          ) VALUES (
            @client_id,
            @titulo,
            @descricao,
            @data,
            @notificacao_hora,
            @notificacao_minuto,
            @repetir_anualmente,
            @notificacao_3_meses,
            @notificacao_1_mes,
            @notificacao_1_semana,
            @notificacao_1_dia,
            @notificacao_no_dia,
            @notificacao_som,
            @notificacao_personalizada_data,
            @updated_at
          )
          RETURNING id, client_id
          '''),
        parameters: {
          ...date.toMap(),
          'client_id': clientId,
          'updated_at': updatedAt,
        },
      );

      await _markLocalRowAsSynced(
        localDb,
        tableName: 'datas_importantes',
        localId: ((row['id'] as num?) ?? 0).toInt(),
        remoteId: ((inserted.first[0] as num?) ?? 0).toInt(),
        clientId: (inserted.first[1] as String?) ?? clientId,
      );
      return;
    }

    await _markLocalRowAsSynced(
      localDb,
      tableName: 'datas_importantes',
      localId: ((row['id'] as num?) ?? 0).toInt(),
      remoteId: remoteId,
      clientId: resolvedClientId,
    );
  }

  Future<void> _pushNoteUpsert(
    Database localDb,
    Connection remote,
    Map<String, Object?> row,
  ) async {
    final note = NoteEntry.fromMap(row);
    final clientId = (row['client_id'] as String?) ?? _generateClientId('note');
    final updatedAt = (row['atualizado_em'] as String?) ?? _nowIso();

    final match = await _findRemoteNote(remote, row);
    final remoteId = (match?['id'] as num?)?.toInt();
    final resolvedClientId = (match?['client_id'] as String?) ?? clientId;

    if (remoteId != null) {
      await remote.execute(
        Sql.named('''
          UPDATE notas
          SET
            client_id = @client_id,
            titulo = @titulo,
            descricao = @descricao,
            tag = @tag,
            data_criacao = @data_criacao,
            updated_at = @updated_at
          WHERE id = @id
          '''),
        parameters: {
          ...note.toMap(),
          'client_id': resolvedClientId,
          'updated_at': updatedAt,
          'id': remoteId,
        },
        ignoreRows: true,
      );
    } else {
      final inserted = await remote.execute(
        Sql.named('''
          INSERT INTO notas (
            client_id,
            titulo,
            descricao,
            tag,
            data_criacao,
            updated_at
          ) VALUES (
            @client_id,
            @titulo,
            @descricao,
            @tag,
            @data_criacao,
            @updated_at
          )
          RETURNING id, client_id
          '''),
        parameters: {
          ...note.toMap(),
          'client_id': clientId,
          'updated_at': updatedAt,
        },
      );

      await _markLocalRowAsSynced(
        localDb,
        tableName: 'notas',
        localId: ((row['id'] as num?) ?? 0).toInt(),
        remoteId: ((inserted.first[0] as num?) ?? 0).toInt(),
        clientId: (inserted.first[1] as String?) ?? clientId,
      );
      return;
    }

    await _markLocalRowAsSynced(
      localDb,
      tableName: 'notas',
      localId: ((row['id'] as num?) ?? 0).toInt(),
      remoteId: remoteId,
      clientId: resolvedClientId,
    );
  }

  Future<void> _pushPreferenceItemUpsert(
    Database localDb,
    Connection remote,
    Map<String, Object?> row, {
    required int remoteCategoryId,
  }) async {
    final categoryName = (row['categoria_nome'] as String?) ?? '';
    final item = PreferenceItem.fromMap({
      ...row,
      'categoria_id': row['categoria_id'],
      'categoria_nome': categoryName,
    });
    final clientId = (row['client_id'] as String?) ?? _generateClientId('item');
    final updatedAt = (row['atualizado_em'] as String?) ?? _nowIso();

    final match = await _findRemotePreferenceItem(remote, row);
    final remoteId = (match?['id'] as num?)?.toInt();
    final resolvedClientId = (match?['client_id'] as String?) ?? clientId;

    if (remoteId != null) {
      await remote.execute(
        Sql.named('''
          UPDATE itens
          SET
            client_id = @client_id,
            categoria_id = @categoria_id,
            nome = @nome,
            gosta = @gosta,
            nao_gosta = @nao_gosta,
            observacao = @observacao,
            updated_at = @updated_at
          WHERE id = @id
          '''),
        parameters: {
          ...item.toMap(),
          'categoria_id': remoteCategoryId,
          'client_id': resolvedClientId,
          'updated_at': updatedAt,
          'id': remoteId,
        },
        ignoreRows: true,
      );
    } else {
      final inserted = await remote.execute(
        Sql.named('''
          INSERT INTO itens (
            client_id,
            categoria_id,
            nome,
            gosta,
            nao_gosta,
            observacao,
            updated_at
          ) VALUES (
            @client_id,
            @categoria_id,
            @nome,
            @gosta,
            @nao_gosta,
            @observacao,
            @updated_at
          )
          RETURNING id, client_id
          '''),
        parameters: {
          ...item.toMap(),
          'categoria_id': remoteCategoryId,
          'client_id': clientId,
          'updated_at': updatedAt,
        },
      );

      await _markLocalRowAsSynced(
        localDb,
        tableName: 'itens',
        localId: ((row['id'] as num?) ?? 0).toInt(),
        remoteId: ((inserted.first[0] as num?) ?? 0).toInt(),
        clientId: (inserted.first[1] as String?) ?? clientId,
      );
      return;
    }

    await _markLocalRowAsSynced(
      localDb,
      tableName: 'itens',
      localId: ((row['id'] as num?) ?? 0).toInt(),
      remoteId: remoteId,
      clientId: resolvedClientId,
    );
  }

  Future<void> _pushMediaEntryUpsert(
    Database localDb,
    Connection remote,
    Map<String, Object?> row,
  ) async {
    final entry = MediaEntry.fromMap(row);
    final clientId =
        (row['client_id'] as String?) ?? _generateClientId('media');
    final updatedAt = (row['atualizado_em'] as String?) ?? _nowIso();

    final match = await _findRemoteMediaEntry(remote, row);
    final remoteId = (match?['id'] as num?)?.toInt();
    final resolvedClientId = (match?['client_id'] as String?) ?? clientId;

    if (remoteId != null) {
      await remote.execute(
        Sql.named('''
          UPDATE arquivos
          SET
            client_id = @client_id,
            caminho = @caminho,
            tipo = @tipo,
            data_criacao = @data_criacao,
            updated_at = @updated_at
          WHERE id = @id
          '''),
        parameters: {
          ...entry.toMap(),
          'client_id': resolvedClientId,
          'updated_at': updatedAt,
          'id': remoteId,
        },
        ignoreRows: true,
      );
    } else {
      final inserted = await remote.execute(
        Sql.named('''
          INSERT INTO arquivos (
            client_id,
            caminho,
            tipo,
            data_criacao,
            updated_at
          ) VALUES (
            @client_id,
            @caminho,
            @tipo,
            @data_criacao,
            @updated_at
          )
          RETURNING id, client_id
          '''),
        parameters: {
          ...entry.toMap(),
          'client_id': clientId,
          'updated_at': updatedAt,
        },
      );

      await _markLocalRowAsSynced(
        localDb,
        tableName: 'arquivos',
        localId: ((row['id'] as num?) ?? 0).toInt(),
        remoteId: ((inserted.first[0] as num?) ?? 0).toInt(),
        clientId: (inserted.first[1] as String?) ?? clientId,
      );
      return;
    }

    await _markLocalRowAsSynced(
      localDb,
      tableName: 'arquivos',
      localId: ((row['id'] as num?) ?? 0).toInt(),
      remoteId: remoteId,
      clientId: resolvedClientId,
    );
  }

  Future<void> _markLocalRowAsSynced(
    Database localDb, {
    required String tableName,
    required int localId,
    required int remoteId,
    required String clientId,
  }) async {
    await localDb.update(
      tableName,
      {
        'remote_id': remoteId,
        'client_id': clientId,
        'pendencia': _syncStateSynced,
        'sincronizado_em': _nowIso(),
        'removido': 0,
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<bool> _pullRemoteSnapshot(Database localDb, Connection remote) async {
    var localChanged = false;

    final remoteDates = await remote.execute(
      'SELECT * FROM datas_importantes ORDER BY data ASC',
    );
    localChanged =
        await _pullRemoteImportantDates(localDb, remoteDates) || localChanged;

    final remoteNotes = await remote.execute(
      'SELECT * FROM notas ORDER BY data_criacao DESC, id DESC',
    );
    localChanged = await _pullRemoteNotes(localDb, remoteNotes) || localChanged;

    final remoteItems = await remote.execute('''
      SELECT
        itens.*,
        categorias.nome AS categoria_nome
      FROM itens
      INNER JOIN categorias ON categorias.id = itens.categoria_id
      ORDER BY itens.id DESC
      ''');
    localChanged =
        await _pullRemotePreferenceItems(localDb, remoteItems) || localChanged;

    final remoteMedia = await remote.execute(
      'SELECT * FROM arquivos ORDER BY data_criacao DESC, id DESC',
    );
    localChanged =
        await _pullRemoteMediaEntries(localDb, remoteMedia) || localChanged;

    return localChanged;
  }

  Future<bool> _pullRemoteImportantDates(
    Database localDb,
    Result remoteRows,
  ) async {
    var changed = false;
    final seenClientIds = <String>{};

    for (final row in remoteRows) {
      final map = row.toColumnMap();
      final remoteClientId = (map['client_id'] as String?) ?? '';
      if (remoteClientId.isNotEmpty) {
        seenClientIds.add(remoteClientId);
      }

      changed =
          await _upsertLocalImportantDateFromRemote(localDb, map) || changed;
    }

    changed =
        await _pruneMissingLocalRows(
          localDb,
          tableName: 'datas_importantes',
          remoteClientIds: seenClientIds,
        ) ||
        changed;
    return changed;
  }

  Future<bool> _pullRemoteNotes(Database localDb, Result remoteRows) async {
    var changed = false;
    final seenClientIds = <String>{};

    for (final row in remoteRows) {
      final map = row.toColumnMap();
      final remoteClientId = (map['client_id'] as String?) ?? '';
      if (remoteClientId.isNotEmpty) {
        seenClientIds.add(remoteClientId);
      }

      changed = await _upsertLocalNoteFromRemote(localDb, map) || changed;
    }

    changed =
        await _pruneMissingLocalRows(
          localDb,
          tableName: 'notas',
          remoteClientIds: seenClientIds,
        ) ||
        changed;
    return changed;
  }

  Future<bool> _pullRemotePreferenceItems(
    Database localDb,
    Result remoteRows,
  ) async {
    var changed = false;
    final seenClientIds = <String>{};

    for (final row in remoteRows) {
      final map = row.toColumnMap();
      final remoteClientId = (map['client_id'] as String?) ?? '';
      if (remoteClientId.isNotEmpty) {
        seenClientIds.add(remoteClientId);
      }

      changed =
          await _upsertLocalPreferenceItemFromRemote(localDb, map) || changed;
    }

    changed =
        await _pruneMissingLocalRows(
          localDb,
          tableName: 'itens',
          remoteClientIds: seenClientIds,
        ) ||
        changed;
    return changed;
  }

  Future<bool> _pullRemoteMediaEntries(
    Database localDb,
    Result remoteRows,
  ) async {
    var changed = false;
    final seenClientIds = <String>{};

    for (final row in remoteRows) {
      final map = row.toColumnMap();
      final remoteClientId = (map['client_id'] as String?) ?? '';
      if (remoteClientId.isNotEmpty) {
        seenClientIds.add(remoteClientId);
      }

      changed = await _upsertLocalMediaEntryFromRemote(localDb, map) || changed;
    }

    changed =
        await _pruneMissingLocalRows(
          localDb,
          tableName: 'arquivos',
          remoteClientIds: seenClientIds,
        ) ||
        changed;
    return changed;
  }

  Future<bool> _upsertLocalImportantDateFromRemote(
    Database localDb,
    Map<String, Object?> remoteRow,
  ) async {
    final localRow = await _findMatchingLocalImportantDate(localDb, remoteRow);
    if (!_shouldApplyRemote(localRow, remoteRow)) {
      return false;
    }

    final values = {
      ...ImportantDate.fromMap(remoteRow).toMap(),
      'remote_id': remoteRow['id'],
      'client_id': remoteRow['client_id'],
      'atualizado_em': (remoteRow['updated_at'] as String?) ?? _nowIso(),
      'sincronizado_em': _nowIso(),
      'pendencia': _syncStateSynced,
      'removido': 0,
    };

    if (localRow == null) {
      await localDb.insert('datas_importantes', values);
      return true;
    }

    await localDb.update(
      'datas_importantes',
      values,
      where: 'id = ?',
      whereArgs: [localRow['id']],
    );
    return true;
  }

  Future<bool> _upsertLocalNoteFromRemote(
    Database localDb,
    Map<String, Object?> remoteRow,
  ) async {
    final localRow = await _findMatchingLocalNote(localDb, remoteRow);
    if (!_shouldApplyRemote(localRow, remoteRow)) {
      return false;
    }

    final values = {
      ...NoteEntry.fromMap(remoteRow).toMap(),
      'remote_id': remoteRow['id'],
      'client_id': remoteRow['client_id'],
      'atualizado_em': (remoteRow['updated_at'] as String?) ?? _nowIso(),
      'sincronizado_em': _nowIso(),
      'pendencia': _syncStateSynced,
      'removido': 0,
    };

    if (localRow == null) {
      await localDb.insert('notas', values);
      return true;
    }

    await localDb.update(
      'notas',
      values,
      where: 'id = ?',
      whereArgs: [localRow['id']],
    );
    return true;
  }

  Future<bool> _upsertLocalPreferenceItemFromRemote(
    Database localDb,
    Map<String, Object?> remoteRow,
  ) async {
    final categoryName = (remoteRow['categoria_nome'] as String?) ?? '';
    final localCategory = await _ensureLocalCategory(localDb, categoryName);
    final localRow = await _findMatchingLocalPreferenceItem(localDb, remoteRow);
    if (!_shouldApplyRemote(localRow, remoteRow)) {
      return false;
    }

    final item = PreferenceItem.fromMap({
      ...remoteRow,
      'categoria_id': localCategory.id,
      'categoria_nome': categoryName,
    });

    final values = {
      ...item.toMap(),
      'remote_id': remoteRow['id'],
      'client_id': remoteRow['client_id'],
      'categoria_id': localCategory.id,
      'atualizado_em': (remoteRow['updated_at'] as String?) ?? _nowIso(),
      'sincronizado_em': _nowIso(),
      'pendencia': _syncStateSynced,
      'removido': 0,
    };

    if (localRow == null) {
      await localDb.insert('itens', values);
      return true;
    }

    await localDb.update(
      'itens',
      values,
      where: 'id = ?',
      whereArgs: [localRow['id']],
    );
    return true;
  }

  Future<bool> _upsertLocalMediaEntryFromRemote(
    Database localDb,
    Map<String, Object?> remoteRow,
  ) async {
    final localRow = await _findMatchingLocalMediaEntry(localDb, remoteRow);
    if (!_shouldApplyRemote(localRow, remoteRow)) {
      return false;
    }

    final values = {
      ...MediaEntry.fromMap(remoteRow).toMap(),
      'remote_id': remoteRow['id'],
      'client_id': remoteRow['client_id'],
      'atualizado_em': (remoteRow['updated_at'] as String?) ?? _nowIso(),
      'sincronizado_em': _nowIso(),
      'pendencia': _syncStateSynced,
      'removido': 0,
    };

    if (localRow == null) {
      await localDb.insert('arquivos', values);
      return true;
    }

    await localDb.update(
      'arquivos',
      values,
      where: 'id = ?',
      whereArgs: [localRow['id']],
    );
    return true;
  }

  Future<CategoryEntry> _ensureLocalCategory(
    Database localDb,
    String categoryName,
  ) async {
    final existing = await localDb.query(
      'categorias',
      columns: ['id', 'nome'],
      where: 'nome = ?',
      whereArgs: [categoryName],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      return CategoryEntry.fromMap(existing.first);
    }

    final id = await localDb.insert('categorias', {'nome': categoryName});
    return CategoryEntry(id: id, name: categoryName);
  }

  Future<bool> _pruneMissingLocalRows(
    Database localDb, {
    required String tableName,
    required Set<String> remoteClientIds,
  }) async {
    if (remoteClientIds.isEmpty) {
      return false;
    }

    final localRows = await localDb.query(
      tableName,
      columns: ['id', 'client_id', 'pendencia', 'removido', 'remote_id'],
      where: 'remote_id IS NOT NULL AND pendencia = ? AND removido = 0',
      whereArgs: [_syncStateSynced],
    );

    var changed = false;
    for (final row in localRows) {
      final clientId = (row['client_id'] as String?) ?? '';
      if (clientId.isEmpty || remoteClientIds.contains(clientId)) {
        continue;
      }

      await localDb.delete(tableName, where: 'id = ?', whereArgs: [row['id']]);
      changed = true;
    }
    return changed;
  }

  bool _shouldApplyRemote(
    Map<String, Object?>? localRow,
    Map<String, Object?> remoteRow,
  ) {
    if (localRow == null) {
      return true;
    }

    final pendingState = (localRow['pendencia'] as String?) ?? _syncStateSynced;
    if (pendingState == _syncStatePendingDelete) {
      return false;
    }

    if (pendingState != _syncStatePendingUpsert) {
      return true;
    }

    final localUpdatedAt = DateTime.tryParse(
      (localRow['atualizado_em'] as String?) ?? '',
    );
    final remoteUpdatedAt = DateTime.tryParse(
      (remoteRow['updated_at'] as String?) ?? '',
    );

    if (localUpdatedAt == null || remoteUpdatedAt == null) {
      return false;
    }

    return !localUpdatedAt.isAfter(remoteUpdatedAt);
  }

  Future<Map<String, Object?>?> _findRemoteImportantDate(
    Session session,
    Map<String, Object?> localRow,
  ) async {
    final clientId = (localRow['client_id'] as String?) ?? '';
    if (clientId.isNotEmpty) {
      final byClient = await session.execute(
        Sql.named(
          'SELECT id, client_id FROM datas_importantes WHERE client_id = @client_id LIMIT 1',
        ),
        parameters: {'client_id': clientId},
      );
      if (byClient.isNotEmpty) {
        return byClient.first.toColumnMap();
      }
    }

    final remoteId = (localRow['remote_id'] as num?)?.toInt();
    if (remoteId != null) {
      final byId = await session.execute(
        Sql.named(
          'SELECT id, client_id FROM datas_importantes WHERE id = @id LIMIT 1',
        ),
        parameters: {'id': remoteId},
      );
      if (byId.isNotEmpty) {
        return byId.first.toColumnMap();
      }
    }

    final byNaturalKey = await session.execute(
      Sql.named('''
        SELECT id, client_id
        FROM datas_importantes
        WHERE titulo = @titulo AND data = @data
        LIMIT 1
        '''),
      parameters: {'titulo': localRow['titulo'], 'data': localRow['data']},
    );

    return byNaturalKey.isEmpty ? null : byNaturalKey.first.toColumnMap();
  }

  Future<Map<String, Object?>?> _findRemoteNote(
    Session session,
    Map<String, Object?> localRow,
  ) async {
    final clientId = (localRow['client_id'] as String?) ?? '';
    if (clientId.isNotEmpty) {
      final byClient = await session.execute(
        Sql.named(
          'SELECT id, client_id FROM notas WHERE client_id = @client_id LIMIT 1',
        ),
        parameters: {'client_id': clientId},
      );
      if (byClient.isNotEmpty) {
        return byClient.first.toColumnMap();
      }
    }

    final remoteId = (localRow['remote_id'] as num?)?.toInt();
    if (remoteId != null) {
      final byId = await session.execute(
        Sql.named('SELECT id, client_id FROM notas WHERE id = @id LIMIT 1'),
        parameters: {'id': remoteId},
      );
      if (byId.isNotEmpty) {
        return byId.first.toColumnMap();
      }
    }

    final byNaturalKey = await session.execute(
      Sql.named('''
        SELECT id, client_id
        FROM notas
        WHERE titulo = @titulo
          AND descricao = @descricao
          AND tag = @tag
          AND data_criacao = @data_criacao
        LIMIT 1
        '''),
      parameters: {
        'titulo': localRow['titulo'],
        'descricao': localRow['descricao'],
        'tag': localRow['tag'],
        'data_criacao': localRow['data_criacao'],
      },
    );

    return byNaturalKey.isEmpty ? null : byNaturalKey.first.toColumnMap();
  }

  Future<Map<String, Object?>?> _findRemotePreferenceItem(
    Session session,
    Map<String, Object?> localRow,
  ) async {
    final clientId = (localRow['client_id'] as String?) ?? '';
    if (clientId.isNotEmpty) {
      final byClient = await session.execute(
        Sql.named(
          'SELECT id, client_id FROM itens WHERE client_id = @client_id LIMIT 1',
        ),
        parameters: {'client_id': clientId},
      );
      if (byClient.isNotEmpty) {
        return byClient.first.toColumnMap();
      }
    }

    final remoteId = (localRow['remote_id'] as num?)?.toInt();
    if (remoteId != null) {
      final byId = await session.execute(
        Sql.named('SELECT id, client_id FROM itens WHERE id = @id LIMIT 1'),
        parameters: {'id': remoteId},
      );
      if (byId.isNotEmpty) {
        return byId.first.toColumnMap();
      }
    }

    final byNaturalKey = await session.execute(
      Sql.named('''
        SELECT
          itens.id,
          itens.client_id
        FROM itens
        INNER JOIN categorias ON categorias.id = itens.categoria_id
        WHERE categorias.nome = @categoria_nome
          AND itens.nome = @nome
          AND itens.gosta = @gosta
          AND itens.nao_gosta = @nao_gosta
          AND COALESCE(itens.observacao, '') = @observacao
        LIMIT 1
        '''),
      parameters: {
        'categoria_nome': localRow['categoria_nome'],
        'nome': localRow['nome'],
        'gosta': localRow['gosta'],
        'nao_gosta': localRow['nao_gosta'],
        'observacao': (localRow['observacao'] as String?) ?? '',
      },
    );

    return byNaturalKey.isEmpty ? null : byNaturalKey.first.toColumnMap();
  }

  Future<Map<String, Object?>?> _findRemoteMediaEntry(
    Session session,
    Map<String, Object?> localRow,
  ) async {
    final clientId = (localRow['client_id'] as String?) ?? '';
    if (clientId.isNotEmpty) {
      final byClient = await session.execute(
        Sql.named(
          'SELECT id, client_id FROM arquivos WHERE client_id = @client_id LIMIT 1',
        ),
        parameters: {'client_id': clientId},
      );
      if (byClient.isNotEmpty) {
        return byClient.first.toColumnMap();
      }
    }

    final remoteId = (localRow['remote_id'] as num?)?.toInt();
    if (remoteId != null) {
      final byId = await session.execute(
        Sql.named('SELECT id, client_id FROM arquivos WHERE id = @id LIMIT 1'),
        parameters: {'id': remoteId},
      );
      if (byId.isNotEmpty) {
        return byId.first.toColumnMap();
      }
    }

    final byNaturalKey = await session.execute(
      Sql.named('''
        SELECT id, client_id
        FROM arquivos
        WHERE caminho = @caminho
          AND tipo = @tipo
          AND data_criacao = @data_criacao
        LIMIT 1
        '''),
      parameters: {
        'caminho': localRow['caminho'],
        'tipo': localRow['tipo'],
        'data_criacao': localRow['data_criacao'],
      },
    );

    return byNaturalKey.isEmpty ? null : byNaturalKey.first.toColumnMap();
  }

  Future<Map<String, Object?>?> _findMatchingLocalImportantDate(
    Database localDb,
    Map<String, Object?> remoteRow,
  ) async {
    return _findMatchingLocalRow(
      localDb,
      tableName: 'datas_importantes',
      clientId: (remoteRow['client_id'] as String?) ?? '',
      remoteId: (remoteRow['id'] as num?)?.toInt(),
      naturalWhere: 'titulo = ? AND data = ?',
      naturalArgs: [remoteRow['titulo'], remoteRow['data']],
    );
  }

  Future<Map<String, Object?>?> _findMatchingLocalNote(
    Database localDb,
    Map<String, Object?> remoteRow,
  ) async {
    return _findMatchingLocalRow(
      localDb,
      tableName: 'notas',
      clientId: (remoteRow['client_id'] as String?) ?? '',
      remoteId: (remoteRow['id'] as num?)?.toInt(),
      naturalWhere:
          'titulo = ? AND descricao = ? AND tag = ? AND data_criacao = ?',
      naturalArgs: [
        remoteRow['titulo'],
        remoteRow['descricao'],
        remoteRow['tag'],
        remoteRow['data_criacao'],
      ],
    );
  }

  Future<Map<String, Object?>?> _findMatchingLocalPreferenceItem(
    Database localDb,
    Map<String, Object?> remoteRow,
  ) async {
    final clientId = (remoteRow['client_id'] as String?) ?? '';
    if (clientId.isNotEmpty) {
      final byClient = await localDb.query(
        'itens',
        where: 'client_id = ?',
        whereArgs: [clientId],
        limit: 1,
      );
      if (byClient.isNotEmpty) {
        return byClient.first;
      }
    }

    final remoteId = (remoteRow['id'] as num?)?.toInt();
    if (remoteId != null) {
      final byRemoteId = await localDb.query(
        'itens',
        where: 'remote_id = ?',
        whereArgs: [remoteId],
        limit: 1,
      );
      if (byRemoteId.isNotEmpty) {
        return byRemoteId.first;
      }
    }

    final categoryName = (remoteRow['categoria_nome'] as String?) ?? '';
    final byNaturalKey = await localDb.rawQuery(
      '''
      SELECT
        itens.*
      FROM itens
      INNER JOIN categorias ON categorias.id = itens.categoria_id
      WHERE categorias.nome = ?
        AND itens.nome = ?
        AND itens.gosta = ?
        AND itens.nao_gosta = ?
        AND COALESCE(itens.observacao, '') = ?
      LIMIT 1
    ''',
      [
        categoryName,
        remoteRow['nome'],
        remoteRow['gosta'],
        remoteRow['nao_gosta'],
        (remoteRow['observacao'] as String?) ?? '',
      ],
    );

    return byNaturalKey.isEmpty ? null : byNaturalKey.first;
  }

  Future<Map<String, Object?>?> _findMatchingLocalMediaEntry(
    Database localDb,
    Map<String, Object?> remoteRow,
  ) async {
    return _findMatchingLocalRow(
      localDb,
      tableName: 'arquivos',
      clientId: (remoteRow['client_id'] as String?) ?? '',
      remoteId: (remoteRow['id'] as num?)?.toInt(),
      naturalWhere: 'caminho = ? AND tipo = ? AND data_criacao = ?',
      naturalArgs: [
        remoteRow['caminho'],
        remoteRow['tipo'],
        remoteRow['data_criacao'],
      ],
    );
  }

  Future<Map<String, Object?>?> _findMatchingLocalRow(
    Database localDb, {
    required String tableName,
    required String clientId,
    required int? remoteId,
    required String naturalWhere,
    required List<Object?> naturalArgs,
  }) async {
    if (clientId.isNotEmpty) {
      final byClient = await localDb.query(
        tableName,
        where: 'client_id = ?',
        whereArgs: [clientId],
        limit: 1,
      );
      if (byClient.isNotEmpty) {
        return byClient.first;
      }
    }

    if (remoteId != null) {
      final byRemoteId = await localDb.query(
        tableName,
        where: 'remote_id = ?',
        whereArgs: [remoteId],
        limit: 1,
      );
      if (byRemoteId.isNotEmpty) {
        return byRemoteId.first;
      }
    }

    final byNaturalKey = await localDb.query(
      tableName,
      where: naturalWhere,
      whereArgs: naturalArgs,
      limit: 1,
    );

    return byNaturalKey.isEmpty ? null : byNaturalKey.first;
  }

  bool _isRemovedRow(Map<String, Object?> row) {
    return ((row['removido'] as num?) ?? 0).toInt() == 1;
  }

  String _generateClientId(String prefix) {
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final randomPart = List.generate(
      12,
      (_) => _random.nextInt(16).toRadixString(16),
    ).join();
    return '$prefix-$timestamp-$randomPart';
  }

  String _nowIso() => DateTime.now().toUtc().toIso8601String();

  static String _normalizeKey(String value) => value.trim().toLowerCase();

  static String _buildImportantDateSeedKey({
    required String title,
    required String isoDate,
  }) {
    return '${_normalizeKey(title)}|$isoDate';
  }

  static String _buildPreferenceSeedKey(PreferenceItem item) {
    return [
      _normalizeKey(item.category),
      _normalizeKey(item.name),
      item.status.name,
      item.observation.trim(),
    ].join('|');
  }

  static String _buildNoteKey(NoteEntry note) {
    return [
      _normalizeKey(note.title),
      note.description.trim(),
      _normalizeKey(note.tag),
      note.createdAt.toIso8601String(),
    ].join('|');
  }

  static String _buildMediaKey(MediaEntry entry) {
    return '${entry.path}|${entry.type.name}|${entry.createdAt.toIso8601String()}';
  }

  static const List<String> _importantDateColumns = [
    'id',
    'titulo',
    'descricao',
    'data',
    'notificacao_hora',
    'notificacao_minuto',
    'repetir_anualmente',
    'notificacao_3_meses',
    'notificacao_1_mes',
    'notificacao_1_semana',
    'notificacao_1_dia',
    'notificacao_no_dia',
    'notificacao_som',
    'notificacao_personalizada_dias',
    'notificacao_personalizada_data',
  ];

  static const List<String> _noteColumns = [
    'id',
    'titulo',
    'descricao',
    'tag',
    'data_criacao',
  ];

  static const List<String> _mediaColumns = [
    'id',
    'caminho',
    'tipo',
    'data_criacao',
  ];

  static const List<String> _localSchemaStatements = [
    '''
    CREATE TABLE IF NOT EXISTS app_meta (
      chave TEXT PRIMARY KEY,
      valor TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS categorias (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      remote_id INTEGER UNIQUE,
      nome TEXT NOT NULL UNIQUE
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS datas_importantes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      remote_id INTEGER UNIQUE,
      client_id TEXT NOT NULL UNIQUE,
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
      notificacao_som TEXT NOT NULL DEFAULT 'default',
      notificacao_personalizada_dias INTEGER,
      notificacao_personalizada_data TEXT,
      atualizado_em TEXT NOT NULL,
      sincronizado_em TEXT,
      pendencia TEXT NOT NULL DEFAULT 'synced',
      removido INTEGER NOT NULL DEFAULT 0
    )
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_local_datas_importantes_pendencia
    ON datas_importantes(pendencia, removido)
    ''',
    '''
    CREATE TABLE IF NOT EXISTS notas (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      remote_id INTEGER UNIQUE,
      client_id TEXT NOT NULL UNIQUE,
      titulo TEXT NOT NULL,
      descricao TEXT NOT NULL,
      tag TEXT NOT NULL,
      data_criacao TEXT NOT NULL,
      atualizado_em TEXT NOT NULL,
      sincronizado_em TEXT,
      pendencia TEXT NOT NULL DEFAULT 'synced',
      removido INTEGER NOT NULL DEFAULT 0
    )
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_local_notas_pendencia
    ON notas(pendencia, removido)
    ''',
    '''
    CREATE TABLE IF NOT EXISTS itens (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      remote_id INTEGER UNIQUE,
      client_id TEXT NOT NULL UNIQUE,
      categoria_id INTEGER NOT NULL REFERENCES categorias(id) ON DELETE CASCADE,
      nome TEXT NOT NULL,
      gosta INTEGER NOT NULL DEFAULT 0,
      nao_gosta INTEGER NOT NULL DEFAULT 0,
      observacao TEXT,
      atualizado_em TEXT NOT NULL,
      sincronizado_em TEXT,
      pendencia TEXT NOT NULL DEFAULT 'synced',
      removido INTEGER NOT NULL DEFAULT 0
    )
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_local_itens_pendencia
    ON itens(pendencia, removido)
    ''',
    '''
    CREATE TABLE IF NOT EXISTS arquivos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      remote_id INTEGER UNIQUE,
      client_id TEXT NOT NULL UNIQUE,
      caminho TEXT NOT NULL,
      tipo TEXT NOT NULL,
      data_criacao TEXT NOT NULL,
      atualizado_em TEXT NOT NULL,
      sincronizado_em TEXT,
      pendencia TEXT NOT NULL DEFAULT 'synced',
      removido INTEGER NOT NULL DEFAULT 0
    )
    ''',
    '''
    CREATE INDEX IF NOT EXISTS idx_local_arquivos_pendencia
    ON arquivos(pendencia, removido)
    ''',
  ];

  static const List<String> _remoteSchemaStatements = [
    '''
    CREATE TABLE IF NOT EXISTS categorias (
      id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
      nome TEXT NOT NULL UNIQUE
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS datas_importantes (
      id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
      client_id TEXT,
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
      notificacao_som TEXT NOT NULL DEFAULT 'default',
      notificacao_personalizada_dias INTEGER,
      notificacao_personalizada_data TEXT,
      updated_at TEXT
    )
    ''',
    '''
    ALTER TABLE datas_importantes ADD COLUMN IF NOT EXISTS client_id TEXT
    ''',
    '''
    ALTER TABLE datas_importantes ADD COLUMN IF NOT EXISTS updated_at TEXT
    ''',
    '''
    UPDATE datas_importantes
    SET client_id = 'legacy-date-' || id || '-' || substring(md5(clock_timestamp()::text || random()::text) from 1 for 12)
    WHERE client_id IS NULL OR client_id = ''
    ''',
    '''
    UPDATE datas_importantes
    SET updated_at = COALESCE(updated_at, data, clock_timestamp()::text)
    WHERE updated_at IS NULL
    ''',
    '''
    CREATE UNIQUE INDEX IF NOT EXISTS idx_datas_importantes_unique_titulo_data
    ON datas_importantes(titulo, data)
    ''',
    '''
    CREATE UNIQUE INDEX IF NOT EXISTS idx_datas_importantes_client_id
    ON datas_importantes(client_id)
    ''',
    '''
    CREATE TABLE IF NOT EXISTS notas (
      id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
      client_id TEXT,
      titulo TEXT NOT NULL,
      descricao TEXT NOT NULL,
      tag TEXT NOT NULL,
      data_criacao TEXT NOT NULL,
      updated_at TEXT
    )
    ''',
    '''
    ALTER TABLE notas ADD COLUMN IF NOT EXISTS client_id TEXT
    ''',
    '''
    ALTER TABLE notas ADD COLUMN IF NOT EXISTS updated_at TEXT
    ''',
    '''
    UPDATE notas
    SET client_id = 'legacy-note-' || id || '-' || substring(md5(clock_timestamp()::text || random()::text) from 1 for 12)
    WHERE client_id IS NULL OR client_id = ''
    ''',
    '''
    UPDATE notas
    SET updated_at = COALESCE(updated_at, data_criacao, clock_timestamp()::text)
    WHERE updated_at IS NULL
    ''',
    '''
    CREATE UNIQUE INDEX IF NOT EXISTS idx_notas_client_id
    ON notas(client_id)
    ''',
    '''
    CREATE TABLE IF NOT EXISTS itens (
      id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
      client_id TEXT,
      categoria_id BIGINT NOT NULL REFERENCES categorias(id) ON DELETE CASCADE,
      nome TEXT NOT NULL,
      gosta INTEGER NOT NULL DEFAULT 0,
      nao_gosta INTEGER NOT NULL DEFAULT 0,
      observacao TEXT,
      updated_at TEXT
    )
    ''',
    '''
    ALTER TABLE itens ADD COLUMN IF NOT EXISTS client_id TEXT
    ''',
    '''
    ALTER TABLE itens ADD COLUMN IF NOT EXISTS updated_at TEXT
    ''',
    '''
    UPDATE itens
    SET client_id = 'legacy-item-' || id || '-' || substring(md5(clock_timestamp()::text || random()::text) from 1 for 12)
    WHERE client_id IS NULL OR client_id = ''
    ''',
    '''
    UPDATE itens
    SET updated_at = COALESCE(updated_at, clock_timestamp()::text)
    WHERE updated_at IS NULL
    ''',
    '''
    CREATE UNIQUE INDEX IF NOT EXISTS idx_itens_client_id
    ON itens(client_id)
    ''',
    '''
    CREATE TABLE IF NOT EXISTS arquivos (
      id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
      client_id TEXT,
      caminho TEXT NOT NULL,
      tipo TEXT NOT NULL,
      data_criacao TEXT NOT NULL,
      updated_at TEXT
    )
    ''',
    '''
    ALTER TABLE arquivos ADD COLUMN IF NOT EXISTS client_id TEXT
    ''',
    '''
    ALTER TABLE arquivos ADD COLUMN IF NOT EXISTS updated_at TEXT
    ''',
    '''
    UPDATE arquivos
    SET client_id = 'legacy-media-' || id || '-' || substring(md5(clock_timestamp()::text || random()::text) from 1 for 12)
    WHERE client_id IS NULL OR client_id = ''
    ''',
    '''
    UPDATE arquivos
    SET updated_at = COALESCE(updated_at, data_criacao, clock_timestamp()::text)
    WHERE updated_at IS NULL
    ''',
    '''
    CREATE UNIQUE INDEX IF NOT EXISTS idx_arquivos_client_id
    ON arquivos(client_id)
    ''',
  ];
}

class _LegacySqliteSnapshot {
  const _LegacySqliteSnapshot({
    required this.categories,
    required this.importantDates,
    required this.notes,
    required this.preferenceItems,
    required this.mediaEntries,
  });

  final List<CategoryEntry> categories;
  final List<ImportantDate> importantDates;
  final List<NoteEntry> notes;
  final List<PreferenceItem> preferenceItems;
  final List<MediaEntry> mediaEntries;
}

class _SeedPreferenceItem {
  const _SeedPreferenceItem({
    required this.categoryName,
    required this.name,
    required this.status,
    this.observation = '',
  });

  final String categoryName;
  final String name;
  final PreferenceStatus status;
  final String observation;

  PreferenceItem toPreferenceItem(int categoryId) {
    return PreferenceItem(
      id: 0,
      categoryId: categoryId,
      category: categoryName,
      name: name,
      status: status,
      observation: observation,
    );
  }
}

class _SeedImportantDate {
  const _SeedImportantDate({
    required this.title,
    required this.description,
    required this.year,
    required this.month,
    required this.day,
    required this.repeatsAnnually,
    required this.notificationsEnabled,
    this.notificationHour = 9,
    this.notificationMinute = 0,
    this.notificationSound = ImportantDate.notificationSoundDefault,
  });

  final String title;
  final String description;
  final int year;
  final int month;
  final int day;
  final bool repeatsAnnually;
  final bool notificationsEnabled;
  final int notificationHour;
  final int notificationMinute;
  final String notificationSound;

  ImportantDate toImportantDate() {
    return ImportantDate(
      id: 0,
      title: title,
      description: description,
      date: DateTime(year, month, day),
      notificationHour: notificationHour,
      notificationMinute: notificationMinute,
      repeatsAnnually: repeatsAnnually,
      notify3Months: notificationsEnabled,
      notify1Month: notificationsEnabled,
      notify1Week: notificationsEnabled,
      notify1Day: notificationsEnabled,
      notifyOnDay: false,
      notificationSound: notificationSound,
    );
  }
}
