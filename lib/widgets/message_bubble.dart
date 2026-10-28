import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/api_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/file_download_helper.dart';
import '../models/message_model.dart';
import '../screens/chat/image_preview_screen.dart';
import '../screens/chat/pdf_preview_screen.dart';
import '../screens/chat/video_preview_screen.dart';
import 'linkify_text.dart';
import 'task_message_card.dart';

bool _isImageUrl(String url) =>
    RegExp(r'\.(jpg|jpeg|png|gif|webp)(\?.*)?$', caseSensitive: false).hasMatch(url);
bool _isVideoUrl(String url) =>
    RegExp(r'\.(mp4|mov|avi|mkv|webm)(\?.*)?$', caseSensitive: false).hasMatch(url);
bool _isPdfUrl(String url) =>
    RegExp(r'\.pdf(\?.*)?$', caseSensitive: false).hasMatch(url);
bool _isDocUrl(String url) => RegExp(
      r'\.(pdf|docx?|xlsx?|pptx?|csv|txt|zip|rar)(\?.*)?$',
      caseSensitive: false,
    ).hasMatch(url);

/// True when a *system* message's text is actually a file path/URL rather
/// than a plain notice (e.g. "X joined the channel"). Used to give channel
/// task reports — posted as a system message whose `message` field is the
/// report's file path — a proper file chip instead of a plain-text pill.
/// Guarded by the leading "/" or "http" so ordinary sentences are never
/// misclassified — free-form text never starts with either.
bool _looksLikeFileUrl(String value) {
  if (!(value.startsWith('http://') || value.startsWith('https://') || value.startsWith('/'))) {
    return false;
  }
  return _isImageUrl(value) || _isVideoUrl(value) || _isDocUrl(value);
}

