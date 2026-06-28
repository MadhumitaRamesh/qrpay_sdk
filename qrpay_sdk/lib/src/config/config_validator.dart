import 'qrpay_config.dart';

class ConfigInvalidError {
  final String field;
  final String reason;

  ConfigInvalidError(this.field, this.reason);
}

class Result<T, E> {
  final T? value;
  final E? error;
  
  bool get isSuccess => value != null && error == null;
  bool get isError => error != null;

  Result.success(this.value) : error = null;
  Result.error(this.error) : value = null;
}

class ConfigValidator {
  static Result<void, ConfigInvalidError> validate(QRPayConfig config) {
    if (config.autoZoomThreshold <= 0 || config.autoZoomThreshold > 0.5) {
      return Result.error(ConfigInvalidError(
        'autoZoomThreshold',
        'Must be in range (0, 0.5]',
      ));
    }
    if (config.maxDigitalZoom < 1.0 || config.maxDigitalZoom > 10.0) {
      return Result.error(ConfigInvalidError(
        'maxDigitalZoom',
        'Must be in range [1.0, 10.0]',
      ));
    }
    return Result.success(null);
  }
}
