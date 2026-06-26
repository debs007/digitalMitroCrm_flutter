import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../core/theme/app_colors.dart';
import '../models/message_model.dart';

bool _isImageFile(String path) =>
    RegExp(r'\.(jpg|jpeg|png|gif|webp)$', caseSensitive: false).hasMatch(path);
bool _isVideoFile(String path) =>
    RegExp(r'\.(mp4|mov|avi|mkv|webm)$', caseSensitive: false).hasMatch(path);

class ChatInputBar extends StatefulWidget {
  final ChatMessage? replyingTo;
  final VoidCallback? onCancelReply;
  final Future<void> Function(String text, File? attachment) onSend;
  final bool sending;

  const ChatInputBar({
    super.key,
    this.replyingTo,
    this.onCancelReply,
    required this.onSend,
    this.sending = false,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  File? _pendingAttachment;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _showAttachMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(alignment: Alignment.centerLeft, child: Text('Share', style: TextStyle(fontWeight: FontWeight.w700))),
            ),
            ListTile(
              leading: Icon(Icons.photo_camera_outlined, color: AppColors.primary),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('Photo or video from gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: Icon(Icons.insert_drive_file_outlined, color: AppColors.primary),
              title: const Text('Document or other file'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );

    if (choice == null) return;

    switch (choice) {
      case 'camera':
        await _pickFromCamera();
        break;
      case 'gallery':
        await _pickFromGallery();
        break;
      case 'file':
        await _pickAnyFile();
        break;
    }
  }

  Future<void> _pickFromCamera() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
    if (picked != null) setState(() => _pendingAttachment = File(picked.path));
  }

  Future<void> _pickFromGallery() async {
    // pickMedia covers both images and videos from the gallery in one picker.
    final picked = await ImagePicker().pickMedia(imageQuality: 80);
    if (picked != null) setState(() => _pendingAttachment = File(picked.path));
  }

  Future<void> _pickAnyFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      setState(() => _pendingAttachment = File(result.files.single.path!));
    }
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _pendingAttachment == null) return;
    final attachment = _pendingAttachment;
    _controller.clear();
    setState(() => _pendingAttachment = null);
    await widget.onSend(text, attachment);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.replyingTo != null) _buildReplyPreview(),
            if (_pendingAttachment != null) _buildAttachmentPreview(),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: AppColors.textSecondary),
                    onPressed: widget.sending ? null : _showAttachMenu,
                  ),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          filled: true,
                          fillColor: AppColors.neutralBg,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  widget.sending
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.loader)),
                        )
                      : IconButton(
                          icon: Icon(Icons.send_rounded, color: AppColors.primary),
                          onPressed: _handleSend,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: AppColors.primarySoft,
      child: Row(
        children: [
          Container(width: 3, height: 32, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
                Text(
                  widget.replyingTo?.message ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: widget.onCancelReply,
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentPreview() {
    final path = _pendingAttachment!.path;
    final isImage = _isImageFile(path);
    final isVideo = _isVideoFile(path);
    final fileName = path.split('/').last;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: AppColors.neutralBg,
      child: Row(
        children: [
          if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(_pendingAttachment!, width: 44, height: 44, fit: BoxFit.cover),
            )
          else
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(8)),
              child: Icon(
                isVideo ? Icons.videocam_outlined : Icons.insert_drive_file_outlined,
                color: AppColors.primary,
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isImage ? 'Image attached' : (isVideo ? 'Video attached' : fileName),
              style: const TextStyle(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _pendingAttachment = null),
          ),
        ],
      ),
    );
  }
}
