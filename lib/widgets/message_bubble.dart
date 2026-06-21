import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_colors.dart';
import '../models/message_model.dart';
import 'linkify_text.dart';

bool _isImageUrl(String url) =>
    RegExp(r'\.(jpg|jpeg|png|gif|webp)(\?.*)?$', caseSensitive: false).hasMatch(url);

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isSelf;
  final String senderLabel;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTogglePin;
  final VoidCallback? onTapReplyPreview;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isSelf,
    required this.senderLabel,
    this.onReply,
    this.onEdit,
    this.onDelete,
    this.onTogglePin,
    this.onTapReplyPreview,
  });

  void _showActions(BuildContext context) {
    if (message.isDeleted || message.isSystem) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () { Navigator.pop(ctx); onReply?.call(); },
            ),
            ListTile(
              leading: Icon(message.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(message.isPinned ? 'Unpin' : 'Pin'),
              onTap: () { Navigator.pop(ctx); onTogglePin?.call(); },
            ),
            if (isSelf && message.isWithinEditWindow) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () { Navigator.pop(ctx); onEdit?.call(); },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                title: const Text('Delete', style: TextStyle(color: AppColors.danger)),
                onTap: () { Navigator.pop(ctx); onDelete?.call(); },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: AppColors.neutralBg, borderRadius: BorderRadius.circular(12)),
          child: Text(message.message, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ),
      );
    }

    final bubbleColor = isSelf ? AppColors.primary : AppColors.neutralBg;
    final textColor = isSelf ? Colors.white : AppColors.textPrimary;

    return Align(
      alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showActions(context),
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(isSelf ? 14 : 2),
              bottomRight: Radius.circular(isSelf ? 2 : 14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isSelf && senderLabel.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    senderLabel,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ),
              if (message.replyPreview?.message != null)
                GestureDetector(
                  onTap: onTapReplyPreview,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelf ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border(left: BorderSide(color: isSelf ? Colors.white : AppColors.primary, width: 3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.replyPreview!.senderName ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelf ? Colors.white70 : AppColors.primary,
                          ),
                        ),
                        Text(
                          message.replyPreview!.message ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: isSelf ? Colors.white70 : AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              if (message.hasAttachments) _buildAttachments(),
              if (message.isDeleted)
                Text(
                  'This message was deleted',
                  style: TextStyle(fontStyle: FontStyle.italic, color: textColor.withValues(alpha: 0.7), fontSize: 13),
                )
              else if (message.message.isNotEmpty)
                LinkifyText(
                  text: message.message,
                  style: TextStyle(color: textColor, fontSize: 14),
                  linkColor: isSelf ? Colors.white : AppColors.info,
                ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.isPinned)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.push_pin, size: 11, color: textColor.withValues(alpha: 0.7)),
                    ),
                  if (message.isEdited && !message.isDeleted)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text('edited', style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.6))),
                    ),
                  Text(
                    DateFormat('HH:mm').format(message.createdAt),
                    style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachments() {
    final images = message.attachments.where(_isImageUrl).toList();
    final files = message.attachments.where((a) => !_isImageUrl(a)).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (images.isNotEmpty)
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: images.map((url) => ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: url,
                  width: 140,
                  height: 140,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(width: 140, height: 140, color: AppColors.neutralBg),
                  errorWidget: (_, __, ___) => Container(
                    width: 140,
                    height: 140,
                    color: AppColors.neutralBg,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              )).toList(),
            ),
          ...files.map((url) {
            final segments = Uri.tryParse(url)?.pathSegments ?? [];
            final fileLabel = segments.isNotEmpty ? segments.last : 'Attachment';
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.insert_drive_file_outlined, size: 16),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      fileLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
