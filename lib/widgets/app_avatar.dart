import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';

/// Circular avatar — shows the network image when [imageUrl] is non-empty,
/// otherwise falls back to a coloured circle with the person's initials
/// (mirrors the web app's Avatar.jsx behaviour).
class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final Widget? badge;

  const AppAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 44,
    this.badge,
  });

  String get _initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  Color get _bgColor {
    // Deterministic colour from the name so the same person always gets
    // the same avatar colour.
    const palette = [
      Color(0xFF6D28D9),
      Color(0xFF2563EB),
      Color(0xFF059669),
      Color(0xFFD97706),
      Color(0xFFDB2777),
      Color(0xFF0891B2),
    ];
    final hash = name.codeUnits.fold<int>(0, (a, b) => a + b);
    return palette[hash % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    final core = ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: hasImage
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, __) => _initialsCircle(),
              errorWidget: (_, __, ___) => _initialsCircle(),
            )
          : _initialsCircle(),
    );

    if (badge == null) return core;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        core,
        Positioned(right: -1, bottom: -1, child: badge!),
      ],
    );
  }

  Widget _initialsCircle() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: _bgColor,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.38,
        ),
      ),
    );
  }
}

/// Small green/grey dot used to show online presence, matching the web app.
class PresenceDot extends StatelessWidget {
  final bool isOnline;
  final double size;

  const PresenceDot({super.key, required this.isOnline, this.size = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline ? AppColors.online : AppColors.offline,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}
