import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:shaumsi/src/data/shaumsi_database.dart';
import 'package:shaumsi/src/models/note_entry.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
  });

  test(
    'normalizeDatabaseUrl strips wrapping quotes, Neon-only params and adds timeout',
    () {
      const rawUrl =
          '"postgresql://user:password@ep-example-pooler.sa-east-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require"';

      expect(
        ShauMsiDatabase.normalizeDatabaseUrl(rawUrl),
        'postgresql://user:password@ep-example-pooler.sa-east-1.aws.neon.tech/neondb?sslmode=require&connect_timeout=2',
      );
    },
  );

  test(
    'local cache works without DATABASE_URL and keeps starter data',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('shaumsi-db-test');
      final databasePath = path.join(tempDir.path, 'offline.db');
      final database = ShauMsiDatabase.test(
        localDatabasePath: databasePath,
        databaseFactory: databaseFactoryFfi,
      );

      try {
        await database.ensureReady();

        final categories = await database.fetchCategories();
        final dates = await database.fetchImportantDates();
        final items = await database.fetchPreferenceItems();

        expect(categories, isNotEmpty);
        expect(dates.map((item) => item.title), contains('Aniversário'));
        expect(items.map((item) => item.name), contains('conchas'));

        final insertedId = await database.insertNote(
          NoteEntry(
            id: 0,
            title: 'Offline note',
            description: 'cache local',
            tag: 'teste',
            createdAt: DateTime(2026, 4, 5, 18, 0),
          ),
        );
        expect(insertedId, greaterThan(0));

        final notes = await database.fetchNotes();
        expect(notes.map((item) => item.title), contains('Offline note'));

        final syncChanged = await database.syncWithCloud();
        expect(syncChanged, isFalse);
      } finally {
        await database.close();
        await tempDir.delete(recursive: true);
      }
    },
  );
}
