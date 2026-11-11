import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parseFragment;

/// `flutter_html` 3.0.0 draws its text in a way a [SelectionArea] cannot
/// select (confirmed with a widget test), so highlighting never worked through
/// it. A paragraph made only of running text and inline formatting is drawn
/// here as ordinary rich text instead; images, headings, lists and tables stay
/// on `Html`.
const _inlineTags = {
  'a',
  'abbr',
  'b',
  'br',
  'cite',
  'code',
  'em',
  'i',
  'mark',
  'small',
  'span',
  'strong',
  'sub',
  'sup',
  'u',
};

/// True when [element] is a `p`/`div` whose subtree is only text and inline tags.
bool isSelectableParagraph(dom.Element element) {
  if (element.localName != 'p' && element.localName != 'div') return false;
  bool inline(dom.Node node) {
    for (final child in node.nodes) {
      if (child is dom.Element) {
        if (!_inlineTags.contains(child.localName) || !inline(child)) {
          return false;
        }
      }
    }
    return true;
  }

  return inline(element);
}

final _live = <_SelectableParagraphState>{};

/// The index of the on-screen paragraph that spans global height [y] and
/// contains [snippet]. A selection only reports its text, so this is how a
/// highlight finds the right paragraph when the same word appears in several.
int? paragraphIndexAtY(double y, String snippet) {
  for (final state in _live) {
    final index = state.widget.index;
    final box = state.context.findRenderObject();
    if (index == null || box is! RenderBox || !box.attached) continue;
    final top = box.localToGlobal(Offset.zero).dy;
    if (y >= top - 4 &&
        y <= top + box.size.height + 4 &&
        parseFragment(state.widget.html).text!.contains(snippet)) {
      return index;
    }
  }
  return null;
}

/// A paragraph rendered as selectable rich text, with `<mark>` shown as a
/// highlight and links kept tappable.
class SelectableParagraph extends StatefulWidget {
  const SelectableParagraph({
    required this.html,
    required this.style,
    required this.padding,
    required this.justify,
    this.onLink,
    this.index,
    super.key,
  });

  final String html;
  final TextStyle style;
  final EdgeInsets padding;
  final bool justify;
  final ValueChanged<String>? onLink;

  /// This paragraph's position in the book, used to place highlights.
  final int? index;

  @override
  State<SelectableParagraph> createState() => _SelectableParagraphState();
}

class _SelectableParagraphState extends State<SelectableParagraph> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void initState() {
    super.initState();
    _live.add(this);
  }

  @override
  void dispose() {
    _live.remove(this);
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  List<TextSpan> _leaves() {
    final leaves = <TextSpan>[];
    void walk(dom.Node node, TextStyle style, String? href) {
      if (node is dom.Text) {
        final text = node.text.replaceAll(RegExp(r'\s+'), ' ');
        if (text.isEmpty) return;
        TapGestureRecognizer? tap;
        if (href != null && widget.onLink != null) {
          tap = TapGestureRecognizer()..onTap = () => widget.onLink!(href);
          _recognizers.add(tap);
        }
        leaves.add(TextSpan(text: text, style: style, recognizer: tap));
      } else if (node is dom.Element) {
        if (node.localName == 'br') {
          leaves.add(const TextSpan(text: '\n'));
          return;
        }
        var next = style;
        var nextHref = href;
        switch (node.localName) {
          case 'b' || 'strong':
            next = style.copyWith(fontWeight: FontWeight.w700);
          case 'i' || 'em' || 'cite':
            next = style.copyWith(fontStyle: FontStyle.italic);
          case 'u':
            next = style.copyWith(decoration: TextDecoration.underline);
          case 'code':
            next = style.copyWith(fontFamily: 'monospace');
          case 'small':
            next = style.copyWith(fontSize: (style.fontSize ?? 16) * 0.85);
          case 'sup' || 'sub':
            next = style.copyWith(fontSize: (style.fontSize ?? 16) * 0.75);
          case 'mark':
            next = style.copyWith(backgroundColor: const Color(0x66FFC83D));
          case 'a':
            nextHref = node.attributes['href'];
            next = style.copyWith(
              color: const Color(0xFF2196F3),
              decoration: TextDecoration.underline,
            );
        }
        for (final child in node.nodes) {
          walk(child, next, nextHref);
        }
      }
    }

    final fragment = parseFragment(widget.html);
    for (final node in fragment.nodes) {
      walk(node, const TextStyle(), null);
    }
    // HTML drops a space that follows another space, even across tags, and
    // ignores the whitespace at the edges of a block.
    final out = <TextSpan>[];
    var afterSpace = true;
    for (final leaf in leaves) {
      var text = leaf.text ?? '';
      if (afterSpace) text = text.trimLeft();
      if (text.isEmpty) continue;
      afterSpace = text.endsWith(' ') || text.endsWith('\n');
      out.add(
        TextSpan(text: text, style: leaf.style, recognizer: leaf.recognizer),
      );
    }
    if (out.isNotEmpty) {
      final last = out.last;
      out[out.length - 1] = TextSpan(
        text: last.text?.trimRight(),
        style: last.style,
        recognizer: last.recognizer,
      );
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    return Padding(
      padding: widget.padding,
      child: Text.rich(
        TextSpan(children: _leaves()),
        style: widget.style,
        textAlign: widget.justify ? TextAlign.justify : TextAlign.start,
      ),
    );
  }
}
