import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Shared cover-art widget (PLAN.md Phase 4.9) — every book/podcast cover
/// in the app should go through this so caching behavior stays consistent.
class CoverImage extends StatelessWidget {
  const CoverImage({required this.url, this.width, this.height, super.key});

  final String url;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final placeholderColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: placeholderColor),
        errorWidget: (context, url, error) => Container(
          color: placeholderColor,
          child: const Icon(Icons.menu_book_outlined),
        ),
      ),
    );
  }
}
