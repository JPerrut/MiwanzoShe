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

  static const String _channelId = 'miwanzo_important_dates';
  static const String _channelName = 'Datas importantes';
  static const String _channelDescription =
      'Lembretes locais para datas importantes do Miwanzo.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

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

    for (final rule in rules) {
      final nextTrigger = _computeNextTrigger(date.date, rule.offset);
      if (nextTrigger == null) continue;

      await _plugin.zonedSchedule(
        _notificationId(date.id, rule.code),
        rule.title,
        rule.body,
        nextTrigger,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'important_date:${date.id}',
      );
    }
  }

  Future<void> cancelForImportantDate(int importantDateId) async {
    if (!_isSupportedPlatform) return;

    await initialize();

    for (final code in _ruleCodes) {
      await _plugin.cancel(_notificationId(importantDateId, code));
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

    if (date.notifyCustomDays case final customDays?) {
      rules.add(
        _RuleNotification(
          code: 6,
          offset: _RelativeOffset.days(customDays),
          title: '$title em $customDays dias',
          body: body,
        ),
      );
    }

    return rules;
  }

  tz.TZDateTime? _computeNextTrigger(
    DateTime baseDate,
    _RelativeOffset offset,
  ) {
    final now = tz.TZDateTime.now(tz.local);
    final eventMonth = baseDate.month;
    final eventDay = baseDate.day;

    for (var yearDelta = 0; yearDelta <= 3; yearDelta++) {
      final year = now.year + yearDelta;
      final occurrence = _safeDate(year, eventMonth, eventDay);
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

    return tz.TZDateTime(tz.local, targetYear, targetMonth, targetDay, 9);
  }

  tz.TZDateTime _safeDate(int year, int month, int day) {
    final maxDay = DateTime(year, month + 1, 0).day;
    final safeDay = day > maxDay ? maxDay : day;

    return tz.TZDateTime(tz.local, year, month, safeDay, 9);
  }

  int _notificationId(int importantDateId, int code) {
    return importantDateId * 100 + code;
  }

  List<int> get _ruleCodes => const [1, 2, 3, 4, 5, 6];
}

class _RuleNotification {
  const _RuleNotification({
    required this.code,
    required this.offset,
    required this.title,
    required this.body,
  });

  final int code;
  final _RelativeOffset offset;
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
