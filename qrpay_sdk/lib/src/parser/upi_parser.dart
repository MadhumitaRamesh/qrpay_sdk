import '../model/payment_data.dart';
import '../model/qrpay_error.dart';
import '../config/config_validator.dart';
import 'parser.dart';

class UpiParser implements SchemeParser {
  @override
  String get schemeId => 'upi';

  @override
  bool matches(String rawString) {
    return rawString.startsWith('upi://');
  }

  @override
  Result<PaymentData, QRPayError> parse(String rawString) {
    try {
      final uri = Uri.parse(rawString);
      final queryParams = uri.queryParameters;

      if (!queryParams.containsKey('pa') || queryParams['pa']!.isEmpty) {
        return Result.error(MalformedQr(
          rawString: rawString,
          description: 'Missing required parameter "pa" (payee address)',
        ));
      }

      double? amount;
      if (queryParams.containsKey('am')) {
        amount = double.tryParse(queryParams['am']!);
      }

      return Result.success(PaymentData(
        schemeId: schemeId,
        amount: amount,
        currency: queryParams['cu'] ?? 'INR',
        merchantName: queryParams['pn'],
        rawFields: queryParams,
      ));
    } catch (e) {
      return Result.error(MalformedQr(
        rawString: rawString,
        description: 'Failed to parse UPI URI',
      ));
    }
  }
}
