# Inventory Audit — Contract Freeze (T0)

**Authoritative reference for every agent working on the audit feature.** All parallel tracks code against the types, signatures, endpoint paths, and JSON shapes defined below. If an implementation needs to deviate, stop and raise — do not change this doc unilaterally.

Backend source of truth lives at `/Users/othman/Developer/backend/arraf_backend/app/Http/Controllers/Api/InventoryAuditController.php`.

---

## 1. Endpoint map

Base URL: `${API_BASE_URL}` (e.g. `https://arraf_backend.test/api/`).

All endpoints require `Authorization: Bearer <token>`. Accept both User (Sanctum) and ShopEmployee tokens — the server resolves the actor from the token's `tokenable_type`.

| Method | Path | Purpose | Owner | Employee |
|---|---|---|---|---|
| GET  | `shops/my/audits` | paginated list; filter `?status=draft\|in_progress\|completed` | ✓ | ✓ |
| POST | `shops/my/audits` | start a new session; body `{ notes?: string }` | ✓ | **403** |
| GET  | `shops/my/audits/{uuid}` | session detail + live counters | ✓ | ✓ |
| POST | `shops/my/audits/{uuid}/scans` | record a scan — see §4 | ✓ | ✓ (auto-attributed) |
| POST | `shops/my/audits/{uuid}/complete` | freeze session + persist report snapshot | ✓ | **403** |
| GET  | `shops/my/audits/{uuid}/summary` | summary payload only | ✓ | ✓ |
| GET  | `shops/my/audits/{uuid}/missing` | paginated snapshot rows with `scanned_at IS NULL` | ✓ | ✓ |
| GET  | `shops/my/audits/{uuid}/unexpected` | paginated scans with `result='unexpected'` | ✓ | ✓ |

Realtime channel auth: `POST api/broadcasting/auth` (Sanctum-guarded; backend already wired).

Cross-shop access returns `403 Forbidden`. Unknown UUID returns `404 Not Found`. Invalid state transitions return `409 Conflict`. Validation errors return `422 Unprocessable Entity` with `{ status, message, errors: {field: [msgs]} }`.

---

## 2. Envelope shapes

Every successful JSON response wraps the resource:

```json
{
  "status": "success",
  "message": "…",
  "data": { /* resource */ }
}
```

Paginated list responses add a `meta` block:

```json
{
  "status": "success",
  "message": "Success",
  "data": [ /* items */ ],
  "meta": { "current_page": 1, "per_page": 20, "total": 42, "last_page": 3 }
}
```

Errors:

```json
{ "status": "error", "message": "…", "errors": { /* or null for 403/404 */ } }
```

---

## 3. JSON resource shapes

### 3.1 `AuditSession`

```json
{
  "uuid": "9f4a3b82-…",
  "shop_id": 7,
  "status": "in_progress",
  "expected_count": 128,
  "expected_weight_grams": 4213.517,
  "scanned_count": 41,
  "scanned_weight_grams": 1320.045,
  "progress_percent": 32,
  "started_at": "2026-04-22T10:14:05+00:00",
  "completed_at": null,
  "started_by": { "id": 3, "name": "Ali" },
  "completed_by": null,
  "notes": "Q2 audit",
  "channel": "private-shop-audit.17",
  "report_snapshot": null,
  "created_at": "2026-04-22T10:14:05+00:00",
  "updated_at": "2026-04-22T10:19:12+00:00"
}
```

`report_snapshot` is present only when `status == "completed"`. Its shape is in §3.4.

### 3.2 `AuditScan`

```json
{
  "id": 912,
  "result": "valid",
  "barcode_scanned": "7-A1B2C3D4",
  "shop_product_id": 482,
  "shop_employee_id": 11,
  "device_label": "iPad — Floor 1",
  "weight_grams": 3.215,
  "scanned_at": "2026-04-22T10:19:07+00:00"
}
```

