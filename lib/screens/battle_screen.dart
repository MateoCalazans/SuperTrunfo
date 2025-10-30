import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../database/database_holder.dart';
import '../models/hero_model.dart';
import '../widgets/hero_trumps_card.dart';

class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  late Future<void> _initFuture;

  List<HeroModel> _deck = [];
  int _index = 0;

  String? _selectedAttrKey;

  int _wins = 0;
  int _losses = 0;
  int _draws = 0;

  static const List<String> kAttrOrder = [
    'intelligence',
    'strength',
    'speed',
    'durability',
    'power',
    'combat',
  ];

  static const Map<String, String> kAttrLabels = {
    'intelligence': 'Inteligência',
    'strength': 'Força',
    'speed': 'Velocidade',
    'durability': 'Durabilidade',
    'power': 'Poder',
    'combat': 'Combate',
  };

  @override
  void initState() {
    super.initState();
    _initFuture = _loadAndShuffleDeck();
  }

  Future<void> _loadAndShuffleDeck() async {
    final idsRows = await DatabaseHolder.I.run((db) async {
      return await db.query('deck_cards', orderBy: 'addedAt DESC', limit: 15);
    }) as List<Map<String, Object?>>;

    if (idsRows.isEmpty) {
      setState(() {
        _deck = [];
        _index = 0;
      });
      return;
    }

    final ids = idsRows.map((r) => r['id'] as int).toList();
    final placeholders = List.filled(ids.length, '?').join(',');

    final rows = await DatabaseHolder.I.run((db) async {
      return await db.rawQuery('SELECT * FROM heroes WHERE id IN ($placeholders)', ids);
    }) as List<Map<String, Object?>>;

    List<HeroModel> list = rows.map((row) {
      Map<String, dynamic> _decode(Object? v) {
        if (v == null) return {};
        try {
          return Map<String, dynamic>.from(jsonDecode(v as String));
        } catch (_) {
          return {};
        }
      }

      return HeroModel(
        id: row['id'] as int,
        name: row['name'] as String,
        powerstats: _decode(row['powerstats']),
        appearance: _decode(row['appearance']),
        images: _decode(row['images']),
        biography: _decode(row['biography']),
        work: _decode(row['work']),
        connections: _decode(row['connections']),
      );
    }).toList();

    list.shuffle(Random());

    setState(() {
      _deck = list;
      _index = 0;
      _selectedAttrKey = null;
      _wins = 0;
      _losses = 0;
      _draws = 0;
    });
  }

  bool get _finished => _index >= _deck.length || _deck.isEmpty;

  void _nextCard() {
    if (_finished) return;
    setState(() {
      _index += 1;
      _selectedAttrKey = null;
    });
  }

  void _markWin() {
    setState(() => _wins += 1);
    _nextCard();
  }

  void _markLoss() {
    setState(() => _losses += 1);
    _nextCard();
  }

  void _markDraw() {
    setState(() => _draws += 1);
    _nextCard();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batalhar'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Reiniciar',
            onPressed: () => setState(() => _initFuture = _loadAndShuffleDeck()),
            icon: const Icon(Icons.restart_alt),
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
            return const _EmptyDeck();
          }
          if (_finished) {
            return _BattleSummary(
              total: _deck.length,
              wins: _wins,
              losses: _losses,
              draws: _draws,
              onRestart: () => setState(() => _initFuture = _loadAndShuffleDeck()),
            );
          }

          final hero = _deck[_index];
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _BattleHeader(
                  current: _index + 1,
                  total: _deck.length,
                  wins: _wins,
                  losses: _losses,
                  draws: _draws,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxWidth = constraints.maxWidth.clamp(280.0, 420.0);
                      final cardHeight = constraints.maxHeight - 16;
                      return Center(
                        child: SizedBox(
                          width: maxWidth,
                          height: cardHeight,
                          child: HeroTrumpsCard(hero: hero),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _AttrPicker(
                  powerstats: hero.powerstats,
                  selectedKey: _selectedAttrKey,
                  onSelect: (k) => setState(() => _selectedAttrKey = k),
                ),
                const SizedBox(height: 12),
                _BattleControls(
                  enabled: true,
                  onWin: _markWin,
                  onLoss: _markLoss,
                  onDraw: _markDraw,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyDeck extends StatelessWidget {
  const _EmptyDeck();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.style, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'Seu deck está vazio.\nUse o Card Diário para obter cartas.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _BattleHeader extends StatelessWidget {
  const _BattleHeader({
    required this.current,
    required this.total,
    required this.wins,
    required this.losses,
    required this.draws,
  });

  final int current;
  final int total;
  final int wins;
  final int losses;
  final int draws;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            'Round $current de $total',
            style: theme.textTheme.titleMedium,
          ),
        ),
        _Pill(text: 'Vitórias: $wins', color: Colors.green),
        const SizedBox(width: 8),
        _Pill(text: 'Derrotas: $losses', color: Colors.redAccent),
        const SizedBox(width: 8),
        _Pill(text: 'Empates: $draws', color: Colors.blueGrey),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AttrPicker extends StatelessWidget {
  const _AttrPicker({
    required this.powerstats,
    required this.selectedKey,
    required this.onSelect,
  });

  final Map powerstats;
  final String? selectedKey;
  final ValueChanged<String> onSelect;

  static const List<String> order = _BattleScreenState.kAttrOrder;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    for (final key in order) {
      if (!powerstats.containsKey(key)) continue;
      final lbl = _BattleScreenState.kAttrLabels[key] ?? key;
      final isSel = selectedKey == key;
      chips.add(
        ChoiceChip(
          label: Text(lbl),
          selected: isSel,
          onSelected: (_) => onSelect(key),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: chips,
    );
  }
}

class _BattleControls extends StatelessWidget {
  const _BattleControls({
    required this.enabled,
    required this.onWin,
    required this.onLoss,
    required this.onDraw,
  });

  final bool enabled;
  final VoidCallback onWin;
  final VoidCallback onLoss;
  final VoidCallback onDraw;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BigButton(text: 'Ganhei o round', enabled: enabled, onPressed: onWin, color: Colors.blue),
        const SizedBox(height: 8),
        _BigButton(text: 'Perdi o round', enabled: enabled, onPressed: onLoss, color: Colors.blueGrey),
        const SizedBox(height: 8),
        _BigButton(text: 'Empate', enabled: enabled, onPressed: onDraw, color: Colors.indigo),
      ],
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.text,
    required this.enabled,
    required this.onPressed,
    required this.color,
  });

  final String text;
  final bool enabled;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(backgroundColor: color),
        child: Text(text),
      ),
    );
  }
}

class _BattleSummary extends StatelessWidget {
  const _BattleSummary({
    required this.total,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.onRestart,
  });

  final int total;
  final int wins;
  final int losses;
  final int draws;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final you = wins;
    final opp = losses;
    String result;
    if (you > opp) {
      result = 'Você venceu a batalha!';
    } else if (you < opp) {
      result = 'Seu amigo venceu a batalha.';
    } else {
      result = 'Empate na batalha.';
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(result, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Text('Rounds: $total'),
          Text('Vitórias: $wins  •  Derrotas: $losses  •  Empates: $draws'),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onRestart,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Jogar novamente'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Voltar'),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
