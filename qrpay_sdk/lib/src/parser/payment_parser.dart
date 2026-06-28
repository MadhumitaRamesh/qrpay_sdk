import '../model/payment_data.dart';
import '../model/qrpay_error.dart';
import '../config/config_validator.dart';
import 'custom_scheme_registry.dart';

class PaymentParser {
  static Result<PaymentData, QRPayError> parseQr(String rawString) {
    if (rawString.isEmpty) {
      return Result.error(MalformedQr(
        rawString: rawString,
        description: 'Empty QR string',
        suggestedAction: 'Please scan a valid QR code',
      ));
    }

    final parser = CustomSchemeRegistry.resolve(rawString);
    if (parser != null) {
      return parser.parse(rawString);
    }

    return Result.error(UnsupportedScheme(
      rawString: rawString,
      description: 'The scanned QR code is not supported by any registered parser.',
      suggestedAction: 'If this is a valid payment scheme, please register a custom parser via CustomSchemeRegistry.',
    ));
  }
}
