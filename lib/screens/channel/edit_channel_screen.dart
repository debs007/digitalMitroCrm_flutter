import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/network/api_exception.dart';
import '../../models/channel_detail_model.dart';
import '../../services/channel_service.dart';
import '../../widgets/channel_logo.dart';
import '../../widgets/state_views.dart';

const List<String> kChannelStatusOptions = ['Active', 'Archived', 'Paused', 'Closed'];

/// Admin/SuperAdmin-only "Edit channel" — name, logo, description, status,
/// up to 2 tags, and the purpose/industry/website/location detail fields.
/// Backend note: every field here is owner-only regardless of admin status
/// (the API itself enforces this, not just the menu gating) — if you're
/// not the channel's actual owner, the save will fail with a clear
/// message from the server rather than silently doing nothing.
class EditChannelScreen extends StatefulWidget {
  final String channelId;

  const EditChannelScreen({super.key, required this.channelId});

  @override
  State<EditChannelScreen> createState() => _EditChannelScreenState();
}

class _EditChannelScreenState extends State<EditChannelScreen> {
  bool _isLoading = true;
  String? _loadError;

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tag1Controller = TextEditingController();
  final _tag2Controller = TextEditingController();
  final _purposeController = TextEditingController();
  final _industryController = TextEditingController();
  final _websiteController = TextEditingController();
  final _locationController = TextEditingController();

  String _statusTag = 'Active';
  File? _pendingImage;
  String? _existingImageUrl;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final detail = await ChannelService.instance.getDetail(widget.channelId);
      _nameController.text = detail.name;
      _descriptionController.text = detail.description;
      _existingImageUrl = detail.image;
      _statusTag = kChannelStatusOptions.contains(detail.statusTag) ? detail.statusTag : 'Active';
      if (detail.tags.isNotEmpty) _tag1Controller.text = detail.tags[0];
      if (detail.tags.length > 1) _tag2Controller.text = detail.tags[1];
      _purposeController.text = detail.extraDetails.purpose;
      _industryController.text = detail.extraDetails.industry;
      _websiteController.text = detail.extraDetails.website;
      _locationController.text = detail.extraDetails.location;
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _loadError = e is ApiException ? e.message : 'Could not load channel details.';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _tag1Controller.dispose();
    _tag2Controller.dispose();
    _purposeController.dispose();
    _industryController.dispose();
    _websiteController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 800);
    if (picked != null) setState(() => _pendingImage = File(picked.path));
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _saveError = 'Channel name cannot be empty.');
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final tags = [_tag1Controller.text.trim(), _tag2Controller.text.trim()]
          .where((t) => t.isNotEmpty)
          .toList();

      // Run sequentially rather than in parallel — if this gets rejected
      // (e.g. not the owner), there's no point also uploading the image,
      // and one clear error beats two overlapping ones.
      await ChannelService.instance.updateChannelInfo(
        channelId: widget.channelId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        statusTag: _statusTag,
        tags: tags,
        channelDetails: ChannelExtraDetails(
          purpose: _purposeController.text.trim(),
          industry: _industryController.text.trim(),
          website: _websiteController.text.trim(),
          location: _locationController.text.trim(),
        ),
      );
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
        _saveError = e is ApiException ? e.message : 'Could not save changes.';
        _saving = false;
      });
    }
  }

  Widget _field(String label, TextEditingController controller, {String? hint, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.label),
          const SizedBox(height: 6),
          TextField(controller: controller, maxLines: maxLines, decoration: InputDecoration(hintText: hint)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Channel')),
      body: _isLoading
          ? const LoadingView()
          : _loadError != null
              ? ErrorView(message: _loadError!, onRetry: _load)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_saveError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(_saveError!, style: TextStyle(color: AppColors.danger)),
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

                      _field('Channel name', _nameController),
                      _field('Description', _descriptionController, hint: 'What is this channel for?', maxLines: 2),

                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Status', style: AppText.label),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: _statusTag,
                              items: kChannelStatusOptions
                                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                  .toList(),
                              onChanged: (v) => setState(() => _statusTag = v ?? _statusTag),
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tags (up to 2)', style: AppText.label),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(child: TextField(controller: _tag1Controller, decoration: const InputDecoration(hintText: 'Tag 1'))),
                                const SizedBox(width: 10),
                                Expanded(child: TextField(controller: _tag2Controller, decoration: const InputDecoration(hintText: 'Tag 2'))),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),
                      Text('Channel details', style: AppText.h3),
                      const SizedBox(height: 14),
                      _field('Purpose', _purposeController, hint: 'e.g. Coordinate marketing campaigns'),
                      _field('Industry', _industryController, hint: 'e.g. Retail, SaaS, Healthcare'),
                      _field('Website', _websiteController, hint: 'https://example.com'),
                      _field('Location', _locationController, hint: 'e.g. Kolkata, India'),

                      const SizedBox(height: 8),
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
