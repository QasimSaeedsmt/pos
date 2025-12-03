import 'dart:developer' as developer;
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Log levels for structured logging
enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

/// Structured logger for the application
class Logger {
  final String name;
  final bool isDebugMode;
  final Map<String, String> _context = {};

  /// Create a logger with a specific name
  Logger(
      this.name, {
        this.isDebugMode = kDebugMode,
      });

  /// Log a debug message
  void debug(String message, {dynamic error, Map<String, dynamic>? extra}) {
    _log(LogLevel.debug, message, error: error, extra: extra);
  }

  /// Log an info message
  void info(String message, {dynamic error, Map<String, dynamic>? extra}) {
    _log(LogLevel.info, message, error: error, extra: extra);
  }

  /// Log a warning message
  void warning(String message, {dynamic error, Map<String, dynamic>? extra}) {
    _log(LogLevel.warning, message, error: error, extra: extra);
  }

  /// Log an error message
  void error(String message, {dynamic error, StackTrace? stackTrace, Map<String, dynamic>? extra}) {
    _log(LogLevel.error, message, error: error, stackTrace: stackTrace, extra: extra);
  }

  /// Log a critical error message
  void critical(String message, {dynamic error, StackTrace? stackTrace, Map<String, dynamic>? extra}) {
    _log(LogLevel.critical, message, error: error, stackTrace: stackTrace, extra: extra);
  }

  /// Set contextual information for all subsequent logs
  void setContext(String key, String value) {
    _context[key] = value;
  }

  /// Clear contextual information
  void clearContext() {
    _context.clear();
  }

  /// Internal logging method
  void _log(
      LogLevel level,
      String message, {
        dynamic error,
        StackTrace? stackTrace,
        Map<String, dynamic>? extra,
      }) {
    if (!isDebugMode && level.index < LogLevel.warning.index) {
      return; // Skip debug/info logs in release mode
    }

    final fullMessage = _formatMessage(level, message, error, stackTrace, extra);

    switch (level) {
      case LogLevel.debug:
        developer.log(fullMessage, name: name, level: 0);
        break;
      case LogLevel.info:
        developer.log(fullMessage, name: name, level: 1);
        break;
      case LogLevel.warning:
        developer.log(fullMessage, name: name, level: 2);
        break;
      case LogLevel.error:
        developer.log(fullMessage, name: name, level: 3, error: error, stackTrace: stackTrace);
        break;
      case LogLevel.critical:
        developer.log(fullMessage, name: name, level: 4, error: error, stackTrace: stackTrace);
        break;
    }

    // In production, you might want to send error/critical logs to a monitoring service
    if (level.index >= LogLevel.error.index) {
      _sendToMonitoringService(level, message, error, stackTrace, extra);
    }
  }

  /// Format log message with metadata
  String _formatMessage(
      LogLevel level,
      String message,
      dynamic error,
      StackTrace? stackTrace,
      Map<String, dynamic>? extra,
      ) {
    final buffer = StringBuffer();
    buffer.write('[$name] ${level.name.toUpperCase()}: $message');

    // Add context
    if (_context.isNotEmpty) {
      buffer.write(' | Context: ${_context.entries.map((e) => '${e.key}=${e.value}').join(', ')}');
    }

    // Add extra data
    if (extra != null && extra.isNotEmpty) {
      buffer.write(' | Extra: ${_formatExtra(extra)}');
    }

    // Add error if present
    if (error != null) {
      buffer.write(' | Error: $error');
    }

    return buffer.toString();
  }

  /// Format extra data for logging
  String _formatExtra(Map<String, dynamic> extra) {
    try {
      return extra.entries.map((e) {
        final value = e.value;
        if (value is Map || value is List) {
          return '${e.key}=${value.toString().substring(0, min(100, value.toString().length))}';
        }
        return '${e.key}=$value';
      }).join(', ');
    } catch (e) {
      return 'Unable to format extra data';
    }
  }

  /// Send critical errors to monitoring service (e.g., Sentry, Firebase Crashlytics)
  void _sendToMonitoringService(
      LogLevel level,
      String message,
      dynamic error,
      StackTrace? stackTrace,
      Map<String, dynamic>? extra,
      ) {
    // Implementation depends on your monitoring service
    // Example for Firebase Crashlytics:
    // if (level == LogLevel.critical) {
    //   FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: message);
    // }

    // Example for Sentry:
    // Sentry.captureException(
    //   error,
    //   stackTrace: stackTrace,
    //   hint: message,
    // );
  }

  /// Log performance metrics
  void logPerformance(String operation, Duration duration, {Map<String, dynamic>? metadata}) {
    if (duration.inMilliseconds > 100) { // Log only slow operations
      warning(
        'Performance warning: $operation took ${duration.inMilliseconds}ms',
        extra: metadata,
      );
    } else {
      debug(
        'Performance: $operation took ${duration.inMilliseconds}ms',
        extra: metadata,
      );
    }
  }

  /// Log network request
  void logNetwork(String method, String url, int statusCode, Duration duration, {int? responseSize}) {
    final extra = {
      'method': method,
      'url': url,
      'statusCode': statusCode,
      'durationMs': duration.inMilliseconds,
      if (responseSize != null) 'responseSizeBytes': responseSize,
    };

    if (statusCode >= 400) {
      warning('Network request failed', extra: extra);
    } else {
      debug('Network request completed', extra: extra);
    }
  }

  /// Log database operation
  void logDatabase(String operation, Duration duration, {int? rowsAffected, String? table}) {
    final extra = {
      'operation': operation,
      'durationMs': duration.inMilliseconds,
      if (rowsAffected != null) 'rowsAffected': rowsAffected,
      if (table != null) 'table': table,
    };

    debug('Database operation completed', extra: extra);
  }
}

/// Global logger instance for quick access
Logger get log => Logger('Global');