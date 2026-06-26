import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';

/// Circular channel logo — unlike [AppAvatar] (which uses BoxFit.cover,
/// correct for profile photos), this uses BoxFit.contain so a non-square
/// brand logo is never cropped/zoomed into its center. Falls back to a
/// "#" mark on a tinted circle when the channel has no logo set.
class ChannelLogo extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const ChannelLogo({super.key, this.imageUrl, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.divider, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          color: Colors.white,
          padding: hasImage ? EdgeInsets.all(size * 0.12) : EdgeInsets.zero,
          child: hasImage
              ? CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => _hashPlaceholder(),
                  errorWidget: (_, __, ___) => _hashPlaceholder(),
                )
              : _hashPlaceholder(),
        ),
      ),
    );
  }

  Widget _hashPlaceholder() {
    return Container(
      color: AppColors.primaryTint,
      alignment: Alignment.center,
      child: Text(
        '#',
        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: size * 0.4),
      ),
    );
  }
}
