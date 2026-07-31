/// `GET /api/items/:id/cover`. Auth accepts a `?token=` query param
/// (confirmed against `Auth.js`'s JWT extractor) — needed because
/// [CachedNetworkImage] doesn't go through [dioProvider]'s auth interceptor,
/// it makes its own bare HTTP request straight from this URL.
String coverImageUrl({
  required String serverUrl,
  required String itemId,
  required String? token,
  required int updatedAt,
}) {
  final queryParameters = {'ts': '$updatedAt'};
  if (token != null) queryParameters['token'] = token;
  final uri = Uri.parse(
    '$serverUrl/api/items/$itemId/cover',
  ).replace(queryParameters: queryParameters);
  return uri.toString();
}
