import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/network/api_exception.dart';
import '../../models/channel_model.dart';
import '../../providers/nav_provider.dart';
import '../../services/chat_list_service.dart';
import '../../services/channel_service.dart';
import 'dm_chat_screen.dart';
import 'group_chat_screen.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/channel_logo.dart';
import '../../widgets/state_views.dart';
import '../../widgets/unread_badge.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();

  bool _isLoading = true;
  String? _error;
  List<ChannelModel> _channels = [];
  List<DmConversation> _conversations = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ChatListService.instance.getChannels(),
        ChatListService.instance.getConversations(),
      ]);
      final channels = results[0] as List<ChannelModel>;
      final conversations = results[1] as List<DmConversation>;
      setState(() {
        _channels = channels;
        _conversations = conversations;
        _isLoading = false;
      });
      // Backend doesn't push a socket event when messages are marked read,
      // so sync the bottom-nav badge directly from what we just fetched —
      // this is the moment the displayed unread counts are authoritative.
      if (mounted) {
        final total = channels.fold<int>(0, (s, c) => s + c.unreadCount) +
            conversations.fold<int>(0, (s, c) => s + c.unreadCount);
        context.read<NavProvider>().setChatUnreadCount(total);
      }
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load chats.';
        _isLoading = false;
      });
    }
  }

  List<ChannelModel> get _filteredChannels {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _channels;
    return _channels.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  List<DmConversation> get _filteredConversations {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _conversations;
    return _conversations.where((c) => c.partner.name.toLowerCase().contains(q)).toList();
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;

    if (isToday) return DateFormat('hh:mm a').format(dt);
    if (isYesterday) return 'Yesterday';
    return DateFormat('d MMM').format(dt);
  }

  void _openChannel(String channelId, String channelName) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => GroupChatScreen(channelId: channelId, channelName: channelName)))
        .then((_) => _load());
  }

  void _openDm(String partnerId, String partnerName, String partnerAvatar) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => DmChatScreen(partnerId: partnerId, partnerName: partnerName, partnerAvatar: partnerAvatar),
        ))
        .then((_) => _load());
  }

  Future<void> _openComposeMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.person_outline, color: AppColors.primary),
              title: const Text('New message'),
              subtitle: const Text('Start a direct message with someone'),
              onTap: () => Navigator.pop(ctx, 'dm'),
            ),
            ListTile(
              leading: Icon(Icons.tag, color: AppColors.primary),
              title: const Text('New channel'),
              subtitle: const Text('Create a group for a team or topic'),
              onTap: () => Navigator.pop(ctx, 'channel'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'dm') {
      _openNewMessagePicker();
    } else if (choice == 'channel') {
      _openNewChannelForm();
    }
  }

  Future<void> _openNewMessagePicker() async {
    List<DmPickerUser> users;
    try {
      users = await ChatListService.instance.getAllUsersForDm();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Could not load people.')),
        );
      }
      return;
    }
    if (!mounted) return;

    final selected = await showModalBottomSheet<DmPickerUser>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _UserPickerSheet(users: users, title: 'New message'),
    );
    if (selected == null || !mounted) return;
    _openDm(selected.id, selected.name, selected.avatar);
  }

  Future<void> _openNewChannelForm() async {
    List<DmPickerUser> users;
    try {
      users = await ChatListService.instance.getAllUsersForDm();
    } catch (_) {
      users = []; // Non-fatal — channel creation still works with zero initial members besides yourself.
    }
    if (!mounted) return;

    final createdChannelId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _CreateChannelSheet(allUsers: users),
      ),
    );
    if (createdChannelId == null || !mounted) return;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _openComposeMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search messages or people...',
                prefixIcon: Icon(Icons.search, size: 20),
              ),
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textFaint,
            indicatorColor: AppColors.primary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            tabs: const [Tab(text: 'Channels'), Tab(text: 'DMs')],
          ),
          Expanded(
            child: _isLoading
                ? const LoadingView()
                : _error != null
                    ? ErrorView(message: _error!, onRetry: _load)
                    : TabBarView(
                        controller: _tabController,
                        children: [_buildChannelsTab(), _buildDmsTab()],
                      ),
          ),
        ],
      ),
    );
  }

  /// Shows the channel's actual logo image when it has one set, otherwise
  /// falls back to the "#" placeholder — see ChannelLogo for the shared
  /// circular/contain-fit treatment used everywhere a channel logo appears.
  Widget _channelLeading(ChannelModel channel) {
    return ChannelLogo(imageUrl: channel.image, size: 44);
  }

  Widget _buildChannelsTab() {
    final channels = _filteredChannels;
    if (channels.isEmpty) {
      return const EmptyView(message: 'No channels yet.', icon: Icons.tag);
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.loader,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: channels.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 70),
        itemBuilder: (context, index) {
          final channel = channels[index];
          return ListTile(
            onTap: () => _openChannel(channel.id, channel.name),
            leading: _channelLeading(channel),
            title: Text(channel.name, style: AppText.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              channel.lastMessageText?.isNotEmpty == true ? channel.lastMessageText! : channel.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodyMuted,
            ),
            trailing: SizedBox(
              width: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_formatTime(channel.lastMessageAt), style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  UnreadBadge(count: channel.unreadCount),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDmsTab() {
    final conversations = _filteredConversations;
    if (conversations.isEmpty) {
      return const EmptyView(message: 'No conversations yet.', icon: Icons.chat_bubble_outline);
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.loader,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: conversations.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 70),
        itemBuilder: (context, index) {
          final conv = conversations[index];
          return ListTile(
            onTap: () => _openDm(conv.partnerId, conv.partner.name, conv.partner.avatar),
            leading: AppAvatar(name: conv.partner.name, imageUrl: conv.partner.avatar, size: 44),
            title: Text(conv.partner.name, style: AppText.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              conv.lastMessageText ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodyMuted,
            ),
            trailing: SizedBox(
              width: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_formatTime(conv.lastMessageAt), style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  UnreadBadge(count: conv.unreadCount),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// "New message" — search + pick one person to DM.
class _UserPickerSheet extends StatefulWidget {
  final List<DmPickerUser> users;
  final String title;
  const _UserPickerSheet({required this.users, required this.title});

  @override
  State<_UserPickerSheet> createState() => _UserPickerSheetState();
}

class _UserPickerSheetState extends State<_UserPickerSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<DmPickerUser> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return widget.users;
    return widget.users.where((u) => u.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(widget.title, style: AppText.h3),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'Search people...', prefixIcon: Icon(Icons.search, size: 20)),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(child: Text('No one found.', style: AppText.bodyMuted))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final u = _filtered[index];
                        return ListTile(
                          leading: AppAvatar(name: u.name, imageUrl: u.avatar, size: 40),
                          title: Text(u.name),
                          onTap: () => Navigator.pop(context, u),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// "New channel" — name + description + optional initial members.
class _CreateChannelSheet extends StatefulWidget {
  final List<DmPickerUser> allUsers;
  const _CreateChannelSheet({required this.allUsers});

  @override
  State<_CreateChannelSheet> createState() => _CreateChannelSheetState();
}

class _CreateChannelSheetState extends State<_CreateChannelSheet> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final Set<String> _selectedMemberIds = {};
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Channel name is required.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final channelId = await ChannelService.instance.createChannel(
        name: _name.text.trim(),
        description: _description.text.trim(),
        memberIds: _selectedMemberIds.toList(),
      );
      if (mounted) Navigator.pop(context, channelId);
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Could not create channel.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('New Channel', style: AppText.h3),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: TextStyle(color: AppColors.danger)),
            ),
          Text('Name', style: AppText.label),
          const SizedBox(height: 6),
          TextField(controller: _name, decoration: const InputDecoration(hintText: 'e.g. Marketing Team')),
          const SizedBox(height: 14),
          Text('Description (optional)', style: AppText.label),
          const SizedBox(height: 6),
          TextField(controller: _description, maxLines: 2, decoration: const InputDecoration(hintText: 'What is this channel for?')),
          const SizedBox(height: 14),
          Text('Add members (${_selectedMemberIds.length} selected)', style: AppText.label),
          const SizedBox(height: 8),
          if (widget.allUsers.isEmpty)
            Text('No other users found.', style: AppText.bodyMuted)
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.allUsers.length,
                itemBuilder: (context, index) {
                  final u = widget.allUsers[index];
                  final selected = _selectedMemberIds.contains(u.id);
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: selected,
                    title: Text(u.name),
                    secondary: AppAvatar(name: u.name, imageUrl: u.avatar, size: 32),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _selectedMemberIds.add(u.id);
                      } else {
                        _selectedMemberIds.remove(u.id);
                      }
                    }),
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Create Channel'),
            ),
          ),
        ],
      ),
    );
  }
}
