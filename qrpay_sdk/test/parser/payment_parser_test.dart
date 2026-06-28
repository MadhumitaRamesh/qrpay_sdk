import 'package:flutter_test/flutter_test.dart';
import 'package:qrpay_sdk/src/parser/payment_parser.dart';
import 'package:qrpay_sdk/src/model/qrpay_error.dart';

// Helper to generate valid EMVCo strings and compute CRC for testing.
String generateEmvco(Map<String, String> fields) {
  final buffer = StringBuffer();
  final sortedKeys = fields.keys.toList()..sort();
  for (final key in sortedKeys) {
    if (key == '63') continue;
    buffer.write(key);
    buffer.write(fields[key]!.length.toString().padLeft(2, '0'));
    buffer.write(fields[key]);
  }
  buffer.write('6304');
  
  // compute CRC-16/CCITT-FALSE
  int crc = 0xFFFF;
  final input = buffer.toString();
  for (int i = 0; i < input.length; i++) {
    crc ^= (input.codeUnitAt(i) << 8);
    for (int j = 0; j < 8; j++) {
      if ((crc & 0x8000) != 0) {
        crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
      } else {
        crc = (crc << 1) & 0xFFFF;
      }
    }
  }
  
  buffer.write(crc.toRadixString(16).padLeft(4, '0').toUpperCase());
  return buffer.toString();
}

void main() {
  group('PaymentParser', () {
    test('Valid EMVCo parsing', () {
      final validString = generateEmvco({
        '00': '01',
        '01': '11',
        '52': '0000',
        '53': '356',
        '54': '10.50',
        '58': 'IN',
        '59': 'TEST MERCHANT',
        '60': 'BANGALORE',
      });
      
      final result = PaymentParser.parseQr(validString);
      expect(result.isSuccess, isTrue);
      expect(result.value!.schemeId, 'emvco');
      expect(result.value!.amount, 10.50);
      expect(result.value!.currency, 'INR');
      expect(result.value!.merchantName, 'TEST MERCHANT');
    });

    test('Corrupted EMVCo CRC', () {
      final validString = generateEmvco({
        '00': '01',
        '01': '11',
      });
      // Replace last 4 chars (CRC) with 0000
      final corruptedString = validString.substring(0, validString.length - 4) + '0000';
      
      final result = PaymentParser.parseQr(corruptedString);
      expect(result.isError, isTrue);
      expect(result.error, isA<ChecksumFailed>());
    });

    test('Malformed EMVCo TLV', () {
      // Intentionally break TLV length but compute a valid CRC so it reaches TLV parsing
      final buffer = StringBuffer();
      buffer.write('000201');
      buffer.write('010911'); // tag 01, length 09, but only 2 chars provided!
      buffer.write('6304');
      
      int crc = 0xFFFF;
      final input = buffer.toString();
      for (int i = 0; i < input.length; i++) {
        crc ^= (input.codeUnitAt(i) << 8);
        for (int j = 0; j < 8; j++) {
          if ((crc & 0x8000) != 0) {
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
          } else {
            crc = (crc << 1) & 0xFFFF;
          }
        }
      }
      buffer.write(crc.toRadixString(16).padLeft(4, '0').toUpperCase());
      
      final result = PaymentParser.parseQr(buffer.toString());
      expect(result.isError, isTrue);
      expect(result.error, isA<MalformedQr>());
    });

    test('Valid UPI URI', () {
      final uri = 'upi://pay?pa=test@upi&pn=Test%20User&am=100.50&cu=INR';
      final result = PaymentParser.parseQr(uri);
      
      expect(result.isSuccess, isTrue);
      expect(result.value!.schemeId, 'upi');
      expect(result.value!.amount, 100.50);
      expect(result.value!.merchantName, 'Test User');
    });

    test('UPI URI missing pa', () {
      final uri = 'upi://pay?pn=Test%20User&am=100.50';
      final result = PaymentParser.parseQr(uri);
      
      expect(result.isError, isTrue);
      expect(result.error, isA<MalformedQr>());
    });

    test('Unrelated string', () {
      final result = PaymentParser.parseQr('hello world');
      
      expect(result.isError, isTrue);
      expect(result.error, isA<UnsupportedScheme>());
    });

    test('Property-based EMVCo CRC roundtrip', () {
      final amounts = ['1.00', '10.50', '999.99'];
      final merchants = ['A', 'Long Merchant Name', '123'];
      
      for (final amt in amounts) {
        for (final m in merchants) {
          final s = generateEmvco({
            '00': '01',
            '54': amt,
            '59': m,
          });
          final result = PaymentParser.parseQr(s);
          expect(result.isSuccess, isTrue, reason: 'Failed for amt=\$amt, m=\$m');
        }
      }
    });
  });
}
