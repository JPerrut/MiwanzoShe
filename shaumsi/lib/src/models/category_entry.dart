class CategoryEntry {
  const CategoryEntry({required this.id, required this.name});

  final int id;
  final String name;

  factory CategoryEntry.fromMap(Map<String, Object?> map) {
    return CategoryEntry(
      id: (map['id'] as num).toInt(),
      name: (map['nome'] as String?) ?? '',
    );
  }
}
