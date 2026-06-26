import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/network/api_exception.dart';
import '../../services/channel_service.dart';
import '../../widgets/channel_logo.dart';

/// Admin/SuperAdmin-only "Edit channel" — update the name and/or logo.
/// Backend note: both actions are owner-only regardless of admin status
/// (the API itself enforces this, not just the menu gating) — if you're
/// not the channel's actual owner, the save will fail with a clear
/// message from the server rather than silently doing nothing.
class EditChannelScreen extends StatefulWidget {
  final String channelId;
  final String currentName;
  final String? currentImage;

  const EditChannelScreen({
    super.key,
    required this.channelId,
    required this.currentName,
    this.currentImage,
  });

  @override
  State<EditChannelScreen> createState() => _EditChannelScreenState();
}

class _EditChannelScreenState extends State<EditChannelScreen> {
  late TextEditingController _nameController;
  File? _pendingImage;
  String? _existingImageUrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _existingImageUrl = widget.currentImage;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 800);
    if (picked != null) setState(() => _pendingImage = File(picked.path));
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Channel name cannot be empty.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Run sequentially rather than in parallel — if the name update gets
      // rejected (e.g. not the owner), there's no point also uploading
      // the image, and showing one clear error beats two overlapping ones.
      if (_nameController.text.trim() != widget.currentName) {
        await ChannelService.instance.updateChannelInfo(
          channelId: widget.channelId,
          name: _nameController.text.trim(),
        );
      }
      if (_pendingImage != null) {
        final newUrl = await ChannelService.instance.uploadChannelImage(widget.channelId, _pendingImage!);
        setState(() {
          _existingImageUrl = newUrl;
          _pendingImage = null;
        });
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Could not save changes.';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Channel')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!, style: TextStyle(color: AppColors.danger)),
              ),

            Center(
              child: Stack(
                children: [
                  _pendingImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(44),
                          child: Image.file(_pendingImage!, width: 88, height: 88, fit: BoxFit.cover),
                        )
                      : ChannelLogo(imageUrl: _existingImageUrl, size: 88),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: const Icon(Icons.camera_alt, size: 15, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            Text('Channel name', style: AppText.label),
            const SizedBox(height: 6),
            TextField(controller: _nameController),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
