// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supertrunfo/main.dart';
import 'package:supertrunfo/domain/hero_repository.dart';
import 'package:supertrunfo/models/hero_model.dart';

// Fake em memória para o teste
class FakeHeroRepository implements HeroRepository {
  @override
  Future<List<HeroModel>> fetchPage({required int pageNumber, required int pageSize}) async {
    return <HeroModel>[];
  }

  @override
  Future<void> upsertPage(List<HeroModel> heroes) async {}

  @override
  Future<List<HeroModel>> getCachedPage({required int pageNumber, required int pageSize}) async {
    return <HeroModel>[];
  }

  @override
  Future<HeroModel?> getCachedById(int heroId) async {
    return null;
  }
}

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    final repo = FakeHeroRepository();
    await tester.pumpWidget(MyApp(repository: repo));

    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
