import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/socket_service.dart';
import '../../models/message_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/channel_service.dart';
import '../../services/upload_service.dart';
import '../../widgets/chat_input_bar.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/pinned_banner.dart';
import '../../widgets/state_views.dart';
import '../channel/channel_members_screen.dart';
import '../tasks/create_task_screen.dart';

class GroupChatScreen extends StatefulWidget {
  final String channelId;
  final String channelName;

  const GroupChatScreen({super.key, required this.channelId, required this.channelName});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = []; // newest-first
  List<ChatMessage> _pinned = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int _nextPage = 1;
  String? _error;
  bool _sending = false;
  ChatMessage? _replyingTo;

  late String _myId;
  Map<String, String> _memberNames = {};
  void Function(dynamic)? _onNewMessage;
  void Function(dynamic)? _onMessageUpdated;
  void Function(dynamic)? _onPinned;

  @override
  void initState() {
    super.initState();
    _myId = context.read<AuthProvider>().user?.id ?? '';
    _scrollController.addListener(_onScroll);
    SocketService.instance.joinChannel(widget.channelId);
    _registerSocketListeners();
    _load();
    _loadMemberNames();
    ChannelService.instance.markAsRead(widget.channelId);
  }

  Future<void> _loadMemberNames() async {
    try {
      final detail = await ChannelService.instance.getDetail(widget.channelId);
      if (!mounted) return;
      setState(() {
        _memberNames = {for (final m in detail.members) m.id: m.name};
      });
    } catch (_) {
      // Non-fatal — sender labels just fall back to "Member" if this fails.
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    final socket = SocketService.instance;
    if (_onNewMessage != null) socket.off('new-channel-message', _onNewMessage);
    if (_onMessageUpdated != null) socket.off('channel-message-updated', _onMessageUpdated);
    if (_onPinned != null) socket.off('channel-message-pinned', _onPinned);
    super.dispose();
  }

  void _registerSocketListeners() {
    final socket = SocketService.instance;

    _onNewMessage = (data) {
      if (!mounted || data is! Map) return;
      final msg = ChatMessage.fromJson(Map<String, dynamic>.from(data));
      if (msg.channelId != widget.channelId) return;
      setState(() => _messages.insert(0, msg));
      if (msg.senderId != _myId) {
        ChannelService.instance.markAsRead(widget.channelId);
      }
    };
    socket.on('new-channel-message', _onNewMessage!);

    _onMessageUpdated = (data) {
      if (!mounted || data is! Map) return;
      final updated = ChatMessage.fromJson(Map<String, dynamic>.from(data));
      if (updated.channelId != widget.channelId) return;
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == updated.id);
        if (idx != -1) _messages[idx] = updated;
      });
    };
    socket.on('channel-message-updated', _onMessageUpdated!);

    _onPinned = (data) {
      if (!mounted) return;
      _loadPinned();
    };
    socket.on('channel-message-pinned', _onPinned!);
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await ChannelService.instance.getMessages(channelId: widget.channelId, page: 1);
      setState(() {
        _messages
          ..clear()
          ..addAll(result.messages.reversed);
        _hasMore = result.hasMore;
        _nextPage = result.nextPage;
        _isLoading = false;
      });
      _loadPinned();
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Could not load messages.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final result = await ChannelService.instance.getMessages(channelId: widget.channelId, page: _nextPage);
      setState(() {
        _messages.addAll(result.messages.reversed);
        _hasMore = result.hasMore;
        _nextPage = result.nextPage;
        _isLoadingMore = false;
      });
    } catch (_) {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadPinned() async {
    try {
      final pinned = await ChannelService.instance.getPinned(widget.channelId);
      if (mounted) setState(() => _pinned = pinned);
    } catch (_) {}
  }

  Future<void> _handleSend(String text, File? attachment) async {
    setState(() => _sending = true);
    try {
      List<String> attachments = [];
      if (attachment != null) {
        final url = await UploadService.instance.uploadChatFile(attachment);
        attachments = [url];
      }
      await ChannelService.instance.send(
        senderId: _myId,
        channelId: widget.channelId,
        message: text,
        replyTo: _replyingTo?.id,
        attachments: attachments,
      );
      setState(() => _replyingTo = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Failed to send message.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _handleEdit(ChatMessage message) async {
    final controller = TextEditingController(text: message.message);
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(controller: controller, autofocus: true, maxLines: 4),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (newText == null || newText.isEmpty || newText == message.message) return;
    try {
      await ChannelService.instance.edit(messageId: message.id, newText: newText);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Could not edit message.')),
        );
      }
    }
  }

  Future<void> _handleDelete(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This deletes it for everyone in the channel.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ChannelService.instance.delete(message.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Could not delete message.')),
        );
      }
    }
  }

  Future<void> _handleTogglePin(ChatMessage message) async {
    try {
      await ChannelService.instance.togglePin(message.id);
      await _loadPinned();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Could not update pin.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: const Text('#', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.channelName, style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'members') {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ChannelMembersScreen(channelId: widget.channelId, channelName: widget.channelName),
                ));
              } else if (value == 'create_task') {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CreateTaskScreen(channelId: widget.channelId, channelName: widget.channelName),
                ));
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'members', child: Text('View members')),
              PopupMenuItem(value: 'create_task', child: Text('Create task')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          PinnedBanner(pinned: _pinned, onUnpin: _handleTogglePin),
          Expanded(
            child: _isLoading
                ? const LoadingView()
                : _error != null
                    ? ErrorView(message: _error!, onRetry: _load)
                    : _messages.isEmpty
                        ? const EmptyView(message: 'No messages yet. Start the conversation!', icon: Icons.tag)
                        : ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _messages.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                );
                              }
                              final msg = _messages[index];
                              final isSelf = msg.senderId == _myId;
                              return MessageBubble(
                                message: msg,
                                isSelf: isSelf,
                                senderLabel: isSelf ? '' : (_memberNames[msg.senderId] ?? 'Unknown'),
                                onReply: () => setState(() => _replyingTo = msg),
                                onEdit: () => _handleEdit(msg),
                                onDelete: () => _handleDelete(msg),
                                onTogglePin: () => _handleTogglePin(msg),
                              );
                            },
                          ),
          ),
          ChatInputBar(
            replyingTo: _replyingTo,
            onCancelReply: () => setState(() => _replyingTo = null),
            onSend: _handleSend,
            sending: _sending,
          ),
        ],
      ),
    );
  }
}
