import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Full-screen in-app image viewer — pinch to zoom, swipe down/tap back
/// to dismiss. Opened when tapping an image attachment in chat.
class ImagePreviewScreen extends StatelessWidget {
  final String imageUrl;
  final String? heroTag;

  const ImagePreviewScreen({super.key, required this.imageUrl, this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Hero(
            tag: heroTag ?? imageUrl,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (_, __) => const CircularProgressIndicator(color: Colors.white),
              errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}