`result` is one of: `"valid" | "duplicate" | "not_found" | "unexpected"`.
`weight_grams` and `shop_product_id` are `null` when `result == "not_found"`.

### 3.3 `AuditSessionItem` (returned by `/missing`)

```json
{
  "id": 2201,
  "shop_product_id": 482,
  "barcode": "7-A1B2C3D4",
  "sku": "SKU-7-A1B2C3",
  "name": "22K bracelet",
  "weight_grams": 3.215,
  "scanned_at": null
}
```

### 3.4 `report_snapshot` (completed session)

```json
{
  "expected_count": 128,
  "scanned_count": 125,
  "count_difference": -3,
  "expected_weight": 4213.517,
  "scanned_weight": 4112.110,
  "weight_difference": -101.407,
  "missing_count": 4,
  "unexpected_count": 1,
  "not_found_count": 0
}
```

### 3.5 `POST /scans` response (special — both resources)

```json
{
  "status": "success",
  "message": "Scan recorded.",
  "data": {
    "scan": { /* AuditScan */ },
    "session": { /* AuditSession */ }
  }
}
```

### 3.6 `GET /summary` response

Returns the snapshot shape from §3.4 directly under `data`.

---

## 4. Request bodies

### `POST /shops/my/audits`

```json
{ "notes": "Q2 audit" }
```

`notes` is optional (nullable, max 2000 chars).

### `POST /shops/my/audits/{uuid}/scans`

When the caller is a **User** (owner):

```json
{
  "barcode": "7-A1B2C3D4",
  "shop_employee_id": 11,
  "device_label": "iPad — Floor 1"
}
```

All three fields required.

When the caller is a **ShopEmployee**:

```json
{
  "barcode": "7-A1B2C3D4",
  "device_label": "iPad — Floor 1"
}
```

`shop_employee_id` is optional and ignored server-side — the backend attributes the scan to the authenticated employee.

Validation errors come back as `422` with `errors.barcode`, `errors.shop_employee_id`, `errors.device_label`.

### `POST /shops/my/audits/{uuid}/complete`

Empty body. Owner-only; employee gets `403`.

---

## 5. Dart domain types

Place under `lib/src/features/audits/domain/`.

```dart
// entities/audit_status.dart
enum AuditStatus { draft, inProgress, completed }

// entities/audit_scan_result.dart
enum AuditScanResult { valid, duplicate, notFound, unexpected }

// entities/audit_session.dart
class AuditSession extends Equatable {
  final String uuid;
  final int shopId;
  final AuditStatus status;
  final int expectedCount;
  final double expectedWeightGrams;
  final int scannedCount;
  final double scannedWeightGrams;
  final int progressPercent;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? notes;
  final ActorRef? startedBy;
  final ActorRef? completedBy;
  final String channel;
  final AuditReportSnapshot? reportSnapshot;

  const AuditSession({
    required this.uuid,
    required this.shopId,
    required this.status,
    required this.expectedCount,
    required this.expectedWeightGrams,
    required this.scannedCount,
    required this.scannedWeightGrams,
    required this.progressPercent,
    required this.channel,
    this.startedAt,
    this.completedAt,
    this.notes,
    this.startedBy,
    this.completedBy,
    this.reportSnapshot,
  });

  @override
  List<Object?> get props => [uuid, status, scannedCount, scannedWeightGrams, completedAt];
}

// entities/actor_ref.dart
class ActorRef extends Equatable {
  final int id;
  final String name;
  const ActorRef({required this.id, required this.name});
  @override
  List<Object?> get props => [id, name];
}

// entities/audit_scan.dart
class AuditScan extends Equatable {
  final int id;
  final AuditScanResult result;
  final String barcode;
  final int? shopProductId;
  final int? shopEmployeeId;
  final String deviceLabel;
  final double? weightGrams;
  final DateTime scannedAt;

  const AuditScan({
    required this.id,
    required this.result,
    required this.barcode,
    required this.deviceLabel,
    required this.scannedAt,
    this.shopProductId,
    this.shopEmployeeId,
    this.weightGrams,
  });

  @override
  List<Object?> get props => [id];
}

// entities/audit_session_item.dart
class AuditSessionItem extends Equatable {
  final int id;
  final int shopProductId;
  final String barcode;
  final String? sku;
  final String? name;
  final double? weightGrams;
  final DateTime? scannedAt;

  const AuditSessionItem({
    required this.id,
    required this.shopProductId,
    required this.barcode,
    this.sku,
    this.name,
    this.weightGrams,
    this.scannedAt,
  });

  @override
  List<Object?> get props => [id, scannedAt];
}

// entities/audit_report_snapshot.dart
class AuditReportSnapshot extends Equatable {
  final int expectedCount, scannedCount, countDifference;
  final double expectedWeight, scannedWeight, weightDifference;
  final int missingCount, unexpectedCount, notFoundCount;

  const AuditReportSnapshot({
    required this.expectedCount,
    required this.scannedCount,
    required this.countDifference,
    required this.expectedWeight,
    required this.scannedWeight,
    required this.weightDifference,
    required this.missingCount,
    required this.unexpectedCount,
    required this.notFoundCount,
  });

  @override
  List<Object?> get props => [expectedCount, scannedCount, missingCount, unexpectedCount];
}
```

