import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../domain/hero_repository.dart';
import '../models/hero_model.dart';
import 'hero_detail_screen.dart';

class HeroesScreen extends StatefulWidget {
  const HeroesScreen({super.key, required this.repository});
  final HeroRepository repository;

  @override
  State<HeroesScreen> createState() => _HeroesScreenState();
}

class _HeroesScreenState extends State<HeroesScreen> {
  static const _pageSize = 50;

  final PagingController<int, HeroModel> _pagingController =
  PagingController(firstPageKey: 1);

  @override
  void initState() {
    super.initState();
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
  }

  Future<void> _fetchPage(int pageKey) async {
    try {
      final newItems = await widget.repository.fetchPage(
        pageNumber: pageKey,
        pageSize: _pageSize,
      );

      final isLastPage = newItems.length < _pageSize;

      if (isLastPage) {
        _pagingController.appendLastPage(newItems);
      } else {
        final nextPageKey = pageKey + 1;
        _pagingController.appendPage(newItems, nextPageKey);
      }
    } catch (error) {
      _pagingController.error = error;
    }
  }

  // Linha compacta em PT-BR (consistente com detalhes e card diário)
  String _powerstatsLine(Map<String, dynamic> ps) {
    final forca = _norm(ps['strength']);
    final velocidade = _norm(ps['speed']);
    final poder = _norm(ps['power']);
    return 'Força $forca  •  Velocidade $velocidade  •  Poder $poder';
  }

  String _appearanceLine(Map<String, dynamic> ap) {
    final gender = (ap['gender'] ?? '').toString();
    final race = (ap['race'] ?? '').toString();
    final height = (ap['height'] is List && (ap['height'] as List).isNotEmpty)
        ? (ap['height'] as List).last.toString()
        : '';
    final weight = (ap['weight'] is List && (ap['weight'] as List).isNotEmpty)
        ? (ap['weight'] as List).last.toString()
        : '';
    final bits = <String>[];
    if (gender.isNotEmpty) bits.add(gender);
    if (race.isNotEmpty) bits.add(race);
    if (height.isNotEmpty) bits.add(height);
    if (weight.isNotEmpty) bits.add(weight);
    return bits.join('  •  ');
  }

  int _norm(dynamic raw) {
    if (raw == null) return 0;
    if (raw is num) return raw.clamp(0, 100).toInt();
    final i = int.tryParse(raw.toString());
    if (i != null) return i.clamp(0, 100);
    final d = double.tryParse(raw.toString())?.toInt() ?? 0;
    return d.clamp(0, 100);
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Heróis'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: () => _pagingController.refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => Future.sync(() => _pagingController.refresh()),
        child: PagedListView<int, HeroModel>.separated(
          pagingController: _pagingController,
          builderDelegate: PagedChildBuilderDelegate<HeroModel>(
            itemBuilder: (context, hero, index) {
              final imageUrl = (hero.images['sm'] ??
                  hero.images['xs'] ??
                  hero.images['md'] ??
                  hero.images['lg'] ?? '').toString();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HeroDetailScreen(hero: hero),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      // thumb
                      SizedBox(
                        width: 92,
                        height: 92,
                        child: imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
                        )
                            : const Center(child: Icon(Icons.image)),
                      ),
                      const SizedBox(width: 12),
                      // info
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hero.name,
                                style: theme.textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _powerstatsLine(hero.powerstats),
                                style: theme.textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _appearanceLine(hero.appearance),
                                style: theme.textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              );
            },
            firstPageProgressIndicatorBuilder: (context) => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
            newPageProgressIndicatorBuilder: (context) => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
            firstPageErrorIndicatorBuilder: (context) {
              final error = _pagingController.error;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Falha ao carregar: ${error?.toString() ?? "Erro desconhecido"}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ElevatedButton(
                      onPressed: () => _pagingController.refresh(),
                      child: const Text('Tentar novamente'),
                    ),
                  ),
                ],
              );
            },
            noItemsFoundIndicatorBuilder: (context) => const Center(
              child: Text('Nenhum herói encontrado'),
            ),
            noMoreItemsIndicatorBuilder: (context) => const SizedBox.shrink(),
          ),
          separatorBuilder: (context, index) => const SizedBox(height: 4),
        ),
      ),
    );
  }
}