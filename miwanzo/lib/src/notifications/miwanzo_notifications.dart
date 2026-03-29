import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/important_date.dart';

class MiwanzoNotifications {
  MiwanzoNotifications._();

  static final MiwanzoNotifications instance = MiwanzoNotifications._();

  static const String _defaultChannelId = 'miwanzo_important_dates_default';
  static const String _defaultChannelName = 'Datas importantes';
  static const String _customSoundChannelId =
      'miwanzo_important_dates_miwanzo_tone';
  static const String _customSoundChannelName =
      'Datas importantes (som Miwanzo)';
  static const String _channelDescription =
      'Lembretes locais para datas importantes do Miwanzo.';
  static const String _customSoundResourceName =
      ImportantDate.notificationSoundMiwanzo;
  static const int _customRuleStartCode = 6;
  static const int _idBlockSize = 10000;
  static const int _maxCustomRules = _idBlockSize - _customRuleStartCode;
  static final Int64List _defaultVibrationPattern = Int64List.fromList([
    0,
    260,
    120,
    260,
  ]);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  AndroidScheduleMode _scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;

  bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }

  Future<void> initialize() async {
    if (_initialized || !_isSupportedPlatform) return;

    tz_data.initializeTimeZones();

    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.requestNotificationsPermission();
    try {
      final supportsExact =
          await androidPlugin?.canScheduleExactNotifications() ?? false;
      if (supportsExact) {
        _scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
      } else {
        final exactPermissionGranted =
            await androidPlugin?.requestExactAlarmsPermission() ?? false;
        _scheduleMode = exactPermissionGranted
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle;
      }
    } catch (_) {
      _scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
    }

    _initialized = true;
  }

  Future<void> syncImportantDateNotifications(List<ImportantDate> dates) async {
    if (!_isSupportedPlatform) return;

    await initialize();
    await _plugin.cancelAll();

    for (final date in dates) {
      await scheduleForImportantDate(date);
    }
  }

  Future<void> scheduleForImportantDate(ImportantDate date) async {
    if (!_isSupportedPlatform) return;

    await initialize();
    await cancelForImportantDate(date.id);

    final rules = _buildRules(date);
    final details = _detailsForDate(date);

    for (final rule in rules) {
      final nextTrigger = _computeNextTrigger(date, rule);
      if (nextTrigger == null) continue;

      await _scheduleWithFallback(
        notificationId: _notificationId(date.id, rule.code),
        title: rule.title,
        body: rule.body,
        trigger: nextTrigger,
        details: details,
        payload: 'important_date:${date.id}',
      );
    }
  }

  Future<void> cancelForImportantDate(int importantDateId) async {
    if (!_isSupportedPlatform) return;

    await initialize();

    final payloadPrefix = 'important_date:$importantDateId';
    final requests = await _plugin.pendingNotificationRequests();

    for (final request in requests) {
      final payload = request.payload;
      if (payload == payloadPrefix ||
          payload?.startsWith('$payloadPrefix:') == true) {
        await _plugin.cancel(request.id);
      }
    }
  }

  List<_RuleNotification> _buildRules(ImportantDate date) {
    final title = date.title;
    final body = date.description.trim().isEmpty
        ? 'Lembrete importante de $title.'
        : date.description.trim();

    final rules = <_RuleNotification>[];

    if (date.notify3Months) {
      rules.add(
        _RuleNotification(
          code: 1,
          offset: _RelativeOffset.months(3),
          title: '$title em 3 meses',
          body: body,
        ),
      );
    }

    if (date.notify1Month) {
      rules.add(
        _RuleNotification(
          code: 2,
          offset: _RelativeOffset.months(1),
          title: '$title em 1 mês',
          body: body,
        ),
      );
    }

    if (date.notify1Week) {
      rules.add(
        _RuleNotification(
          code: 3,
          offset: _RelativeOffset.days(7),
          title: '$title em 1 semana',
          body: body,
        ),
      );
    }

    if (date.notify1Day) {
      rules.add(
        _RuleNotification(
          code: 4,
          offset: _RelativeOffset.days(1),
          title: '$title amanhã',
          body: body,
        ),
      );
    }

    if (date.notifyOnDay) {
      rules.add(
        _RuleNotification(
          code: 5,
          offset: _RelativeOffset.days(0),
          title: '$title é hoje',
          body: body,
        ),
      );
    }

    for (
      var index = 0;
      index < date.notifyCustomDates.length && index < _maxCustomRules;
      index++
    ) {
      final customAt = date.notifyCustomDates[index];
      rules.add(
        _RuleNotification(
          code: _customRuleStartCode + index,
          absoluteAt: customAt.isUtc ? customAt.toLocal() : customAt,
          title: 'Lembrete personalizado: $title',
          body: body,
        ),
      );
    }

    return rules;
  }

  tz.TZDateTime? _computeNextTrigger(
    ImportantDate date,
    _RuleNotification rule,
  ) {
    final now = tz.TZDateTime.now(tz.local);

    if (rule.absoluteAt case final absoluteAt?) {
      final trigger = tz.TZDateTime.from(absoluteAt, tz.local);
      if (trigger.isAfter(now.add(const Duration(minutes: 1)))) {
        return trigger;
      }
      return null;
    }

    final offset = rule.offset;
    if (offset == null) return null;

    final baseDate = date.date;
    final hour = date.notificationHour;
    final minute = date.notificationMinute;

    if (!date.repeatsAnnually) {
      final oneTimeOccurrence = _safeDate(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        hour,
        minute,
      );
      final trigger = _applyOffset(oneTimeOccurrence, offset);
      if (trigger.isAfter(now.add(const Duration(minutes: 1)))) {
        return trigger;
      }
      return null;
    }

    final eventMonth = baseDate.month;
    final eventDay = baseDate.day;

    for (var yearDelta = 0; yearDelta <= 3; yearDelta++) {
      final year = now.year + yearDelta;
      final occurrence = _safeDate(year, eventMonth, eventDay, hour, minute);
      final trigger = _applyOffset(occurrence, offset);

      if (trigger.isAfter(now.add(const Duration(minutes: 1)))) {
        return trigger;
      }
    }

    return null;
  }

  tz.TZDateTime _applyOffset(tz.TZDateTime occurrence, _RelativeOffset offset) {
    if (offset.months > 0) {
      return _subtractMonths(occurrence, offset.months);
    }

    return occurrence.subtract(Duration(days: offset.days));
  }

  tz.TZDateTime _subtractMonths(tz.TZDateTime date, int months) {
    final totalMonths = (date.year * 12 + (date.month - 1)) - months;
    final targetYear = totalMonths ~/ 12;
    final targetMonth = totalMonths % 12 + 1;
    final maxDay = DateTime(targetYear, targetMonth + 1, 0).day;
    final targetDay = date.day > maxDay ? maxDay : date.day;

    return tz.TZDateTime(
      tz.local,
      targetYear,
      targetMonth,
      targetDay,
      date.hour,
      date.minute,
    );
  }

  tz.TZDateTime _safeDate(int year, int month, int day, int hour, int minute) {
    final maxDay = DateTime(year, month + 1, 0).day;
    final safeDay = day > maxDay ? maxDay : day;

    return tz.TZDateTime(tz.local, year, month, safeDay, hour, minute);
  }

  int _notificationId(int importantDateId, int code) {
    return importantDateId * _idBlockSize + code;
  }

  NotificationDetails _detailsForDate(ImportantDate date) {
    final usesCustomSound =
        date.notificationSound == ImportantDate.notificationSoundMiwanzo;

    return NotificationDetails(
      android: AndroidNotificationDetails(
        usesCustomSound ? _customSoundChannelId : _defaultChannelId,
        usesCustomSound ? _customSoundChannelName : _defaultChannelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: usesCustomSound
            ? const RawResourceAndroidNotificationSound(
                _customSoundResourceName,
              )
            : null,
        enableVibration: true,
        vibrationPattern: _defaultVibrationPattern,
      ),
    );
  }

  Future<void> _scheduleWithFallback({
    required int notificationId,
    required String title,
    required String body,
    required tz.TZDateTime trigger,
    required NotificationDetails details,
    required String payload,
  }) async {
    try {
      await _plugin.zonedSchedule(
        notificationId,
        title,
        body,
        trigger,
        details,
        androidScheduleMode: _scheduleMode,
        payload: payload,
      );
      return;
    } catch (_) {
      if (_scheduleMode != AndroidScheduleMode.exactAllowWhileIdle) {
        rethrow;
      }
    }

    await _plugin.zonedSchedule(
      notificationId,
      title,
      body,
      trigger,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }
}

class _RuleNotification {
  const _RuleNotification({
    required this.code,
    this.offset,
    this.absoluteAt,
    required this.title,
    required this.body,
  });

  final int code;
  final _RelativeOffset? offset;
  final DateTime? absoluteAt;
  final String title;
  final String body;
}

class _RelativeOffset {
  const _RelativeOffset._({required this.months, required this.days});

  final int months;
  final int days;

  factory _RelativeOffset.months(int months) =>
      _RelativeOffset._(months: months, days: 0);

  factory _RelativeOffset.days(int days) =>
      _RelativeOffset._(months: 0, days: days);
}