---

## 6. Repository interface

```dart
// domain/repositories/audit_repository.dart
import 'package:arraf_shop/src/features/audits/domain/entities/audit_session.dart';
import 'package:arraf_shop/src/features/audits/domain/entities/audit_scan.dart';
import 'package:arraf_shop/src/features/audits/domain/entities/audit_session_item.dart';
import 'package:arraf_shop/src/features/audits/domain/entities/audit_report_snapshot.dart';
import 'package:arraf_shop/src/utils/typedefs.dart'; // FutureEither<T>

class ScanResponse {
  final AuditScan scan;
  final AuditSession session;
  const ScanResponse(this.scan, this.session);
}

class Paginated<T> {
  final List<T> items;
  final int currentPage, perPage, total, lastPage;
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
  FutureEither<ScanResponse> recordScan({
    required String uuid,
    required String barcode,
    required String deviceLabel,
    int? shopEmployeeId, // null when caller is a ShopEmployee
  });
  FutureEither<AuditSession> complete(String uuid);
  FutureEither<AuditReportSnapshot> summary(String uuid);
  FutureEither<Paginated<AuditSessionItem>> missing(String uuid, {int page = 1});
  FutureEither<Paginated<AuditScan>> unexpected(String uuid, {int page = 1});
}
```

---

## 7. Realtime interface + event contract

```dart
// domain/realtime/audit_realtime.dart

class AuditScanEvent {
  final int sessionId;
  final int scanId;
  final AuditScanResult result;
  final int scannedCount;
  final double scannedWeight;
  final String barcode;
  final String deviceLabel;
  final DateTime scannedAt;

  const AuditScanEvent({
    required this.sessionId,
    required this.scanId,
    required this.result,
    required this.scannedCount,
    required this.scannedWeight,
    required this.barcode,
    required this.deviceLabel,
    required this.scannedAt,
  });
}

enum RealtimeConnectionState { disconnected, connecting, connected, reconnecting }

abstract class AuditRealtime {
  Stream<AuditScanEvent> subscribe(int sessionId);
  Future<void> unsubscribe(int sessionId);
  Stream<RealtimeConnectionState> get connectionState;
}
```

**Channel name**: `private-shop-audit.{session.id}` (numeric id, not uuid — matches backend).

**Event name as bound**: `scan.recorded`.

**Pusher event payload** (what arrives over the wire; the service parses this into `AuditScanEvent`):

```json
{
  "session_id": 17,
  "scan_id": 912,
  "result": "valid",
  "scanned_count": 42,
  "scanned_weight": 1323.260,
  "barcode": "7-A1B2C3D4",
  "device_label": "iPad — Floor 1",
  "scanned_at": "2026-04-22T10:19:07+00:00"
}
```

