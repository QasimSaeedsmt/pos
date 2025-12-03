import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/logger.dart';
import '../models/analytics_models.dart';
import '../models/report_models.dart';
import '../models/export_models.dart';

/// Service for exporting analytics data in various formats
class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  final Logger _logger = Logger('ExportService');
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$');
  final NumberFormat _numberFormat = NumberFormat.decimalPattern();

  /// Export report to specified format
  Future<ExportResult> exportReport({
    required BaseReport report,
    required ExportConfig config,
    String? customFileName,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      _logger.info(
        'Exporting report: ${report.name}',
        extra: {'format': config.format.name},
      );

      late ExportResult result;

      switch (config.format) {
        case ExportFormat.csv:
          result = await _exportToCsv(report, config, customFileName);
          break;
        case ExportFormat.excel:
          result = await _exportToExcel(report, config, customFileName);
          break;
        case ExportFormat.pdf:
          result = await _exportToPdf(report, config, customFileName);
          break;
        case ExportFormat.json:
          result = await _exportToJson(report, config, customFileName);
          break;
        case ExportFormat.html:
          result = await _exportToHtml(report, config, customFileName);
          break;
      }

      _logger.info(
        'Export completed in ${stopwatch.elapsedMilliseconds}ms',
        extra: {
          'format': config.format.name,
          'fileSize': result.fileSize,
          'success': result.success,
        },
      );

      return result;
    } catch (e, stackTrace) {
      _logger.error(
        'Export failed',
        error: e,
        stackTrace: stackTrace,
        extra: {'report': report.name, 'format': config.format.name},
      );

      return ExportResult(
        success: false,
        error: e.toString(),
        format: config.format,
        exportedAt: DateTime.now(),
      );
    }
  }

  /// Export to CSV format
  Future<ExportResult> _exportToCsv(
      BaseReport report,
      ExportConfig config,
      String? customFileName,
      ) async {
    try {
      String csvContent = '';

      if (report is SalesReport) {
        csvContent = _generateSalesReportCsv(report, config);
      } else if (report is InventoryReport) {
        csvContent = _generateInventoryReportCsv(report, config);
      } else {
        // Generic CSV export
        csvContent = _generateGenericCsv(report, config);
      }

      // Create file
      final fileName = customFileName ??
          '${report.name.replaceAll(' ', '_')}_${_getTimestamp()}.csv';
      final filePath = await _saveToFile(fileName, csvContent);

      return ExportResult(
        success: true,
        filePath: filePath,
        fileName: fileName,
        fileSize: csvContent.length,
        format: ExportFormat.csv,
        exportedAt: DateTime.now(),
      );
    } catch (e) {
      return ExportResult(
        success: false,
        error: 'CSV export failed: $e',
        format: ExportFormat.csv,
        exportedAt: DateTime.now(),
      );
    }
  }

  /// Generate CSV for sales report
  String _generateSalesReportCsv(SalesReport report, ExportConfig config) {
    final buffer = StringBuffer();

    // Add header
    buffer.writeln('Sales Report - ${report.name}');
    buffer.writeln('Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(report.generatedAt)}');
    buffer.writeln('Period: ${_formatDateRange(report.query)}');
    buffer.writeln();

    // Summary section
    buffer.writeln('SUMMARY');
    buffer.writeln('Metric,Value');
    buffer.writeln('Total Sales,${_currencyFormat.format(report.totalSales)}');
    buffer.writeln('Number of Transactions,${report.numberOfTransactions}');
    buffer.writeln('Average Sale Value,${_currencyFormat.format(report.averageSaleValue)}');
    buffer.writeln();

    // Sales by category
    if (report.salesByCategory.isNotEmpty && config.includeCharts) {
      buffer.writeln('SALES BY CATEGORY');
      buffer.writeln('Category,Total Sales,Items Sold,Percentage');
      for (final category in report.salesByCategory) {
        buffer.writeln(
          '${category.categoryName},'
              '${_currencyFormat.format(category.totalSales)},'
              '${category.itemsSold},'
              '${category.percentageOfTotal.toStringAsFixed(2)}%',
        );
      }
      buffer.writeln();
    }

    // Top products
    if (report.topProducts.isNotEmpty) {
      buffer.writeln('TOP SELLING PRODUCTS');
      buffer.writeln('Product,SKU,Quantity Sold,Total Revenue,Profit Margin');
      for (final product in report.topProducts) {
        buffer.writeln(
          '${product.productName},'
              '${product.productSku},'
              '${product.quantitySold},'
              '${_currencyFormat.format(product.totalRevenue)},'
              '${product.profitMargin.toStringAsFixed(2)}%',
        );
      }
      buffer.writeln();
    }

    // Sales trends
    if (report.salesTrends.isNotEmpty) {
      buffer.writeln('SALES TRENDS');
      buffer.writeln('Date,Sales Amount,Transaction Count');
      for (final trend in report.salesTrends) {
        buffer.writeln(
          '${DateFormat('yyyy-MM-dd').format(trend.date)},'
              '${_currencyFormat.format(trend.salesAmount)},'
              '${trend.transactionCount}',
        );
      }
    }

    // Include raw data if requested
    if (config.includeRawData) {
      buffer.writeln();
      buffer.writeln('RAW DATA');
      buffer.writeln(json.encode(report.data));
    }

    return buffer.toString();
  }

  /// Generate CSV for inventory report
  String _generateInventoryReportCsv(InventoryReport report, ExportConfig config) {
    final buffer = StringBuffer();

    // Add header
    buffer.writeln('Inventory Report - ${report.name}');
    buffer.writeln('Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(report.generatedAt)}');
    buffer.writeln();

    // Summary section
    buffer.writeln('SUMMARY');
    buffer.writeln('Metric,Value');
    buffer.writeln('Total Inventory Value,${_currencyFormat.format(report.totalInventoryValue)}');
    buffer.writeln('Low Stock Items,${report.lowStockItems}');
    buffer.writeln('Out of Stock Items,${report.outOfStockItems}');
    buffer.writeln('Inventory Turnover Rate,${report.inventoryTurnoverRate.toStringAsFixed(2)}');
    buffer.writeln();

    // Slow moving items
    if (report.slowMovingItems.isNotEmpty) {
      buffer.writeln('SLOW MOVING ITEMS');
      buffer.writeln('Product,SKU,Current Stock,Min Stock,Max Stock,Days in Stock,Stock Value');
      for (final item in report.slowMovingItems) {
        buffer.writeln(
          '${item.productName},'
              '${item.sku},'
              '${item.currentStock},'
              '${item.minStockLevel},'
              '${item.maxStockLevel},'
              '${item.daysInStock},'
              '${_currencyFormat.format(item.stockValue)}',
        );
      }
      buffer.writeln();
    }

    // Fast moving items
    if (report.fastMovingItems.isNotEmpty) {
      buffer.writeln('FAST MOVING ITEMS');
      buffer.writeln('Product,SKU,Current Stock,Stock Value,Unit Cost,Retail Price');
      for (final item in report.fastMovingItems) {
        buffer.writeln(
          '${item.productName},'
              '${item.sku},'
              '${item.currentStock},'
              '${_currencyFormat.format(item.stockValue)},'
              '${_currencyFormat.format(item.unitCost)},'
              '${_currencyFormat.format(item.retailPrice)}',
        );
      }
    }

    return buffer.toString();
  }

  /// Generate generic CSV
  String _generateGenericCsv(BaseReport report, ExportConfig config) {
    final buffer = StringBuffer();

    buffer.writeln('Report: ${report.name}');
    buffer.writeln('Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(report.generatedAt)}');
    buffer.writeln('Type: ${report.runtimeType}');
    buffer.writeln();

    // Add data fields
    for (final entry in report.data.entries) {
      buffer.writeln('${entry.key},${entry.value}');
    }

    return buffer.toString();
  }

  /// Export to Excel format (simplified - in production use a proper Excel library)
  Future<ExportResult> _exportToExcel(
      BaseReport report,
      ExportConfig config,
      String? customFileName,
      ) async {
    try {
      // For Excel, we can create a CSV with .xlsx extension or use a library
      // This is a simplified implementation using CSV
      final csvContent = await _generateExcelCompatibleCsv(report, config);
      final fileName = customFileName ??
          '${report.name.replaceAll(' ', '_')}_${_getTimestamp()}.xlsx';

      // In production, use a proper Excel generation library like excel: ^2.0.0
      final filePath = await _saveToFile(fileName, csvContent);

      return ExportResult(
        success: true,
        filePath: filePath,
        fileName: fileName,
        fileSize: csvContent.length,
        format: ExportFormat.excel,
        exportedAt: DateTime.now(),
      );
    } catch (e) {
      return ExportResult(
        success: false,
        error: 'Excel export failed: $e',
        format: ExportFormat.excel,
        exportedAt: DateTime.now(),
      );
    }
  }

  /// Generate Excel-compatible CSV
  Future<String> _generateExcelCompatibleCsv(
      BaseReport report,
      ExportConfig config,
      ) async {
    // For now, reuse CSV generation
    if (report is SalesReport) {
      return _generateSalesReportCsv(report, config);
    } else if (report is InventoryReport) {
      return _generateInventoryReportCsv(report, config);
    } else {
      return _generateGenericCsv(report, config);
    }
  }

  /// Export to PDF format (simplified)
  Future<ExportResult> _exportToPdf(
      BaseReport report,
      ExportConfig config,
      String? customFileName,
      ) async {
    try {
      // In production, use a PDF generation library like pdf: ^3.10.2
      // This is a placeholder implementation

      final pdfContent = '''
PDF Export: ${report.name}
Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}

This is a placeholder PDF export.
In production, implement proper PDF generation using a library like pdf: ^3.10.2

Report Data:
${json.encode(report.data)}
      ''';

      final fileName = customFileName ??
          '${report.name.replaceAll(' ', '_')}_${_getTimestamp()}.pdf';
      final filePath = await _saveToFile(fileName, pdfContent);

      return ExportResult(
        success: true,
        filePath: filePath,
        fileName: fileName,
        fileSize: pdfContent.length,
        format: ExportFormat.pdf,
        exportedAt: DateTime.now(),
      );
    } catch (e) {
      return ExportResult(
        success: false,
        error: 'PDF export failed: $e',
        format: ExportFormat.pdf,
        exportedAt: DateTime.now(),
      );
    }
  }

  /// Export to JSON format
  Future<ExportResult> _exportToJson(
      BaseReport report,
      ExportConfig config,
      String? customFileName,
      ) async {
    try {
      final jsonData = {
        'report': {
          'name': report.name,
          'type': report.runtimeType.toString(),
          'generatedAt': report.generatedAt.toIso8601String(),
          'query': report.query.toMap(),
          'data': report.data,
        },
        'exportConfig': config.toMap(),
        'exportedAt': DateTime.now().toIso8601String(),
      };

      final jsonContent = json.encode(jsonData);
      final fileName = customFileName ??
          '${report.name.replaceAll(' ', '_')}_${_getTimestamp()}.json';
      final filePath = await _saveToFile(fileName, jsonContent);

      return ExportResult(
        success: true,
        filePath: filePath,
        fileName: fileName,
        fileSize: jsonContent.length,
        format: ExportFormat.json,
        exportedAt: DateTime.now(),
      );
    } catch (e) {
      return ExportResult(
        success: false,
        error: 'JSON export failed: $e',
        format: ExportFormat.json,
        exportedAt: DateTime.now(),
      );
    }
  }

  /// Export to HTML format
  Future<ExportResult> _exportToHtml(
      BaseReport report,
      ExportConfig config,
      String? customFileName,
      ) async {
    try {
      final htmlContent = _generateHtmlReport(report, config);
      final fileName = customFileName ??
          '${report.name.replaceAll(' ', '_')}_${_getTimestamp()}.html';
      final filePath = await _saveToFile(fileName, htmlContent);

      return ExportResult(
        success: true,
        filePath: filePath,
        fileName: fileName,
        fileSize: htmlContent.length,
        format: ExportFormat.html,
        exportedAt: DateTime.now(),
      );
    } catch (e) {
      return ExportResult(
        success: false,
        error: 'HTML export failed: $e',
        format: ExportFormat.html,
        exportedAt: DateTime.now(),
      );
    }
  }

  /// Generate HTML report
  String _generateHtmlReport(BaseReport report, ExportConfig config) {
    final buffer = StringBuffer();

    buffer.writeln('''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${report.name}</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
            color: #333;
        }
        .header {
            background-color: #f8f9fa;
            padding: 20px;
            border-radius: 5px;
            margin-bottom: 30px;
        }
        .section {
            margin-bottom: 30px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 20px;
        }
        th, td {
            border: 1px solid #ddd;
            padding: 12px;
            text-align: left;
        }
        th {
            background-color: #f2f2f2;
            font-weight: bold;
        }
        tr:nth-child(even) {
            background-color: #f9f9f9;
        }
        .metric {
            font-size: 24px;
            font-weight: bold;
            color: #2c3e50;
        }
        .timestamp {
            color: #7f8c8d;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>${report.name}</h1>
        <p class="timestamp">Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(report.generatedAt)}</p>
    </div>
''');

    if (report is SalesReport) {
      _generateSalesReportHtml(buffer, report);
    } else if (report is InventoryReport) {
      _generateInventoryReportHtml(buffer, report);
    } else {
      _generateGenericReportHtml(buffer, report);
    }

    buffer.writeln('''
</body>
</html>
''');

    return buffer.toString();
  }

  /// Generate HTML for sales report
  void _generateSalesReportHtml(StringBuffer buffer, SalesReport report) {
    buffer.writeln('''
    <div class="section">
        <h2>Summary</h2>
        <table>
            <tr>
                <td>Total Sales</td>
                <td class="metric">${_currencyFormat.format(report.totalSales)}</td>
            </tr>
            <tr>
                <td>Number of Transactions</td>
                <td>${report.numberOfTransactions}</td>
            </tr>
            <tr>
                <td>Average Sale Value</td>
                <td>${_currencyFormat.format(report.averageSaleValue)}</td>
            </tr>
        </table>
    </div>
    ''');

    if (report.salesByCategory.isNotEmpty) {
      buffer.writeln('''
    <div class="section">
        <h2>Sales by Category</h2>
        <table>
            <tr>
                <th>Category</th>
                <th>Total Sales</th>
                <th>Items Sold</th>
                <th>Percentage</th>
            </tr>
      ''');

      for (final category in report.salesByCategory) {
        buffer.writeln('''
            <tr>
                <td>${category.categoryName}</td>
                <td>${_currencyFormat.format(category.totalSales)}</td>
                <td>${category.itemsSold}</td>
                <td>${category.percentageOfTotal.toStringAsFixed(2)}%</td>
            </tr>
        ''');
      }

      buffer.writeln('''
        </table>
    </div>
      ''');
    }

    if (report.topProducts.isNotEmpty) {
      buffer.writeln('''
    <div class="section">
        <h2>Top Selling Products</h2>
        <table>
            <tr>
                <th>Product</th>
                <th>SKU</th>
                <th>Quantity Sold</th>
                <th>Total Revenue</th>
                <th>Profit Margin</th>
            </tr>
      ''');

      for (final product in report.topProducts) {
        buffer.writeln('''
            <tr>
                <td>${product.productName}</td>
                <td>${product.productSku}</td>
                <td>${product.quantitySold}</td>
                <td>${_currencyFormat.format(product.totalRevenue)}</td>
                <td>${product.profitMargin.toStringAsFixed(2)}%</td>
            </tr>
        ''');
      }

      buffer.writeln('''
        </table>
    </div>
      ''');
    }
  }

  /// Generate HTML for inventory report
  void _generateInventoryReportHtml(StringBuffer buffer, InventoryReport report) {
    buffer.writeln('''
    <div class="section">
        <h2>Inventory Summary</h2>
        <table>
            <tr>
                <td>Total Inventory Value</td>
                <td class="metric">${_currencyFormat.format(report.totalInventoryValue)}</td>
            </tr>
            <tr>
                <td>Low Stock Items</td>
                <td>${report.lowStockItems}</td>
            </tr>
            <tr>
                <td>Out of Stock Items</td>
                <td>${report.outOfStockItems}</td>
            </tr>
            <tr>
                <td>Inventory Turnover Rate</td>
                <td>${report.inventoryTurnoverRate.toStringAsFixed(2)}</td>
            </tr>
        </table>
    </div>
    ''');

    if (report.slowMovingItems.isNotEmpty) {
      buffer.writeln('''
    <div class="section">
        <h2>Slow Moving Items</h2>
        <table>
            <tr>
                <th>Product</th>
                <th>SKU</th>
                <th>Current Stock</th>
                <th>Min Stock</th>
                <th>Max Stock</th>
                <th>Days in Stock</th>
                <th>Stock Value</th>
            </tr>
      ''');

      for (final item in report.slowMovingItems) {
        buffer.writeln('''
            <tr>
                <td>${item.productName}</td>
                <td>${item.sku}</td>
                <td>${item.currentStock}</td>
                <td>${item.minStockLevel}</td>
                <td>${item.maxStockLevel}</td>
                <td>${item.daysInStock}</td>
                <td>${_currencyFormat.format(item.stockValue)}</td>
            </tr>
        ''');
      }

      buffer.writeln('''
        </table>
    </div>
      ''');
    }
  }

  /// Generate HTML for generic report
  void _generateGenericReportHtml(StringBuffer buffer, BaseReport report) {
    buffer.writeln('''
    <div class="section">
        <h2>Report Data</h2>
        <pre>${json.encode(report.data)}</pre>
    </div>
    ''');
  }

  /// Save content to file
  Future<String> _saveToFile(String fileName, String content) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/exports/$fileName');

      // Create directory if it doesn't exist
      await file.parent.create(recursive: true);

      // Write file
      await file.writeAsString(content);

      _logger.debug('File saved: ${file.path}', extra: {'size': content.length});

      return file.path;
    } catch (e) {
      _logger.error('Failed to save file', error: e, extra: {'fileName': fileName});
      rethrow;
    }
  }

  /// Share exported file
  Future<void> shareFile(String filePath, String? subject) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await Share.shareXFiles(
          [XFile(filePath)],
          subject: subject ?? 'Analytics Export',
        );
        _logger.info('File shared successfully', extra: {'filePath': filePath});
      } else {
        throw Exception('File not found: $filePath');
      }
    } catch (e) {
      _logger.error('Failed to share file', error: e, extra: {'filePath': filePath});
      rethrow;
    }
  }

  /// Get timestamp for filename
  String _getTimestamp() {
    return DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  }

  /// Format date range
  String _formatDateRange(AnalyticsQuery query) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    return '${dateFormat.format(query.startDate)} to ${dateFormat.format(query.endDate)}';
  }

  /// Clean up old export files
  Future<void> cleanupOldExports({int daysToKeep = 7}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final exportsDir = Directory('${directory.path}/exports');

      if (await exportsDir.exists()) {
        final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
        final files = await exportsDir.list().toList();

        int deletedCount = 0;
        for (final file in files) {
          if (file is File) {
            final stat = await file.stat();
            if (stat.modified.isBefore(cutoffDate)) {
              await file.delete();
              deletedCount++;
            }
          }
        }

        _logger.info(
          'Cleaned up $deletedCount old export files',
          extra: {'cutoffDate': cutoffDate},
        );
      }
    } catch (e) {
      _logger.warning('Failed to cleanup old exports: $e');
    }
  }
}