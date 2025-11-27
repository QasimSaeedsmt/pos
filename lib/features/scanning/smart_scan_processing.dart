// Create new file: smart_scan_processing.dart
import 'package:flutter/material.dart';

class SmartScanProcessingOverlay extends StatelessWidget {
  final String scannedData;
  final String scanType;

  const SmartScanProcessingOverlay({
    super.key,
    required this.scannedData,
    required this.scanType,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade800, Colors.purple.shade800],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
            SizedBox(height: 20),
            Text(
              'Analyzing Content...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                scannedData.length > 50
                    ? '${scannedData.substring(0, 50)}...'
                    : scannedData,
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SmartScanErrorDialog extends StatelessWidget {
  final String scannedData;
  final String error;
  final VoidCallback onRetry;
  final VoidCallback onManualSearch;

  const SmartScanErrorDialog({
    super.key,
    required this.scannedData,
    required this.error,
    required this.onRetry,
    required this.onManualSearch,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.orange),
          SizedBox(width: 8),
          Text('Scan Not Recognized'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('We couldn\'t automatically identify this content:'),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectableText(
              scannedData,
              style: TextStyle(fontFamily: 'Monospace', fontSize: 12),
            ),
          ),
          SizedBox(height: 8),
          Text('Error: $error', style: TextStyle(color: Colors.red, fontSize: 12)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onManualSearch,
          child: Text('Search Manually'),
        ),
        TextButton(
          onPressed: onRetry,
          child: Text('Try Again'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
      ],
    );
  }
}