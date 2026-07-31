import 'dart:async';
import 'dart:typed_data';

// ignore: implementation_imports
import 'package:epub_view/src/data/models/paragraph.dart' show Paragraph;
import 'package:epub_view/epub_view.dart' hide Image;
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../library/state/library_providers.dart';
import '../player/state/playback_controller.dart' show progressRepositoryProvider;
import 'data/ereader_settings.dart';
import 'state/ebook_providers.dart';

/// Confirmed live against evan's real server (2026-07-31): epub_view
/// 3.2.0's default image-tag handler does
/// `document.Content!.Images![url]!.Content!` with no fallback, which
/// throws "Null check operator used on a null value" (and blanks the
/// entire reader body — `ScrollablePositionedList` has no per-item error
/// boundary) whenever an `<img src>` doesn't exactly match a key in the
/// parsed `Images` map after a naive `../` strip. Reproduced reliably on a
/// real illustrated EPUB (Harry Potter — A History of Magic) via TOC
/// navigation. This is a straight copy of the package's private
/// `_EpubViewState._chapterBuilder` (see its source for the original) with
/// only the image lookup hardened to try a few path variants and fall back
/// to an empty box instead of crashing the whole chapter.
Widget _safeChapterBuilder(
  BuildContext context,
  EpubViewBuilders builders,
  EpubBook document,
  List<EpubChapter> chapters,
  List<Paragraph> paragraphs,
  int index,
  int chapterIndex,
  int paragraphIndex,
  ExternalLinkPressed onExternalLinkPressed,
) {
  if (paragraphs.isEmpty) return const SizedBox.shrink();

  final defaultBuilder = builders as EpubViewBuilders<DefaultBuilderOptions>;
  final options = defaultBuilder.options;

  return Column(
    children: <Widget>[
      if (chapterIndex >= 0 && paragraphIndex == 0)
        builders.chapterDividerBuilder(chapters[chapterIndex]),
      Html(
        data: paragraphs[index].element.outerHtml,
        onLinkTap: (href, attributes, element) =>
            onExternalLinkPressed(href ?? ''),
        style: {
          'html': Style(
            padding: HtmlPaddings.only(
              top: (options.paragraphPadding as EdgeInsets?)?.top,
              right: (options.paragraphPadding as EdgeInsets?)?.right,
              bottom: (options.paragraphPadding as EdgeInsets?)?.bottom,
              left: (options.paragraphPadding as EdgeInsets?)?.left,
            ),
          ).merge(Style.fromTextStyle(options.textStyle)),
        },
        extensions: [
          TagExtension(
            tagsToExtend: {'img'},
            builder: (imageContext) {
              final bytes = _resolveImageBytes(
                document,
                imageContext.attributes['src'],
              );
              if (bytes == null) return const SizedBox.shrink();
              return Image(image: MemoryImage(bytes));
            },
          ),
        ],
      ),
    ],
  );
}

Uint8List? _resolveImageBytes(EpubBook document, String? src) {
  if (src == null) return null;
  final images = document.Content?.Images;
  if (images == null || images.isEmpty) return null;

  final filename = src.split('/').last;
  for (final key in {src, src.replaceAll('../', ''), filename}) {
    final content = images[key]?.Content;
    if (content != null) return Uint8List.fromList(content);
  }
  // Last resort: match any key that ends with the same filename — covers
  // relative-path depths the exact-key attempts above don't.
  for (final entry in images.entries) {
    if (entry.key.endsWith(filename) && entry.value.Content != null) {
      return Uint8List.fromList(entry.value.Content!);
    }
  }
  return null;
}

/// PLAN.md Phase 8.1/8.2: EPUB reader with table of contents, reading
/// position sync (CFI-based), and ereader settings (font/theme/spacing).
class EpubReaderScreen extends ConsumerStatefulWidget {
  const EpubReaderScreen({required this.itemId, super.key});

  final String itemId;

