import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/network/api_exception.dart';
import '../../models/channel_model.dart';
import '../../providers/nav_provider.dart';
import '../../services/chat_list_service.dart';
import 'dm_chat_screen.dart';
import 'group_chat_screen.dart';
import '../../widgets/app_avatar.dart';
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
      setState(() {
        _channels = results[0] as List<ChannelModel>;
        _conversations = results[1] as List<DmConversation>;
        _isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => context.read<NavProvider>().openDrawer(),
        ),
        title: const Text('Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Compose — coming in the next build phase.')),
            ),
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

  Widget _buildChannelsTab() {
    final channels = _filteredChannels;
    if (channels.isEmpty) {
      return const EmptyView(message: 'No channels yet.', icon: Icons.tag);
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: channels.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 70),
        itemBuilder: (context, index) {
          final channel = channels[index];
          return ListTile(
            onTap: () => _openChannel(channel.id, channel.name),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Text(
                '#',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
            title: Text(channel.name, style: AppText.bodyLarge),
            subtitle: Text(
              channel.lastMessageText?.isNotEmpty == true ? channel.lastMessageText! : channel.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodyMuted,
            ),
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_formatTime(channel.lastMessageAt), style: AppText.caption),
                const SizedBox(height: 6),
                UnreadBadge(count: channel.unreadCount),
              ],
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
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: conversations.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 70),
        itemBuilder: (context, index) {
          final conv = conversations[index];
          return ListTile(
            onTap: () => _openDm(conv.partnerId, conv.partner.name, conv.partner.avatar),
            leading: AppAvatar(name: conv.partner.name, imageUrl: conv.partner.avatar, size: 44),
            title: Text(conv.partner.name, style: AppText.bodyLarge),
            subtitle: Text(
              conv.lastMessageText ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodyMuted,
            ),
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_formatTime(conv.lastMessageAt), style: AppText.caption),
                const SizedBox(height: 6),
                UnreadBadge(count: conv.unreadCount),
              ],
            ),
          );
        },
      ),
    );
  }
}
