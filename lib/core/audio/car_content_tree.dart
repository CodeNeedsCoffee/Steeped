import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/state/session_controller.dart';
import '../../features/auth/state/session_state.dart';
import '../../features/downloads/state/download_controller.dart';
import '../../features/library/state/library_providers.dart';
import '../../features/localmedia/state/local_media_providers.dart';
import '../../features/player/state/playback_controller.dart';
import '../../models/library_item.dart';
import '../../models/podcast_episode.dart';
import '../network/cover_image_url.dart';

/// PLAN.md Phase 10.1: one source of truth mapping app data onto a
/// browsable node tree — the shared foundation both Android Auto (now) and
/// CarPlay (Milestone 4, Mac-gated) project onto their own UI shells.
///
/// Root order is offline-first (Downloaded, Local Media) before
/// online-only nodes (Continue Listening, Libraries) — Phase 10.2 wants
/// downloaded/local content browsable with zero connectivity, which only
/// works if the nodes leading to it don't themselves require a network
/// call first.
///
/// Takes a plain [ProviderContainer] rather than a [WidgetRef]: this tree
/// is wired into [SteepedAudioHandler] in `main.dart`, before the widget
/// tree (and any [WidgetRef]) exists — see that file's comment on why a
/// manually-created container is used instead of a plain `ProviderScope`.
class CarContentTree {
  CarContentTree(this._container);

  final ProviderContainer _container;

  static const rootId = AudioService.browsableRootId;
  static const _downloadedId = 'downloaded';
  static const _localMediaId = 'local-media';
  static const _continueListeningId = 'continue-listening';
  static const _librariesId = 'libraries';
  static const _libraryPrefix = 'library:';
  static const _podcastPrefix = 'podcast:';

  Future<List<MediaItem>> getChildren(String parentMediaId) async {
    if (parentMediaId == rootId) return _rootChildren();
    if (parentMediaId == _downloadedId) return _downloadedChildren();
    if (parentMediaId == _localMediaId) return _localMediaChildren();
    if (parentMediaId == _continueListeningId) {
      return _continueListeningChildren();
    }
    if (parentMediaId == _librariesId) return _librariesChildren();
    if (parentMediaId.startsWith(_libraryPrefix)) {
      return _libraryItemsChildren(
        parentMediaId.substring(_libraryPrefix.length),
      );
    }
    if (parentMediaId.startsWith(_podcastPrefix)) {
      return _podcastEpisodesChildren(
        parentMediaId.substring(_podcastPrefix.length),
      );
    }
    return const [];
  }

  /// Dispatches a tapped leaf node to the right playback path. Downloaded
  /// items (books or the composite `podcastId::episodeId` episode form)
  /// and local-media imports are checked first since those must work with
  /// zero connectivity (Phase 10.2) — only falling through to a network
  /// fetch once neither local source claims the id.
  Future<void> play(String mediaId) async {
    final controller = _container.read(playbackControllerProvider.notifier);

    if (await _container.read(downloadRepositoryProvider).isDownloaded(mediaId)) {
      await controller.playItem(mediaId);
      return;
    }

    final localItem = await _container
        .read(localMediaRepositoryProvider)
        .buildPlayableItem(mediaId);
    if (localItem != null) {
      await controller.playLocalMedia(mediaId);
      return;
    }

    final episodeIds = _splitEpisodeId(mediaId);
    if (episodeIds != null) {
      final (podcastId, episodeId) = episodeIds;
      final podcast = await _container
          .read(libraryRepositoryProvider)
          .fetchItemDetail(podcastId);
      for (final episode in podcast.episodes) {
        if (episode.id == episodeId) {
          await controller.playEpisode(podcast, episode);
          return;
        }
      }
      return;
    }

    await controller.playItem(mediaId);
  }

  static (String, String)? _splitEpisodeId(String id) {
    final sep = id.indexOf('::');
    if (sep == -1) return null;
    return (id.substring(0, sep), id.substring(sep + 2));
  }

  List<MediaItem> _rootChildren() {
    return const [
      MediaItem(id: _downloadedId, title: 'Downloaded', playable: false),
      MediaItem(id: _localMediaId, title: 'Local Media', playable: false),
      MediaItem(
        id: _continueListeningId,
        title: 'Continue Listening',
        playable: false,
      ),
      MediaItem(id: _librariesId, title: 'Libraries', playable: false),
    ];
  }

  Future<List<MediaItem>> _downloadedChildren() async {
    final items = await _container
        .read(downloadRepositoryProvider)
        .watchDownloads()
        .first;
    return items
        .where((i) => i.status == 'complete')
        .map(
          (i) => MediaItem(
            id: i.itemId,
            title: i.title,
            artist: i.authorNames.isEmpty ? null : i.authorNames,
            duration: i.totalDuration == null
                ? null
                : Duration(milliseconds: (i.totalDuration! * 1000).round()),
            artUri: i.coverLocalPath == null
                ? null
                : Uri.file(i.coverLocalPath!),
          ),
        )
        .toList();
  }

