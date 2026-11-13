import 'dart:async';
import '../linking/link_providers.dart';
import '../linking/linked_listen_action.dart';
import '../streaks/streak_providers.dart';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../library/state/library_providers.dart';
import 'data/ereader_settings.dart';
import 'ereader_settings_panel.dart';
import 'reader_chrome.dart';
import 'state/ebook_providers.dart';
import '../../l10n/l10n.dart';

const _imageExts = {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp'};

/// Runs off the UI isolate via [compute] — a 128MB-class CBZ (confirmed
/// real-world size against evan's server) would otherwise jank the UI
/// thread while decoding.
List<Uint8List> _decodeCbzPages(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final entries = archive.files.where((f) {
    if (!f.isFile) return false;
    final lower = f.name.toLowerCase();
    return _imageExts.any(lower.endsWith);
  }).toList()
    ..sort((a, b) => _naturalCompare(a.name, b.name));
  return entries.map((f) => f.content as Uint8List).toList();
}

/// Sorts "page2.jpg" before "page10.jpg" — plain string sort would put
/// "page10" before "page2".
int _naturalCompare(String a, String b) {
  final re = RegExp(r'(\d+)|(\D+)');
  final aParts = re.allMatches(a).map((m) => m.group(0)!).toList();
  final bParts = re.allMatches(b).map((m) => m.group(0)!).toList();
  for (var i = 0; i < aParts.length && i < bParts.length; i++) {
    final an = int.tryParse(aParts[i]);
    final bn = int.tryParse(bParts[i]);
    final cmp = (an != null && bn != null)
        ? an.compareTo(bn)
        : aParts[i].compareTo(bParts[i]);
    if (cmp != 0) return cmp;
  }
  return aParts.length.compareTo(bParts.length);
}

/// PLAN.md Phase 8.4: CBZ comic reader. CBR (RAR-based) is not supported —
/// `archive` (pure Dart, no native deps) only decodes zip and a handful of
/// other formats, none of which is RAR, and no maintained pure-Dart RAR
/// decoder exists — see [EbookFile.isSupported].
class ComicReaderScreen extends ConsumerStatefulWidget {
  const ComicReaderScreen({required this.itemId, super.key});

  final String itemId;

  @override
  ConsumerState<ComicReaderScreen> createState() => _ComicReaderScreenState();
}

class _ComicReaderScreenState extends ConsumerState<ComicReaderScreen> {
  List<Uint8List>? _pages;
  double _downloadProgress = 0;
  bool _extracting = false;
  String? _error;
  String _title = '';
  bool _hasAudio = false;
  int _currentPage = 0; // 0-based in memory, 1-based on the wire
  Timer? _syncTimer;
  PageController? _pageController;
  final _listController = ItemScrollController();
  final _positions = ItemPositionsListener.create();

  late final ReadingTracker _reading;

  @override
  void initState() {
    super.initState();
    _reading = ReadingTracker(ProviderScope.containerOf(context, listen: false))
      ..touch();
    _load();
  }

  Future<void> _load() async {
    final item = await ref.read(itemDetailProvider(widget.itemId).future);
    _title = item.title;
    _hasAudio = item.tracks.isNotEmpty;
    try {
      final file = await ref
          .read(ebookRepositoryProvider)
          .ensureLocalFile(
            item,
            onProgress: (p) {
              if (mounted) setState(() => _downloadProgress = p);
            },
          );
      if (!mounted) return;
      setState(() => _extracting = true);
      final bytes = await File(file.path).readAsBytes();
      final pages = await compute(_decodeCbzPages, bytes);
      final start = await resolveStartPosition(
        ProviderScope.containerOf(context, listen: false),
        widget.itemId,
        fromDetail: item.progress,
      );
      if (!mounted) return;
      // The official apps store a 1-based page number.
      var startPage = (int.tryParse(start?.location ?? '') ?? 1) - 1;
      // A switch from the linked audiobook picked the spot (a fraction).
      final jump = ref.read(pendingEbookJumpProvider)[widget.itemId];
      if (jump != null) {
        ref
            .read(pendingEbookJumpProvider.notifier)
            .update((m) => {...m}..remove(widget.itemId));
        startPage = (jump * pages.length).floor();
      }
      _currentPage = startPage.clamp(0, (pages.length - 1).clamp(0, 1 << 30));
      _pageController = PageController(initialPage: _currentPage);
      _positions.itemPositions.addListener(_onScrolled);
      setState(() {
        _pages = pages;
        _extracting = false;
      });
      _syncTimer = Timer.periodic(const Duration(seconds: 20), (_) => _sync());
    } catch (e) {
      await ref.read(ebookRepositoryProvider).evict(item);
      if (mounted) setState(() => _error = e.toString());
    }
  }

  /// Scroll mode: the page occupying most of the top of the viewport.
  void _onScrolled() {
    _reading.touch();
    final visible = _positions.itemPositions.value;
    if (visible.isEmpty) return;
    final top = visible
        .where((p) => p.itemTrailingEdge > 0.2)
        .reduce((a, b) => a.itemLeadingEdge < b.itemLeadingEdge ? a : b);
    if (top.index != _currentPage && mounted) {
      setState(() => _currentPage = top.index);
    }
  }

  double get _fraction {
    final n = _pages?.length ?? 0;
    return n <= 1 ? 0 : (_currentPage / n).clamp(0.0, 1.0);
  }

  void _sync({bool isFinished = false}) {
    final pages = _pages;
    if (pages == null || pages.isEmpty) return;
    saveReadingPosition(
      ref,
      itemId: widget.itemId,
      location: '${_currentPage + 1}',
      fraction: _fraction,
      isFinished: ebookFinishedFlag(
        reachedEnd: isFinished || _currentPage >= pages.length - 1,
        hasAudio: _hasAudio,
      ),
    );
  }

  void _goTo(int page) {
    final n = _pages?.length ?? 0;
    if (n == 0) return;
    final p = page.clamp(0, n - 1);
    if (_pageController?.hasClients ?? false) {
      _pageController!.jumpToPage(p);
    }
    if (_listController.isAttached) _listController.jumpTo(index: p);
    setState(() => _currentPage = p);
    _sync();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _positions.itemPositions.removeListener(_onScrolled);
    _sync();
    _reading.close();
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(ereaderSettingsProvider).valueOrNull ?? const EreaderSettings();
    final scroll = settings.comicFlow == ReadingFlow.scroll;
    final pages = _pages;

    final Widget body = _error != null
        ? Center(
            child: Text(
              context.l10n.failedToLoad(_error ?? ''),
              style: const TextStyle(color: Colors.white),
            ),
          )
        : pages == null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  value: !_extracting && _downloadProgress > 0
                      ? _downloadProgress
                      : null,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                Text(
                  _extracting
                      ? context.l10n.extractingPages
                      : context.l10n.downloadingEllipsis,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          )
        : scroll
        // Continuous vertical strip: pages stack at full width.
        ? ScrollablePositionedList.builder(
            key: const ValueKey('scroll'),
            itemCount: pages.length,
            initialScrollIndex: _currentPage,
            itemScrollController: _listController,
            itemPositionsListener: _positions,
            itemBuilder: (context, i) => Image.memory(
              pages[i],
              fit: BoxFit.fitWidth,
              width: double.infinity,
              gaplessPlayback: true,
            ),
          )
        // Confirmed live: an InteractiveViewer here (for pinch-zoom)
        // silently breaks page-swiping — see git history — so paged mode
        // stays a plain PageView.
        : PageView.builder(
            key: const ValueKey('paged'),
            controller: PageController(initialPage: _currentPage),
            itemCount: pages.length,
            onPageChanged: (index) {
              _reading.touch();
              setState(() => _currentPage = index);
              _sync();
            },
            itemBuilder: (context, index) => Center(
              child: Image.memory(pages[index], fit: BoxFit.contain),
            ),
          );

    return ReaderChrome(
      // Comics stay on black whatever the text theme is.
      settings: settings.copyWith(theme: EreaderTheme.black),
      title: _title,
      body: body,
      // In paged mode the PageView owns swipes; edge taps jump a page. In
      // scroll mode taps only toggle the bars.
      onPrev: pages == null || scroll ? null : () => _goTo(_currentPage - 1),
      onNext: pages == null || scroll ? null : () => _goTo(_currentPage + 1),
      progress: pages == null ? null : _fraction,
      onScrub: pages == null
          ? null
          : (f) => _goTo((f * pages.length).floor()),
      footerLabel: pages == null
          ? null
          : context.l10n.pageOfTotal(_currentPage + 1, pages.length),
      actions: [
        LinkedListenAction(itemId: widget.itemId, saveFirst: _sync),
        IconButton(
          icon: const Icon(Icons.tune),
          tooltip: context.l10n.readingSettingsTooltip,
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const SingleChildScrollView(
              child: EreaderSettingsPanel(
                format: EreaderFormat.comic,
                showTheme: false,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
