/// Formats a weight in grams into a human-readable string.
///
/// Grams under 1 kg are shown in grams (two decimals), values at or above
/// 1000 g are shown in kilograms (three decimals). The unit suffix is always
/// included, e.g. `"987.50 g"`, `"1.234 kg"`.
String formatWeight(double grams, {int gramsFractionDigits = 2}) {
  if (grams.abs() >= 1000) {
    return '${(grams / 1000).toStringAsFixed(3)} kg';
  }
  return '${grams.toStringAsFixed(gramsFractionDigits)} g';
}
