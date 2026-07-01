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
      title: 'QRPay SDK Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QRPay SDK Demo')),
      body: SafeArea(
        child: Column(
          children: [
            if (kIsWeb)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.orange.shade100,
                child: const Text(
                  'Running in browser — camera scanning requires Android or iOS device',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.deepOrange),
                ),
              ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton(
                      onPressed: kIsWeb
                          ? null
                          : () async {
                              await QRPay.initialize(QRPayConfig(overlayStyle: OverlayStyle.dark()));
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ScannerScreen(),
                                  ),
                                );
                              }
                            },
                      child: const Text('Start Scanner'),
                    ),
                    const SizedBox(height: 16),
                    const Text('Tap to scan EMVCo or UPI payment QR codes'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _isTorchOn = false;

  void _onScan(ScanResult result) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultScreen(result: result),
      ),
    );
  }

  void _onError(QRPayError error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${error.runtimeType}: ${error.description}'),
        backgroundColor: Colors.red,
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () {
              setState(() {
                _isTorchOn = !_isTorchOn;
              });
              QRPay.setTorch(_isTorchOn);
            },
          ),
        ],
      ),
      body: ScannerView(
        config: QRPayConfig(
          overlayStyle: OverlayStyle.dark(),
        ),
        onScan: _onScan,
        onError: _onError,
        onScanComplete: () {
          if (mounted) {
            final navigator = Navigator.of(context);
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                navigator.popUntil((route) => route.isFirst);
              }
            });
          }
        },
      ),
    );
  }
}

class ResultScreen extends StatelessWidget {
  final ScanResult result;

  const ResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final payment = result.payment;
    final amountText = payment?.amount != null
        ? '${payment!.amount} ${payment.currency ?? ''}'
        : 'Not specified';

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Payment QR Detected',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          _buildCard('Merchant', payment?.merchantName ?? 'Unknown'),
          _buildCard('Amount', amountText),
          _buildCard('Scheme', payment?.schemeId ?? 'Unknown'),
          _buildCard(
              'Raw String',
              result.rawString.length > 100
                  ? '${result.rawString.substring(0, 100)}...'
                  : result.rawString,
              isMono: true),
          _buildCard('Timestamp', result.timestamp.toIso8601String()),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Scan Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String title, String value, {bool isMono = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontFamily: isMono ? 'monospace' : null,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
