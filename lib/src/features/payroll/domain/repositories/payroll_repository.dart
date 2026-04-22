import '../../../../utils/typedefs.dart';
import '../entities/payslip.dart';

abstract class PayrollRepository {
  /// Paginated payslip list (most recent first). Optional `year`/`month`
  /// narrow the query — use both to jump to a specific period, or `year`
  /// alone for an annual view.
  FutureEither<List<Payslip>> list({int? year, int? month});

  FutureEither<Payslip> show(int id);
}
