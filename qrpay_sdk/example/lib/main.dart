import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:qrpay_sdk/qrpay_sdk.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('QRPay SDK Example')),
        body: ScannerView(
          config: QRPayConfig(
            overlayStyle: OverlayStyle.dark(),
          ),
          onScan: (result) {
            if (kDebugMode) {
              print('Scanned: \${result.rawString}');
            }
          },
          onError: (error) {
            if (kDebugMode) {
              print('Error: \${error.description}');
            }
          },
        ),
      ),
    );
  }
}
