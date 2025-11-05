import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../invoiceBase/invoice_and_printing_base.dart';



class BarcodeService {
  static Future<BarcodeScanResult> scanBarcode(BuildContext context) async {
    try {
      final barcode = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (context) => BarcodeScannerScreen()),
      );

      if (barcode != null && barcode.isNotEmpty) {
        return BarcodeScanResult(barcode: barcode, success: true);
      } else {
        return BarcodeScanResult(
          barcode: '',
          success: false,
          error: 'Scan cancelled',
        );
      }
    } catch (e) {
      return BarcodeScanResult(
        barcode: '',
        success: false,
        error: e.toString(),
      );
    }
  }
}

class BarcodeScanResult {
  final String barcode;
  final bool success;
  final String? error;

  BarcodeScanResult({required this.barcode, required this.success, this.error});
}

// Barcode Scanner Screen
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  _BarcodeScannerScreenState createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _hasScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Scan Barcode'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController,
              builder: (context, state, child) {
                switch (state) {
                  case TorchState.off:
                    return Icon(Icons.flash_off, color: Colors.grey);
                  case TorchState.on:
                    return Icon(Icons.flash_on, color: Colors.yellow);
                }
                return Icon(Icons.flash_off, color: Colors.yellow);
              },
            ),
            onPressed: () => cameraController.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (_hasScanned) return;
              final barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                _hasScanned = true;
                final barcode = barcodes.first.rawValue;
                if (barcode != null) {
                  Navigator.of(context).pop(barcode);
                }
              }
            },
          ),
          CustomPaint(painter: ScannerOverlay()),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}

// Barcode Manual Input Dialog
class BarcodeManualInputDialog extends StatefulWidget {
  final Function(String) onBarcodeScanned;

  const BarcodeManualInputDialog({super.key, required this.onBarcodeScanned});

  @override
  _BarcodeManualInputDialogState createState() =>
      _BarcodeManualInputDialogState();
}

class _BarcodeManualInputDialogState extends State<BarcodeManualInputDialog> {
  final TextEditingController _barcodeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Enter Barcode'),
      content: TextField(
        controller: _barcodeController,
        decoration: InputDecoration(labelText: 'Barcode'),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final barcode = _barcodeController.text.trim();
            if (barcode.isNotEmpty) {
              Navigator.of(context).pop();
              widget.onBarcodeScanned(barcode);
            }
          },
          child: Text('Search'),
        ),
      ],
    );
  }
}

