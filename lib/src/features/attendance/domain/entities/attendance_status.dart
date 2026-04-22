enum AttendanceStatus {
  present,
  late,
  absent,
  checkedOut;

  static AttendanceStatus fromString(String raw) => switch (raw) {
    'present' => AttendanceStatus.present,
    'late' => AttendanceStatus.late,
    'absent' => AttendanceStatus.absent,
    'checked_out' => AttendanceStatus.checkedOut,
    _ => AttendanceStatus.present,
  };
}
