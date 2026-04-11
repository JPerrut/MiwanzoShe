import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/logging/app_logger.dart';

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();

      final logger = AppLogger.instance;

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        logger.error(
          'FlutterError',
          details.exceptionAsString(),
          error: details.exception,
          stackTrace: details.stack,
        );
      };

      PlatformDispatcher.instance.onError = (error, stackTrace) {
        logger.error(
          'PlatformDispatcher',
          'Unhandled platform error.',
          error: error,
          stackTrace: stackTrace,
        );
        return false;
      };

      runApp(const ShauMsiApp());
    },
    (error, stackTrace) {
      AppLogger.instance.error(
        'runZonedGuarded',
        'Unhandled app exception.',
        error: error,
        stackTrace: stackTrace,
      );
    },
  );
}
