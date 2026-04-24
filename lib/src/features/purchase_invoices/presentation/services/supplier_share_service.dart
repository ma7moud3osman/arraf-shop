import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Thin abstraction around [launchUrl] / [Share] so the share-with-supplier
/// flow can be exercised end-to-end in widget tests with a fake.
///
/// Production code injects [DefaultSupplierShareService]; tests inject a
/// recording fake. Keep this surface narrow — only the calls the share
/// sheet actually makes.
abstract class SupplierShareService {
  /// Open the URL in the platform default handler. Returns whether the
  /// launch was accepted by the OS.
  Future<bool> openUrl(Uri uri);

  /// Show the native share sheet for [text] (with an optional [subject]
  /// that some platforms surface as the email subject line).
  Future<void> shareText(String text, {String? subject});
}

/// Default implementation backed by `url_launcher` and `share_plus`.
class DefaultSupplierShareService implements SupplierShareService {
  const DefaultSupplierShareService();

  @override
  Future<bool> openUrl(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Future<void> shareText(String text, {String? subject}) async {
    await Share.share(text, subject: subject);
  }
}

/// Default Egypt country code prefix used when a supplier phone number is
/// stored without one. The shop is Egypt-based; if/when we go
/// multi-tenant this should move to per-shop config.
const String kDefaultCountryDialPrefix = '20';

/// Strips every non-digit from [raw] and prepends [defaultDialPrefix] when
/// the input doesn't already include a country code (i.e. it doesn't start
/// with `+` or `00`). Returns `null` if no digits remain.
String? normalizeWhatsAppPhone(
  String? raw, {
  String defaultDialPrefix = kDefaultCountryDialPrefix,
}) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final hasCountryCode = trimmed.startsWith('+') || trimmed.startsWith('00');
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;

  if (hasCountryCode) {
    // `00` is the international-access form of `+`; drop it so wa.me sees
    // a bare country-code-prefixed number.
    return trimmed.startsWith('00') ? digits.substring(2) : digits;
  }

  // Egyptian mobile numbers are stored locally as `01xxxxxxxxx`. wa.me
  // wants `201xxxxxxxxx` — strip the leading 0 before prepending.
  final withoutLeadingZero =
      digits.startsWith('0') ? digits.substring(1) : digits;
  return '$defaultDialPrefix$withoutLeadingZero';
}

/// Build the canonical wa.me deep link for a normalized phone + message.
Uri buildWhatsAppUri({required String phoneDigits, required String message}) {
  return Uri.parse(
    'https://wa.me/$phoneDigits?text=${Uri.encodeComponent(message)}',
  );
}
