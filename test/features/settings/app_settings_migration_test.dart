import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/settings/data/app_settings.dart';

void main() {
  group('AppSettings migration', () {
    test('old single jump interval seeds both directions', () {
      final s = AppSettings.fromJson({'jumpIntervalSeconds': 45});
      expect(s.jumpBackSeconds, 45);
      expect(s.jumpForwardSeconds, 45);
    });

    test('new fields win over the legacy one', () {
      final s = AppSettings.fromJson({
        'jumpIntervalSeconds': 45,
        'jumpBackSeconds': 10,
        'jumpForwardSeconds': 60,
      });
      expect(s.jumpBackSeconds, 10);
      expect(s.jumpForwardSeconds, 60);
    });

    test('legacy cellular bools map to always / never', () {
      final s = AppSettings.fromJson({
        'allowCellularStreaming': false,
        'allowCellularDownloads': true,
      });
      expect(s.cellularStreaming, CellularPolicy.never);
      expect(s.cellularDownloads, CellularPolicy.always);
    });

    test('empty JSON keeps today\'s defaults', () {
      final s = AppSettings.fromJson({});
      expect(s.jumpBackSeconds, 30);
      expect(s.jumpForwardSeconds, 30);
      expect(s.cellularStreaming, CellularPolicy.always);
      expect(s.maskServerAddress, false);
      expect(s.allowSeekOnMediaControls, true);
    });

    test('round-trips through toJson', () {
      const original = AppSettings(
        jumpBackSeconds: 15,
        jumpForwardSeconds: 90,
        cellularStreaming: CellularPolicy.ask,
        maskServerAddress: true,
        allowSeekOnMediaControls: false,
      );
      final back = AppSettings.fromJson(original.toJson());
      expect(back.jumpBackSeconds, 15);
      expect(back.jumpForwardSeconds, 90);
      expect(back.cellularStreaming, CellularPolicy.ask);
      expect(back.maskServerAddress, true);
      expect(back.allowSeekOnMediaControls, false);
    });

    test('unknown policy name falls back to always', () {
      final s = AppSettings.fromJson({'cellularStreaming': 'bogus'});
      expect(s.cellularStreaming, CellularPolicy.always);
    });
  });
}
