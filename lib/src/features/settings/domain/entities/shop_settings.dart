import 'package:equatable/equatable.dart';

/// Owner-editable shop preferences. Currently only [weeklyHolidays] —
/// modeled as ISO weekday integers (1 = Monday … 7 = Sunday) to match
/// the backend wire format exactly.
class ShopSettings extends Equatable {
  final List<int> weeklyHolidays;

  const ShopSettings({this.weeklyHolidays = const []});

  bool isHoliday(int isoWeekday) => weeklyHolidays.contains(isoWeekday);

  ShopSettings copyWith({List<int>? weeklyHolidays}) {
    return ShopSettings(
      weeklyHolidays: weeklyHolidays ?? this.weeklyHolidays,
    );
  }

  @override
  List<Object?> get props => [weeklyHolidays];
}
