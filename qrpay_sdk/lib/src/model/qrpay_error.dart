/// Base sealed class for all typed errors emitted by the QRPay SDK.
/// Subclasses provide semantic categorization of failures (e.g. [CameraUnrecoverable], [MalformedQr]).
sealed class QRPayError {
  final String code;
  final String? rawString;
  final String description;
  final String suggestedAction;

  const QRPayError({
    required this.code,
    this.rawString,
    required this.description,
    required this.suggestedAction,
  });
}

class InvalidPaymentQr extends QRPayError {
  const InvalidPaymentQr({
    String? rawString,
    String description = 'Invalid Payment QR',
    String suggestedAction = 'Try scanning a valid payment QR code',
  }) : super(code: 'invalid_payment_qr', rawString: rawString, description: description, suggestedAction: suggestedAction);
}

class MalformedQr extends QRPayError {
  const MalformedQr({
    String? rawString,
    String description = 'Malformed QR Data',
    String suggestedAction = 'The QR code might be corrupted or poorly printed',
  }) : super(code: 'malformed_qr', rawString: rawString, description: description, suggestedAction: suggestedAction);
}

class ChecksumFailed extends QRPayError {
  const ChecksumFailed({
    String? rawString,
    String description = 'Checksum Validation Failed',
    String suggestedAction = 'Ensure the QR code is fully visible and not damaged',
  }) : super(code: 'checksum_failed', rawString: rawString, description: description, suggestedAction: suggestedAction);
}

class UnsupportedScheme extends QRPayError {
  const UnsupportedScheme({
    String? rawString,
    String description = 'Unsupported QR Scheme',
    String suggestedAction = 'Try scanning a supported payment scheme QR code',
  }) : super(code: 'unsupported_scheme', rawString: rawString, description: description, suggestedAction: suggestedAction);
}

class ConfigInvalid extends QRPayError {
  const ConfigInvalid({
    String? rawString,
    String description = 'Invalid Configuration',
    String suggestedAction = 'Check the SDK configuration parameters',
  }) : super(code: 'config_invalid', rawString: rawString, description: description, suggestedAction: suggestedAction);
}

class LocationUnavailable extends QRPayError {
  const LocationUnavailable({
    String? rawString,
    String description = 'Location Data Unavailable',
    String suggestedAction = 'Ensure location permissions are granted',
  }) : super(code: 'location_unavailable', rawString: rawString, description: description, suggestedAction: suggestedAction);
}

class CameraUnrecoverable extends QRPayError {
  const CameraUnrecoverable({
    String? rawString,
    String description = 'Camera is unrecoverable after repeated failures',
    String suggestedAction = 'Close and reopen the scanner, or restart the app',
  }) : super(code: 'camera_unrecoverable', rawString: rawString, description: description, suggestedAction: suggestedAction);
}

class PermissionRevoked extends QRPayError {
  const PermissionRevoked({
    String? rawString,
    String description = 'Camera permission was revoked at runtime',
    String suggestedAction = 'Grant camera permission in device settings to use the scanner',
  }) : super(code: 'permission_revoked', rawString: rawString, description: description, suggestedAction: suggestedAction);
}

class SessionTimeout extends QRPayError {
  const SessionTimeout({
    String? rawString,
    String description = 'Scan session timed out with no successful decode',
    String suggestedAction = 'Relaunch the scanner and try again',
  }) : super(code: 'session_timeout', rawString: rawString, description: description, suggestedAction: suggestedAction);
}

class PermissionDenied extends QRPayError {
  const PermissionDenied({
    String? rawString,
    String description = 'Camera permission not granted',
    String suggestedAction = 'Grant camera permission to use the scanner',
  }) : super(code: 'permission_denied', rawString: rawString, description: description, suggestedAction: suggestedAction);
}

class CameraUnavailable extends QRPayError {
  const CameraUnavailable({
    String? rawString,
    String description = 'Failed to start camera',
    String suggestedAction = 'Ensure device has a working camera and is not in use',
  }) : super(code: 'camera_unavailable', rawString: rawString, description: description, suggestedAction: suggestedAction);
}

class TorchUnavailable extends QRPayError {
  const TorchUnavailable({
    String? rawString,
    String description = 'No flash unit available',
    String suggestedAction = 'Device does not support torch/flash',
  }) : super(code: 'torch_unavailable', rawString: rawString, description: description, suggestedAction: suggestedAction);
}
