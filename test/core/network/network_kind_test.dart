import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/core/network/connectivity_service.dart';

void main() {
  group('classifyNetwork', () {
    test('mobile only is cellular', () {
      expect(
        classifyNetwork([ConnectivityResult.mobile], true),
        NetworkKind.cellular,
      );
    });
    test('wifi + mobile counts as wifi', () {
      expect(
        classifyNetwork([ConnectivityResult.wifi, ConnectivityResult.mobile], false),
        NetworkKind.unmetered,
      );
    });
    test('metered wifi (hotspot) is its own kind', () {
      expect(
        classifyNetwork([ConnectivityResult.wifi], true),
        NetworkKind.meteredWifi,
      );
    });
    test('unknown metered flag (iOS) never claims metered', () {
      expect(
        classifyNetwork([ConnectivityResult.wifi], null),
        NetworkKind.unmetered,
      );
    });
    test('nothing connected', () {
      expect(classifyNetwork([ConnectivityResult.none], null), NetworkKind.none);
      expect(classifyNetwork(const [], null), NetworkKind.none);
    });
  });

  group('countsAsCellular', () {
    test('cellular always counts', () {
      expect(countsAsCellular(NetworkKind.cellular, treatMeteredAsCellular: false), isTrue);
    });
    test('metered wifi only with the setting', () {
      expect(countsAsCellular(NetworkKind.meteredWifi, treatMeteredAsCellular: false), isFalse);
      expect(countsAsCellular(NetworkKind.meteredWifi, treatMeteredAsCellular: true), isTrue);
    });
    test('plain wifi never counts', () {
      expect(countsAsCellular(NetworkKind.unmetered, treatMeteredAsCellular: true), isFalse);
    });
  });
}
