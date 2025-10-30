import 'dart:convert';
import 'package:sqflite/sqflite.dart';

import '../models/hero_model.dart';
import '../domain/hero_repository.dart';
import 'database_holder.dart';

class SqliteHeroRepository implements HeroRepository {
  Map<String, dynamic> _decode(Object? v) {
    if (v == null) return {};
    try { return Map<String, dynamic>.from(jsonDecode(v as String)); } catch (_) { return {}; }
  }

  @override
  Future<void> upsertPage(List<HeroModel> heroes) {
    return DatabaseHolder.I.run((db) async {
      await db.transaction((txn) async {
        final b = txn.batch();
        for (final h in heroes) {
          b.insert('heroes', {
            'id': h.id,
            'name': h.name,
            'powerstats': jsonEncode(h.powerstats),
            'appearance': jsonEncode(h.appearance),
            'images': jsonEncode(h.images),
            'biography': jsonEncode(h.biography),
            'work': jsonEncode(h.work),
            'connections': jsonEncode(h.connections),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        b.insert('meta', {'key': 'updatedAt', 'value': DateTime.now().toIso8601String()},
            conflictAlgorithm: ConflictAlgorithm.replace);
        await b.commit(noResult: true);
      });
    });
  }

  @override
  Future<List<HeroModel>> getCachedPage({required int pageNumber, required int pageSize}) {
    return DatabaseHolder.I.run((db) async {
      final rows = await db.query(
        'heroes',
        orderBy: 'id ASC',
        limit: pageSize,
        offset: (pageNumber - 1) * pageSize,
      );
      return rows.map((r) => HeroModel(
        id: r['id'] as int,
        name: r['name'] as String,
        powerstats: _decode(r['powerstats']),
        appearance: _decode(r['appearance']),
        images: _decode(r['images']),
        biography: _decode(r['biography']),
        work: _decode(r['work']),
        connections: _decode(r['connections']),
      )).toList();
    });
  }

  @override
  Future<HeroModel?> getCachedById(int id) {
    return DatabaseHolder.I.run((db) async {
      final rows = await db.query('heroes', where: 'id=?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) return null;
      final r = rows.first;
      return HeroModel(
        id: r['id'] as int,
        name: r['name'] as String,
        powerstats: _decode(r['powerstats']),
        appearance: _decode(r['appearance']),
        images: _decode(r['images']),
        biography: _decode(r['biography']),
        work: _decode(r['work']),
        connections: _decode(r['connections']),
      );
    });
  }

  // compatibilidade
  @override
  Future<List<HeroModel>> fetchPage({required int pageNumber, required int pageSize}) =>
      getCachedPage(pageNumber: pageNumber, pageSize: pageSize);
}
