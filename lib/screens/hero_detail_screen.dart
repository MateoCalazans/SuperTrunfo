import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:primer_progress_bar/primer_progress_bar.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_holder.dart';
import '../models/hero_model.dart';

class HeroDetailScreen extends StatelessWidget {
  const HeroDetailScreen({
    super.key,
    required this.hero,
    this.fromDeck = false,          // mostra botão apenas quando vier do deck
    this.onAbandoned,
  });

  final HeroModel hero;
  final bool fromDeck;
  final VoidCallback? onAbandoned;

  @override
  Widget build(BuildContext context) {
    final images = hero.images;
    final powerstats = hero.powerstats;
    final appearance = hero.appearance;
    final biography = hero.biography;
    final work = hero.work;
    final connections = hero.connections;

    final imageUrl = selectBestImageUrl(images);

    return Scaffold(
      appBar: AppBar(
        title: Text(hero.name),
        actions: [
          if (fromDeck)
            IconButton(
              tooltip: 'Abandonar carta',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmAbandon(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HeroHeaderImage(imageUrl: imageUrl),
            const SizedBox(height: 16),

            Text('Powerstats', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            PowerstatsBars(powerstats: powerstats),
            const SizedBox(height: 16),

            Text('Aparência', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            KeyValueList(map: appearance),
            const SizedBox(height: 16),

            if (biography.isNotEmpty) ...[
              Text('Biografia', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              KeyValueList(map: biography),
              const SizedBox(height: 16),
            ],

            if (work.isNotEmpty) ...[
              Text('Trabalho', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              KeyValueList(map: work),
              const SizedBox(height: 16),
            ],

            if (connections.isNotEmpty) ...[
              Text('Conexões', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              KeyValueList(map: connections),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmAbandon(BuildContext context) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.scale,
      title: 'Abandonar carta?',
      desc: 'Essa carta será removida do seu deck.',
      btnCancelOnPress: () {},
      btnOkText: 'Confirmar',
      btnOkOnPress: () async {
        await DatabaseHolder.I.run((db) async {
          await db.delete('deck_cards', where: 'id = ?', whereArgs: [hero.id]);
        });
        onAbandoned?.call();
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        // Feedback
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${hero.name} abandonado.')),
          );
        }
      },
    ).show();
  }
}

String selectBestImageUrl(Map images) {
  return (images['lg'] ?? images['md'] ?? images['sm'] ?? images['xs'] ?? '').toString();
}

class HeroHeaderImage extends StatelessWidget {
  const HeroHeaderImage({super.key, required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: imageUrl.isNotEmpty
            ? CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
          errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 64)),
        )
            : const Center(child: Icon(Icons.image, size: 64)),
      ),
    );
  }
}

class PowerstatsBars extends StatelessWidget {
  const PowerstatsBars({super.key, required this.powerstats});
  final Map powerstats;

  static const List<String> statOrder = [
    'intelligence',
    'strength',
    'speed',
    'durability',
    'power',
    'combat',
  ];

  @override
  Widget build(BuildContext context) {
    if (powerstats.isEmpty) {
      return const Text('Sem dados de powerstats');
    }
    final List<Widget> children = [];

    for (final key in statOrder) {
      if (!powerstats.containsKey(key)) continue;
      children.add(_buildBar(key, powerstats[key]));
    }
    for (final entry in powerstats.entries) {
      if (statOrder.contains(entry.key)) continue;
      children.add(_buildBar(entry.key, entry.value, isExtra: true));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildBar(String statKey, dynamic rawValue, {bool isExtra = false}) {
    final percent = _normalizeToPercent(rawValue);
    final color = _colorForStat(statKey, isExtra: isExtra);
    final label = Text(_labelForStat(statKey));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PrimerProgressBar(
        segments: [
          Segment(
            value: percent,
            color: color,
            label: label,
            valueLabel: Text('$percent%'),
          ),
        ],
        maxTotalValue: 100,
      ),
    );
  }

  int _normalizeToPercent(dynamic rawValue) {
    if (rawValue == null) return 0;
    if (rawValue is num) return rawValue.clamp(0, 100).toInt();
    final s = rawValue.toString().trim();
    final i = int.tryParse(s);
    if (i != null) return i.clamp(0, 100);
    final d = double.tryParse(s)?.toInt();
    return (d ?? 0).clamp(0, 100);
  }

  String _labelForStat(String key) {
    switch (key) {
      case 'intelligence':
        return 'Inteligência';
      case 'strength':
        return 'Força';
      case 'speed':
        return 'Velocidade';
      case 'durability':
        return 'Durabilidade';
      case 'power':
        return 'Poder';
      case 'combat':
        return 'Combate';
      default:
        return key;
    }
  }

  Color _colorForStat(String key, {bool isExtra = false}) {
    if (isExtra) return Colors.blueGrey;
    switch (key) {
      case 'intelligence':
        return Colors.indigo;
      case 'strength':
        return Colors.redAccent;
      case 'speed':
        return Colors.orangeAccent;
      case 'durability':
        return Colors.teal;
      case 'power':
        return Colors.purple;
      case 'combat':
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }
}

class KeyValueList extends StatelessWidget {
  const KeyValueList({super.key, required this.map});
  final Map map;

  @override
  Widget build(BuildContext context) {
    if (map.isEmpty) return const Text('Sem dados disponíveis');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: map.entries.map((entry) {
        final prettyKey = _prettifyKey(entry.key);
        final prettyValue = _prettifyValue(entry.value);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('$prettyKey: $prettyValue'),
        );
      }).toList(),
    );
  }

  String _prettifyKey(String key) {
    if (key.isEmpty) return key;
    final k = key.replaceAll('_', ' ');
    return k[0].toUpperCase() + k.substring(1);
  }

  String _prettifyValue(dynamic value) {
    if (value == null) return 'N/D';
    if (value is List) return value.join(', ');
    return value.toString();
  }
}
