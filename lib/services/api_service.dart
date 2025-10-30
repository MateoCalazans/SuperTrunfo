import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/hero_model.dart';

class ApiService {
  ApiService({required this.client, required this.baseUrl});
  final http.Client client;
  final String baseUrl;

  factory ApiService.defaultInstance() {
    return ApiService(client: http.Client(), baseUrl: 'http://10.0.2.2:3000');
  }

  // Paginação determinística por _start/_end e log para diagnóstico.
  Future<List<HeroModel>> fetchHeroesPage(int page, int pageSize) async {
    final start = (page - 1) * pageSize;
    final end = start + pageSize;
    final uri = Uri.parse('$baseUrl/heroes?_start=$start&_end=$end&_sort=id&_order=asc');
    // ignore: avoid_print
    print('[API] GET $uri');

    final res = await client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Erro ao buscar heróis: ${res.statusCode}');
    }

    final body = jsonDecode(res.body);
    if (body is! List) {
      throw Exception('Formato inesperado: esperado List');
    }

    return body
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .map(HeroModel.fromJson)
        .toList();
  }

  // Baixa tudo e ordena numericamente por id no cliente (primeiro acesso).
  Future<List<HeroModel>> fetchAllHeroes() async {
    final uri = Uri.parse('$baseUrl/heroes');
    // ignore: avoid_print
    print('[API] GET $uri (ALL)');

    final res = await client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Erro ao buscar heróis: ${res.statusCode}');
    }

    final body = jsonDecode(res.body);
    if (body is! List) {
      throw Exception('Formato inesperado: esperado List');
    }

    final list = body
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .map(HeroModel.fromJson)
        .toList();

    list.sort((a, b) => a.id.compareTo(b.id));
    return list;
  }

  void dispose() {
    client.close();
  }
}
