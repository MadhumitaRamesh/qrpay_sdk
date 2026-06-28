import '../model/payment_data.dart';
import '../model/qrpay_error.dart';
import '../config/config_validator.dart';

abstract class SchemeParser {
  String get schemeId;
  
  bool matches(String rawString);
  
  Result<PaymentData, QRPayError> parse(String rawString);
}
