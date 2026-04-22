enum AuditScanResult {
  valid,
  duplicate,
  notFound,
  unexpected;

  static AuditScanResult fromString(String value) {
    switch (value) {
      case 'valid':
        return AuditScanResult.valid;
      case 'duplicate':
        return AuditScanResult.duplicate;
      case 'not_found':
        return AuditScanResult.notFound;
      case 'unexpected':
        return AuditScanResult.unexpected;
      default:
        throw FormatException('Unknown AuditScanResult: $value');
    }
  }

  String get wireValue {
    switch (this) {
      case AuditScanResult.valid:
        return 'valid';
      case AuditScanResult.duplicate:
        return 'duplicate';
      case AuditScanResult.notFound:
        return 'not_found';
      case AuditScanResult.unexpected:
        return 'unexpected';
    }
  }
}
