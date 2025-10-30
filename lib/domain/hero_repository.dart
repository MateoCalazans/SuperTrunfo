import '../models/hero_model.dart';

abstract class HeroRepository {
  Future<List<HeroModel>> fetchPage({required int pageNumber, required int pageSize});
  Future<void> upsertPage(List<HeroModel> heroes);
  Future<List<HeroModel>> getCachedPage({required int pageNumber, required int pageSize});
  Future<HeroModel?> getCachedById(int heroId);
}
