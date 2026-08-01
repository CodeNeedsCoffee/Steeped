import 'package:flutter/services.dart';

/// PLAN.md Phase 6.10: free device-storage space, for the low-storage
/// warning on the Downloads screen. A small native `StatFs` call via
/// platform channel rather than a pub dependency — no cross-package
/// `image`-style version conflict risk, and this project already keeps
/// `flutter_launcher_icons`/`flutter_native_splash` out of pubspec.yaml for
/// exactly that reason (see Phase 8.1's note there).
///
/// Android-only for now, matching Phase 6's own iOS deferral (background
/// URLSession + sandbox paths land at the Xcode checkpoint 3 pass). Returns
/// null on iOS or any platform-channel failure; callers treat null as
/// "unknown" and simply skip the low-storage banner.
class DeviceStorage {
  DeviceStorage._();

  static const _channel = MethodChannel('steeped/device_storage');

  static Future<int?> freeBytes() async {
    try {
      return await _channel.invokeMethod<int>('freeBytes');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
