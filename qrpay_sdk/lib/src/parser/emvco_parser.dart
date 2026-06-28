import '../model/payment_data.dart';
import '../model/qrpay_error.dart';
import '../config/config_validator.dart';
import 'parser.dart';

class EMVCoParser implements SchemeParser {
  @override
  String get schemeId => 'emvco';

  @override
  bool matches(String rawString) {
    return rawString.startsWith('000201');
  }

  @override
  Result<PaymentData, QRPayError> parse(String rawString) {
    // 1. Validate CRC
    if (!rawString.contains('6304')) {
      return Result.error(ChecksumFailed(
        rawString: rawString,
        description: 'Missing CRC tag 6304',
      ));
    }

    // CRC is typically at the very end
    final crcIndex = rawString.lastIndexOf('6304');
    if (crcIndex + 8 > rawString.length) {
      return Result.error(MalformedQr(
        rawString: rawString,
        description: 'CRC tag truncated',
      ));
    }

    final payloadToHash = rawString.substring(0, crcIndex + 4);
    final providedCrc = rawString.substring(crcIndex + 4, crcIndex + 8).toUpperCase();
    final calculatedCrc = _calculateCrc16(payloadToHash).toRadixString(16).padLeft(4, '0').toUpperCase();

    if (providedCrc != calculatedCrc) {
      return Result.error(ChecksumFailed(
        rawString: rawString,
        description: 'CRC validation failed. Expected \$calculatedCrc, got \$providedCrc',
      ));
    }

    // 2. Parse TLV
    final Map<String, dynamic> rawFields = {};
    int index = 0;

    try {
      while (index < rawString.length) {
        if (index + 4 > rawString.length) {
          return Result.error(MalformedQr(
            rawString: rawString,
            description: 'Incomplete TLV structure at end of string',
          ));
        }
        
        final tag = rawString.substring(index, index + 2);
        final lengthStr = rawString.substring(index + 2, index + 4);
        final length = int.parse(lengthStr);
        
        if (index + 4 + length > rawString.length) {
          return Result.error(MalformedQr(
            rawString: rawString,
            description: 'Length for tag \$tag exceeds string length',
          ));
        }

        final value = rawString.substring(index + 4, index + 4 + length);
        rawFields[tag] = value;

        index += 4 + length;
      }
      
      if (index != rawString.length) {
        return Result.error(MalformedQr(
          rawString: rawString,
          description: 'Trailing characters after parsing TLV',
        ));
      }
    } catch (e) {
      return Result.error(MalformedQr(
        rawString: rawString,
        description: 'Failed to parse TLV structure',
      ));
    }

    // 3. Extract required fields
    double? amount;
    if (rawFields.containsKey('54')) {
      amount = double.tryParse(rawFields['54']);
    }

    String? currency;
    if (rawFields.containsKey('53')) {
      currency = _mapIso4217NumericToAlpha(rawFields['53']);
    }

    final merchantName = rawFields['59'];

    return Result.success(PaymentData(
      schemeId: schemeId,
      amount: amount,
      currency: currency,
      merchantName: merchantName,
      rawFields: rawFields,
    ));
  }

  int _calculateCrc16(String input) {
    int crc = 0xFFFF;
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
    return crc;
  }

  String _mapIso4217NumericToAlpha(String numericCode) {
    const map = {
      '356': 'INR',
      '840': 'USD',
      '978': 'EUR',
      '826': 'GBP',
      '392': 'JPY',
      '036': 'AUD',
      '124': 'CAD',
      '756': 'CHF',
      '156': 'CNY',
      '344': 'HKD',
      '702': 'SGD',
      '932': 'ZWL',
    };
    return map[numericCode] ?? numericCode;
  }
}
