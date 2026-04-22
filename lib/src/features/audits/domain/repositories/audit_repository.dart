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

  FutureEither<AuditSession> start({String? notes});

  FutureEither<AuditSession> show(String uuid);

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
