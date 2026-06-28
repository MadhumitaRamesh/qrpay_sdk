/// Standardized payment information extracted from a recognized QR code scheme (e.g. EMVCo or UPI).
class PaymentData {
  final String schemeId;
  final double? amount;
  final String? currency;
  final String? merchantName;
  final Map<String, dynamic> rawFields;

  PaymentData({
    required this.schemeId,
    this.amount,
    this.currency,
    this.merchantName,
    required this.rawFields,
  });
}
