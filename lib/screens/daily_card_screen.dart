// lib/screens/daily_card_screen.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_holder.dart';
import '../domain/hero_repository.dart';
import '../models/hero_model.dart';
import '../widgets/hero_trumps_card.dart';

class DailyCardScreen extends StatefulWidget {
  const DailyCardScreen({
    super.key,
    required this.repository,
    this.testingMode = true,
    this.testingTtlSeconds = 30,
  });

  final HeroRepository repository;
  final bool testingMode;
  final int testingTtlSeconds;

  @override
  State<DailyCardScreen> createState() => _DailyCardScreenState();
}

class _DailyCardScreenState extends State<DailyCardScreen> {
  HeroModel? _todayHero;
  late Future<void> _initFuture;

  // Definitivo (após obter)
  static const _prefsKeyDate = 'daily_card_date';       // YYYY-MM-DD (modo diário)
  static const _prefsKeyHeroId = 'daily_card_hero_id';  // id definitivo
  static const _prefsKeyTs = 'daily_card_timestamp';    // ms epoch (modo teste)

  // Preview (antes de obter)
  static const _prefsKeyPrevId = 'daily_card_preview_id';
  static const _prefsKeyPrevTs = 'daily_card_preview_ts'; // usado no modo teste

  bool _disposed = false;
  Timer? _tick;
  Duration _remaining = Duration.zero;

  bool _lockedToday = false;   // modo diário: já obteve hoje
  int? _savedHeroId;           // id definitivo ativo (dia/TTL)
  Set<int> _obtainedIds = {};  // ids já obtidos (nunca re-sortear)

  @override
  void initState() {
    super.initState();
    _initFuture = _init();
  }