**Auth endpoint**: `POST ${API_BASE_URL}broadcasting/auth` with `Authorization: Bearer <token>`. Pusher SDK handles the call when configured with this endpoint + headers.

---

## 8. Enum parsing

```dart
AuditStatus _parseStatus(String v) => switch (v) {
  'draft' => AuditStatus.draft,
  'in_progress' => AuditStatus.inProgress,
  'completed' => AuditStatus.completed,
  _ => throw FormatException('Unknown AuditStatus: $v'),
};

AuditScanResult _parseScanResult(String v) => switch (v) {
  'valid' => AuditScanResult.valid,
  'duplicate' => AuditScanResult.duplicate,
  'not_found' => AuditScanResult.notFound,
  'unexpected' => AuditScanResult.unexpected,
  _ => throw FormatException('Unknown AuditScanResult: $v'),
};
```

Wire-format strings (`in_progress`, `not_found`) are **snake_case** on the server side — parsers must accept exactly those.

---

## 9. Authentication model

### Owner (User) token
- Endpoint: `POST api/signin` → `{ data: { token, user } }`
- Stored in secure-storage key: `auth.owner_token`

### Employee (ShopEmployee) token
- Endpoint: `POST api/shop-employees/login` with `{ code, pin }` → `{ data: { token, employee } }`
- Stored in secure-storage key: `auth.employee_token`
- **Stored separately** from owner token — both may exist on the same device.

### Token selection
The Dio interceptor (Track A) reads whichever token is currently active based on an `authMode` slot (`owner | employee`) written by the login flow.

### Broadcasting auth
The Pusher SDK is configured with the **same** `Authorization: Bearer <token>` header derived from whichever mode is active.

---

## 10. Errors the UI must handle

| Status | When | UI reaction |
|---|---|---|
| `401` | token missing/expired | route to login |
| `403` | cross-shop, or employee hitting owner-only | friendly "not permitted" toast |
| `404` | unknown UUID | return to list with toast |
| `409` | session not in progress (scan or complete), or owner check failed on complete | refresh session + toast |
| `422` | validation failure | inline form errors keyed by `errors.{field}[0]` |
| network | offline / timeout | keep input enabled, show banner |

---

## 11. Conventions every track must follow

- **Entities**: `Equatable`, hand-written (no freezed / json_serializable unless codegen is already set up for this feature — it isn't).
- **Models (data layer)**: extend or compose entities, expose `fromJson(Map<String, dynamic>)` and (where mutated) `toJson()`.
- **Repository returns**: `FutureEither<T>` from `fpdart`. Left = `Failure`, right = success.
- **Repo IO wrapping**: every repo method wraps its Dio call in `runTask(task: …, requiresNetwork: true)` (see `lib/src/utils/task_runner.dart`).
- **Provider state**: `AppStatus` enum (initial / loading / success / failure), plus typed data. No bespoke loading booleans.
- **Strings**: every user-facing string goes through `easy_localization` (`'audit.session.title'.tr()`). No hardcoded English.
- **Date parsing**: `DateTime.parse(iso8601String).toLocal()`.
- **File scope**: each track stays within its `Owns` list in the parallelization plan. If a track needs to touch outside, raise before editing.

---

## 12. Open questions (non-blocking — defaults assumed)

1. **Which mode on startup** — if both tokens exist, default to the most recently used. Track H owns this logic.
2. **Offline scan queue** — out of scope for phase 1. Network failures return `Left(Failure)` and bubble to the user.
3. **Multiple sessions in progress on one shop** — backend doesn't prevent it. UI lists them all; the "resume" action on each card leads to its own session screen.

---

**Questions about this doc?** Raise in the parent backend repo's issue tracker (tagged `mobile-audit`). Do not edit this file unilaterally.
