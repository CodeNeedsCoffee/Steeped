import 'dart:async';
import '../../core/utils/format_duration.dart';
import 'epub_loader.dart';
import 'reader_math.dart';
import '../streaks/streak_providers.dart';
import 'dart:typed_data';

// ignore: implementation_imports
import 'package:epub_view/src/data/models/paragraph.dart' show Paragraph;
import 'package:epub_view/epub_view.dart' hide Image;
import 'package:html/dom.dart' as dom;
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../library/state/library_providers.dart';
import 'data/ereader_settings.dart';
import 'data/reading_position.dart';
import '../linking/link_providers.dart';
import '../linking/sync_anchors.dart';
import '../linking/ebook_spans.dart';
import '../linking/link_switch.dart';
import '../linking/precise_busy.dart';
import '../linking/precise_service.dart';
import '../linking/read_along.dart';
import '../linking/reader_dock.dart';
import '../player/state/playback_controller.dart';
import '../settings/state/settings_providers.dart';
import '../linking/linked_listen_action.dart';
import '../linking/sync_strategy.dart' show ChapterSpan, SyncMode;
import 'ereader_settings_panel.dart';
import 'epub_cfi_fix.dart';
import 'reader_chrome.dart';
import 'selectable_paragraph.dart';
import 'state/ebook_providers.dart';
import '../../l10n/l10n.dart';

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
ChaptersBuilder _safeChapterBuilder({
  required bool justify,
  required Map<int, List<String>> Function() highlights,
  required void Function(List<Paragraph>) onParagraphs,
  required void Function(EpubBook, List<EpubChapter>) onBook,
  required int Function() marked,
}) =>
    (
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
      onParagraphs(paragraphs);
      onBook(document, chapters);
      if (paragraphs.isEmpty) return const SizedBox.shrink();

      final defaultBuilder =
          builders as EpubViewBuilders<DefaultBuilderOptions>;
      final options = defaultBuilder.options;

      return _AudioMarker(
        active: marked() == index,
        child: Column(
          children: <Widget>[
            if (chapterIndex >= 0 && paragraphIndex == 0)
              builders.chapterDividerBuilder(chapters[chapterIndex]),
            isSelectableParagraph(paragraphs[index].element)
                ? SelectableParagraph(
                    html: _withHighlights(
                      paragraphs[index].element,
                      highlights()[index],
                    ),
                    style: options.textStyle,
                    padding:
                        (options.paragraphPadding as EdgeInsets?) ??
                        EdgeInsets.zero,
                    justify: justify,
                    onLink: onExternalLinkPressed,
                    index: index,
                  )
                : Html(
                    data: _withHighlights(
                      paragraphs[index].element,
                      highlights()[index],
                    ),
                    onLinkTap: (href, attributes, element) =>
                        onExternalLinkPressed(href ?? ''),
                    style: {
                      'html': Style(
                        padding: HtmlPaddings.only(
                          top: (options.paragraphPadding as EdgeInsets?)?.top,
                          right:
                              (options.paragraphPadding as EdgeInsets?)?.right,
                          bottom:
                              (options.paragraphPadding as EdgeInsets?)?.bottom,
                          left: (options.paragraphPadding as EdgeInsets?)?.left,
                        ),
                      ).merge(Style.fromTextStyle(options.textStyle)),
                      if (justify) 'p': Style(textAlign: TextAlign.justify),
                      'mark': Style(
                        backgroundColor: const Color(0x66FFC83D),
                        color: options.textStyle.color,
                      ),
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
        ),
      );
    };

/// A thin accent band down the left edge of the paragraph the audio is
/// reading (listening while reading).
class _AudioMarker extends StatelessWidget {
  const _AudioMarker({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) => active
      ? DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Color(0xCCFFC83D), width: 3),
            ),
          ),
          child: child,
        )
      : child;
}

