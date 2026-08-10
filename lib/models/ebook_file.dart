/// `media.ebookFile` on an expanded item response — confirmed live against
/// evan's real server (2026-07-31): `{ ino, metadata: { filename, ext,
/// size, ... }, ebookFormat, addedAt, updatedAt }`. Covers both text ebooks
/// (epub/pdf/mobi/azw3) and comic archives (cbz/cbr) — both are `mediaType:
/// 'book'` items differentiated only by [format], not by library type (a
/// server library's own "eBooks" vs "Comics" naming is cosmetic).
///
/// The file's bytes are served by the same generic `GET
/// /api/items/:id/file/:ino` endpoint already used for audio tracks —
/// confirmed live by fetching a real 44MB EPUB and a real 128MB CBZ through
/// it and checking the response's magic bytes (`PK\x03\x04`, correct ZIP
/// signature for both container formats).
class EbookFile {
  const EbookFile({
    required this.ino,
    required this.filename,
    required this.format,
    required this.size,
  });

  factory EbookFile.fromJson(Map<String, dynamic> json) {
    final metadata = (json['metadata'] as Map<String, dynamic>?) ?? const {};
    return EbookFile(
      ino: json['ino'] as String? ?? '',
      filename: metadata['filename'] as String? ?? '',
      format: (json['ebookFormat'] as String? ?? '').toLowerCase(),
      size: (metadata['size'] as num?)?.toInt() ?? 0,
    );
  }

  final String ino;
  final String filename;
  final String format; // epub | pdf | cbz | cbr | mobi | azw3 | ...
  final int size;

  bool get isEpub => format == 'epub';
  bool get isPdf => format == 'pdf';
  bool get isComic => format == 'cbz' || format == 'cbr';

  /// `archive` (pure Dart) only decodes zip — cbr is RAR-based and has no
  /// pure-Dart decoder available, so it's not readable client-side.
  bool get isSupported => isEpub || isPdf || format == 'cbz';
}
