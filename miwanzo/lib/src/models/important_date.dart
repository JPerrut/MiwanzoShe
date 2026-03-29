import 'dart:convert';

class ImportantDate {
  static const String notificationSoundDefault = 'default';
  static const String notificationSoundMiwanzo = 'miwanzo_tone';
  static const List<String> supportedNotificationSounds = [
    notificationSoundDefault,
    notificationSoundMiwanzo,
  ];

  ImportantDate({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.notificationHour,
    required this.notificationMinute,
    required this.repeatsAnnually,
    required this.notify3Months,
    required this.notify1Month,
    required this.notify1Week,
    required this.notify1Day,
    required this.notifyOnDay,
    String notificationSound = notificationSoundDefault,
    List<DateTime> notifyCustomDates = const [],
  }) : notificationSound = _normalizeNotificationSound(notificationSound),
       notifyCustomDates = _normalizeCustomDates(notifyCustomDates);

  final int id;
  final String title;
  final String description;
  final DateTime date;
  final int notificationHour;
  final int notificationMinute;
  final bool repeatsAnnually;

  final bool notify3Months;
  final bool notify1Month;
  final bool notify1Week;
  final bool notify1Day;
  final bool notifyOnDay;
  final String notificationSound;
  final List<DateTime> notifyCustomDates;

  DateTime? get notifyCustomAt =>
      notifyCustomDates.isEmpty ? null : notifyCustomDates.first;

  bool get hasAnyNotification {
    return notify3Months ||
        notify1Month ||
        notify1Week ||
        notify1Day ||
        notifyOnDay ||
        notifyCustomDates.isNotEmpty;
  }

  bool get isPastNonRepeating {
    if (repeatsAnnually) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.isBefore(today);
  }

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
    int? notificationHour,
    int? notificationMinute,
    bool? repeatsAnnually,
    bool? notify3Months,
    bool? notify1Month,
    bool? notify1Week,
    bool? notify1Day,
    bool? notifyOnDay,
    String? notificationSound,
    List<DateTime>? notifyCustomDates,
    bool clearCustomDates = false,
  }) {
    return ImportantDate(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      notificationHour: notificationHour ?? this.notificationHour,
      notificationMinute: notificationMinute ?? this.notificationMinute,
      repeatsAnnually: repeatsAnnually ?? this.repeatsAnnually,
      notify3Months: notify3Months ?? this.notify3Months,
      notify1Month: notify1Month ?? this.notify1Month,
      notify1Week: notify1Week ?? this.notify1Week,
      notify1Day: notify1Day ?? this.notify1Day,
      notifyOnDay: notifyOnDay ?? this.notifyOnDay,
      notificationSound: notificationSound ?? this.notificationSound,
      notifyCustomDates: clearCustomDates
          ? const []
          : (notifyCustomDates ?? this.notifyCustomDates),
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{
      'titulo': title,
      'descricao': description,
      'data': date.toIso8601String(),
      'notificacao_hora': notificationHour,
      'notificacao_minuto': notificationMinute,
      'repetir_anualmente': repeatsAnnually ? 1 : 0,
      'notificacao_3_meses': notify3Months ? 1 : 0,
      'notificacao_1_mes': notify1Month ? 1 : 0,
      'notificacao_1_semana': notify1Week ? 1 : 0,
      'notificacao_1_dia': notify1Day ? 1 : 0,
      'notificacao_no_dia': notifyOnDay ? 1 : 0,
      'notificacao_som': notificationSound,
      'notificacao_personalizada_data': _encodeCustomDates(notifyCustomDates),
    };

    if (includeId) {
      map['id'] = id;
    }

    return map;
  }

  factory ImportantDate.fromMap(Map<String, Object?> map) {
    final parsedDate = DateTime.parse(
      (map['data'] as String?) ?? DateTime.now().toIso8601String(),
    );
    final hour = ((map['notificacao_hora'] as num?) ?? 9).toInt();
    final minute = ((map['notificacao_minuto'] as num?) ?? 0).toInt();
    final sound = _normalizeNotificationSound(
      (map['notificacao_som'] as String?) ?? notificationSoundDefault,
    );
    final customAtRaw = map['notificacao_personalizada_data'] as String?;
    final legacyCustomDays = (map['notificacao_personalizada_dias'] as num?)
        ?.toInt();

    var customDates = _decodeCustomDates(customAtRaw);

    if (customDates.isEmpty && legacyCustomDays != null) {
      customDates = _normalizeCustomDates([
        DateTime(
          parsedDate.year,
          parsedDate.month,
          parsedDate.day,
          hour,
          minute,
        ).subtract(Duration(days: legacyCustomDays)),
      ]);
    }

    return ImportantDate(
      id: (map['id'] as num).toInt(),
      title: (map['titulo'] as String?) ?? '',
      description: (map['descricao'] as String?) ?? '',
      date: parsedDate,
      notificationHour: hour,
      notificationMinute: minute,
      repeatsAnnually: ((map['repetir_anualmente'] as num?) ?? 1).toInt() == 1,
      notify3Months: ((map['notificacao_3_meses'] as num?) ?? 0).toInt() == 1,
      notify1Month: ((map['notificacao_1_mes'] as num?) ?? 0).toInt() == 1,
      notify1Week: ((map['notificacao_1_semana'] as num?) ?? 0).toInt() == 1,
      notify1Day: ((map['notificacao_1_dia'] as num?) ?? 0).toInt() == 1,
      notifyOnDay: ((map['notificacao_no_dia'] as num?) ?? 0).toInt() == 1,
      notificationSound: sound,
      notifyCustomDates: customDates,
    );
  }

  static DateTime _safeDate(int year, int month, int day) {
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    final safeDay = day > lastDayOfMonth ? lastDayOfMonth : day;
    return DateTime(year, month, safeDay);
  }

  static String? _encodeCustomDates(List<DateTime> customDates) {
    final normalized = _normalizeCustomDates(customDates);
    if (normalized.isEmpty) return null;
    if (normalized.length == 1) {
      return normalized.first.toIso8601String();
    }
    return jsonEncode(
      normalized.map((date) => date.toIso8601String()).toList(growable: false),
    );
  }

  static List<DateTime> _decodeCustomDates(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];

    final trimmed = raw.trim();

    if (trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          final parsed = decoded
              .whereType<String>()
              .map(DateTime.tryParse)
              .whereType<DateTime>()
              .toList(growable: false);
          return _normalizeCustomDates(parsed);
        }
      } catch (_) {
        return const [];
      }
    }

    final single = DateTime.tryParse(trimmed);
    if (single == null) return const [];
    return _normalizeCustomDates([single]);
  }

  static List<DateTime> _normalizeCustomDates(Iterable<DateTime> values) {
    final unique = <int, DateTime>{};
    for (final value in values) {
      final normalized = value.isUtc ? value.toLocal() : value;
      unique[normalized.millisecondsSinceEpoch] = normalized;
    }

    final normalized = unique.values.toList(growable: false)
      ..sort((a, b) => a.compareTo(b));

    return List<DateTime>.unmodifiable(normalized);
  }

  static String _normalizeNotificationSound(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return notificationSoundDefault;
    if (supportedNotificationSounds.contains(raw)) return raw;
    return notificationSoundDefault;
  }
}
