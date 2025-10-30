// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import '../domain/hero_repository.dart';
import 'heroes_screen.dart';
import 'daily_card_screen.dart';
import 'my_cards_screen.dart';
import 'battle_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.repository});
  final HeroRepository repository;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Trunfo dos Heróis'),
        centerTitle: true,
        backgroundColor: colorScheme.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMenuButton(
                context,
                label: 'Heróis',
                icon: Icons.people_alt_rounded,
                color: colorScheme.primaryContainer,
                destinationBuilder: () => HeroesScreen(repository: repository),
              ),
              const SizedBox(height: 20),
              _buildMenuButton(
                context,
                label: 'Card Diário',
                icon: Icons.card_giftcard_rounded,
                color: colorScheme.secondaryContainer,
                destinationBuilder: () => DailyCardScreen(repository: repository,testingMode: false),
              ),
              const SizedBox(height: 20),
              _buildMenuButton(
                context,
                label: 'Minhas Cartas',
                icon: Icons.collections_rounded,
                color: colorScheme.tertiaryContainer,
                destinationBuilder: () => const MyCardsScreen(),
              ),
              const SizedBox(height: 20),
              _buildMenuButton(
                context,
                label: 'Batalhar',
                icon: Icons.sports_rounded,
                color: colorScheme.primaryFixedDim,
                destinationBuilder: () => const BattleScreen(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(
      BuildContext context, {
        required String label,
        required IconData icon,
        required Color color,
        required Widget Function() destinationBuilder,
      }) {
    final textColor = Theme.of(context).colorScheme.onPrimaryContainer;
    return SizedBox(
      width: double.infinity,
      height: 80,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 3,
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destinationBuilder()),
          );
        },
        icon: Icon(icon, size: 32, color: textColor),
        label: Text(
          label,
          style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
