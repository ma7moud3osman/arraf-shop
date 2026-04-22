import 'package:easy_localization/easy_localization.dart';

/// Formats a weight in grams into a localized human-readable string.
///
/// Grams under 1 kg are shown in grams (two decimals), values at or above
/// 1000 g are shown in kilograms (three decimals). The unit suffix reads
/// from the `units.kg` / `units.g` translation keys.
String formatWeight(double grams, {int gramsFractionDigits = 2}) {
  if (grams.abs() >= 1000) {
    return '${(grams / 1000).toStringAsFixed(3)} ${'units.kg'.tr()}';
  }
  return '${grams.toStringAsFixed(gramsFractionDigits)} ${'units.g'.tr()}';
}
