import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Export configuration for different formats
class ExportConfig {
  final ExportFormat format;
  final bool includeCharts;
  final bool includeRawData;
  final List<String> selectedFields;
  final Map<String, dynamic> customOptions;

  const ExportConfig({
    required this.format,
    this.includeCharts = true,
    this.includeRawData = false,
    this.selectedFields = const [],
    this.customOptions = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'format': format.name,
      'includeCharts': includeCharts,
      'includeRawData': includeRawData,
      'selectedFields': selectedFields,
      'customOptions': customOptions,
    };
  }

  factory ExportConfig.fromMap(Map<String, dynamic> map) {
    return ExportConfig(
      format: ExportFormat.values.firstWhere(
            (f) => f.name == map['format'],
        orElse: () => ExportFormat.csv,
      ),
      includeCharts: map['includeCharts'] ?? true,
      includeRawData: map['includeRawData'] ?? false,
      selectedFields: List<String>.from(map['selectedFields'] ?? []),
      customOptions: Map<String, dynamic>.from(map['customOptions'] ?? {}),
    );
  }

  String toJson() => json.encode(toMap());

  factory ExportConfig.fromJson(String source) =>
      ExportConfig.fromMap(json.decode(source));

  /// Copy with method for immutable updates
  ExportConfig copyWith({
    ExportFormat? format,
    bool? includeCharts,
    bool? includeRawData,
    List<String>? selectedFields,
    Map<String, dynamic>? customOptions,
  }) {
    return ExportConfig(
      format: format ?? this.format,
      includeCharts: includeCharts ?? this.includeCharts,
      includeRawData: includeRawData ?? this.includeRawData,
      selectedFields: selectedFields ?? this.selectedFields,
      customOptions: customOptions ?? this.customOptions,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ExportConfig &&
        other.format == format &&
        other.includeCharts == includeCharts &&
        other.includeRawData == includeRawData &&
        listEquals(other.selectedFields, selectedFields) &&
        mapEquals(other.customOptions, customOptions);
  }

  @override
  int get hashCode {
    return format.hashCode ^
    includeCharts.hashCode ^
    includeRawData.hashCode ^
    selectedFields.hashCode ^
    customOptions.hashCode;
  }

  @override
  String toString() {
    return 'ExportConfig(format: $format, includeCharts: $includeCharts, includeRawData: $includeRawData, selectedFields: $selectedFields, customOptions: $customOptions)';
  }
}

/// Supported export formats
enum ExportFormat {
  csv,
  excel,
  pdf,
  json,
  html,
}

/// Export result with file details
class ExportResult {
  final bool success;
  final String? filePath;
  final String? fileName;
  final int fileSize;
  final String? error;
  final ExportFormat format;
  final DateTime exportedAt;

  ExportResult({
    required this.success,
    this.filePath,
    this.fileName,
    this.fileSize = 0,
    this.error,
    required this.format,
    required this.exportedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'filePath': filePath,
      'fileName': fileName,
      'fileSize': fileSize,
      'error': error,
      'format': format.name,
      'exportedAt': exportedAt.toIso8601String(),
    };
  }

  factory ExportResult.fromMap(Map<String, dynamic> map) {
    return ExportResult(
      success: map['success'] ?? false,
      filePath: map['filePath'],
      fileName: map['fileName'],
      fileSize: map['fileSize']?.toInt() ?? 0,
      error: map['error'],
      format: ExportFormat.values.firstWhere(
            (f) => f.name == map['format'],
        orElse: () => ExportFormat.csv,
      ),
      exportedAt: DateTime.parse(map['exportedAt']),
    );
  }

  String toJson() => json.encode(toMap());

  factory ExportResult.fromJson(String source) =>
      ExportResult.fromMap(json.decode(source));

  @override
  String toString() {
    return 'ExportResult(success: $success, filePath: $filePath, fileName: $fileName, fileSize: $fileSize, error: $error, format: $format, exportedAt: $exportedAt)';
  }
}
