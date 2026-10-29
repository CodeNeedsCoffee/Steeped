import 'dart:io' show Platform;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = Provider<Connectivity>((ref) => Connectivity());

/// PLAN.md Phase 9.3 (Data/cellular controls): true only when the active
/// connection is cellular with no wifi/ethernet also up.
Future<bool> isOnCellularConnection(Connectivity connectivity) async {
  final results = await connectivity.checkConnectivity();
  return results.contains(ConnectivityResult.mobile) &&
      !results.contains(ConnectivityResult.wifi) &&
      !results.contains(ConnectivityResult.ethernet);
}

/// QOL_PLAN E1: what the active connection is, for the Live badge and the
/// "treat metered Wi-Fi like cellular" setting.
enum NetworkKind { none, unmetered, cellular, meteredWifi }

/// Pure classification of a connectivity result. [metered] is Android's
/// `isActiveNetworkMetered` (null where unknown, i.e. iOS).
NetworkKind classifyNetwork(List<ConnectivityResult> results, bool? metered) {
  final hasWifi =
      results.contains(ConnectivityResult.wifi) ||
      results.contains(ConnectivityResult.ethernet);
  if (results.contains(ConnectivityResult.mobile) && !hasWifi) {
    return NetworkKind.cellular;
  }
  if (hasWifi) {
    return metered == true ? NetworkKind.meteredWifi : NetworkKind.unmetered;
  }
  if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
    return NetworkKind.none;
  }
  return NetworkKind.unmetered;
}

/// Whether [kind] should be treated as cellular for the Ask/Never data
/// policy. Metered Wi-Fi only counts when [treatMeteredAsCellular] is on.
bool countsAsCellular(NetworkKind kind, {required bool treatMeteredAsCellular}) {
  return kind == NetworkKind.cellular ||
      (treatMeteredAsCellular && kind == NetworkKind.meteredWifi);
}

/// Android's metered flag via the existing native channel; null on iOS or
/// on any channel failure.
Future<bool?> isActiveNetworkMetered() async {
  if (!Platform.isAndroid) return null;
  try {
    return await const MethodChannel(
      'steeped/device_storage',
    ).invokeMethod<bool>('isMetered');
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  }
}

Future<NetworkKind> currentNetworkKind(Connectivity connectivity) async {
  final results = await connectivity.checkConnectivity();
  return classifyNetwork(results, await isActiveNetworkMetered());
}

/// Live network kind, re-evaluated on every connectivity change.
final networkKindProvider = StreamProvider<NetworkKind>((ref) async* {
  final connectivity = ref.watch(connectivityProvider);
  yield await currentNetworkKind(connectivity);
  await for (final results in connectivity.onConnectivityChanged) {
    yield classifyNetwork(results, await isActiveNetworkMetered());
  }
});
