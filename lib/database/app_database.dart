import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const _dbName = 'app.db';
  static const _dbVersion = 4;

  static Future<Database> open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE heroes (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            powerstats TEXT NOT NULL,
            appearance TEXT NOT NULL,
            images TEXT NOT NULL,
            biography TEXT NOT NULL,
            work TEXT NOT NULL,
            connections TEXT NOT NULL
          );
        ''');
        await db.execute('''
          CREATE TABLE meta (
            key TEXT PRIMARY KEY,
            value TEXT
          );
        ''');
        await db.execute('''
          CREATE TABLE my_cards (
            id INTEGER PRIMARY KEY,
            addedAt TEXT NOT NULL
          );
        ''');
        await db.execute('''
          CREATE TABLE deck_cards (
            id INTEGER PRIMARY KEY,
            addedAt TEXT NOT NULL
          );
        ''');
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          await _safeAddColumn(db, 'heroes', 'biography', "TEXT NOT NULL DEFAULT '{}'");
          await _safeAddColumn(db, 'heroes', 'work', "TEXT NOT NULL DEFAULT '{}'");
          await _safeAddColumn(db, 'heroes', 'connections', "TEXT NOT NULL DEFAULT '{}'");
        }
        if (oldV < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS my_cards (
              id INTEGER PRIMARY KEY,
              addedAt TEXT NOT NULL
            );
          ''');
        }
        if (oldV < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS deck_cards (
              id INTEGER PRIMARY KEY,
              addedAt TEXT NOT NULL
            );
          ''');
        }
      },
    );
  }

  static Future<void> _safeAddColumn(Database db, String table, String column, String definition) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition;');
    } catch (_) {}
  }
}
