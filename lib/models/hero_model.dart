class HeroModel {
  final int id;
  final String name;

  // Blocos principais
  final Map<String, dynamic> powerstats;
  final Map<String, dynamic> appearance;
  final Map<String, dynamic> images;

  // Novos blocos do dataset
  final Map<String, dynamic> biography;
  final Map<String, dynamic> work;
  final Map<String, dynamic> connections;

  HeroModel({
    required this.id,
    required this.name,
    required this.powerstats,
    required this.appearance,
    required this.images,
    required this.biography,
    required this.work,
    required this.connections,
  });

  factory HeroModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> _asMap(dynamic v) =>
        v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

    return HeroModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? 'Sem nome',
      powerstats: _asMap(json['powerstats']),
      appearance: _asMap(json['appearance']),
      images: _asMap(json['images']),
      biography: _asMap(json['biography']),
      work: _asMap(json['work']),
      connections: _asMap(json['connections']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'powerstats': powerstats,
      'appearance': appearance,
      'images': images,
      'biography': biography,
      'work': work,
      'connections': connections,
    };
  }
}
