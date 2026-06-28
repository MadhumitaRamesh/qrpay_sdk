import 'package:flutter_test/flutter_test.dart';
import 'package:qrpay_sdk/qrpay_sdk.dart';
import 'package:qrpay_sdk/src/parser/payment_parser.dart';

class DummyParser implements SchemeParser {
  @override
  String get schemeId => 'dummy';

  @override
  bool matches(String rawString) => rawString.startsWith('dummy://');

  @override
  Result<PaymentData, QRPayError> parse(String rawString) {
    return Result.success(PaymentData(
      schemeId: 'dummy',
      merchantName: 'Dummy Merchant',
      rawFields: {'merchantId': 'dummy123'},
    ));
  }
}

void main() {
  group('CustomSchemeRegistry', () {
    setUp(() {
      CustomSchemeRegistry.clearCustom();
    });

    test('registers and resolves custom parser', () {
      CustomSchemeRegistry.register(DummyParser());
      
      final result = PaymentParser.parseQr('dummy://pay?id=123');
      expect(result.isSuccess, true);
      expect(result.value?.schemeId, 'dummy');
      expect(result.value?.merchantName, 'Dummy Merchant');
    });

    test('falls back to built-in parsers', () {
      CustomSchemeRegistry.register(DummyParser());
      
      // UPI URI
      final upiString = 'upi://pay?pa=test@bank&pn=Test&am=100';
      final upiResult = PaymentParser.parseQr(upiString);
      expect(upiResult.isSuccess, true);
      expect(upiResult.value?.schemeId, 'upi');
      expect(upiResult.value?.merchantName, 'Test');
    });

    test('unsupported scheme returns error', () {
      final result = PaymentParser.parseQr('unknown://pay');
      expect(result.isError, true);
      expect(result.error, isA<UnsupportedScheme>());
    });
  });
}
