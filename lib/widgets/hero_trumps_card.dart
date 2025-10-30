// lib/widgets/hero_trumps_card.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:primer_progress_bar/primer_progress_bar.dart';
import '../models/hero_model.dart';

class HeroTrumpsCard extends StatelessWidget {
  const HeroTrumpsCard({super.key, required this.hero});
  final HeroModel hero;

  @override
  Widget build(BuildContext context) {
    final borderRed = const Color(0xFFCF2A1E);
    final navy = const Color(0xFF0E2B4F);
    final panelBlue = const Color(0xFF183552);
    final blueAccent = const Color(0xFF1B4F9C);

    final images = hero.images;
    final imageUrl = (images['lg'] ?? images['md'] ?? images['sm'] ?? images['xs'] ?? '').toString();

    String buildBioParagraph() {
      final bio = hero.biography;
      final work = hero.work;
      final connections = hero.connections;
      final fullName = (bio['fullName'] ?? bio['full-name'] ?? '').toString();
      final publisher = (bio['publisher'] ?? '').toString();
      final place = (bio['placeOfBirth'] ?? bio['place-of-birth'] ?? '').toString();
      final first = (bio['firstAppearance'] ?? bio['first-appearance'] ?? '').toString();
      final occupation = (work['occupation'] ?? '').toString();
      final affiliation = (connections['groupAffiliation'] ?? '').toString();
      final parts = <String>[];
      if (fullName.isNotEmpty) parts.add('Nome: $fullName.');
      if (publisher.isNotEmpty) parts.add('Editora: $publisher.');
      if (place.isNotEmpty) parts.add('Origem: $place.');
      if (first.isNotEmpty) parts.add('Primeira aparição: $first.');
      if (occupation.isNotEmpty) parts.add('Ocupação: $occupation.');
      if (affiliation.isNotEmpty) parts.add('Afiliação: $affiliation.');
      if (parts.isEmpty) return 'Herói lendário com feitos notáveis.';
      return parts.join(' ');
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderRed, width: 8),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 8))],
      ),
      padding: const EdgeInsets.all(10),
      child: Container(
        decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            // Cabeçalho
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: blueAccent, borderRadius: BorderRadius.circular(8)),
              child: Text(
                hero.name.toUpperCase(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            // Imagem
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                  errorWidget: (_, __, ___) =>
                  const Center(child: Icon(Icons.broken_image, color: Colors.white70, size: 48)),
                )
                    : const Center(child: Icon(Icons.image, color: Colors.white70, size: 48)),
              ),
            ),
            const SizedBox(height: 8),
            // Bio
            Flexible(
              flex: 5,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: panelBlue, borderRadius: BorderRadius.circular(8)),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Text(
                    buildBioParagraph(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white, height: 1.25),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Stats (PrimerProgressBar para cada atributo)
            Flexible(
              flex: 6,
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: _StatsWithPrimer(powerstats: hero.powerstats),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsWithPrimer extends StatelessWidget {
  const _StatsWithPrimer({required this.powerstats});
  final Map powerstats;

  static const rows = [
    _RowSpec('inteligência', 'intelligence', Colors.indigo),
    _RowSpec('força', 'strength', Colors.redAccent),
    _RowSpec('velocidade', 'speed', Colors.orangeAccent),
    _RowSpec('durabilidade', 'durability', Colors.teal),
    _RowSpec('poder', 'power', Colors.purple),
    _RowSpec('combate', 'combat', Colors.green),
  ];

  int _norm(dynamic raw) {
    if (raw == null) return 0;
    if (raw is num) return raw.clamp(0, 100).toInt();
    final i = int.tryParse(raw.toString());
    if (i != null) return i.clamp(0, 100);
    final d = double.tryParse(raw.toString())?.toInt() ?? 0;
    return d.clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final r in rows)
          _StatRowPrimer(
            label: r.label,
            value: _norm(powerstats[r.key]),
            color: r.color,
          ),
      ],
    );
  }
}

class _RowSpec {
  const _RowSpec(this.label, this.key, this.color);
  final String label;
  final String key;
  final Color color;
}

class _StatRowPrimer extends StatelessWidget {
  const _StatRowPrimer({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final trackColor = Colors.black.withValues(alpha: 0.25);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // barra
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: trackColor,
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: PrimerProgressBar(
                segments: [
                  Segment(
                    value: value,
                    color: color,
                    label: null,
                    valueLabel: Text(
                      '$value',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
                maxTotalValue: 100,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
