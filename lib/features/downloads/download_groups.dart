import '../../core/storage/app_database.dart';

/// One server's downloads, for the grouped Downloads screen.
class DownloadGroup {
  const DownloadGroup({
    required this.key,
    required this.serverUrl,
    required this.profileId,
    required this.items,
    required this.isActive,
  });

  /// Stable id: the profile id, or `url:<server>` for downloads that predate
  /// profiles and were never assigned one.
  final String key;
  final String serverUrl;

  /// Empty for unassigned (pre-profile) downloads.
  final String profileId;
  final List<DownloadedItem> items;
  final bool isActive;
}

/// QOL_PLAN E2.5. Offline, every downloaded book is listed, grouped by the
/// server it came from. Online, the active server's downloads come first and
/// other servers' follow in their own sections -- unless [showOtherServers]
/// is off, which hides them while online.
List<DownloadGroup> groupDownloads(
  List<DownloadedItem> items, {
  required String? activeProfileId,
  required bool offline,
  required bool showOtherServers,
}) {
  final byKey = <String, List<DownloadedItem>>{};
  final meta = <String, (String serverUrl, String profileId)>{};
  for (final item in items) {
    final key = item.profileId.isNotEmpty
        ? item.profileId
        : 'url:${item.serverUrl}';
    byKey.putIfAbsent(key, () => []).add(item);
    meta[key] = (item.serverUrl, item.profileId);
  }

  final groups = [
    for (final entry in byKey.entries)
      DownloadGroup(
        key: entry.key,
        serverUrl: meta[entry.key]!.$1,
        profileId: meta[entry.key]!.$2,
        items: entry.value,
        isActive: activeProfileId != null && entry.key == activeProfileId,
      ),
  ];

  groups.sort((a, b) {
    if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
    return a.serverUrl.compareTo(b.serverUrl);
  });

  if (!offline && !showOtherServers) {
    return [
      for (final g in groups)
        if (g.isActive) g,
    ];
  }
  return groups;
}
