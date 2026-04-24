import '../../../../utils/typedefs.dart';
import '../entities/gold_price_snapshot.dart';

/// Read + admin-update API for the gold price feature.
abstract class GoldPriceRepository {
  /// Fetch the current snapshot for [country] (defaults to "eg" on the
  /// backend if omitted).
  FutureEither<GoldPriceSnapshot> today({String country = 'eg'});

  /// Patch one or more karat/unit fields on the latest record.
  /// Admin-only on the backend (returns 401 otherwise).
  FutureEither<GoldPriceSnapshot> update({
    String country = 'eg',
    required Map<String, double> updates,
  });
}
