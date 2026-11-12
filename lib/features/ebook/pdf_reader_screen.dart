import 'dart:async';

import '../streaks/streak_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';

import '../library/state/library_providers.dart';
import 'data/ereader_settings.dart';
import 'ereader_settings_panel.dart';
import 'reader_chrome.dart';
import 'state/ebook_providers.dart';
import '../../l10n/l10n.dart';

/// PLAN.md Phase 8.3: PDF reader. Progress is synced the way the official
/// apps do it so a book can be picked up on any of them: `ebookLocation` is
/// the 1-based page number and `ebookProgress` is `(page - 1) / pageCount`.
/// Paged mode swipes horizontally with snapping; scroll mode is one
/// continuous vertical column.
class PdfReaderScreen extends ConsumerStatefulWidget {
  const PdfReaderScreen({required this.itemId, super.key});

  final String itemId;

  @override
  ConsumerState<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends ConsumerState<PdfReaderScreen> {
  PdfController? _controller;
  double _downloadProgress = 0;
  bool _downloading = true;
  String? _error;
  Timer? _syncTimer;
  String _title = '';
  bool _hasAudio = false;
  int _page = 1;
  int _pageCount = 1;

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
      final repo = ref.read(ebookRepositoryProvider);
      final file = await repo.ensureLocalFile(
        item,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );
      final start = await resolveStartPosition(
        ref,
        widget.itemId,
        fromDetail: item.progress,
      );
      if (!mounted) return;
      _page = (int.tryParse(start?.location ?? '') ?? 1).clamp(1, 1 << 30);
      final controller = PdfController(
        document: PdfDocument.openFile(file.path),
        initialPage: _page,
      );
      setState(() {
        _controller = controller;
        _downloading = false;
      });
      _syncTimer = Timer.periodic(const Duration(seconds: 20), (_) => _sync());
    } catch (e) {
      await ref.read(ebookRepositoryProvider).evict(item);
      if (mounted) setState(() => _error = e.toString());
    }
  }

  double get _fraction =>
      _pageCount <= 1 ? 0 : ((_page - 1) / _pageCount).clamp(0.0, 1.0);

  void _sync({bool isFinished = false}) {
    final controller = _controller;
    if (controller == null) return;
    _pageCount = controller.pagesCount ?? _pageCount;
    saveReadingPosition(
      ref,
      itemId: widget.itemId,
      location: '${controller.page}',
      fraction: _fraction,
      isFinished: ebookFinishedFlag(
        reachedEnd:
            isFinished || (controller.page >= _pageCount && _pageCount > 1),
        hasAudio: _hasAudio,
      ),
    );
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _sync();
    _reading.close();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(ereaderSettingsProvider).valueOrNull ?? const EreaderSettings();
    final scroll = settings.pdfFlow == ReadingFlow.scroll;
    final c = _controller;

    final Widget body = _error != null
        ? Center(
            child: Text(
              context.l10n.failedToLoad(_error ?? ''),
              style: TextStyle(color: settings.textColor),
            ),
          )
        : (_downloading || c == null)
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  value: _downloadProgress > 0 ? _downloadProgress : null,
                  color: settings.textColor,
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.downloading,
                  style: TextStyle(color: settings.textColor),
                ),
              ],
            ),
          )
        : PdfView(
            key: ValueKey(scroll),
            controller: c,
            scrollDirection: scroll ? Axis.vertical : Axis.horizontal,
            pageSnapping: !scroll,
            onDocumentLoaded: (d) => setState(() => _pageCount = d.pagesCount),
            onPageChanged: (p) {
              _reading.touch();
              setState(() => _page = p);
              _sync();
            },
          );

    return ReaderChrome(
      settings: settings,
      title: _title,
      body: body,
      onPrev: c == null ? null : () => c.previousPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      ),
      onNext: c == null ? null : () => c.nextPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      ),
      progress: c == null ? null : _fraction,
      onScrub: c == null
          ? null
          : (f) => c.jumpToPage((f * _pageCount).floor().clamp(0, _pageCount - 1) + 1),
      footerLabel: context.l10n.pageOfTotal(_page, _pageCount),
      actions: [
        IconButton(
          icon: const Icon(Icons.text_fields),
          tooltip: context.l10n.readingSettingsTooltip,
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const SingleChildScrollView(
              child: EreaderSettingsPanel(
                format: EreaderFormat.pdf,
                showTheme: false,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
