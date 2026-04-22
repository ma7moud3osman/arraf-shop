import '../../../../utils/typedefs.dart';
import '../entities/attendance_record.dart';

abstract class AttendanceRepository {
  /// `GET /attendance/today` — returns today's record, or `null` if the
  /// employee hasn't checked in yet.
  FutureEither<AttendanceRecord?> today();

  /// `POST /attendance/check-in` — returns the freshly created record.
  /// Server enforces the GPS fence; a failure comes back as a Failure
  /// with a human-readable message.
  FutureEither<AttendanceRecord> checkIn({
    required double lat,
    required double lng,
    double? accuracy,
  });

  /// `POST /attendance/check-out` — updates today's record and returns it.
  FutureEither<AttendanceRecord> checkOut({
    required double lat,
    required double lng,
    double? accuracy,
  });

  /// `GET /attendance/me?year=&month=` — records for a calendar month.
  FutureEither<List<AttendanceRecord>> history({
    required int year,
    required int month,
  });
}
