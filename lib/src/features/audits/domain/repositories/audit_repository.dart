import 'package:arraf_shop/src/utils/typedefs.dart';

import '../entities/audit_report_snapshot.dart';
import '../entities/audit_scan.dart';
import '../entities/audit_session.dart';
import '../entities/audit_session_item.dart';

class ScanResponse {
  final AuditScan scan;
  final AuditSession session;

  const ScanResponse({required this.scan, required this.session});
}

class SessionWithScans {
  final AuditSession session;
  final List<AuditScan> recentScans;

  const SessionWithScans({required this.session, this.recentScans = const []});
}

class Paginated<T> {
  final List<T> items;
  final int currentPage;
  final int perPage;
  final int total;
  final int lastPage;

  const Paginated({
    required this.items,
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  bool get hasMore => currentPage < lastPage;
}

abstract class AuditRepository {
  FutureEither<Paginated<AuditSession>> list({int page = 1, String? status});

  /// Start a new audit session.
  ///
  /// [participantEmployeeIds] is the list of `shop_employee` ids permitted
  /// to scan/view the session. The backend rejects empty arrays for
  /// non-owner-only sessions and 422s with `messages.audit_session.already_active`
  /// when there's already an in-progress session for this shop.
  FutureEither<AuditSession> start({
    String? notes,
    List<int> participantEmployeeIds = const [],
  });

  FutureEither<SessionWithScans> show(String uuid);

  /// Records a scan against an in-progress session.
  ///
  /// [shopEmployeeId] is required when the caller is a User (owner) and is
  /// ignored when the caller is a ShopEmployee (the backend attributes the
  /// scan to the authenticated employee).
  FutureEither<ScanResponse> recordScan({
    required String uuid,
    required String barcode,
    required String deviceLabel,
    int? shopEmployeeId,
  });

  FutureEither<AuditSession> complete(String uuid);

  FutureEither<AuditReportSnapshot> summary(String uuid);

  FutureEither<Paginated<AuditSessionItem>> missing(
    String uuid, {
    int page = 1,
  });

  FutureEither<Paginated<AuditScan>> unexpected(String uuid, {int page = 1});
}
