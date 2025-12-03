import 'dart:async';
import 'dart:isolate';

import 'logger.dart';

/// Message type for isolate communication
class IsolateMessage {
  final String id;
  final String action;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  IsolateMessage({
    required this.id,
    required this.action,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'action': action,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory IsolateMessage.fromMap(Map<String, dynamic> map) {
    return IsolateMessage(
      id: map['id'],
      action: map['action'],
      data: Map<String, dynamic>.from(map['data']),
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}

/// Response from isolate
class IsolateResponse {
  final String messageId;
  final bool success;
  final Map<String, dynamic> data;
  final String? error;
  final Duration processingTime;

  IsolateResponse({
    required this.messageId,
    required this.success,
    required this.data,
    this.error,
    required this.processingTime,
  });
}

/// Handler for managing persistent isolates
class IsolateHandler {
  final Logger _logger = Logger('IsolateHandler');
  final String _isolateName;

  Isolate? _isolate;
  ReceivePort? _receivePort;
  SendPort? _sendPort;
  final _responseCompleters = <String, Completer<Map<String, dynamic>>>{};
  final _messageQueue = <IsolateMessage>[];
  bool _isInitialized = false;
  bool _isProcessing = false;
  final _lock = Lock();
  Timer? _healthCheckTimer;

  /// Create an isolate handler with a specific name
  IsolateHandler({String? isolateName})
      : _isolateName = isolateName ?? 'default_isolate';

  /// Initialize the isolate
  Future<void> initialize(void Function(SendPort) isolateEntryPoint) async {
    if (_isInitialized) {
      _logger.debug('Isolate already initialized');
      return;
    }

    try {
      _logger.info('Initializing isolate: $_isolateName');

      // Create receive port for communication
      _receivePort = ReceivePort();

      // Spawn the isolate
      _isolate = await Isolate.spawn(
        isolateEntryPoint,                 // Must be: void Function(SendPort)
        _receivePort!.sendPort,            // Passed into entry point
        debugName: _isolateName,
        onError: _receivePort!.sendPort,
        onExit: _receivePort!.sendPort,
      );

      // Listen for messages from isolate
      _receivePort!.listen(_handleIsolateMessage);

      _isInitialized = true;
      _logger.info('Isolate initialized successfully');

      // Start health check
      _startHealthCheck();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to initialize isolate',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Send a message to the isolate
  Future<Map<String, dynamic>> sendMessage(Map<String, dynamic> data) async {
    if (!_isInitialized || _sendPort == null) {
      _logger.warning('Isolate not initialized, cannot send message');
      throw Exception('Isolate not initialized');
    }

    final messageId = '${DateTime.now().millisecondsSinceEpoch}_${_messageQueue.length}';
    final completer = Completer<Map<String, dynamic>>();

    await _lock.synchronized(() {
      _responseCompleters[messageId] = completer;
      return Future.value();
    });


    final message = IsolateMessage(
      id: messageId,
      action: data['action']?.toString() ?? 'process',
      data: data,
    );

    // Queue the message
    _messageQueue.add(message);

    // Process queue if not already processing
    if (!_isProcessing) {
      _processQueue();
    }

    _logger.debug('Message queued for isolate', extra: {
      'messageId': messageId,
      'action': message.action,
      'queueLength': _messageQueue.length,
    });

    // Set timeout for response
    return completer.future.timeout(
      Duration(seconds: 30),
      onTimeout: () {
        _logger.error('Isolate response timeout', extra: {'messageId': messageId});
        _responseCompleters.remove(messageId);
        return {'success': false, 'error': 'Timeout', 'messageId': messageId};
      },
    );
  }

  /// Process the message queue
  void _processQueue() async {
    if (_isProcessing || _messageQueue.isEmpty || _sendPort == null) return;

    _isProcessing = true;

    while (_messageQueue.isNotEmpty) {
      final message = _messageQueue.removeAt(0);
      final stopwatch = Stopwatch()..start();

      try {
        _logger.debug('Sending message to isolate', extra: {
          'messageId': message.id,
          'action': message.action,
        });

        _sendPort!.send(message.toMap());

        // Wait for response with timeout
        final response = await _responseCompleters[message.id]!.future
            .timeout(Duration(seconds: 25));

        stopwatch.stop();
        _logger.debug('Isolate response received', extra: {
          'messageId': message.id,
          'processingTimeMs': stopwatch.elapsedMilliseconds,
          'success': response['success'],
        });
      } catch (e) {
        stopwatch.stop();
        _logger.error(
          'Failed to process message',
          error: e,
          extra: {'messageId': message.id},
        );

        final completer = _responseCompleters[message.id];
        if (completer != null && !completer.isCompleted) {
          completer.complete({
            'success': false,
            'error': 'Failed to process: $e',
            'messageId': message.id,
            'processingTimeMs': stopwatch.elapsedMilliseconds,
          });
        }
      }
    }

    _isProcessing = false;
  }

  /// Handle incoming messages from isolate
  void _handleIsolateMessage(dynamic message) {
    try {
      if (message is SendPort) {
        // First message is the send port from isolate
        _sendPort = message;
        _logger.debug('Received send port from isolate');
        return;
      }

      if (message is Map<String, dynamic>) {
        final messageId = message['messageId']?.toString();
        final responseData = message['response'] as Map<String, dynamic>? ?? message;

        if (messageId != null) {
          final completer = _responseCompleters[messageId];
          if (completer != null && !completer.isCompleted) {
            completer.complete(responseData);
            _responseCompleters.remove(messageId);
          }
        } else if (message.containsKey('log')) {
          // Handle log messages from isolate
          _handleIsolateLog(message);
        }
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Error handling isolate message',
        error: e,
        stackTrace: stackTrace,
        extra: {'message': message.toString()},
      );
    }
  }

  /// Handle log messages from isolate
  void _handleIsolateLog(Map<String, dynamic> logMessage) {
    final level = logMessage['level']?.toString() ?? 'info';
    final message = logMessage['message']?.toString() ?? '';
    final extra = logMessage['extra'] as Map<String, dynamic>?;

    switch (level) {
      case 'debug':
        _logger.debug('Isolate: $message', extra: extra);
        break;
      case 'info':
        _logger.info('Isolate: $message', extra: extra);
        break;
      case 'warning':
        _logger.warning('Isolate: $message', extra: extra);
        break;
      case 'error':
        _logger.error('Isolate: $message', extra: extra);
        break;
      default:
        _logger.info('Isolate: $message', extra: extra);
    }
  }

  /// Start health check timer
  void _startHealthCheck() {
    _healthCheckTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      if (!_isInitialized) return;

      try {
        final healthCheck = await sendMessage({
          'action': 'health_check',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }).timeout(Duration(seconds: 5));

        if (healthCheck['success'] == true) {
          _logger.debug('Isolate health check passed');
        } else {
          _logger.warning('Isolate health check failed', extra: healthCheck);
        }
      } catch (e) {
        _logger.warning('Isolate health check timeout/error', error: e);
        _restartIsolate();
      }
    });
  }

  /// Restart the isolate
  Future<void> _restartIsolate() async {
    _logger.warning('Restarting isolate');
    await dispose();
    // Note: You'll need to reinitialize with the entry point
    _logger.info('Isolate restart complete - needs reinitialization');
  }

  /// Check if isolate is healthy
  Future<bool> isHealthy() async {
    if (!_isInitialized) return false;

    try {
      final response = await sendMessage({
        'action': 'ping',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }).timeout(Duration(seconds: 5));

      return response['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Get isolate statistics
  Map<String, dynamic> getStats() {
    return {
      'name': _isolateName,
      'isInitialized': _isInitialized,
      'isProcessing': _isProcessing,
      'queueLength': _messageQueue.length,
      'pendingResponses': _responseCompleters.length,
      'hasSendPort': _sendPort != null,
    };
  }

  /// Dispose resources
  Future<void> dispose() async {
    _logger.info('Disposing isolate handler');

    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;

    // Complete all pending completers
    for (final completer in _responseCompleters.values) {
      if (!completer.isCompleted) {
        completer.complete({
          'success': false,
          'error': 'Isolate disposed',
          'disposedAt': DateTime.now().toIso8601String(),
        });
      }
    }
    _responseCompleters.clear();
    _messageQueue.clear();

    // Kill the isolate
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;

    // Close the receive port
    _receivePort?.close();
    _receivePort = null;

    _sendPort = null;
    _isInitialized = false;
    _isProcessing = false;

    _logger.info('Isolate handler disposed');
  }
}

/// Simple lock for synchronization
class Lock {
  Completer<void>? _lock;

  Future<void> synchronized(Future<void> Function() callback) async {
    while (_lock != null) {
      await _lock!.future;
    }

    _lock = Completer<void>();
    try {
      await callback();
    } finally {
      _lock!.complete();
      _lock = null;
    }
  }
}