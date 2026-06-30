import 'package:flutter_test/flutter_test.dart';
// glados re-exports package:test — hide the conflicting symbols so
// flutter_test's versions take precedence.
import 'package:glados/glados.dart' hide test, group, expect, setUp,
    setUpAll, tearDown, tearDownAll, addTearDown, isA, closeTo, isTrue,
    isFalse, isNull, isNotNull, isA, throwsA, same, anything;
import 'package:qrpay_sdk/src/parser/payment_parser.dart';
import 'package:qrpay_sdk/src/model/qrpay_error.dart';

// ---------------------------------------------------------------------------
// Helper: build a structurally valid EMVCo string with correct CRC-16/CCITT-FALSE
// ---------------------------------------------------------------------------
String buildEmvco(Map<String, String> fields) {
  final buffer = StringBuffer();
  final sortedKeys = fields.keys.toList()..sort();
  for (final key in sortedKeys) {
    if (key == '63') continue;
    final v = fields[key]!;
    buffer.write(key);
    buffer.write(v.length.toString().padLeft(2, '0'));
    buffer.write(v);
  }
  buffer.write('6304');

  int crc = 0xFFFF;
  final input = buffer.toString();
  for (int i = 0; i < input.length; i++) {
    crc ^= (input.codeUnitAt(i) << 8);
    for (int j = 0; j < 8; j++) {
      crc = (crc & 0x8000) != 0
          ? ((crc << 1) ^ 0x1021) & 0xFFFF
          : (crc << 1) & 0xFFFF;
    }
  }
  buffer.write(crc.toRadixString(16).padLeft(4, '0').toUpperCase());
  return buffer.toString();
}

// ---------------------------------------------------------------------------
// Glados custom generators for EMVCo field values
// ---------------------------------------------------------------------------
extension EmvcoAny on Any {
  /// Merchant name: 1–25 uppercase ASCII letters and spaces.
  Generator<String> get merchantName => simple(
        generate: (random, size) {
          const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ ';
          final len = 1 + random.nextInt(25.clamp(1, size.clamp(1, 25)));
          return List.generate(len, (_) => chars[random.nextInt(chars.length)])
              .join()
              .trim()
              .padRight(1, 'A'); // ensure at least 1 char
        },
        shrink: (s) sync* {
          if (s.length > 1) yield s.substring(0, s.length - 1);
        },
      );

  /// Amount: positive decimal with 2 decimal places, 0.01 – 9999.99.
  Generator<String> get emvcoAmount => simple(
        generate: (random, size) {
          final whole = random.nextInt(9999.clamp(1, size.clamp(1, 9999)));
          final cents = random.nextInt(100);
          return '$whole.${cents.toString().padLeft(2, '0')}';
        },
        shrink: (s) sync* {
          final v = double.tryParse(s) ?? 1.0;
          if (v > 1.0) yield '1.00';
        },
      );

