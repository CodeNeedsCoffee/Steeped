import 'package:connectivity_plus/connectivity_plus.dart';
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
