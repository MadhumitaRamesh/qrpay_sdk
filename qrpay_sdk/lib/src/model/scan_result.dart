import 'payment_data.dart';
import 'location_fix.dart';

class ScanResult {
  final String rawString;
  final PaymentData? payment;
  final DateTime timestamp;
  final LocationFix? location;
  final double confidence; // 0.0-1.0
  final String schemeId;

  ScanResult({
    required this.rawString,
    this.payment,
    required this.timestamp,
    this.location,
    required this.confidence,
    required this.schemeId,
  });
}
