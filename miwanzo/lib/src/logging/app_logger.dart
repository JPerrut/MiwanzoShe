import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

enum AppLogLevel { info, warning, error }

class AppLogEntry {
  const AppLogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
    this.error,
    this.stackTrace,
  });

  final DateTime timestamp;
  final AppLogLevel level;
  final String source;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  String toLine() {
    final levelText = switch (level) {
      AppLogLevel.info => 'INFO',
      AppLogLevel.warning => 'WARN',
      AppLogLevel.error => 'ERROR',
    };

    final base =
        '[${timestamp.toIso8601String()}] [$levelText] [$source] $message';

    if (error == null && stackTrace == null) {
      return base;
    }

    final errorText = error == null ? '' : '\nerror: $error';
    final stackText = stackTrace == null ? '' : '\nstack: $stackTrace';
    return '$base$errorText$stackText';
  }
}

class AppLogger extends ChangeNotifier {
  AppLogger._();

  static final AppLogger instance = AppLogger._();

  static const int _maxEntries = 500;
  final List<AppLogEntry> _entries = [];
  bool _notifyScheduled = false;

  UnmodifiableListView<AppLogEntry> get entries =>
      UnmodifiableListView(_entries.reversed.toList(growable: false));

  void info(String source, String message) {
    _add(
      AppLogEntry(
        timestamp: DateTime.now(),
        level: AppLogLevel.info,
        source: source,
        message: message,
      ),
    );
  }

  void warning(String source, String message, {Object? error}) {
    _add(
      AppLogEntry(
        timestamp: DateTime.now(),
        level: AppLogLevel.warning,
        source: source,
        message: message,
        error: error,
      ),
    );
  }

  void error(
    String source,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    _add(
      AppLogEntry(
        timestamp: DateTime.now(),
        level: AppLogLevel.error,
        source: source,
        message: message,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  void clear() {
    _entries.clear();
    _notifySafely();
  }

  String exportAll() {
    if (_entries.isEmpty) {
      return 'Sem logs registrados.';
    }

    return _entries.map((entry) => entry.toLine()).join('\n\n');
  }

  void _add(AppLogEntry entry) {
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
    debugPrint(entry.toLine());
    _notifySafely();
  }

  void _notifySafely() {
    if (_notifyScheduled) {
      return;
    }

    final scheduler = SchedulerBinding.instance;
    final phase = scheduler.schedulerPhase;

    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
      return;
    }

    _notifyScheduled = true;
    scheduler.addPostFrameCallback((_) {
      _notifyScheduled = false;
      notifyListeners();
    });
  }
}
