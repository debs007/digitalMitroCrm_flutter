import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/network/api_exception.dart';
import '../../models/channel_detail_model.dart';
import '../../models/employee_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/channel_service.dart';
import '../../services/employee_service.dart';
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
  String? _busyMemberId;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _isAdmin = context.read<AuthProvider>().user?.isAdmin ?? false;
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

  Future<void> _removeMember(ChannelMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text('${member.name} will lose access to #${widget.channelName}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Remove', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyMemberId = member.id);
    try {
      await ChannelService.instance.removeMember(widget.channelId, member.id);
      await _load();
    } catch (e) {
      if (mounted) {
        // Surfaced as-is — the backend only allows the channel's actual
        // owner to remove members, even for Admin/SuperAdmin, so this is
        // the honest result rather than a generic failure message.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Could not remove member.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyMemberId = null);
    }
  }

  Future<void> _openAddMember() async {
    List<EmployeeModel> allEmployees;
    try {
      allEmployees = await EmployeeService.instance.getAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load employees.')),
        );
      }
      return;
    }
    final existingIds = _detail?.members.map((m) => m.id).toSet() ?? {};
    final candidates = allEmployees.where((e) => !existingIds.contains(e.id)).toList();

    if (!mounted) return;
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Everyone is already in this channel.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<EmployeeModel>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Add to channel', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.5),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: candidates.length,
                itemBuilder: (context, index) {
                  final e = candidates[index];
                  return ListTile(
                    leading: AppAvatar(name: e.name, imageUrl: e.avatar, size: 38),
                    title: Text(e.name),
                    subtitle: Text(e.email, style: AppText.caption),
                    onTap: () => Navigator.pop(ctx, e),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;

    setState(() => _busyMemberId = 'adding');
    try {
      await ChannelService.instance.addMember(widget.channelId, selected.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Could not add member.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyMemberId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('#${widget.channelName}')),
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
              onPressed: _busyMemberId == 'adding' ? null : _openAddMember,
              backgroundColor: AppColors.primary,
              child: _busyMemberId == 'adding'
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.person_add_alt_1, color: Colors.white),
            )
          : null,
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
                            Text('About', style: AppText.captionBold),
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
                                final isBusy = _busyMemberId == member.id;
                                return ListTile(
                                  leading: AppAvatar(name: member.name, imageUrl: member.avatar, size: 42),
                                  title: Text(member.name),
                                  subtitle: Text(member.email, style: AppText.caption),
                                  trailing: isBusy
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                      : isOwner
                                          ? Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryTint,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text('Owner', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700)),
                                            )
                                          : (_isAdmin
                                              ? IconButton(
                                                  icon: Icon(Icons.person_remove_outlined, color: AppColors.danger, size: 20),
                                                  onPressed: () => _removeMember(member),
                                                )
                                              : null),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
