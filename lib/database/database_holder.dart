import 'package:sqflite/sqflite.dart';
import 'app_database.dart';

class DatabaseHolder {
  DatabaseHolder._();
  static final DatabaseHolder I = DatabaseHolder._();

  Database? _db;
  Future<Database>? _opening;

  // fila para serializar operações e evitar lock
  Future _queue = Future.value();

  Future<Database> get db async {
    if (_db != null && _db!.isOpen) return _db!;
    if (_opening != null) return _opening!;
    _opening = AppDatabase.open();
    _db = await _opening!;
    _opening = null;
    return _db!;
  }

  Future<T> run<T>(Future<T> Function(Database db) op) async {
    final database = await db;
    _queue = _queue.then((_) => op(database));
    return await _queue as T;
  }
}
