// Add to your existing models or create a new file: smart_scan_models.dart

// Smart Scanning Data Models
enum ScanType {
  invoice,
  product,
  order,
  customer,
  generic,
}

class ScanContext {
  final ScanType type;
  final double confidence;
  final List<String> suggestedActions;
  final Map<String, dynamic> metadata;

  const ScanContext({
    required this.type,
    required this.confidence,
    required this.suggestedActions,
    required this.metadata,
  });
}

class ScanResult {
  final String data;
  final String type;
  final DateTime timestamp;
  final ScanContext? context;

  ScanResult({
    required this.data,
    required this.type,
    required this.timestamp,
    this.context,
  });

  Map<String, dynamic> toMap() {
    return {
      'data': data,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'context': context != null ? {
        'type': context!.type.toString(),
        'confidence': context!.confidence,
        'suggestedActions': context!.suggestedActions,
        'metadata': context!.metadata,
      } : null,
    };
  }
}