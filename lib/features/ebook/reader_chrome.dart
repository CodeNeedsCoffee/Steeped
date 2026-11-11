import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../l10n/l10n.dart';
import 'data/ereader_settings.dart';

/// Kindle-style frame shared by the EPUB, PDF and comic readers: a tap on the
/// middle toggles the header/footer (and system bars), taps on the left/right
/// edges turn the page, brightness dims with an overlay, and the screen stays
/// awake while reading.
class ReaderChrome extends StatefulWidget {
  const ReaderChrome({
    required this.settings,
    required this.body,
    this.actions = const [],
    this.title,
    this.onPrev,
    this.onNext,
    this.blockBodyGestures = false,
    this.progress,
    this.onScrub,
    this.footerLabel,
    super.key,
  });

  final EreaderSettings settings;
  final Widget body;
  final List<Widget> actions;
  final String? title;

  /// Edge-tap and horizontal-swipe handlers; null disables turning that way.
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  /// Swallow the body's own drags/taps so only [onPrev]/[onNext] move it
  /// (used for EPUB "paged" mode, where the underlying list scrolls freely).
  final bool blockBodyGestures;

  /// 0..1 progress through the book, shown on the footer scrubber.
  final double? progress;
  final ValueChanged<double>? onScrub;
  final String? footerLabel;

  @override
  State<ReaderChrome> createState() => _ReaderChromeState();
}

class _ReaderChromeState extends State<ReaderChrome> {
  bool _showBars = true;
  double? _dragValue;

  @override
  void initState() {
    super.initState();
    _applyWakelock();
  }

  @override
  void didUpdateWidget(ReaderChrome old) {
    super.didUpdateWidget(old);
    if (old.settings.keepScreenOn != widget.settings.keepScreenOn) {
      _applyWakelock();
    }
  }

  void _applyWakelock() {
    try {
      widget.settings.keepScreenOn
          ? WakelockPlus.enable()
          : WakelockPlus.disable();
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      WakelockPlus.disable();
    } catch (_) {}
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleBars() {
    setState(() => _showBars = !_showBars);
    SystemChrome.setEnabledSystemUIMode(
      _showBars ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  // Taps are read from raw pointer events rather than a gesture recogniser:
  // the EPUB body keeps a SelectionArea (for highlights) that wins the gesture
  // arena, so an onTapUp on this widget never fired there.
  Offset? _downAt;
  Duration? _downTime;

  void _onPointerDown(PointerDownEvent e) {
    _downAt = e.localPosition;
    _downTime = e.timeStamp;
  }

  void _onPointerUp(PointerUpEvent e, double width) {
    final at = _downAt;
    final t = _downTime;
    _downAt = null;
    _downTime = null;
    if (at == null || t == null) return;
    final isTap = (e.localPosition - at).distance < kTouchSlop &&
        e.timeStamp - t < const Duration(milliseconds: 350);
    if (isTap) _onTap(e.localPosition.dx / width);
  }

  void _onTap(double x) {
    if (widget.settings.tapToTurn && x < 0.25) {
      widget.onPrev?.call();
    } else if (widget.settings.tapToTurn && x > 0.75) {
      widget.onNext?.call();
    } else {
      _toggleBars();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final fg = s.textColor;
    final progress = (_dragValue ?? widget.progress)?.clamp(0.0, 1.0);

    Widget body = widget.body;
    if (widget.blockBodyGestures) body = IgnorePointer(child: body);

    return Scaffold(
      backgroundColor: s.backgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, c) => Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: _onPointerDown,
                onPointerUp: (e) => _onPointerUp(e, c.maxWidth),
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: widget.blockBodyGestures
                      ? (d) {
                          final v = d.primaryVelocity ?? 0;
                          if (v < -150) widget.onNext?.call();
                          if (v > 150) widget.onPrev?.call();
                        }
                      : null,
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: _showBars ? 0 : MediaQuery.paddingOf(context).top,
                    ),
                    child: body,
                  ),
                ),
              ),
            ),
          ),
          if (s.brightness < 1)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 1 - s.brightness),
                ),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _Bar(
              visible: _showBars,
              color: s.backgroundColor,
              child: SafeArea(
                bottom: false,
                child: IconTheme(
                  data: IconThemeData(color: fg),
                  child: SizedBox(
                    height: kToolbarHeight,
                    child: Row(
                      children: [
                        const BackButton(),
                        Expanded(
                          child: Text(
                            widget.title ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: fg),
                          ),
                        ),
                        ...widget.actions,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _Bar(
              visible: _showBars && progress != null,
              color: s.backgroundColor,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        label: context.l10n.readingProgress,
                        child: Slider(
                          value: progress ?? 0,
                          onChanged: widget.onScrub == null
                              ? null
                              : (v) => setState(() => _dragValue = v),
                          onChangeEnd: widget.onScrub == null
                              ? null
                              : (v) {
                                  setState(() => _dragValue = null);
                                  widget.onScrub!(v);
                                },
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.footerLabel ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: fg, fontSize: 12),
                            ),
                          ),
                          Text(
                            '${((progress ?? 0) * 100).round()}%',
                            style: TextStyle(color: fg, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.visible, required this.color, required this.child});

  final bool visible;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: visible ? 1 : 0,
        child: ColoredBox(color: color, child: child),
      ),
    );
  }
}