// Small curated set for quick message reactions — matches the web app's
// QUICK_REACTIONS so the experience is consistent across platforms.
const List<String> kQuickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isSelf;
  final String senderLabel;
  final String? senderAvatar;
  final String currentUserId;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTogglePin;
  final void Function(String emoji)? onReact;
  final VoidCallback? onTapReplyPreview;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isSelf,
    required this.senderLabel,
    this.senderAvatar,
    this.currentUserId = '',
    this.onReply,
    this.onEdit,
    this.onDelete,
    this.onTogglePin,
    this.onReact,
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
            // Quick-react row — the whole point of "hold to react": no
            // extra tap needed, the emojis are right here on long-press.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: kQuickReactions.map((emoji) {
                  return GestureDetector(
                    onTap: () { Navigator.pop(ctx); onReact?.call(emoji); },
                    child: Text(emoji, style: const TextStyle(fontSize: 26)),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),
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
                leading: Icon(Icons.delete_outline, color: AppColors.danger),
                title: Text('Delete', style: TextStyle(color: AppColors.danger)),
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
      if (message.taskSnapshot != null) {
        return TaskMessageCard(message: message);
      }
      // A monthly/task report is posted as a system message whose `message`
      // field is the report's file path (not a human-written notice) — show
      // it as a downloadable file chip instead of the raw path as text.
      if (_looksLikeFileUrl(message.message)) {
        return _buildSystemFileMessage(context, message.message);
      }
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: AppColors.neutralBg, borderRadius: BorderRadius.circular(12)),
          child: Text(message.message, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ),
      );
    }

    final bubbleColor = isSelf ? AppColors.primary : AppColors.neutralBg;
    final textColor = isSelf ? Colors.white : AppColors.textPrimary;

    return Align(
      alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSelf) _senderAvatarWidget(),
          GestureDetector(
        onLongPress: () => _showActions(context),
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
          margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            gradient: isSelf ? AppColors.primaryGradient : null,
            color: isSelf ? null : bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isSelf ? 18 : 4),
              bottomRight: Radius.circular(isSelf ? 4 : 18),
            ),
            boxShadow: [
              BoxShadow(
                color: (isSelf ? AppColors.primary : Colors.black).withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isSelf && senderLabel.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    senderLabel,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
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
              if (message.hasAttachments) _buildAttachments(context),
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
                  if (isSelf) ...[
                    const SizedBox(width: 3),
                    Icon(
                      (message.seen || message.seenBy.isNotEmpty) ? Icons.done_all : Icons.done,
                      size: 13,
                      color: (message.seen || message.seenBy.isNotEmpty)
                          ? Colors.lightBlueAccent
                          : Colors.white.withValues(alpha: 0.75),
                    ),
                  ],
                ],
              ),
              if (message.hasReactions) _buildReactionRow(),
            ],
          ),
        ),
          ),
        ],
      ),
    );
  }

  Widget _senderAvatarWidget() {
    return Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 2),
      child: senderAvatar != null && senderAvatar!.isNotEmpty
          ? CircleAvatar(
              radius: 13,
              backgroundColor: AppColors.neutralBg,
              backgroundImage: CachedNetworkImageProvider(senderAvatar!),
            )
          : CircleAvatar(
              radius: 13,
              backgroundColor: AppColors.primaryTint,
              child: Text(
                senderLabel.isNotEmpty ? senderLabel[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ),
    );
  }

  Widget _buildReactionRow() {
    final grouped = message.reactionsByEmoji;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: grouped.entries.map((entry) {
          final emoji = entry.key;
          final reactors = entry.value;
          final iReacted = reactors.any((r) => r.userId == currentUserId);
          return GestureDetector(
            onTap: () => onReact?.call(emoji),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: iReacted ? AppColors.primarySoft : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: iReacted ? AppColors.primary : AppColors.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 3),
                  Text(
                    reactors.length.toString(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: iReacted ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAttachments(BuildContext context) {
    final attachments = message.attachments.map(ApiConstants.resolveFileUrl).toList();
    final images = attachments.where(_isImageUrl).toList();
    final videos = attachments.where(_isVideoUrl).toList();
    final otherFiles = attachments
        .where((a) => !_isImageUrl(a) && !_isVideoUrl(a))
        .toList();

    String fileNameOf(String url) {
      // Backend appends ?filename=original.ext to chat uploads.
      final uri = Uri.tryParse(url);
      final fromQuery = uri?.queryParameters['filename'];
      if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;
      final segments = uri?.pathSegments ?? [];
      return segments.isNotEmpty ? segments.last : 'Attachment';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (images.isNotEmpty)
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: images.map((url) => GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ImagePreviewScreen(imageUrl: url)),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
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
                    ),
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: _downloadDot(context, url, fileNameOf(url)),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ...videos.map((url) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => VideoPreviewScreen(url: url)),
              ),
              child: Stack(
                children: [
                  Container(
                    width: 140,
                    height: 100,
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(10)),
                    alignment: Alignment.center,
                    child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 36),
                  ),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: _downloadDot(context, url, fileNameOf(url)),
                  ),
                ],
              ),
            ),
          )),
          ...otherFiles.map((url) {
            final fileLabel = fileNameOf(url);
            final isPdf = _isPdfUrl(url);
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: isPdf
                        ? () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => PdfPreviewScreen(url: url, title: fileLabel)),
                            )
                        : () async {
                            final uri = Uri.tryParse(url);
                            if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                          },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isPdf ? Icons.picture_as_pdf_outlined : Icons.insert_drive_file_outlined, size: 16),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: Text(
                            fileLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, decoration: TextDecoration.underline),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_outlined, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => downloadAttachment(context, url, fileLabel),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Renders a system message whose text is actually a file path (e.g. a
  /// monthly/task report) as a tappable chip — PDF/image tap into the
  /// existing in-app preview screens, other types launch externally — with
  /// a download button, instead of showing the raw path as plain text.
  Widget _buildSystemFileMessage(BuildContext context, String rawUrl) {
    final url = ApiConstants.resolveFileUrl(rawUrl);
    // Prefer the human title carried in replyPreview.message (e.g. "July
    // 2026 task report") over the disk filename, which is prefixed with
    // the channel id and a timestamp.
    final label = message.replyPreview?.message;
    final uri = Uri.tryParse(url);
    final diskName = (uri?.pathSegments.isNotEmpty ?? false) ? uri!.pathSegments.last : 'Report';
    final displayName = (label != null && label.isNotEmpty) ? label : diskName;
    final isPdf = _isPdfUrl(url);
    final isImg = _isImageUrl(url);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {
          if (isPdf) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PdfPreviewScreen(url: url, title: displayName)),
            );
          } else if (isImg) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ImagePreviewScreen(imageUrl: url)),
            );
          } else {
            final launchUri = Uri.tryParse(url);
            if (launchUri != null) launchUrl(launchUri, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.neutralBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPdf
                    ? Icons.picture_as_pdf_outlined
                    : (isImg ? Icons.image_outlined : Icons.insert_drive_file_outlined),
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.download_outlined, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () => downloadAttachment(context, url, diskName),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _downloadDot(BuildContext context, String url, String fileName) {
    return GestureDetector(
      onTap: () => downloadAttachment(context, url, fileName),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
        alignment: Alignment.center,
        child: const Icon(Icons.download_outlined, color: Colors.white, size: 14),
      ),
    );
  }
}
