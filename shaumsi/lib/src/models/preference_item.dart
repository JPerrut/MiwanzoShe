enum PreferenceStatus { likes, dislikes }

class PreferenceItem {
  const PreferenceItem({
    required this.id,
    required this.categoryId,
    required this.category,
    required this.name,
    required this.status,
    required this.observation,
  });

  final int id;
  final int categoryId;
  final String category;
  final String name;
  final PreferenceStatus status;
  final String observation;

  PreferenceItem copyWith({
    int? id,
    int? categoryId,
    String? category,
    String? name,
    PreferenceStatus? status,
    String? observation,
  }) {
    return PreferenceItem(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      category: category ?? this.category,
      name: name ?? this.name,
      status: status ?? this.status,
      observation: observation ?? this.observation,
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    final likes = status == PreferenceStatus.likes;

    final map = <String, Object?>{
      'categoria_id': categoryId,
      'nome': name,
      'gosta': likes ? 1 : 0,
      'nao_gosta': likes ? 0 : 1,
      'observacao': observation,
    };

    if (includeId) {
      map['id'] = id;
    }

    return map;
  }

  factory PreferenceItem.fromMap(Map<String, Object?> map) {
    final likes = ((map['gosta'] as num?) ?? 0).toInt() == 1;

    return PreferenceItem(
      id: (map['id'] as num).toInt(),
      categoryId: ((map['categoria_id'] as num?) ?? 0).toInt(),
      category:
          (map['categoria_nome'] as String?) ??
          (map['categoria'] as String?) ??
          '',
      name: (map['nome'] as String?) ?? '',
      status: likes ? PreferenceStatus.likes : PreferenceStatus.dislikes,
      observation: (map['observacao'] as String?) ?? '',
    );
  }
}
