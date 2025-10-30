import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_holder.dart';
import '../models/hero_model.dart';
import 'hero_detail_screen.dart';

class MyCardsScreen extends StatefulWidget {
  const MyCardsScreen({super.key});

  @override
  State<MyCardsScreen> createState() => _MyCardsScreenState();
}

class _MyCardsScreenState extends State<MyCardsScreen> {
  late Future<void> _initFuture;
  List<HeroModel> _deck = const [];

  // id -> addedAt (ISO)
  final Map<int, String> _deckAddedAt = {};

  // chaves do diário (para priorizar a data lógica do sorteio)
  static const _prefsKeyDate = 'daily_card_date';       // YYYY-MM-DD
  static const _prefsKeyHeroId = 'daily_card_hero_id';  // id definitivo

  String? _dailyDateYmd;
  int? _dailyHeroId;

  @override
  void initState() {
    super.initState();
    _initFuture = _reloadDeck();
  }

  Map<String, dynamic> _decodeJsonColumn(Object? value) {
    if (value == null) return <String, dynamic>{};
    try {
      return Map<String, dynamic>.from(jsonDecode(value as String));
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String _formatIsoToBr(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final local = dt.toLocal(); // crítico para não virar o dia
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yy = local.year.toString();
    return '$dd/$mm/$yy';
  }

  String _brFromYmd(String? ymd) {
    if (ymd == null || ymd.length != 10) return '';
    final p = ymd.split('-');
    if (p.length != 3) return '';
    return '${p[2]}/${p[1]}/${p[0]}';
  }

  Future<void> _loadDailyPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _dailyHeroId = prefs.getInt(_prefsKeyHeroId);
    _dailyDateYmd = prefs.getString(_prefsKeyDate);
  }

  Future<void> _reloadDeck() async {
    await _loadDailyPrefs();

    final idsRows = await DatabaseHolder.I.run((db) async {
      return await db.query('deck_cards', orderBy: 'addedAt DESC', limit: 15);
    });

    if (idsRows.isEmpty) {
      if (!mounted) return;
      setState(() {
        _deck = const [];
        _deckAddedAt.clear();
      });
      return;
    }

    final ids = <int>[];
    _deckAddedAt.clear();
    for (final r in idsRows) {
      final id = r['id'] as int;
      ids.add(id);
      _deckAddedAt[id] = (r['addedAt'] ?? '').toString();
    }

    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await DatabaseHolder.I.run((db) async {
      return await db.rawQuery('SELECT * FROM heroes WHERE id IN ($placeholders)', ids);
    });

    final list = rows.map((row) {
      return HeroModel(
        id: row['id'] as int,
        name: row['name'] as String,
        powerstats: _decodeJsonColumn(row['powerstats']),
        appearance: _decodeJsonColumn(row['appearance']),
        images: _decodeJsonColumn(row['images']),
        biography: _decodeJsonColumn(row['biography']),
        work: _decodeJsonColumn(row['work']),
        connections: _decodeJsonColumn(row['connections']),
      );
    }).toList();

    // Reordenar conforme deck_cards
    final order = {for (int i = 0; i < ids.length; i++) ids[i]: i};
    list.sort((a, b) => (order[a.id] ?? 999).compareTo(order[b.id] ?? 999));

    if (!mounted) return;
    setState(() => _deck = list);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Cartas (Deck)'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: () => setState(() => _initFuture = _reloadDeck()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_deck.isEmpty) {
            return const Center(child: Text('Seu deck está vazio. Use o Card Diário para obter cartas.'));
          }
          return RefreshIndicator(
            onRefresh: _reloadDeck,
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 63 / 88,
              ),
              itemCount: _deck.length,
              itemBuilder: (context, index) {
                final hero = _deck[index];

                // 1) Se for a carta diária definitiva, mostre a data lógica do dia:
                String? sorteadoEm;
                if (_dailyHeroId != null && _dailyHeroId == hero.id) {
                  final br = _brFromYmd(_dailyDateYmd);
                  if (br.isNotEmpty) {
                    sorteadoEm = 'Sorteado em: $br';
                  }
                }

                // 2) Caso contrário, use addedAt em horário local
                if (sorteadoEm == null) {
                  final addedAtIso = _deckAddedAt[hero.id];
                  final br = _formatIsoToBr(addedAtIso);
                  if (br.isNotEmpty) {
                    sorteadoEm = 'Sorteado em: $br';
                  }
                }

                return MyCardTile(
                  hero: hero,
                  sorteadoEm: sorteadoEm,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HeroDetailScreen(
                          hero: hero,
                          fromDeck: true,
                          onAbandoned: () async {
                            await _reloadDeck();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${hero.name} abandonado.')),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class MyCardTile extends StatelessWidget {
  const MyCardTile({
    super.key,
    required this.hero,
    required this.onTap,
    this.sorteadoEm,
  });

  final HeroModel hero;
  final VoidCallback onTap;
  final String? sorteadoEm;

  @override
  Widget build(BuildContext context) {
    final borderRed = const Color(0xFFCF2A1E);
    final navy = const Color(0xFF0E2B4F);
    final blueAccent = const Color(0xFF1B4F9C);
    final imageUrl = (hero.images['md'] ?? hero.images['sm'] ?? hero.images['xs'] ?? hero.images['lg'] ?? '').toString();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: borderRed, width: 4),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            color: navy,
            child: Column(
              children: [
                // faixa de topo com nome e "Sorteado em"
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  color: blueAccent,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hero.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                      if (sorteadoEm != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            sorteadoEm!,
                            style: const TextStyle(color: Colors.white70, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                // imagem
                Expanded(
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                    const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    errorWidget: (_, __, ___) =>
                    const Center(child: Icon(Icons.broken_image, color: Colors.white70)),
                  )
                      : const Center(child: Icon(Icons.image, color: Colors.white70)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
