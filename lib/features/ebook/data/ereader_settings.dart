import 'package:flutter/material.dart';

/// PLAN.md Phase 8.2: EPUB-only (PDF/CBZ are image/page-based, no text
/// styling applies). Persisted locally via [EbookRepository] — these are
/// device display prefs, not something the server tracks.
enum EreaderFontFamily { sans, serif }

enum EreaderTheme { light, dark, black }

/// Page-turn style. EPUB and PDF default to [paged]; comics to [scroll]
/// (long strips read better scrolling).
enum ReadingFlow { paged, scroll }

class EreaderSettings {
  const EreaderSettings({
    this.fontFamily = EreaderFontFamily.sans,
    this.fontScale = 1.0,
    this.bold = false,
    this.lineSpacing = 1.25,
    this.theme = EreaderTheme.dark,
    this.epubFlow = ReadingFlow.paged,
    this.pdfFlow = ReadingFlow.paged,
    this.comicFlow = ReadingFlow.scroll,
    this.justify = false,
    this.margin = 16,
    this.marginVertical = 4,
    this.brightness = 1.0,
    this.keepScreenOn = true,
    this.tapToTurn = true,
  });

  factory EreaderSettings.fromJson(Map<String, dynamic> json) {
    return EreaderSettings(
      fontFamily: EreaderFontFamily.values.firstWhere(
        (f) => f.name == json['fontFamily'],
        orElse: () => EreaderFontFamily.sans,
      ),
      fontScale: (json['fontScale'] as num?)?.toDouble() ?? 1.0,
      bold: json['bold'] as bool? ?? false,
      lineSpacing: (json['lineSpacing'] as num?)?.toDouble() ?? 1.25,
      theme: EreaderTheme.values.firstWhere(
        (t) => t.name == json['theme'],
        orElse: () => EreaderTheme.dark,
      ),
      epubFlow: _flow(json['epubFlow'], ReadingFlow.paged),
      pdfFlow: _flow(json['pdfFlow'], ReadingFlow.paged),
      comicFlow: _flow(json['comicFlow'], ReadingFlow.scroll),
      justify: json['justify'] as bool? ?? false,
      margin: (json['margin'] as num?)?.toDouble() ?? 16,
      marginVertical: (json['marginVertical'] as num?)?.toDouble() ?? 4,
      brightness: (json['brightness'] as num?)?.toDouble() ?? 1.0,
      keepScreenOn: json['keepScreenOn'] as bool? ?? true,
      tapToTurn: json['tapToTurn'] as bool? ?? true,
    );
  }

  static ReadingFlow _flow(Object? raw, ReadingFlow fallback) => ReadingFlow
      .values
      .firstWhere((f) => f.name == raw, orElse: () => fallback);

  final EreaderFontFamily fontFamily;
  final double fontScale;
  final bool bold;
  final double lineSpacing;
  final EreaderTheme theme;
  final ReadingFlow epubFlow;
  final ReadingFlow pdfFlow;
  final ReadingFlow comicFlow;
  final bool justify;

  /// Horizontal text margin in logical pixels.
  final double margin;

  /// Space above and below the text, in logical pixels.
  final double marginVertical;

  /// 0.2..1.0; below 1 dims the reader with an overlay (no system permission).
  final double brightness;
  final bool keepScreenOn;

  /// Tap the left/right edge of the page to turn it.
  final bool tapToTurn;

  Map<String, dynamic> toJson() => {
    'fontFamily': fontFamily.name,
    'fontScale': fontScale,
    'bold': bold,
    'lineSpacing': lineSpacing,
    'theme': theme.name,
    'epubFlow': epubFlow.name,
    'pdfFlow': pdfFlow.name,
    'comicFlow': comicFlow.name,
    'justify': justify,
    'margin': margin,
    'marginVertical': marginVertical,
    'brightness': brightness,
    'keepScreenOn': keepScreenOn,
    'tapToTurn': tapToTurn,
  };

  EreaderSettings copyWith({
    EreaderFontFamily? fontFamily,
    double? fontScale,
    bool? bold,
    double? lineSpacing,
    EreaderTheme? theme,
    ReadingFlow? epubFlow,
    ReadingFlow? pdfFlow,
    ReadingFlow? comicFlow,
    bool? justify,
    double? margin,
    double? marginVertical,
    double? brightness,
    bool? keepScreenOn,
    bool? tapToTurn,
  }) {
    return EreaderSettings(
      fontFamily: fontFamily ?? this.fontFamily,
      fontScale: fontScale ?? this.fontScale,
      bold: bold ?? this.bold,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      theme: theme ?? this.theme,
      epubFlow: epubFlow ?? this.epubFlow,
      pdfFlow: pdfFlow ?? this.pdfFlow,
      comicFlow: comicFlow ?? this.comicFlow,
      justify: justify ?? this.justify,
      margin: margin ?? this.margin,
      marginVertical: marginVertical ?? this.marginVertical,
      brightness: brightness ?? this.brightness,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      tapToTurn: tapToTurn ?? this.tapToTurn,
    );
  }

  Color get backgroundColor => switch (theme) {
    EreaderTheme.light => const Color(0xFFFAF6EF),
    EreaderTheme.dark => const Color(0xFF1B1410),
    EreaderTheme.black => Colors.black,
  };

  Color get textColor => switch (theme) {
    EreaderTheme.light => const Color(0xFF2A211A),
    EreaderTheme.dark => const Color(0xFFEDE2D3),
    EreaderTheme.black => const Color(0xFFCFCFCF),
  };

  TextStyle textStyle({double baseFontSize = 16}) {
    return TextStyle(
      fontFamily: fontFamily == EreaderFontFamily.serif ? 'serif' : null,
      fontSize: baseFontSize * fontScale,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      height: lineSpacing,
      color: textColor,
    );
  }
}
