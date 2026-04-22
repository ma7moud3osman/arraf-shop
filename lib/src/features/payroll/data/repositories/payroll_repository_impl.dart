import 'package:fpdart/fpdart.dart';

import '../../../../services/dio_service.dart';
import '../../../../utils/failure.dart';
import '../../../../utils/typedefs.dart';
import '../../domain/entities/payslip.dart';
import '../../domain/repositories/payroll_repository.dart';
import '../models/payslip_model.dart';

class PayrollRepositoryImpl implements PayrollRepository {
  PayrollRepositoryImpl({DioService? dio}) : _dio = dio ?? DioService.instance;

  final DioService _dio;

  @override
  FutureEither<List<Payslip>> list({int? year, int? month}) async {
    final result = await _dio.get(
      'payroll',
      queryParameters: {
        if (year != null) 'year': year,
        if (month != null) 'month': month,
      },
    );
    return result.flatMap((response) {
      final body = response.data as Map<String, dynamic>;
      final raw = body['data'];
      final list = raw is List ? raw : <dynamic>[];
      final payslips = list
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => PayslipModel.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      return right<Failure, List<Payslip>>(payslips);
    });
  }

  @override
  FutureEither<Payslip> show(int id) async {
    final result = await _dio.get('payroll/$id');
    return result.flatMap((response) {
      final body = response.data as Map<String, dynamic>;
      final data = Map<String, dynamic>.from(body['data'] as Map);
      return right(PayslipModel.fromJson(data));
    });
  }
}
