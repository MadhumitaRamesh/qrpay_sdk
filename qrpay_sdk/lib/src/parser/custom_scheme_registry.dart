import 'parser.dart';
import 'emvco_parser.dart';
import 'upi_parser.dart';

class CustomSchemeRegistry {
  static final CustomSchemeRegistry _instance = CustomSchemeRegistry._internal();
  
  factory CustomSchemeRegistry() {
    return _instance;
  }
  
  CustomSchemeRegistry._internal() {
    // Register built-ins
    _parsers.add(EMVCoParser());
    _parsers.add(UpiParser());
  }

  final List<SchemeParser> _parsers = [];

  static void register(SchemeParser parser) {
    _instance._parsers.add(parser);
  }

  static List<SchemeParser> getRegisteredParsers() {
    return List.unmodifiable(_instance._parsers);
  }

  static SchemeParser? resolve(String rawString) {
    for (final parser in _instance._parsers) {
      if (parser.matches(rawString)) {
        return parser;
      }
    }
    return null;
  }
  
  // For testing purposes
  static void clearCustom() {
    _instance._parsers.removeWhere((p) => p is! EMVCoParser && p is! UpiParser);
  }
}
