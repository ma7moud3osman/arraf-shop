import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../shared/enums/app_status.dart';
import '../../../../utils/failure.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/repositories/attendance_repository.dart';

/// Today's attendance + live check-in / check-out actions.
///
/// Captures the GPS fix locally (geolocator), sends it to the server, and
/// relies on the server to enforce the shop fence (500m by default) and
/// accuracy threshold — we surface any server rejection as an error message.
class AttendanceProvider extends ChangeNotifier {
  AttendanceProvider({required AttendanceRepository repository})
    : _repository = repository;

  final AttendanceRepository _repository;

  AppStatus _status = AppStatus.initial;
  AppStatus _actionStatus = AppStatus.initial;
  AttendanceRecord? _today;
  String? _errorMessage;

  AppStatus get status => _status;
  AppStatus get actionStatus => _actionStatus;
  AttendanceRecord? get today => _today;
  String? get errorMessage => _errorMessage;

  bool get canCheckIn => _today?.hasCheckedIn != true;
  bool get canCheckOut =>
      (_today?.hasCheckedIn ?? false) && _today?.hasCheckedOut != true;

  Future<void> load() async {
    _status = AppStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.today();
    result.fold(
      (failure) {
        _status = AppStatus.failure;
        _errorMessage = failure.message;
      },
      (record) {
        _today = record;
        _status = AppStatus.success;
      },
    );
    notifyListeners();
  }

  Future<bool> checkIn() => _runAction(
    (lat, lng, acc) => _repository.checkIn(lat: lat, lng: lng, accuracy: acc),
  );

  Future<bool> checkOut() => _runAction(
    (lat, lng, acc) => _repository.checkOut(lat: lat, lng: lng, accuracy: acc),
  );

  Future<bool> _runAction(
    Future<dynamic> Function(double lat, double lng, double? accuracy) call,
  ) async {
    _actionStatus = AppStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final Position? position;
    try {
      position = await _resolvePosition();
    } on _LocationException catch (e) {
      _actionStatus = AppStatus.failure;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }

    final result = await call(
      position.latitude,
      position.longitude,
      position.accuracy,
    );
    final success = (result as dynamic).fold<bool>(
      (Failure failure) {
        _actionStatus = AppStatus.failure;
        _errorMessage = failure.message;
        return false;
      },
      (AttendanceRecord record) {
        _today = record;
        _actionStatus = AppStatus.success;
        return true;
      },
    );
    notifyListeners();
    return success;
  }

  /// Ensures location services are on + permission is granted, then returns a
  /// high-accuracy fix with a 10s timeout. Throws [_LocationException] with
  /// a user-friendly message on any failure.
  Future<Position> _resolvePosition() async {
    final servicesOn = await Geolocator.isLocationServiceEnabled();
    if (!servicesOn) {
      throw const _LocationException('attendance.errors.location_services_off');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const _LocationException('attendance.errors.permission_denied');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const _LocationException('attendance.errors.permission_permanent');
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      throw const _LocationException('attendance.errors.fix_timeout');
    }
  }
}

class _LocationException implements Exception {
  const _LocationException(this.message);
  final String message;
}
