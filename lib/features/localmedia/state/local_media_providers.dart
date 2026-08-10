import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_database.dart';
import '../data/local_media_repository.dart';

final localMediaRepositoryProvider = Provider<LocalMediaRepository>((ref) {
  return LocalMediaRepository(ref.watch(appDatabaseProvider));
});

final localMediaListProvider = StreamProvider<List<LocalMediaItem>>((ref) {
  return ref.watch(localMediaRepositoryProvider).watchAll();
});
