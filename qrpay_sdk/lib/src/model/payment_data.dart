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