  Future<List<MediaItem>> _localMediaChildren() async {
    final items = await _container
        .read(localMediaRepositoryProvider)
        .watchAll()
        .first;
    return items
        .map(
          (i) => MediaItem(
            id: i.id,
            title: i.title,
            duration: i.durationSeconds == null
                ? null
                : Duration(milliseconds: (i.durationSeconds! * 1000).round()),
          ),
        )
        .toList();
  }

  (String serverUrl, String? token)? _session() {
    final session = _container.read(sessionControllerProvider);
    if (session is! SessionAuthenticated) return null;
    return (session.serverUrl, session.user.effectiveToken);
  }

  /// A podcast browses into its episodes rather than playing directly, so
  /// its node id is prefixed to route back into [_podcastEpisodesChildren]
  /// when Android Auto calls [getChildren] with this item's own id as the
  /// new parent (that's how Android's media-browse API descends a tree —
  /// there's no separate side-channel id, the tapped item's id *is* the
  /// next `getChildren` call's `parentMediaId`).
  MediaItem _mediaItemForLibraryItem(
    LibraryItem item,
    String serverUrl,
    String? token,
  ) {
    final isPodcast = item.mediaType == 'podcast';
    return MediaItem(
      id: isPodcast ? '$_podcastPrefix${item.id}' : item.id,
      title: item.title,
      artist: item.authorOrPublisherName,
      playable: !isPodcast,
      duration: item.duration == null
          ? null
          : Duration(milliseconds: (item.duration! * 1000).round()),
      artUri: Uri.parse(
        coverImageUrl(
          serverUrl: serverUrl,
          itemId: item.id,
          token: token,
          updatedAt: item.updatedAt,
        ),
      ),
    );
  }

  /// [selectedLibraryIdProvider] only ever gets a real value when the user
  /// manually switches libraries via the in-app picker — the home shell's
  /// `?? libraries.first.id` fallback is display-only and never writes
  /// back into the provider. Found via temporary debug logging of the real
  /// tree output against evan's real server/library, then reverted: without
  /// this fallback, "Continue Listening" silently returned empty on every
  /// real device/session that hadn't touched the picker yet — effectively
  /// "always empty" for most users, not just a first-launch edge case.
  Future<String?> _resolveLibraryId() async {
    final selected = _container.read(selectedLibraryIdProvider);
    if (selected != null) return selected;
    final libraries = await _container.read(librariesProvider.future);
    return libraries.isEmpty ? null : libraries.first.id;
  }

  /// Combines both `continue-listening` (audio) and `continue-reading`
  /// (ebook) shelves — confirmed against
  /// `~/Code/audiobookshelf/server/models/LibraryItem.js`'s
  /// `getPersonalizedShelves`, which uses those two distinct ids.
  Future<List<MediaItem>> _continueListeningChildren() async {
    final session = _session();
    if (session == null) return const [];
    final (serverUrl, token) = session;
    final libraryId = await _resolveLibraryId();
    if (libraryId == null) return const [];

    final shelves = await _container.read(
      personalizedShelvesProvider(libraryId).future,
    );
    final items = shelves
        .where((s) => s.id == 'continue-listening' || s.id == 'continue-reading')
        .expand((s) => s.items)
        .toList();
    return items
        .map((i) => _mediaItemForLibraryItem(i, serverUrl, token))
        .toList();
  }

  Future<List<MediaItem>> _librariesChildren() async {
    final libraries = await _container.read(librariesProvider.future);
    return libraries
        .map(
          (l) => MediaItem(
            id: '$_libraryPrefix${l.id}',
            title: l.name,
            playable: false,
          ),
        )
        .toList();
  }

  Future<List<MediaItem>> _libraryItemsChildren(String libraryId) async {
    final session = _session();
    if (session == null) return const [];
    final (serverUrl, token) = session;
    final page = await _container
        .read(libraryRepositoryProvider)
        .fetchLibraryItems(libraryId, page: 0, limit: 40);
    return page.items
        .map((i) => _mediaItemForLibraryItem(i, serverUrl, token))
        .toList();
  }

  Future<List<MediaItem>> _podcastEpisodesChildren(String podcastId) async {
    final session = _session();
    if (session == null) return const [];
    final (serverUrl, token) = session;
    final podcast = await _container
        .read(libraryRepositoryProvider)
        .fetchItemDetail(podcastId);
    return podcast.episodes
        .where((e) => e.audioTrack != null)
        .map((e) => _mediaItemForEpisode(podcast.id, e, serverUrl, token))
        .toList();
  }

  MediaItem _mediaItemForEpisode(
    String podcastId,
    PodcastEpisode episode,
    String serverUrl,
    String? token,
  ) {
    return MediaItem(
      id: '$podcastId::${episode.id}',
      title: episode.title,
      duration: episode.duration == null
          ? null
          : Duration(milliseconds: (episode.duration! * 1000).round()),
      artUri: Uri.parse(
        coverImageUrl(
          serverUrl: serverUrl,
          itemId: podcastId,
          token: token,
          updatedAt: 0,
        ),
      ),
    );
  }
}
