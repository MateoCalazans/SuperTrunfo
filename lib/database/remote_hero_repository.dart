import '../domain/hero_repository.dart';
import '../models/hero_model.dart';
import '../services/api_service.dart';

class RemoteHeroRepository implements HeroRepository {
  RemoteHeroRepository(this._api);
  final ApiService _api;

  @override
  Future<List<HeroModel>> fetchPage({required int pageNumber, required int pageSize}) {
    return _api.fetchHeroesPage(pageNumber, pageSize);
  }

  @override
  Future<void> upsertPage(List<HeroModel> heroes) async {
    // Repositório remoto não persiste localmente.
  }

  @override
  Future<List<HeroModel>> getCachedPage({required int pageNumber, required int pageSize}) async {
    return const <HeroModel>[];
  }

  @override
  Future<HeroModel?> getCachedById(int heroId) async {
    return null;
  }
}
