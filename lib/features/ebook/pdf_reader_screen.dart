import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';

import '../library/state/library_providers.dart';
import '../player/state/playback_controller.dart' show progressRepositoryProvider;
import 'state/ebook_providers.dart';

/// PLAN.md Phase 8.3: PDF reader (paged, no ereader text-styling — that's
/// EPUB-specific per 8.2). Progress synced as page/pageCount, reusing the
/// same `ebookLocation`/`ebookProgress` fields as EPUB — [ebookLocation] is
/// just the page number as a string here rather than a CFI, since pdfx has
/// no CFI-equivalent concept and a page number round-trips fine as the
/// resume point.
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
  int _pageCount = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final item = await ref.read(itemDetailProvider(widget.itemId).future);
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
      final startPage = int.tryParse(item.progress?.ebookLocation ?? '') ?? 1;
      final controller = PdfController(
        document: PdfDocument.openFile(file.path),
        initialPage: startPage,
      );
      setState(() {
        _controller = controller;
        _downloading = false;
      });
      _syncTimer = Timer.periodic(const Duration(seconds: 20), (_) => _sync());
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _sync({bool isFinished = false}) {
    final controller = _controller;
    if (controller == null) return;
    _pageCount = controller.pagesCount ?? _pageCount;
    final fraction = (controller.page / _pageCount).clamp(0.0, 1.0);
    ref
        .read(progressRepositoryProvider)
        .updateEbookProgress(
          libraryItemId: widget.itemId,
          ebookLocation: '${controller.page}',
          ebookProgress: fraction,
          isFinished: isFinished ? true : null,
        )
        .catchError((_) {});
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _sync();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (_controller != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: PdfPageNumber(
                  controller: _controller!,
                  builder: (context, loadingState, page, pagesCount) => Text(
                    '$page / ${pagesCount ?? '?'}',
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _error != null
          ? Center(child: Text('Failed to load: $_error'))
          : _downloading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    value: _downloadProgress > 0 ? _downloadProgress : null,
                  ),
                  const SizedBox(height: 12),
                  const Text('Downloading…'),
                ],
              ),
            )
          : PdfView(
              controller: _controller!,
              onPageChanged: (_) => _sync(),
            ),
    );
  }
}
