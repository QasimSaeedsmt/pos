// Create new file: smart_scanner_overlay.dart
import 'package:flutter/material.dart';

import '../invoiceBase/invoice_and_printing_base.dart';

class SmartScannerOverlay extends StatefulWidget {
  final Function(Map<String, dynamic>) onScanComplete;

  const SmartScannerOverlay({super.key, required this.onScanComplete});

  @override
  _SmartScannerOverlayState createState() => _SmartScannerOverlayState();
}

class _SmartScannerOverlayState extends State<SmartScannerOverlay> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.9),
            Colors.black.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Scanner',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Point at any barcode, QR code, or text',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Scanner Options
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(16),
              children: [
                _buildScannerOption(
                  icon: Icons.qr_code,
                  title: 'QR Code Scanner',
                  subtitle: 'Invoices, orders, product info',
                  onTap: () => _launchQRScanner(),
                ),
                _buildScannerOption(
                  icon: Icons.barcode_reader,
                  title: 'Barcode Scanner',
                  subtitle: 'Products, inventory items',
                  onTap: () => _launchBarcodeScanner(),
                ),
                _buildScannerOption(
                  icon: Icons.document_scanner,
                  title: 'Document Scanner',
                  subtitle: 'Text, numbers, references',
                  onTap: () => _launchDocumentScanner(),
                ),
                _buildScannerOption(
                  icon: Icons.keyboard,
                  title: 'Manual Input',
                  subtitle: 'Type or paste any reference',
                  onTap: () => _showManualInput(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: Colors.white.withOpacity(0.1),
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.purple],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(
          title,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.white70),
        ),
        trailing: Icon(Icons.arrow_forward, color: Colors.white54),
        onTap: onTap,
      ),
    );
  }

  void _launchQRScanner() async {
    final result = await UniversalScanningService.scanBarcode(
      context,
      purpose: 'smart_scan',
    );

    if (result != null) {
      widget.onScanComplete({
        'data': result,
        'type': 'qr_code',
        'timestamp': DateTime.now(),
      });
    }
  }

  void _launchBarcodeScanner() async {
    final result = await UniversalScanningService.scanBarcode(
      context,
      purpose: 'barcode',
    );

    if (result != null) {
      widget.onScanComplete({
        'data': result,
        'type': 'barcode',
        'timestamp': DateTime.now(),
      });
    }
  }

  void _launchDocumentScanner() {
    _showManualInput();
  }

  void _showManualInput() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => ManualInputDialog(),
    );

    if (result != null) {
      widget.onScanComplete({
        'data': result,
        'type': 'manual_input',
        'timestamp': DateTime.now(),
      });
    }
  }
}

class ManualInputDialog extends StatefulWidget {
  const ManualInputDialog({super.key});

  @override
  _ManualInputDialogState createState() => _ManualInputDialogState();
}

class _ManualInputDialogState extends State<ManualInputDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter Reference',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Barcode, order number, email, etc...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              maxLines: 3,
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (_controller.text.trim().isNotEmpty) {
                      Navigator.pop(context, _controller.text.trim());
                    }
                  },
                  child: Text('Scan'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}