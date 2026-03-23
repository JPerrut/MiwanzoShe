class NoteEntry {
  const NoteEntry({
    required this.id,
    required this.title,
    required this.description,
    required this.tag,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String description;
  final String tag;
  final DateTime createdAt;

  NoteEntry copyWith({
    int? id,
    String? title,
    String? description,
    String? tag,
    DateTime? createdAt,
  }) {
    return NoteEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      tag: tag ?? this.tag,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{
      'titulo': title,
      'descricao': description,
      'tag': tag,
      'data_criacao': createdAt.toIso8601String(),
    };

    if (includeId) {
      map['id'] = id;
    }

    return map;
  }

  factory NoteEntry.fromMap(Map<String, Object?> map) {
    return NoteEntry(
      id: (map['id'] as num).toInt(),
      title: (map['titulo'] as String?) ?? '',
      description: (map['descricao'] as String?) ?? '',
      tag: (map['tag'] as String?) ?? 'sem_tag',
      createdAt: DateTime.parse(
        (map['data_criacao'] as String?) ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