  @override
  void dispose() {
    _disposed = true;
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _safeSet(VoidCallback fn) async {
    if (!mounted || _disposed) return;
    setState(fn);
  }

  Future<Set<int>> _loadObtainedIds() async {
    final rows = await DatabaseHolder.I.run((db) async {
      return await db.query('deck_cards', columns: ['id']);
    }) as List<Map<String, Object?>>;
    return rows.map((r) => r['id'] as int).toSet();
  }

  Future<void> _init() async {
    _obtainedIds = await _loadObtainedIds();

    final prefs = await SharedPreferences.getInstance();
    final storedDate = prefs.getString(_prefsKeyDate);
    final storedHeroId = prefs.getInt(_prefsKeyHeroId);
    final storedTs = prefs.getInt(_prefsKeyTs);

    final prevId = prefs.getInt(_prefsKeyPrevId);
    final prevTs = prefs.getInt(_prefsKeyPrevTs);

    final now = DateTime.now();

    _lockedToday = false;
    _savedHeroId = null;

    if (widget.testingMode) {
      final ttl = Duration(seconds: widget.testingTtlSeconds);
      final last = storedTs != null ? DateTime.fromMillisecondsSinceEpoch(storedTs) : null;
      final withinTtl = last != null && now.difference(last) < ttl;
      _startCountdown(withinTtl ? ttl - now.difference(last!) : Duration.zero);

      // Definitivo ativo dentro do TTL
      if (withinTtl && storedHeroId != null) {
        _savedHeroId = storedHeroId;
        final cached = await widget.repository.getCachedById(storedHeroId);
        if (cached != null) {
          await _safeSet(() => _todayHero = cached);
          return;
        }
        if (_todayHero != null && _todayHero!.id == storedHeroId) return;
        return;
      }

      // Preview válido dentro do TTL de teste
      if (prevId != null && prevTs != null) {
        final prevAge = now.difference(DateTime.fromMillisecondsSinceEpoch(prevTs));
        final prevWithin = prevAge < ttl;
        if (prevWithin) {
          final cached = await widget.repository.getCachedById(prevId);
          if (cached != null) {
            await _safeSet(() => _todayHero = cached);
            _savedHeroId = null;
            return;
          } else if (_todayHero != null && _todayHero!.id == prevId) {
            return;
          } else {
            return;
          }
        }
      }

      // Sem definitiva/preview válido → sortear preview novo
      await _drawNewPreviewAndSavePreview();
      return;
    }

    // Modo diário (sem TTL)
    final todayKey = _yyyyMmDd(now);
    _startCountdown(Duration.zero);

    // Já obteve hoje
    if (storedDate == todayKey && storedHeroId != null) {
      final cached = await widget.repository.getCachedById(storedHeroId);
      if (cached != null) {
        _lockedToday = true;
        _savedHeroId = storedHeroId;
        await _safeSet(() => _todayHero = cached);
        return;
      }
    }

    // Preview persistido (mesma carta entre visitas)
    if (prevId != null) {
      final cached = await widget.repository.getCachedById(prevId);
      if (cached != null) {
        await _safeSet(() => _todayHero = cached);
        _savedHeroId = null;
        return;
      } else if (_todayHero != null && _todayHero!.id == prevId) {
        return;
      }
    }

    // Sortear novo preview
    await _drawNewPreviewAndSavePreview();
  }

  String _yyyyMmDd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _startCountdown(Duration initial) {
    _tick?.cancel();
    _remaining = initial.isNegative ? Duration.zero : initial;
    if (!mounted) return;
    setState(() {});
    if (_remaining == Duration.zero) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _disposed) return;
      _remaining -= const Duration(seconds: 1);
      if (_remaining <= Duration.zero) {
        _remaining = Duration.zero;
        _tick?.cancel();
      }
      if (!mounted || _disposed) return;
      setState(() {});
    });
  }

  String _format(Duration d) {
    final s = d.inSeconds;
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<List<HeroModel>> _buildRandomPool() async {
    final pool = <HeroModel>[];
    for (int p = 1; p <= 3; p++) {
      final page = await widget.repository.getCachedPage(pageNumber: p, pageSize: 50);
      if (page.isEmpty) break;
      pool.addAll(page);
    }
    if (pool.isEmpty) {
      try {
        final fetched = await widget.repository.fetchPage(pageNumber: 1, pageSize: 50);
        pool.addAll(fetched);
      } catch (_) {}
    }
    return pool;
  }

  Future<void> _drawNewPreviewAndSavePreview() async {
    await _drawNewPreview();
    if (_todayHero == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKeyPrevId, _todayHero!.id);
    if (widget.testingMode) {
      await prefs.setInt(_prefsKeyPrevTs, DateTime.now().millisecondsSinceEpoch);
    } else {
      await prefs.remove(_prefsKeyPrevTs);
    }
  }

  Future<void> _clearPreviewPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyPrevId);
    await prefs.remove(_prefsKeyPrevTs);
  }

  Future<void> _drawNewPreview({int? prevId}) async {
    var pool = await _buildRandomPool();
    if (pool.isEmpty) {
      await _safeSet(() => _todayHero = null);
      return;
    }

    // Excluir obtidos/definitivo/último salvo/prevId
    final excluded = <int>{..._obtainedIds};
    if (prevId != null) excluded.add(prevId);
    if (_savedHeroId != null) excluded.add(_savedHeroId!);
    final prefs = await SharedPreferences.getInstance();
    final lastSaved = prefs.getInt(_prefsKeyHeroId);
    if (lastSaved != null) excluded.add(lastSaved);

    pool = pool.where((h) => !excluded.contains(h.id)).toList();

    if (pool.isEmpty) {
      pool = await _buildRandomPool();
      pool = pool.where((h) => !excluded.contains(h.id)).toList();
      if (pool.isEmpty) {
        await _safeSet(() => _todayHero = null);
        return;
      }
    }

    pool.shuffle();
    final selected = pool[Random().nextInt(pool.length)];
    await _safeSet(() => _todayHero = selected);
  }

  Future<bool> _deckHasSpace() async {
    final count = await DatabaseHolder.I.run<int>((db) async {
      return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM deck_cards')) ?? 0;
    });
    return count < 15;
  }

  Future<void> _addCurrentToDeck() async {
    final hero = _todayHero;
    if (hero == null) return;
    await DatabaseHolder.I.run((db) async {
      final exists = await db.query('deck_cards', where: 'id = ?', whereArgs: [hero.id], limit: 1);
      if (exists.isEmpty) {
        await db.insert('deck_cards', {
          'id': hero.id,
          'addedAt': DateTime.now().toLocal().toIso8601String(), // horário local
        });
      }
    });
    _obtainedIds.add(hero.id);
  }

  Future<void> _handleObter() async {
    final prefs = await SharedPreferences.getInstance();

    if (!widget.testingMode) {
      final todayKey = _yyyyMmDd(DateTime.now());
      final storedDate = prefs.getString(_prefsKeyDate);
      if (storedDate == todayKey) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hoje você já obteve um card. Volte amanhã.')),
        );
        return;
      }
    } else {
      if (_remaining > Duration.zero) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Aguarde ${_format(_remaining)} para novo sorteio.')),
        );
        return;
      }
    }

    if (!await _deckHasSpace()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seu deck tem 15 cartas. Remova uma para obter outra.')),
      );
      return;
    }

    await _addCurrentToDeck();

    final now = DateTime.now();
    await prefs.setInt(_prefsKeyHeroId, _todayHero!.id);
    await _clearPreviewPrefs();

    if (widget.testingMode) {
      await prefs.setInt(_prefsKeyTs, now.millisecondsSinceEpoch);
      await prefs.remove(_prefsKeyDate);
      _savedHeroId = _todayHero!.id;
      _startCountdown(Duration(seconds: widget.testingTtlSeconds));
    } else {
      final todayKey = _yyyyMmDd(now);
      await prefs.setString(_prefsKeyDate, todayKey);
      await prefs.remove(_prefsKeyTs);
      _lockedToday = true;
      _savedHeroId = _todayHero!.id;
      _startCountdown(Duration.zero);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Carta adicionada ao Deck!')),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.testingMode
        ? 'Modo de teste: novo sorteio a cada ${widget.testingTtlSeconds}s'
        : 'Um card por dia';

    final canObtain = widget.testingMode ? _remaining == Duration.zero : !_lockedToday;
    final buttonLabel = widget.testingMode
        ? (_remaining == Duration.zero ? 'Obter' : 'Aguarde ${_format(_remaining)}')
        : (_lockedToday ? 'Já obtido hoje' : 'Obter');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Card Diário'),
        centerTitle: true,
        actions: [
          // TEMP: gerar novo preview (mantém bloqueios)
          IconButton(
            tooltip: 'Novo preview',
            icon: const Icon(Icons.casino),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(_prefsKeyPrevId);
              await prefs.remove(_prefsKeyPrevTs);
              if (!mounted) return;
              setState(() => _initFuture = _init()); // recarrega e sorteia outro preview
            },
          ),
          // TEMP: liberar hoje (remove bloqueio diário/TTL, sem mexer no preview)
          IconButton(
            tooltip: 'Liberar hoje',
            icon: const Icon(Icons.lock_open),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(_prefsKeyDate);   // diário
              await prefs.remove(_prefsKeyHeroId); // definitivo
              await prefs.remove(_prefsKeyTs);     // TTL teste
              if (!mounted) return;
              setState(() => _initFuture = _init());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Liberação feita: você pode obter outra carta.')),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(22),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(subtitle, style: Theme.of(context).textTheme.labelMedium),
          ),
        ),
      ),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_todayHero == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Sem dados no cache para sortear.'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _initFuture = _init()),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = constraints.maxWidth.clamp(280.0, 420.0);
                    final cardHeight = constraints.maxHeight - 16;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: SizedBox(
                          width: maxWidth,
                          height: cardHeight,
                          child: HeroTrumpsCard(hero: _todayHero!), // reaproveitado
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: canObtain ? _handleObter : null,
                    child: Text(buttonLabel),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
