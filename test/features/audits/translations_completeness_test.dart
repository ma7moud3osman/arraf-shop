import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Parses [assets/translations/en.json] and [ar.json] and asserts:
///   * both files are valid JSON
///   * every dot-path under `audits.*` present in one is also present in the other
///   * every known audit key used by the UI (see [_knownAuditKeys]) resolves
///
/// The known-keys list is sourced from a grep of `.tr()` call sites across
/// lib/src/features/audits. If a screen introduces a new key, add it here;
/// this test will fail clearly instead of surfacing an untranslated key at
/// runtime.
void main() {
  final projectRoot = Directory.current.path;
  final en = _readJson('$projectRoot/assets/translations/en.json');
  final ar = _readJson('$projectRoot/assets/translations/ar.json');

  group('translations completeness — audits', () {
    test('English file contains an `audits` block', () {
      expect(en['audits'], isA<Map<String, dynamic>>());
    });

    test('Arabic file contains an `audits` block', () {
      expect(ar['audits'], isA<Map<String, dynamic>>());
    });

    test('every key used by the UI resolves in both locales', () {
      final missingEn = <String>[];
      final missingAr = <String>[];

      for (final key in _knownAuditKeys) {
        if (_resolve(en, key) == null) missingEn.add(key);
        if (_resolve(ar, key) == null) missingAr.add(key);
      }

      expect(
        missingEn,
        isEmpty,
        reason: 'en.json is missing audit keys: $missingEn',
      );
      expect(
        missingAr,
        isEmpty,
        reason: 'ar.json is missing audit keys: $missingAr',
      );
    });

    test('audits.* key sets match across locales (no orphans)', () {
      final enKeys = _flatten(en['audits'] as Map<String, dynamic>, 'audits');
      final arKeys = _flatten(ar['audits'] as Map<String, dynamic>, 'audits');

      final onlyInEn = enKeys.difference(arKeys);
      final onlyInAr = arKeys.difference(enKeys);

      expect(onlyInEn, isEmpty, reason: 'Keys only in en.json: $onlyInEn');
      expect(onlyInAr, isEmpty, reason: 'Keys only in ar.json: $onlyInAr');
    });

    test('no audit key has an empty string value in either locale', () {
      final blankEn = _blanks(en['audits'] as Map<String, dynamic>, 'audits');
      final blankAr = _blanks(ar['audits'] as Map<String, dynamic>, 'audits');

      expect(blankEn, isEmpty, reason: 'Blank EN values: $blankEn');
      expect(blankAr, isEmpty, reason: 'Blank AR values: $blankAr');
    });
  });
}

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

Map<String, dynamic> _readJson(String path) {
  final text = File(path).readAsStringSync();
  return jsonDecode(text) as Map<String, dynamic>;
}

/// Returns the string at [dotPath], or `null` if any segment is missing.
String? _resolve(Map<String, dynamic> root, String dotPath) {
  dynamic node = root;
  for (final segment in dotPath.split('.')) {
    if (node is! Map<String, dynamic>) return null;
    if (!node.containsKey(segment)) return null;
    node = node[segment];
  }
  return node is String ? node : null;
}

/// Flattens a translation map into dot-notation keys, prefixed with [prefix].
Set<String> _flatten(Map<String, dynamic> map, String prefix) {
  final out = <String>{};
  void walk(Map<String, dynamic> m, String path) {
    for (final entry in m.entries) {
      final next = '$path.${entry.key}';
      final v = entry.value;
      if (v is Map<String, dynamic>) {
        walk(v, next);
      } else {
        out.add(next);
      }
    }
  }

  walk(map, prefix);
  return out;
}

/// Returns dot-paths whose leaf value is an empty or whitespace-only string.
List<String> _blanks(Map<String, dynamic> map, String prefix) {
  final out = <String>[];
  void walk(Map<String, dynamic> m, String path) {
    for (final entry in m.entries) {
      final next = '$path.${entry.key}';
      final v = entry.value;
      if (v is Map<String, dynamic>) {
        walk(v, next);
      } else if (v is String && v.trim().isEmpty) {
        out.add(next);
      }
    }
  }

  walk(map, prefix);
  return out;
}

/// Every audit-feature translation key found via
/// `grep -rnE "['\"]audits\\." lib/src/features/audits`.
/// Keep alphabetised.
const _knownAuditKeys = <String>{
  'audits.list.empty_subtitle',
  'audits.list.empty_title',
  'audits.list.load_failed',
  'audits.list.progress_counts',
  'audits.list.start_failed',
  'audits.list.start_new',
  'audits.list.title',
  'audits.list.untitled',
  'audits.scan.duplicate',
  'audits.scan.not_found',
  'audits.scan.unexpected',
  'audits.scan.valid',
  'audits.scanner.camera_error',
  'audits.scanner.grant_permission',
  'audits.scanner.open_settings',
  'audits.scanner.permission_denied_body',
  'audits.scanner.permission_denied_title',
  'audits.scanner.switch_camera',
  'audits.scanner.torch_off',
  'audits.scanner.torch_on',
  'audits.session.complete',
  'audits.session.complete_failed',
  'audits.session.completed_at',
  'audits.session.feed_empty',
  'audits.session.load_failed',
  'audits.session.loading',
  'audits.session.progress_title',
  'audits.session.scan_failed',
  'audits.session.title',
  'audits.session.weight_title',
  'audits.status.completed',
  'audits.status.draft',
  'audits.status.in_progress',
  'audits.summary.count_difference',
  'audits.summary.expected_count',
  'audits.summary.expected_weight',
  'audits.summary.load_failed',
  'audits.summary.loading',
  'audits.summary.missing',
  'audits.summary.missing_failed',
  'audits.summary.missing_label',
  'audits.summary.no_missing',
  'audits.summary.no_unexpected',
  'audits.summary.not_found_label',
  'audits.summary.overview',
  'audits.summary.scanned_count',
  'audits.summary.scanned_weight',
  'audits.summary.title',
  'audits.summary.unexpected',
  'audits.summary.unexpected_failed',
  'audits.summary.unexpected_label',
  'audits.summary.weight_difference',
};
