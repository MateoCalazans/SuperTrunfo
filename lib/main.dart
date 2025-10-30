import 'package:flutter/material.dart';

import 'database/app_database.dart'; // mantém para inicializar se quiser
import 'database/offline_first_hero_repository.dart';
import 'database/remote_hero_repository.dart';
import 'database/sqlite_hero_repository.dart';
import 'services/api_service.dart';
import 'domain/hero_repository.dart';
import 'core/theme/theme.dart';
import 'screens/home_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;

// Prefetch paginado (background, opcional como fallback)
Future<void> prefetchAllHeroes({
  required HeroRepository remote,
  required HeroRepository cache,
  int pageSize = 50,
  int maxPages = 2, // reduz para evitar concorrência no start
}) async {
  var page = 1;
  while (page <= maxPages) {
    final items = await remote.fetchPage(pageNumber: page, pageSize: pageSize);
    if (items.isEmpty) break;
    await cache.upsertPage(items);
    if (items.length < pageSize) break;
    page += 1;
  }
}

// Verifica rede no endpoint real (leve)
Future<bool> _hasNetwork(String baseUrl) async {
  try {
    final uri = Uri.parse('$baseUrl/heroes?_start=0&_end=1');
    final res = await http.get(uri).timeout(const Duration(seconds: 3));
    return res.statusCode >= 200 && res.statusCode < 500;
  } catch (_) {
    return false;
  }
}

// Prefetch paralelo de imagens (xs, md, lg) com pool de workers
Future<void> prefetchAllImagesParallel(
    List<dynamic> heroesAll, {
      int concurrency = 6,
    }) async {
  final urls = <String>[];
  for (final h in heroesAll) {
    final xs = (h.images['xs'] ?? '') as String;
    final md = (h.images['md'] ?? '') as String;
    final lg = (h.images['lg'] ?? '') as String;
    if (xs.isNotEmpty) urls.add(xs);
    if (md.isNotEmpty) urls.add(md);
    if (lg.isNotEmpty) urls.add(lg);
  }
  final uniqueUrls = urls.toSet().toList();

  var index = 0;
  Future<void> worker() async {
    while (true) {
      String? url;
      if (index < uniqueUrls.length) {
        url = uniqueUrls[index];
        index += 1;
      } else {
        break;
      }
      try {
        final provider = CachedNetworkImageProvider(url);
        provider.resolve(const ImageConfiguration());
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  final tasks = List.generate(concurrency, (_) => worker());
  await Future.wait(tasks);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Opcional: força criação/migração do DB uma vez no boot
  await AppDatabase.open();

  // Repositórios
  final cacheRepo = SqliteHeroRepository(); // <-- sem argumentos agora
  final api = ApiService.defaultInstance();
  final remoteRepo = RemoteHeroRepository(api);
  final repository = OfflineFirstHeroRepository(remote: remoteRepo, cache: cacheRepo);

  runApp(MyApp(repository: repository));

  // Prefetch leve em background (não paralelize demais no boot)
  () async {
    try {
      await prefetchAllHeroes(remote: remoteRepo, cache: cacheRepo, pageSize: 50, maxPages: 2)
          .timeout(const Duration(seconds: 15));
    } catch (_) {}
  }();

  // Prefetch completo e imagens (opcional)
  () async {
    try {
      final all = await api.fetchAllHeroes().timeout(const Duration(seconds: 20));
      await cacheRepo.upsertPage(all);
      if (await _hasNetwork(api.baseUrl)) {
        await prefetchAllImagesParallel(all, concurrency: 6);
      }
    } catch (_) {
      // silencia para não travar boot
    } finally {
      api.dispose();
    }
  }();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.repository});
  final HeroRepository repository;

  @override
  Widget build(BuildContext context) {
    final theme = MaterialTheme(Typography.material2021().black);
    return MaterialApp(
      title: 'Super Trunfo dos Heróis',
      debugShowCheckedModeBanner: false,
      theme: theme.light(),
      darkTheme: theme.dark(),
      themeMode: ThemeMode.system,
      home: HomeScreen(repository: repository),
    );
  }
}
