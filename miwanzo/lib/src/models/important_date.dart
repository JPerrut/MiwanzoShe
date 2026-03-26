class ImportantDate {
  const ImportantDate({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.repeatsAnnually,
    required this.notify3Months,
    required this.notify1Month,
    required this.notify1Week,
    required this.notify1Day,
    required this.notifyOnDay,
    this.notifyCustomDays,
  });

  final int id;
  final String title;
  final String description;
  final DateTime date;
  final bool repeatsAnnually;

  final bool notify3Months;
  final bool notify1Month;
  final bool notify1Week;
  final bool notify1Day;
  final bool notifyOnDay;
  final int? notifyCustomDays;

  DateTime get nextOccurrence {
    if (!repeatsAnnually) {
      return DateTime(date.year, date.month, date.day);
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var occurrence = _safeDate(now.year, date.month, date.day);

    if (occurrence.isBefore(today)) {
      occurrence = _safeDate(now.year + 1, date.month, date.day);
    }

    return occurrence;
  }

  int get daysUntilNextOccurrence {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return nextOccurrence.difference(today).inDays;
  }

  ImportantDate copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? date,
    bool? repeatsAnnually,
    bool? notify3Months,
    bool? notify1Month,
    bool? notify1Week,
    bool? notify1Day,
    bool? notifyOnDay,
    int? notifyCustomDays,
    bool clearCustomDays = false,
  }) {
    return ImportantDate(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      repeatsAnnually: repeatsAnnually ?? this.repeatsAnnually,
      notify3Months: notify3Months ?? this.notify3Months,
      notify1Month: notify1Month ?? this.notify1Month,
      notify1Week: notify1Week ?? this.notify1Week,
      notify1Day: notify1Day ?? this.notify1Day,
      notifyOnDay: notifyOnDay ?? this.notifyOnDay,
      notifyCustomDays: clearCustomDays
          ? null
          : (notifyCustomDays ?? this.notifyCustomDays),
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{
      'titulo': title,
      'descricao': description,
      'data': date.toIso8601String(),
      'repetir_anualmente': repeatsAnnually ? 1 : 0,
      'notificacao_3_meses': notify3Months ? 1 : 0,
      'notificacao_1_mes': notify1Month ? 1 : 0,
      'notificacao_1_semana': notify1Week ? 1 : 0,
      'notificacao_1_dia': notify1Day ? 1 : 0,
      'notificacao_no_dia': notifyOnDay ? 1 : 0,
      'notificacao_personalizada_dias': notifyCustomDays,
    };

    if (includeId) {
      map['id'] = id;
    }

    return map;
  }

  factory ImportantDate.fromMap(Map<String, Object?> map) {
    return ImportantDate(
      id: (map['id'] as num).toInt(),
      title: (map['titulo'] as String?) ?? '',
      description: (map['descricao'] as String?) ?? '',
      date: DateTime.parse(
        (map['data'] as String?) ?? DateTime.now().toIso8601String(),
      ),
      repeatsAnnually: ((map['repetir_anualmente'] as num?) ?? 1).toInt() == 1,
      notify3Months: ((map['notificacao_3_meses'] as num?) ?? 0).toInt() == 1,
      notify1Month: ((map['notificacao_1_mes'] as num?) ?? 0).toInt() == 1,
      notify1Week: ((map['notificacao_1_semana'] as num?) ?? 0).toInt() == 1,
      notify1Day: ((map['notificacao_1_dia'] as num?) ?? 0).toInt() == 1,
      notifyOnDay: ((map['notificacao_no_dia'] as num?) ?? 0).toInt() == 1,
      notifyCustomDays: (map['notificacao_personalizada_dias'] as num?)
          ?.toInt(),
    );
  }

  static DateTime _safeDate(int year, int month, int day) {
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    final safeDay = day > lastDayOfMonth ? lastDayOfMonth : day;
    return DateTime(year, month, safeDay);
  }
}
