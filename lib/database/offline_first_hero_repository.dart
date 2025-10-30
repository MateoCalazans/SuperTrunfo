import '../domain/hero_repository.dart';
import '../models/hero_model.dart';

class OfflineFirstHeroRepository implements HeroRepository {
  OfflineFirstHeroRepository({required this.remote, required this.cache});

  final HeroRepository remote;
  final HeroRepository cache;

  @override
  Future<List<HeroModel>> fetchPage({required int pageNumber, required int pageSize}) async {
    bool saved = false;
    try {
      final remoteItems = await remote.fetchPage(pageNumber: pageNumber, pageSize: pageSize);
      if (remoteItems.isNotEmpty) {
        await cache.upsertPage(remoteItems);
        saved = true;
      }
    } catch (_) {}
    final cached = await cache.getCachedPage(pageNumber: pageNumber, pageSize: pageSize);
    if (cached.isNotEmpty || saved) return cached;
    throw Exception('Sem conexão e sem dados no cache para esta página.');
  }

  @override
  Future<void> upsertPage(List<HeroModel> heroes) => cache.upsertPage(heroes);

  @override
  Future<List<HeroModel>> getCachedPage({required int pageNumber, required int pageSize}) =>
      cache.getCachedPage(pageNumber: pageNumber, pageSize: pageSize);

  @override
  Future<HeroModel?> getCachedById(int heroId) => cache.getCachedById(heroId);
}
