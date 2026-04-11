enum MediaType { image, video }

class MediaEntry {
  const MediaEntry({
    required this.id,
    required this.path,
    required this.type,
    required this.createdAt,
  });

  final int id;
  final String path;
  final MediaType type;
  final DateTime createdAt;

  bool get isImage => type == MediaType.image;
  bool get isVideo => type == MediaType.video;

  MediaEntry copyWith({
    int? id,
    String? path,
    MediaType? type,
    DateTime? createdAt,
  }) {
    return MediaEntry(
      id: id ?? this.id,
      path: path ?? this.path,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{
      'caminho': path,
      'tipo': type.name,
      'data_criacao': createdAt.toIso8601String(),
    };

    if (includeId) {
      map['id'] = id;
    }

    return map;
  }

  factory MediaEntry.fromMap(Map<String, Object?> map) {
    final rawType = (map['tipo'] as String?) ?? MediaType.image.name;

    return MediaEntry(
      id: (map['id'] as num).toInt(),
      path: (map['caminho'] as String?) ?? '',
      type: rawType == MediaType.video.name ? MediaType.video : MediaType.image,
      createdAt: DateTime.parse(
        (map['data_criacao'] as String?) ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