/// Wraps each highlighted snippet in `<mark>` inside a copy of the paragraph.
/// Best effort: a snippet that spans inline tags (bold, links) inside one
/// paragraph isn't found as a single text run and simply isn't painted.
String _withHighlights(dom.Element element, List<String>? snippets) {
  if (snippets == null || snippets.isEmpty) return element.outerHtml;
  final copy = element.clone(true);
  for (final snippet in snippets) {
    void walk(dom.Node node) {
      for (final child in List<dom.Node>.of(node.nodes)) {
        if (child is dom.Text) {
          final at = child.text.indexOf(snippet);
          if (at < 0) continue;
          final mark = dom.Element.tag('mark')..append(dom.Text(snippet));
          final after = child.text.substring(at + snippet.length);
          final before = child.text.substring(0, at);
          final parent = child.parent!;
          final i = parent.nodes.indexOf(child);
          parent.nodes
            ..removeAt(i)
            ..insertAll(i, [
              if (before.isNotEmpty) dom.Text(before),
              mark,
              if (after.isNotEmpty) dom.Text(after),
            ]);
          return;
        } else {
          walk(child);
        }
      }
    }

    walk(copy);
  }
  return copy.outerHtml;
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
/// position sync, ereader settings, and (device-local) bookmarks/highlights.
///
/// Paged mode: [EpubView] only knows how to scroll, so "pages" are one
/// viewport-height jumps of its underlying list (edge taps and swipes), with
/// the list's own drag-scrolling switched off. A line can straddle a page
/// boundary; a small overlap keeps it readable.
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
  String _title = '';
  final _bodyKey = GlobalKey();

  List<Paragraph> _paragraphs = const [];
  EpubBook? _book;
  List<EpubChapter> _chapters = const [];
  List<EbookBookmark> _bookmarks = [];
  List<EbookHighlight> _highlights = [];
  String _selectedText = '';
  double _fraction = 0;
  bool _hasAudio = false;
  // Where the book was meant to open; used when the saved CFI does not resolve.
  double _startFraction = 0;
  bool _resumeChecked = false;
  String _chapterLabel = '';
  // Listening while reading: follow the audio, and the paragraph it is at.
  bool _follow = false;
  int _marked = -1;

  /// Places confirmed by listening; the marker follows these before it falls
  /// back to the chapter estimate.
  List<SyncAnchor> _anchors = const [];

  Future<void> _loadAnchors() async {
    final a = await ref.read(syncAnchorStoreProvider).load(widget.itemId);
    if (mounted) _anchors = a;
  }
  List<ChapterSpan>? _ebookSpans;
  // A switch from the audiobook, mapped properly (by words) once the text is
  // laid out; Precise then refines it by listening.
  AudioPoint? _audioFrom;
  ParagraphMap? _map;
  int _mapFor = -1;

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
      // Parse the book once: the contents, the chapter spans for a switch from
      // the audiobook and the reader itself all use this.
      final bookFuture = openEpubFile(file);
      final audioPoint = ref.read(pendingEbookSwitchProvider)[widget.itemId];
      if (audioPoint != null) {
        _audioFrom = audioPoint;
        ref
            .read(pendingEbookSwitchProvider.notifier)
            .update((m) => {...m}..remove(widget.itemId));
        try {
          final f = audioPoint.fractionIn(chapterSpansOfBook(await bookFuture));
          if (f != null) {
            ref
                .read(pendingEbookJumpProvider.notifier)
                .update((m) => {...m, widget.itemId: f});
          }
        } catch (_) {
          // Mapping is a convenience; the reader opens at its own position.
        }
      }
      var start = await resolveStartPosition(
        ProviderScope.containerOf(context, listen: false),
        widget.itemId,
        fromDetail: item.progress,
      );
      // A switch from the linked audiobook picked the spot (opens by fraction).
      final jump = ref.read(pendingEbookJumpProvider)[widget.itemId];
      if (jump != null) {
        ref
            .read(pendingEbookJumpProvider.notifier)
            .update((m) => {...m}..remove(widget.itemId));
        start = ReadingPosition(
          location: '',
          fraction: jump,
          updatedAt: DateTime.now(),
        );
      }
      _bookmarks = await repo.loadBookmarks(widget.itemId);
      _highlights = await repo.loadHighlights(widget.itemId);
      if (!mounted) return;
      final cfi = start?.location;
      final controller = EpubController(
        document: bookFuture,
        // The official apps write epub.js CFIs; only hand ours a real CFI.
        epubCfi: (cfi != null && cfi.startsWith('epubcfi')) ? cfi : null,
      );
      controller.currentValueListenable.addListener(_onMoved);
      setState(() {
        _controller = controller;
        _downloading = false;
        _fraction = start?.fraction ?? 0;
        _startFraction = start?.fraction ?? 0;
      });
      _syncTimer = Timer.periodic(const Duration(seconds: 20), (_) => _sync());
    } catch (e) {
      // A cached copy that won't open may be truncated: drop it so retrying
      // downloads a fresh one.
      await ref.read(ebookRepositoryProvider).evict(item);
      if (mounted) setState(() => _error = e.toString());
    }
  }

  /// Book length in paragraphs. The chapter builder hands over the whole
  /// paragraph list once the book renders, so use that; the table-of-contents
  /// guess (last chapter start plus an average chapter) only covers the first
  /// frames, and it is wrong for books whose contents page links into one file.
  int _estimatedTotal(EpubController c) {
    if (_paragraphs.isNotEmpty) return _paragraphs.length;
    final toc = c.tableOfContents();
    if (toc.isEmpty) return 1;
    final last = toc.last.startIndex;
    final avg = toc.length > 1 ? last / (toc.length - 1) : 100;
    return (last + avg).round().clamp(1, 1 << 30);
  }

  double _currentFraction() {
    final c = _controller;
    final v = c?.currentValue;
    if (c == null || v == null) return _fraction;
    final pos = v.position;
    final within =
        (-pos.itemLeadingEdge /
                (pos.itemTrailingEdge - pos.itemLeadingEdge).clamp(0.001, 1e9))
            .clamp(0.0, 1.0);
    return ((pos.index + within) / _estimatedTotal(c)).clamp(0.0, 1.0);
  }

  /// The reader's position as a CFI other EPUB readers can resume from.
  String? _currentCfi() {
    final raw = _controller?.generateEpubCfi();
    final book = _book;
    if (raw == null || book == null) return raw;
    final at = _controller?.currentValue?.position.index;
    final fallback = (at != null && at >= 0 && at < _paragraphs.length)
        ? _paragraphs[at].chapterIndex
        : null;
    return fixSpineStep(raw, book, _chapters, fallbackChapterIndex: fallback);
  }

  /// epub_view writes the first spine item as `/6/0[...]` and cannot read that
  /// back, so a saved CFI can silently fail and the book opens at the top. If
  /// we were meant to open further in but landed on the first paragraph, jump
  /// by the saved fraction instead.
  void _checkResume(EpubController c, int index) {
    if (_resumeChecked || _paragraphs.isEmpty) return;
    _resumeChecked = true;
    final landed = _currentFraction();
    if (_startFraction > 0.003 &&
        (index == 0 || (landed - _startFraction).abs() > 0.08)) {
      c.jumpTo(index: (_startFraction * _paragraphs.length).floor());
    }
  }

  void _onMoved() {
    final v = _controller?.currentValue;
    if (v == null || !mounted) return;
    _reading.touch();
    _checkResume(_controller!, v.position.index);
    // epub_view's own `chapter` can stay on the first spine item (it showed the
    // licence heading deep into a book), so name the chapter from the contents.
    final title =
        _titleAt(_controller!, v.position.index) ?? v.chapter?.Title?.trim();
    final fraction = _currentFraction();
    final label = (title != null && title.isNotEmpty)
        ? title
        : context.l10n.chapterNumber(v.chapterNumber);
    // This fires on every scroll frame. Rebuilding the whole reader each time
    // made it lag, so rebuild only when something shown changes: the slider
    // and percentage move in half-percent steps, or the chapter name changes.
    final changed =
        (fraction * 200).round() != (_fraction * 200).round() ||
        label != _chapterLabel;
    _fraction = fraction;
    _chapterLabel = label;
    if (changed) setState(() {});
  }

  /// The table of contents as `epub_view` reports it, read once: it builds a
  /// new list of every entry each time it is asked.
  List<dynamic>? _tocEntries;

  String? _titleAt(EpubController c, int index) {
    String? title;
    for (final e in _tocEntries ??= c.tableOfContents()) {
      if (e.startIndex > index) break;
      final t = e.title?.trim();
      if (t != null && t.isNotEmpty) title = t;
    }
    return title;
  }

  void _jumpToFraction(double f) {
    final c = _controller;
    if (c == null) return;
    _detach();
    c.jumpTo(index: (f * _estimatedTotal(c)).floor());
  }

  void _sync({bool isFinished = false}) {
    final controller = _controller;
    final cfi = _currentCfi();
    if (controller == null || controller.currentValue == null || cfi == null) {
      return;
    }
    final fraction = _currentFraction();
    saveReadingPosition(
      ref,
      itemId: widget.itemId,
      location: cfi,
      fraction: fraction,
      isFinished: ebookFinishedFlag(
        reachedEnd: isFinished || fraction >= 0.995,
        hasAudio: _hasAudio,
      ),
    );
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _sync();
    _reading.close();
    _controller?.currentValueListenable.removeListener(_onMoved);
    _controller?.dispose();
    super.dispose();
  }

  ScrollPosition? _scrollPosition() {
    final ctx = _bodyKey.currentContext;
    if (ctx == null) return null;
    ScrollPosition? found;
    void visit(Element e) {
      if (found != null) return;
      if (e is StatefulElement && e.state is ScrollableState) {
        found = (e.state as ScrollableState).position;
        return;
      }
      e.visitChildren(visit);
    }

    (ctx as Element).visitChildren(visit);
    return found;
  }

  /// Turns a page: scrolls by what is visible between the bars (the body runs
  /// under them), less a line and a half so the last lines of a page repeat at
  /// the top of the next. Stepping by 92% of the whole screen skipped the
  /// lines the bars were covering.
  void _turn(int direction, EdgeInsets covered) {
    final pos = _scrollPosition();
    if (pos == null) return;
    _detach();
    final s = ref.read(ereaderSettingsProvider).valueOrNull;
    final line = 18 * (s?.fontScale ?? 1.0) * (s?.lineSpacing ?? 1.25);
    final visible = pos.viewportDimension - covered.top - covered.bottom;
    final step = (visible - line * 1.5).clamp(line, double.infinity);
    pos.animateTo(
      pos.pixels + direction * step,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  /// Jumps to paragraph [index], then corrects by what actually got laid out:
  /// the line of [snippet] (a highlight) or [within] of the paragraph's height
  /// (a bookmark) is moved to just under the top bar, whether the jump landed
  /// short of it or past it.
  void _revealIn(
    int index, {
    String? snippet,
    double within = 0,
    double at = 0.15,
    bool fromFollow = false,
  }) {
    final c = _controller;
    if (c == null) return;
    if (!fromFollow) _detach();
    c.jumpTo(index: index);
    var tries = 0;
    void fix(Duration _) {
      if (!mounted) return;
      final pos = _scrollPosition();
      final box = _bodyKey.currentContext?.findRenderObject();
      final b = paragraphBounds(index);
      if (pos == null || box is! RenderBox || !box.attached || b == null) {
        if (++tries < 6) WidgetsBinding.instance.addPostFrameCallback(fix);
        return;
      }
      final y =
          (snippet == null ? null : snippetY(index, snippet)) ??
          b.top + within * b.height;
      final want = box.localToGlobal(Offset.zero).dy + box.size.height * at;
      if ((y - want).abs() > 8) pos.jumpTo(pos.pixels + y - want);
    }

    WidgetsBinding.instance.addPostFrameCallback(fix);
  }

  /// The book in words (chapters, and places converted both ways), built once
  /// the text is laid out. Null until then.
  ParagraphMap? get _paragraphMap {
    if (_paragraphs.isEmpty) return null;
    if (_map == null || _mapFor != _paragraphs.length) {
      final c = _controller;
      _map = ParagraphMap(
        [
          for (final q in _paragraphs)
            RegExp(r'\S+').allMatches(q.element.text).length,
        ],
        [
          if (c != null)
            for (final e in _tocEntries ??= c.tableOfContents())
              (title: (e.title as String?)?.trim() ?? '', start: e.startIndex as int),
        ],
      );
      _mapFor = _paragraphs.length;
    }
    return _map;
  }

  /// A switch from the audiobook arrives as a rough spot (chapter sizes by
  /// HTML length). Once the text is laid out, redo it by words, which follows
  /// the narration far more closely, then (Precise) refine by listening.
  Future<void> _onTextReady() async {
    final p = _audioFrom;
    final map = _paragraphMap;
    _loadAnchors();
    if (p == null || map == null || !mounted) return;
    _audioFrom = null;
    var f = p.fractionIn(map.spans);
    // Places confirmed by earlier listening beat the chapter estimate.
    final total = p.audio?.duration;
    if (total != null && p.mode != SyncMode.off) {
      final anchors = await ref
          .read(syncAnchorStoreProvider)
          .load(widget.itemId);
      f = wordFor(anchors, p.seconds, total) ?? f;
      if (!mounted) return;
    }
    if (f != null) {
      final pos = map.paragraphPos(f);
      final n = _paragraphs.length;
      if ((pos - _startFraction * n).abs() > n * 0.01) {
        _revealIn(pos.floor(), within: pos - pos.floor());
      }
      _startFraction = pos / n;
    }
    if (p.mode == SyncMode.precise) _refine(p);
  }

  /// Precise, audio -> text: listens to the audiobook at the switch point and
  /// moves to the paragraph the narrator is actually reading.
  void _refine(AudioPoint p) {
    final audio = p.audio;
    if (audio == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    final container = ProviderScope.containerOf(context, listen: false);
    final estimate = (_startFraction * _paragraphs.length).floor();
    final texts = [for (final q in _paragraphs) q.element.text];
    final busy = container.read(preciseBusyProvider.notifier);
    busy.state = true;
    refineParagraph(container, audio, p.seconds, texts, estimate)
        .whenComplete(() => busy.state = false)
        .then((r) {
          if (!mounted) return;
          if (r == null) {
            messenger?.showSnackBar(
              SnackBar(content: Text(l10n.preciseApproximate)),
            );
            return;
          }
          _revealIn(r.paragraph, within: r.within);
          final map = _paragraphMap;
          if (map != null) {
            ref
                .read(syncAnchorStoreProvider)
                .add(
                  widget.itemId,
                  SyncAnchor(
                    map.wordFraction(r.paragraph + r.within),
                    p.seconds,
                  ),
                )
                .then((_) => _loadAnchors());
          }
        });
  }

  /// The reader's place as paragraph index plus how far into it, or null.
  double? _positionNow() {
    final v = _controller?.currentValue;
    if (v == null || _paragraphs.isEmpty) return null;
    final pos = v.position;
    final within =
        (-pos.itemLeadingEdge /
                (pos.itemTrailingEdge - pos.itemLeadingEdge).clamp(0.001, 1e9))
            .clamp(0.0, 0.95);
    return pos.index + within;
  }

  /// The words at the top of the screen (for Precise to find in the audio).
  String _visibleText() {
    final v = _controller?.currentValue;
    if (v == null || _paragraphs.isEmpty) return '';
    final pos = v.position;
    final within =
        (-pos.itemLeadingEdge /
                (pos.itemTrailingEdge - pos.itemLeadingEdge).clamp(0.001, 1e9))
            .clamp(0.0, 0.95);
    final out = <String>[];
    for (var i = pos.index; i < _paragraphs.length && out.length < 60; i++) {
      var words = _paragraphs[i].element.text.split(RegExp(r'\s+'));
      if (i == pos.index) words = words.skip((within * words.length).floor()).toList();
      out.addAll(words);
    }
    return out.join(' ');
  }

  /// Stops following the audio (the reader moved on its own).
  void _detach() {
    if (_follow && mounted) setState(() => _follow = false);
  }

  /// Chapters of the book: by words once the text is laid out, by HTML size
  /// before that.
  List<ChapterSpan> get _spans {
    final map = _paragraphMap;
    if (map != null && map.spans.isNotEmpty) return map.spans;
    final book = _book;
    return _ebookSpans ??= book == null
        ? const [ChapterSpan('', 0, 1)]
        : chapterSpansOfBook(book);
  }

  void _toggleFollow() {
    if (_follow) {
      setState(() => _follow = false);
    } else {
      setState(() => _follow = true);
      _onAudioTick(ref.read(playbackPositionProvider).valueOrNull, force: true);
    }
  }

  /// Audio position -> the paragraph it is at: moves the marker, and while
  /// following scrolls so that paragraph is on screen.
  void _onAudioTick(double? seconds, {bool force = false}) {
    final audio = ref.read(linkedPlayingProvider(widget.itemId));
    final c = _controller;
    if (seconds == null ||
        audio == null ||
        c == null ||
        _paragraphs.isEmpty ||
        _book == null) {
      return;
    }
    final mode = syncModeFromName(
      ref.read(appSettingsProvider).valueOrNull?.linkSyncToEbook ?? 'estimated',
    );
    final f = AudioPoint(
      seconds: seconds,
      spans: audioSpansOf(audio),
      mode: mode,
    ).fractionIn(_spans);
    if (f == null) return;
    final map = _paragraphMap;
    final total = audio.duration;
    final confirmed = mode == SyncMode.off || map == null || total == null
        ? null
        : wordFor(_anchors, seconds, total);
    final pos = confirmed != null
        ? map!.paragraphPos(confirmed)
        : map != null
        ? map.paragraphPos(f)
        : (f * _paragraphs.length).clamp(0.0, _paragraphs.length - 0.0001);
    final index = pos.floor();
    if (index == _marked && !force) return;
    setState(() => _marked = index);
    if (!_follow) return;
    final b = paragraphBounds(index);
    final box = _bodyKey.currentContext?.findRenderObject();
    if (!force &&
        b != null &&
        box is RenderBox &&
        box.attached &&
        inComfortZone(
          paragraphTop: b.top,
          bodyTop: box.localToGlobal(Offset.zero).dy,
          bodyHeight: box.size.height,
        )) {
      return;
    }
    _revealIn(index, within: pos - index, at: 0.3, fromFollow: true);
  }

  /// Long-press "Play from here": the audio starts at the selected paragraph.
  Future<void> _playFromHere(double anchorY) async {
    final audio = ref.read(linkedAudioProvider(widget.itemId));
    final v = _controller?.currentValue;
    if (audio == null || v == null || _paragraphs.isEmpty) return;
    final index = paragraphIndexAtY(anchorY, _selectedText) ?? v.position.index;
    final mode = syncModeFromName(
      ref.read(appSettingsProvider).valueOrNull?.linkSyncToAudio ?? 'estimated',
    );
    final map = _paragraphMap;
    final seconds = audioSecondsForFraction(
      fraction: map != null
          ? map.wordFraction(index.toDouble())
          : index / _paragraphs.length,
      ebookSpans: _spans,
      audioSpans: audioSpansOf(audio),
      mode: mode,
    );
    if (seconds == null) return;
    var start = seconds;
    if (mode == SyncMode.precise) {
      final refined = await refineAudioStart(
        ProviderScope.containerOf(context, listen: false),
        audio,
        seconds,
        _paragraphs[index].element.text,
        guide: (
          paragraphs: [for (final q in _paragraphs) q.element.text],
          position: index.toDouble(),
        ),
      );
      if (refined != null) {
        start = refined;
        if (map != null) {
          ref
              .read(syncAnchorStoreProvider)
              .add(
                widget.itemId,
                SyncAnchor(map.wordFraction(index.toDouble()), refined),
              )
              .then((_) => _loadAnchors());
        }
      }
    }
    final controller = ref.read(playbackControllerProvider.notifier);
    if (ref.read(linkedPlayingProvider(widget.itemId)) != null) {
      await controller.seekToGlobalPosition(start);
      await controller.resume();
    } else {
      await controller.playItem(audio.id, startAt: start);
    }
    if (!mounted) return;
    setState(() {
      _follow = ref.read(appSettingsProvider).valueOrNull?.linkFollow ?? true;
      _marked = index;
    });
  }

  /// A bookmark's position is a fraction of the book in paragraphs; the whole
  /// part is the paragraph and the rest is how far down it.
  void _gotoBookmark(EpubController c, EbookBookmark b) {
    final n = _paragraphs.length;
    if (n == 0) {
      c.gotoEpubCfi(b.location);
      return;
    }
    final at = (b.fraction.clamp(0.0, 0.9999) * n);
    _revealIn(at.floor(), within: at - at.floor());
  }

  Future<void> _renameBookmark(
    BuildContext context,
    EbookBookmark b,
    VoidCallback refreshSheet,
  ) async {
    final text = TextEditingController(text: b.label);
    final name = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(context.l10n.rename),
        content: TextField(
          controller: text,
          autofocus: true,
          decoration: InputDecoration(labelText: context.l10n.note),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, text.text.trim()),
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    if (name == null) return;
    setState(
      () => _bookmarks = [
        for (final x in _bookmarks) x == b ? b.withLabel(name) : x,
      ],
    );
    refreshSheet();
    await ref
        .read(ebookRepositoryProvider)
        .saveBookmarks(widget.itemId, _bookmarks);
  }

  bool get _isBookmarked {
    final cfi = _currentCfi();
    return cfi != null && _bookmarks.any((b) => b.location == cfi);
  }

  Future<void> _toggleBookmark() async {
    final cfi = _currentCfi();
    if (cfi == null) return;
    final repo = ref.read(ebookRepositoryProvider);
    final existing = _bookmarks.where((b) => b.location == cfi).toList();
    setState(() {
      if (existing.isNotEmpty) {
        _bookmarks = [
          for (final b in _bookmarks)
            if (b.location != cfi) b,
        ];
      } else {
        _bookmarks = [
          ..._bookmarks,
          EbookBookmark(
            location: cfi,
            fraction: _currentFraction(),
            label: _chapterLabel,
            createdAt: DateTime.now(),
          ),
        ];
      }
    });
    await repo.saveBookmarks(widget.itemId, _bookmarks);
  }

  Future<void> _addHighlight([double? anchorY]) async {
    final c = _controller;
    final v = c?.currentValue;
    if (c == null || v == null || _paragraphs.isEmpty) return;
    final added = <EbookHighlight>[];
    final from = (v.position.index - 3).clamp(0, _paragraphs.length - 1);
    final to = (v.position.index + 25).clamp(0, _paragraphs.length - 1);
    // A selection spanning paragraphs arrives as several lines of text.
    for (final raw in _selectedText.split('\n')) {
      final text = raw.trim();
      if (text.length < 2) continue;
      final onScreen = anchorY == null
          ? null
          : paragraphIndexAtY(anchorY, text);
      if (onScreen != null) {
        added.add(
          EbookHighlight(
            paragraph: onScreen,
            text: text,
            createdAt: DateTime.now(),
          ),
        );
        continue;
      }
      for (var i = from; i <= to; i++) {
        if (_paragraphs[i].element.text.contains(text)) {
          added.add(
            EbookHighlight(paragraph: i, text: text, createdAt: DateTime.now()),
          );
          break;
        }
      }
    }
    final merged = mergeHighlights(_highlights, added);
    if (added.isEmpty ||
        merged.length == _highlights.length &&
            merged.every(_highlights.contains)) {
      return;
    }
    setState(() => _highlights = merged);
    await ref
        .read(ebookRepositoryProvider)
        .saveHighlights(widget.itemId, _highlights);
  }

  Map<int, List<String>> _highlightsByParagraph() {
    final map = <int, List<String>>{};
    for (final h in _highlights) {
      (map[h.paragraph] ??= []).add(h.text);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    // Listening while reading: the audio starting beside the reader turns
    // Follow on (if the setting allows); the audio stopping clears the marker.
    ref.listen(linkedPlayingProvider(widget.itemId), (prev, next) {
      if (next == null) {
        if (_marked != -1 || _follow) {
          setState(() {
            _marked = -1;
            _follow = false;
          });
        }
      } else if (prev == null) {
        final on =
            ref.read(appSettingsProvider).valueOrNull?.linkFollow ?? true;
        setState(() => _follow = on);
        _onAudioTick(
          ref.read(playbackPositionProvider).valueOrNull,
          force: true,
        );
      }
    });
    ref.listen(playbackPositionProvider, (_, n) => _onAudioTick(n.valueOrNull));
    final playingAudio = ref.watch(linkedPlayingProvider(widget.itemId));
    final wantPlayer =
        playingAudio != null &&
        (ref.watch(appSettingsProvider).valueOrNull?.linkDock ?? true);
    // Beside the page when there is room, otherwise a strip under it.
    final sidePanel =
        wantPlayer && wideEnoughForPanel(MediaQuery.sizeOf(context).width);
    final showDock = wantPlayer && !sidePanel;
    final settings =
        ref.watch(ereaderSettingsProvider).valueOrNull ??
        const EreaderSettings();
    final paged = settings.epubFlow == ReadingFlow.paged;
    final controller = _controller;

    Widget body;
    if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.l10n.failedToLoad(_error ?? ''),
            style: TextStyle(color: settings.textColor),
          ),
        ),
      );
    } else if (_downloading || controller == null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              value: _downloadProgress > 0 ? _downloadProgress : null,
              color: settings.textColor,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.downloadingBook,
              style: TextStyle(color: settings.textColor),
            ),
          ],
        ),
      );
    } else {
      body = ScrollConfiguration(
        behavior: PagedScrollBehavior(paged: paged),
        child: SelectionArea(
          onSelectionChanged: (c) => _selectedText = c?.plainText ?? '',
          contextMenuBuilder: (context, state) =>
              AdaptiveTextSelectionToolbar.buttonItems(
                anchors: state.contextMenuAnchors,
                buttonItems: [
                  // Highlight first: the system adds many items on some phones
                  // (search, translate, AI apps) and a last item ends up hidden
                  // behind the overflow arrow.
                  ContextMenuButtonItem(
                    label: context.l10n.highlight,
                    onPressed: () {
                      final a = state.contextMenuAnchors;
                      _addHighlight(
                        (a.primaryAnchor.dy +
                                (a.secondaryAnchor?.dy ?? a.primaryAnchor.dy)) /
                            2,
                      );
                      state.hideToolbar();
                    },
                  ),
                  if (ref.read(linkedAudioProvider(widget.itemId)) != null)
                    ContextMenuButtonItem(
                      label: context.l10n.playFromHere,
                      onPressed: () {
                        final a = state.contextMenuAnchors;
                        _playFromHere(
                          (a.primaryAnchor.dy +
                                  (a.secondaryAnchor?.dy ??
                                      a.primaryAnchor.dy)) /
                              2,
                        );
                        state.hideToolbar();
                      },
                    ),
                  ...state.contextMenuButtonItems,
                ],
              ),
          child: NotificationListener<ScrollStartNotification>(
            onNotification: (n) {
              // A finger drag in scroll mode moves the page itself.
              if (n.dragDetails != null) _detach();
              return false;
            },
            child: KeyedSubtree(
              key: _bodyKey,
              child: EpubView(
                controller: controller,
                builders: EpubViewBuilders<DefaultBuilderOptions>(
                  options: DefaultBuilderOptions(
                    textStyle: settings.textStyle(),
                    paragraphPadding: EdgeInsets.symmetric(
                      horizontal: settings.margin,
                      vertical: 4,
                    ),
                  ),
                  chapterBuilder: _safeChapterBuilder(
                    justify: settings.justify,
                    highlights: _highlightsByParagraph,
                    marked: () => _marked,
                    onParagraphs: (p) {
                    _paragraphs = p;
                    if (_audioFrom != null) {
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _onTextReady(),
                      );
                    }
                  },
                    onBook: (b, c) {
                      _book = b;
                      _chapters = c;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final chrome = ReaderChrome(
      settings: settings,
      title: _title,
      body: body,
      dock: showDock
          ? ReaderPlayerDock(
              audio: playingAudio,
              following: _follow,
              onToggleFollow: _toggleFollow,
              color: settings.textColor,
            )
          : null,
      // Leaves room under the bars the first time; tapping the middle hides
      // them and the text keeps its place.
      onPage: paged ? _turn : null,
      fadeBottomEdge: true,
      bodyInsets: EdgeInsets.symmetric(vertical: settings.marginVertical),
      blockBodyGestures: false,
      progress: controller == null ? null : _fraction,
      onScrub: controller == null ? null : _jumpToFraction,
      footerLabel: _chapterLabel,
      progressNote: controller == null || _paragraphs.isEmpty
          ? null
          : context.l10n.timeLeftInBook(
              formatDurationText(
                context.l10n,
                readingTimeLeft(
                  totalWords: _totalWords,
                  fraction: _fraction,
                ).inSeconds.toDouble(),
              ),
            ),
      actions: [
        if (controller != null) ...[
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: context.l10n.searchInBook,
            onPressed: () => _showSearch(context, controller),
          ),
          IconButton(
            icon: Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_border),
            tooltip: context.l10n.bookmarkThisPage,
            onPressed: _toggleBookmark,
          ),
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: context.l10n.tableOfContents,
            onPressed: () => _showToc(context, controller),
          ),
          IconButton(
            icon: const Icon(Icons.collections_bookmark_outlined),
            tooltip: context.l10n.bookmarksAndHighlights,
            onPressed: () => _showNotes(context, controller),
          ),
        ],
        LinkedListenAction(
          itemId: widget.itemId,
          saveFirst: _sync,
          canListenAlongside: true,
          onListenAlongside: () {
            if (!_follow &&
                (ref.read(appSettingsProvider).valueOrNull?.linkFollow ??
                    true)) {
              _toggleFollow();
            }
          },
          pointNow: () {
            final book = _book;
            final map = _paragraphMap;
            final here = _positionNow();
            return EbookPoint(
              fraction: map != null && here != null
                  ? map.wordFraction(here)
                  : _fraction,
              visibleText: _visibleText(),
              paragraphTexts: [for (final q in _paragraphs) q.element.text],
              paragraphPosition: _positionNow(),
              inWords: map != null && here != null,
              spans: map != null
                  ? map.spans
                  : book == null
                  ? const [ChapterSpan('', 0, 1)]
                  : chapterSpansOfBook(book),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.text_fields),
          tooltip: context.l10n.readingSettingsTooltip,
          onPressed: () => _showSettings(context),
        ),
      ],
    );
    if (!sidePanel) return PreciseBusyOverlay(child: chrome);
    return PreciseBusyOverlay(
      child: Row(
      children: [
        Expanded(child: chrome),
        SizedBox(
          width: 320,
          child: ReaderPlayerPanel(
            audio: playingAudio,
            following: _follow,
            onToggleFollow: _toggleFollow,
          ),
        ),
      ],
    ));
  }

  int? _wordsCache;
  int _wordsFor = -1;

  /// Words in the book, estimated from the text length (cached per paragraph
  /// count, which only changes once when the book finishes loading).
  int get _totalWords {
    if (_wordsFor != _paragraphs.length) {
      var chars = 0;
      for (final p in _paragraphs) {
        chars += p.element.text.length;
      }
      _wordsCache = approximateWords(chars);
      _wordsFor = _paragraphs.length;
    }
    return _wordsCache ?? 0;
  }

  void _showSearch(BuildContext context, EpubController controller) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => _BookSearchSheet(
        texts: [for (final p in _paragraphs) p.element.text],
        onPick: (index) {
          Navigator.pop(sheet);
          _detach();
          controller.jumpTo(index: index);
        },
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
              contentPadding: EdgeInsets.only(
                left: chapter.type == 'subchapter' ? 40 : 16,
                right: 16,
              ),
              title: Text(
                chapter.title ?? context.l10n.chapterNumber(index + 1),
              ),
              onTap: () {
                _detach();
                controller.jumpTo(index: chapter.startIndex);
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  void _showNotes(BuildContext context, EpubController controller) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => DefaultTabController(
          length: 2,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.6,
            child: Column(
              children: [
                TabBar(
                  tabs: [
                    Tab(text: context.l10n.bookmarks),
                    Tab(text: context.l10n.highlights),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _bookmarks.isEmpty
                          ? Center(child: Text(context.l10n.noBookmarksYet))
                          : ListView(
                              children: [
                                for (final b in _bookmarks)
                                  ListTile(
                                    leading: const Icon(Icons.bookmark),
                                    title: Text(
                                      b.label.isEmpty
                                          ? '${(b.fraction * 100).round()}%'
                                          : b.label,
                                    ),
                                    subtitle: Text(
                                      '${(b.fraction * 100).round()}%',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined),
                                          tooltip: context.l10n.rename,
                                          onPressed: () => _renameBookmark(
                                            context,
                                            b,
                                            () => setSheet(() {}),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          onPressed: () async {
                                            setState(
                                              () => _bookmarks = [
                                                for (final x in _bookmarks)
                                                  if (x != b) x,
                                              ],
                                            );
                                            setSheet(() {});
                                            await ref
                                                .read(ebookRepositoryProvider)
                                                .saveBookmarks(
                                                  widget.itemId,
                                                  _bookmarks,
                                                );
                                          },
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      _gotoBookmark(controller, b);
                                      Navigator.pop(context);
                                    },
                                  ),
                              ],
                            ),
                      _highlights.isEmpty
                          ? Center(child: Text(context.l10n.noHighlightsYet))
                          : ListView(
                              children: [
                                for (final h in _highlights)
                                  ListTile(
                                    leading: const Icon(
                                      Icons.format_color_fill,
                                    ),
                                    title: Text(
                                      h.text,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () async {
                                        setState(
                                          () => _highlights = [
                                            for (final x in _highlights)
                                              if (x != h) x,
                                          ],
                                        );
                                        setSheet(() {});
                                        await ref
                                            .read(ebookRepositoryProvider)
                                            .saveHighlights(
                                              widget.itemId,
                                              _highlights,
                                            );
                                      },
                                    ),
                                    onTap: () {
                                      _revealIn(h.paragraph, snippet: h.text);
                                      Navigator.pop(context);
                                    },
                                  ),
                              ],
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const SingleChildScrollView(
        child: EreaderSettingsPanel(format: EreaderFormat.epub),
      ),
    );
  }
}

/// Turns off finger-scrolling for paged mode; programmatic page turns still
/// animate the same list.
@visibleForTesting
class PagedScrollBehavior extends ScrollBehavior {
  const PagedScrollBehavior({required this.paged});

  final bool paged;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => paged
      ? const NeverScrollableScrollPhysics()
      : super.getScrollPhysics(context);

  // Without this the scrollables below keep the physics they were built with,
  // so switching Pages/Scroll while reading did nothing until the book was
  // reopened.
  @override
  bool shouldNotify(covariant PagedScrollBehavior oldDelegate) =>
      paged != oldDelegate.paged;
}

/// The in-book search sheet: type, see matching passages, tap to jump.
class _BookSearchSheet extends StatefulWidget {
  const _BookSearchSheet({required this.texts, required this.onPick});

  final List<String> texts;
  final ValueChanged<int> onPick;

  @override
  State<_BookSearchSheet> createState() => _BookSearchSheetState();
}

class _BookSearchSheetState extends State<_BookSearchSheet> {
  List<SearchHit> _hits = const [];
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: context.l10n.searchInBookHint,
                  labelText: context.l10n.searchInBook,
                ),
                onChanged: (v) => setState(() {
                  _query = v;
                  _hits = searchTexts(widget.texts, v);
                }),
              ),
            ),
            Expanded(
              child: _hits.isEmpty
                  ? Center(
                      child: Text(
                        _query.trim().length < 2 ? '' : context.l10n.noResults,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _hits.length,
                      itemBuilder: (context, i) => ListTile(
                        title: Text(
                          _hits[i].snippet,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => widget.onPick(_hits[i].index),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
