enum AuditStatus {
  draft,
  inProgress,
  completed;

  static AuditStatus fromString(String value) {
    switch (value) {
      case 'draft':
        return AuditStatus.draft;
      case 'in_progress':
        return AuditStatus.inProgress;
      case 'completed':
        return AuditStatus.completed;
      default:
        throw FormatException('Unknown AuditStatus: $value');
    }
  }

  String get wireValue {
    switch (this) {
      case AuditStatus.draft:
        return 'draft';
      case AuditStatus.inProgress:
        return 'in_progress';
      case AuditStatus.completed:
        return 'completed';
    }
  }
}
