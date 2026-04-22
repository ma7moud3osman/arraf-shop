import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'secure_storage_service.dart';

/// Signs Pusher private-channel auth requests against the Laravel backend.
///
/// The Pusher SDK invokes an "authorizer" callback for each private channel;
/// this helper performs the actual `POST api/broadcasting/auth` call with the
/// active bearer token (owner or employee — whichever is current per
/// [SecureStorageService.readActiveToken]).
///
/// Returned map is forwarded verbatim to the Pusher SDK, which expects:
/// ```
/// { "auth": "<app_key>:<hmac>", "channel_data"?: "..." }
/// ```
class AuthEndpointSigner {
  AuthEndpointSigner({Dio? dio, SecureStorageService? storage})
    : _dio = dio ?? AppConfig.dio,
      _storage = storage ?? SecureStorageService.instance;

  final Dio _dio;
  final SecureStorageService _storage;

  /// Perform the auth round-trip. Pass the `socketId` Pusher hands to us and
  /// the `channelName` we're trying to join.
  ///
  /// Throws on HTTP failure so the Pusher SDK marks the subscription as
  /// failed; callers receive a `subscription_error` event.
  Future<Map<String, dynamic>> sign({
    required String socketId,
    required String channelName,
  }) async {
    final token = await _storage.readActiveToken();
    if (token == null || token.isEmpty) {
      throw StateError(
        'No active auth token; cannot sign channel $channelName',
      );
    }

    final response = await _dio.post<Map<String, dynamic>>(
      'broadcasting/auth',
      data: {'socket_id': socketId, 'channel_name': channelName},
      options: Options(
        // Dio's interceptor will also inject the header, but we set it here
        // explicitly so a misconfigured base-dio still gets the right token
        // for this single call.
        headers: {'Authorization': 'Bearer $token'},
        contentType: Headers.formUrlEncodedContentType,
      ),
    );

    final body = response.data;
    if (body == null) {
      throw StateError('Empty auth response for channel $channelName');
    }
    return body;
  }
}
