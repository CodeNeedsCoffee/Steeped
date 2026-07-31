import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../library/state/library_providers.dart';
import '../player/state/playback_controller.dart' show progressRepositoryProvider;
import 'state/ebook_providers.dart';

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
  int _currentPage = 0;
  Timer? _syncTimer;
  late final PageController _pageController;

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
      setState(() => _extracting = true);
      final bytes = await File(file.path).readAsBytes();
      final pages = await compute(_decodeCbzPages, bytes);
      if (!mounted) return;
      final startPage = int.tryParse(item.progress?.ebookLocation ?? '') ?? 0;
      _currentPage = startPage.clamp(0, (pages.length - 1).clamp(0, 1 << 30));
      _pageController = PageController(initialPage: _currentPage);
      setState(() {
        _pages = pages;
        _extracting = false;
      });
      _syncTimer = Timer.periodic(const Duration(seconds: 20), (_) => _sync());
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _sync({bool isFinished = false}) {
    final pages = _pages;
    if (pages == null || pages.isEmpty) return;
    final fraction = ((_currentPage + 1) / pages.length).clamp(0.0, 1.0);
    ref
        .read(progressRepositoryProvider)
        .updateEbookProgress(
          libraryItemId: widget.itemId,
          ebookLocation: '$_currentPage',
          ebookProgress: fraction,
          isFinished: isFinished ? true : null,
        )
        .catchError((_) {});
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _sync();
    if (_pages != null) _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: pages != null
            ? Text('${_currentPage + 1} / ${pages.length}')
            : null,
      ),
      body: _error != null
          ? Center(
              child: Text(
                'Failed to load: $_error',
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
                    _extracting ? 'Extracting pages…' : 'Downloading…',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            )
          : PageView.builder(
              controller: _pageController,
              itemCount: pages.length,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
                _sync();
              },
              // Confirmed live: an InteractiveViewer here (for pinch-zoom)
              // silently breaks page-swiping — its ScaleGestureRecognizer
              // claims every single-finger drag from the gesture arena
              // before PageView ever sees it, and `panEnabled: false` only
              // suppresses the resulting pan translation, not the claim
              // itself (see InteractiveViewer._onScaleStart). Reliable
              // paging matters more than pinch-zoom here, so it's dropped
              // rather than shipping swipes that silently don't work.
              itemBuilder: (context, index) => Center(
                child: Image.memory(pages[index], fit: BoxFit.contain),
              ),
            ),
    );
  }
}