  @override
  ConsumerState<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends ConsumerState<EpubReaderScreen> {
  EpubController? _controller;
  double _downloadProgress = 0;
  bool _downloading = true;
  String? _error;
  Timer? _syncTimer;
  int _totalChapters = 1;

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
      final controller = EpubController(
        document: EpubDocument.openFile(file),
        epubCfi: item.progress?.ebookLocation,
      );
      controller.loadingState.addListener(() {
        if (controller.loadingState.value == EpubViewLoadingState.success) {
          _totalChapters = controller.tableOfContents().length.clamp(
            1,
            1 << 30,
          );
        }
      });
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
    final value = controller?.currentValue;
    final cfi = controller?.generateEpubCfi();
    if (controller == null || value == null || cfi == null) return;
    final fraction = ((value.chapterNumber + (value.progress / 100)) /
            _totalChapters)
        .clamp(0.0, 1.0);
    ref
        .read(progressRepositoryProvider)
        .updateEbookProgress(
          libraryItemId: widget.itemId,
          ebookLocation: cfi,
          ebookProgress: fraction,
          isFinished: isFinished ? true : null,
        )
        .catchError((_) {
          // Best-effort — matches the audio sync's silent-retry policy (5.9).
        });
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
    final settingsAsync = ref.watch(ereaderSettingsProvider);
    final settings = settingsAsync.valueOrNull ?? const EreaderSettings();

    return Scaffold(
      backgroundColor: settings.backgroundColor,
      appBar: AppBar(
        backgroundColor: settings.backgroundColor,
        foregroundColor: settings.textColor,
        actions: [
          if (_controller != null)
            IconButton(
              icon: const Icon(Icons.list),
              tooltip: 'Table of Contents',
              onPressed: () => _showToc(context, _controller!),
            ),
          IconButton(
            icon: const Icon(Icons.text_fields),
            tooltip: 'Reading settings',
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Text(
                'Failed to load: $_error',
                style: TextStyle(color: settings.textColor),
              ),
            )
          : _downloading
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
                    'Downloading book…',
                    style: TextStyle(color: settings.textColor),
                  ),
                ],
              ),
            )
          : EpubView(
              controller: _controller!,
              builders: EpubViewBuilders<DefaultBuilderOptions>(
                options: DefaultBuilderOptions(
                  textStyle: settings.textStyle(),
                  paragraphPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                ),
                chapterBuilder: _safeChapterBuilder,
              ),
            ),
    );
  }

  void _showToc(BuildContext context, EpubController controller) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        final toc = controller.tableOfContents();
        return ListView.builder(
          itemCount: toc.length,
          itemBuilder: (context, index) {
            final chapter = toc[index];
            return ListTile(
              title: Text(chapter.title ?? 'Chapter ${index + 1}'),
              onTap: () {
                controller.scrollTo(index: chapter.startIndex);
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => const _EreaderSettingsSheet(),
    );
  }
}

class _EreaderSettingsSheet extends ConsumerWidget {
  const _EreaderSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(ereaderSettingsProvider).valueOrNull ?? const EreaderSettings();
    final controller = ref.read(ereaderSettingsProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reading Settings', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Font'),
              const Spacer(),
              SegmentedButton<EreaderFontFamily>(
                segments: const [
                  ButtonSegment(
                    value: EreaderFontFamily.sans,
                    label: Text('Sans'),
                  ),
                  ButtonSegment(
                    value: EreaderFontFamily.serif,
                    label: Text('Serif'),
                  ),
                ],
                selected: {settings.fontFamily},
                onSelectionChanged: (s) =>
                    controller.save(settings.copyWith(fontFamily: s.first)),
              ),
            ],
          ),
          Row(
            children: [
              const Text('Bold'),
              const Spacer(),
              Switch(
                value: settings.bold,
                onChanged: (v) => controller.save(settings.copyWith(bold: v)),
              ),
            ],
          ),
          Text('Font size'),
          Slider(
            value: settings.fontScale,
            min: 0.7,
            max: 2.0,
            divisions: 13,
            label: settings.fontScale.toStringAsFixed(1),
            onChanged: (v) => controller.save(settings.copyWith(fontScale: v)),
          ),
          Text('Line spacing'),
          Slider(
            value: settings.lineSpacing,
            min: 1.0,
            max: 2.2,
            divisions: 12,
            label: settings.lineSpacing.toStringAsFixed(1),
            onChanged: (v) =>
                controller.save(settings.copyWith(lineSpacing: v)),
          ),
          Row(
            children: [
              const Text('Theme'),
              const Spacer(),
              SegmentedButton<EreaderTheme>(
                segments: const [
                  ButtonSegment(value: EreaderTheme.light, label: Text('Light')),
                  ButtonSegment(value: EreaderTheme.dark, label: Text('Dark')),
                  ButtonSegment(value: EreaderTheme.black, label: Text('Black')),
                ],
                selected: {settings.theme},
                onSelectionChanged: (s) =>
                    controller.save(settings.copyWith(theme: s.first)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
