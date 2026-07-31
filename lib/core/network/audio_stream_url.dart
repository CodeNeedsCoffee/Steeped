/// Turns an [AudioTrack.contentUrl] (relative, e.g.
/// `/api/items/:id/file/:ino`) into a fully-qualified, authenticated URL
/// `just_audio` can stream directly. Same `?token=` query-param auth path
/// as [coverImageUrl] — playback doesn't go through `dioProvider` either.
String audioStreamUrl({
  required String serverUrl,
  required String relativeContentUrl,
  required String? token,
}) {
  final uri = Uri.parse('$serverUrl$relativeContentUrl');
  if (token == null) return uri.toString();
  return uri.replace(queryParameters: {...uri.queryParameters, 'token': token}).toString();
}