  /// ISO 4217 currency code: one of a fixed set so the parser can map it.
  Generator<String> get currencyCode =>
      choose(['356', '840', '978', '826', '392']);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  group('PaymentParser', () {
    // -- Manual deterministic tests ------------------------------------------
    test('Valid EMVCo parsing', () {
      final s = buildEmvco({
        '00': '01',
        '01': '11',
        '52': '0000',
        '53': '356',
        '54': '10.50',
        '58': 'IN',
        '59': 'TEST MERCHANT',
        '60': 'BANGALORE',
      });

      final result = PaymentParser.parseQr(s);
      expect(result.isSuccess, isTrue);
      expect(result.value!.schemeId, 'emvco');
      expect(result.value!.amount, 10.50);
      expect(result.value!.currency, 'INR');
      expect(result.value!.merchantName, 'TEST MERCHANT');
    });

    test('Corrupted EMVCo CRC', () {
      final s = buildEmvco({'00': '01', '01': '11'});
      final corrupted = s.substring(0, s.length - 4) + '0000';
      final result = PaymentParser.parseQr(corrupted);
      expect(result.isError, isTrue);
      expect(result.error, isA<ChecksumFailed>());
    });

    test('Malformed EMVCo TLV', () {
      final buf = StringBuffer();
      buf.write('000201');
      buf.write('010911'); // tag 01, claimed length 09, only 2 bytes provided
      buf.write('6304');
      int crc = 0xFFFF;
      final input = buf.toString();
      for (int i = 0; i < input.length; i++) {
        crc ^= (input.codeUnitAt(i) << 8);
        for (int j = 0; j < 8; j++) {
          crc = (crc & 0x8000) != 0
              ? ((crc << 1) ^ 0x1021) & 0xFFFF
              : (crc << 1) & 0xFFFF;
        }
      }
      buf.write(crc.toRadixString(16).padLeft(4, '0').toUpperCase());
      final result = PaymentParser.parseQr(buf.toString());
      expect(result.isError, isTrue);
      expect(result.error, isA<MalformedQr>());
    });

    test('Valid UPI URI', () {
      final result =
          PaymentParser.parseQr('upi://pay?pa=test@upi&pn=Test%20User&am=100.50&cu=INR');
      expect(result.isSuccess, isTrue);
      expect(result.value!.schemeId, 'upi');
      expect(result.value!.amount, 100.50);
      expect(result.value!.merchantName, 'Test User');
    });

    test('UPI URI missing pa', () {
      final result = PaymentParser.parseQr('upi://pay?pn=Test%20User&am=100.50');
      expect(result.isError, isTrue);
      expect(result.error, isA<MalformedQr>());
    });

    test('Unrelated string', () {
      final result = PaymentParser.parseQr('hello world');
      expect(result.isError, isTrue);
      expect(result.error, isA<UnsupportedScheme>());
    });

    // -- Property-based: EMVCo CRC roundtrip ---------------------------------
    // Glados generates randomised merchant names, amounts and currency codes
    // and asserts that any structurally valid EMVCo string is accepted by the
    // parser (CRC is always recomputed correctly by buildEmvco, so if the
    // parser rejects it the CRC implementation is broken).
    Glados3(
      any.merchantName,
      any.emvcoAmount,
      any.currencyCode,
      ExploreConfig(numRuns: 100),
    ).test('EMVCo CRC roundtrip holds for randomised fields',
        (merchant, amount, currency) {
      final s = buildEmvco({
        '00': '01',
        '52': '0000',
        '53': currency,
        '54': amount,
        '58': 'IN',
        '59': merchant,
      });
      final result = PaymentParser.parseQr(s);
      expect(
        result.isSuccess,
        isTrue,
        reason: 'Parser rejected valid EMVCo string '
            '(merchant=$merchant, amount=$amount, currency=$currency)',
      );
    });

    // -- Property-based: UPI roundtrip ---------------------------------------
    // Generates randomised UPI query parameter combinations and asserts that
    // the parser always succeeds for structurally valid URIs, and that the
    // returned amount matches what was passed in.
    Glados2(
      any.emvcoAmount, // re-use amount generator — UPI amounts have same format
      any.choose(['INR', 'USD', 'EUR', 'GBP', 'JPY']),
      ExploreConfig(numRuns: 100),
    ).test('UPI parsing succeeds and amount round-trips for valid URIs',
        (amount, currency) {
      final pa = 'merchant@upi';
      final pn = 'Test%20Merchant';
      final uri =
          'upi://pay?pa=$pa&pn=$pn&am=$amount&cu=$currency';
      final result = PaymentParser.parseQr(uri);
      expect(
        result.isSuccess,
        isTrue,
        reason: 'UPI parser rejected valid URI: $uri',
      );
      expect(
        result.value!.amount,
        closeTo(double.parse(amount), 0.001),
        reason: 'Amount did not round-trip for $uri',
      );
    });
  });
}
