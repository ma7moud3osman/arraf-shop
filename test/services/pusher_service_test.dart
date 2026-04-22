import 'package:arraf_shop/src/services/pusher_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PusherService channel naming', () {
    test('channelFor builds the contract-defined private channel name', () {
      expect(PusherService.channelFor(17), 'private-shop-audit.17');
      expect(PusherService.channelFor(1), 'private-shop-audit.1');
    });

    test('sessionIdFromChannel round-trips numeric ids', () {
      expect(PusherService.sessionIdFromChannel('private-shop-audit.17'), 17);
      expect(
        PusherService.sessionIdFromChannel('private-shop-audit.9000'),
        9000,
      );
    });

    test('sessionIdFromChannel returns null for unrelated channel names', () {
      expect(PusherService.sessionIdFromChannel('presence-shop.1'), isNull);
      expect(PusherService.sessionIdFromChannel('private-other.17'), isNull);
      expect(
        PusherService.sessionIdFromChannel('private-shop-audit.abc'),
        isNull,
      );
    });
  });
}
