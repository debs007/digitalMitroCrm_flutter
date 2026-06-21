import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/network/api_exception.dart';
import '../../models/channel_detail_model.dart';
import '../../services/channel_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/state_views.dart';

class ChannelMembersScreen extends StatefulWidget {
  final String channelId;
  final String channelName;

  const ChannelMembersScreen({super.key, required this.channelId, required this.channelName});

  @override
  State<ChannelMembersScreen> createState() => _ChannelMembersScreenState();
}

class _ChannelMembersScreenState extends State<ChannelMembersScreen> {
  bool _isLoading = true;
  String? _error;
  ChannelDetail? _detail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final detail = await ChannelService.instance.getDetail(widget.channelId);
      setState(() {
        _detail = detail;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load channel members.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('#${widget.channelName}')),
      body: _isLoading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    if (_detail?.description.isNotEmpty == true)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        color: AppColors.primarySoft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('About', style: AppText.captionBold),
                            const SizedBox(height: 4),
                            Text(_detail!.description, style: AppText.body),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Text('Members', style: AppText.h3),
                          const SizedBox(width: 8),
                          Text('(${_detail?.members.length ?? 0})', style: AppText.bodyMuted),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _detail == null || _detail!.members.isEmpty
                          ? const EmptyView(message: 'No members found.', icon: Icons.people_outline)
                          : ListView.builder(
                              itemCount: _detail!.members.length,
                              itemBuilder: (context, index) {
                                final member = _detail!.members[index];
                                final isOwner = member.id == _detail!.ownerId;
                                return ListTile(
                                  leading: AppAvatar(name: member.name, imageUrl: member.avatar, size: 42),
                                  title: Text(member.name),
                                  subtitle: Text(member.email, style: AppText.caption),
                                  trailing: isOwner
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryTint,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text('Owner', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700)),
                                        )
                                      : null,
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
