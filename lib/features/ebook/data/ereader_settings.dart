import 'package:flutter/material.dart';

/// PLAN.md Phase 8.2: EPUB-only (PDF/CBZ are image/page-based, no text
/// styling applies). Persisted locally via [EbookRepository] — these are
/// device display prefs, not something the server tracks.
enum EreaderFontFamily { sans, serif }

enum EreaderTheme { light, dark, black }

class EreaderSettings {
  const EreaderSettings({
    this.fontFamily = EreaderFontFamily.sans,
    this.fontScale = 1.0,
    this.bold = false,
    this.lineSpacing = 1.25,
    this.theme = EreaderTheme.dark,
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
    );
  }

  final EreaderFontFamily fontFamily;
  final double fontScale;
  final bool bold;
  final double lineSpacing;
  final EreaderTheme theme;

  Map<String, dynamic> toJson() => {
    'fontFamily': fontFamily.name,
    'fontScale': fontScale,
    'bold': bold,
    'lineSpacing': lineSpacing,
    'theme': theme.name,
  };

  EreaderSettings copyWith({
    EreaderFontFamily? fontFamily,
    double? fontScale,
    bool? bold,
    double? lineSpacing,
    EreaderTheme? theme,
  }) {
    return EreaderSettings(
      fontFamily: fontFamily ?? this.fontFamily,
      fontScale: fontScale ?? this.fontScale,
      bold: bold ?? this.bold,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      theme: theme ?? this.theme,
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
