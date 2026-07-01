// NOTE: This integration test currently requires a physical device or a camera-capable
// emulator to execute successfully because the QRPay SDK requires actual camera hardware
// to initialize and start scanning.
//
// To run this test when a device is available, execute:
// flutter test integration_test/scan_flow_test.dart -d <device_id>

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qrpay_sdk/qrpay_sdk.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('End-to-end scan flow: initialize -> start -> stop', (WidgetTester tester) async {
    // 1. Initialize
    final config = QRPayConfig(overlayStyle: OverlayStyle.dark());
    await QRPay.initialize(config);
    
    // 2. Start scanning
    final stream = QRPay.startScanning();
    
    // 3. Wait for camera-ready event (maps to LifecycleEvent.resumed in dart side)
    final readyEvent = await stream.firstWhere(
      (event) => event is ScanEventLifecycle && event.event == LifecycleEvent.resumed,
    ).timeout(const Duration(seconds: 5), onTimeout: () {
      throw Exception('Timed out waiting for camera-ready event');
    });
    
    expect(readyEvent, isNotNull);

    // 4. Stop scanning
    await QRPay.stopScanning();

    // 5. Wait for scan-complete event (maps to LifecycleEvent.stopped in dart side)
    final completeEvent = await stream.firstWhere(
      (event) => event is ScanEventLifecycle && event.event == LifecycleEvent.stopped,
    ).timeout(const Duration(seconds: 5), onTimeout: () {
      throw Exception('Timed out waiting for scan-complete event');
    });

    expect(completeEvent, isNotNull);
  });
}
