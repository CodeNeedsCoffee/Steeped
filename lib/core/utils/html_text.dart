/// Audiobookshelf descriptions are often HTML (`<br />`, `<p>`, `<i>`, `&amp;`)
/// from the metadata provider. The app shows them as plain text, so turn
/// block breaks into line breaks, drop the tags and decode common entities.
String plainTextFromHtml(String html) {
  var s = html;
  s = s.replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'<\s*/\s*(p|div|h[1-6]|li|ul|ol)\s*>', caseSensitive: false), '\n\n');
  s = s.replaceAll(RegExp(r'<\s*li[^>]*>', caseSensitive: false), '• ');
  s = s.replaceAll(RegExp(r'<[^>]*>'), '');
  s = s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&rsquo;', '’')
      .replaceAll('&lsquo;', '‘')
      .replaceAll('&rdquo;', '”')
      .replaceAll('&ldquo;', '“')
      .replaceAll('&mdash;', '—')
      .replaceAll('&ndash;', '–')
      .replaceAll('&hellip;', '…')
      .replaceAll('&amp;', '&');
  s = s.replaceAll(RegExp(r'[ \t]+\n'), '\n').replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return s.trim();
}
