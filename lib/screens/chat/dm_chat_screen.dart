import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/socket_service.dart';
import '../../models/message_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/message_service.dart';
import '../../services/upload_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/chat_input_bar.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/pinned_banner.dart';
import '../../widgets/state_views.dart';

class DmChatScreen extends StatefulWidget {
  final String partnerId;
  final String partnerName;
  final String partnerAvatar;

  const DmChatScreen({
    super.key,
    required this.partnerId,
    required this.partnerName,
    required this.partnerAvatar,
  });

  @override
  State<DmChatScreen> createState() => _DmChatScreenState();
}

class _DmChatScreenState extends State<DmChatScreen> {
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
  // One GlobalKey per currently-rendered message, so tapping a pinned item
  // can scroll straight to it instead of just highlighting it in a list.
  final Map<String, GlobalKey> _bubbleKeys = {};
  String? _highlightedMessageId;

  late String _myId;
  void Function(dynamic)? _onNewMessage;
  void Function(dynamic)? _onMessageUpdated;
  void Function(dynamic)? _onPinned;

  @override
  void initState() {
    super.initState();
    _myId = context.read<AuthProvider>().user?.id ?? '';
    _scrollController.addListener(_onScroll);
    _load();
    _registerSocketListeners();
    MessageService.instance.markAsRead(widget.partnerId);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    final socket = SocketService.instance;
    if (_onNewMessage != null) socket.off('new-message', _onNewMessage);
    if (_onMessageUpdated != null) socket.off('direct-message-updated', _onMessageUpdated);
    if (_onPinned != null) socket.off('dm-message-pinned', _onPinned);
    super.dispose();
  }

  void _registerSocketListeners() {
    final socket = SocketService.instance;

    _onNewMessage = (data) {
      if (!mounted || data is! Map) return;
      final msg = ChatMessage.fromJson(Map<String, dynamic>.from(data));
      final isThisConversation = (msg.senderId == widget.partnerId && msg.receiverId == _myId) ||
          (msg.senderId == _myId && msg.receiverId == widget.partnerId);
      if (!isThisConversation) return;
      setState(() => _messages.insert(0, msg));
      if (msg.senderId == widget.partnerId) {
        MessageService.instance.markAsRead(widget.partnerId);
      }
    };
    socket.on('new-message', _onNewMessage!);

    _onMessageUpdated = (data) {
      if (!mounted || data is! Map) return;
      final updated = ChatMessage.fromJson(Map<String, dynamic>.from(data));
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == updated.id);
        if (idx != -1) _messages[idx] = updated;
      });
    };
    socket.on('direct-message-updated', _onMessageUpdated!);

    _onPinned = (data) {
      if (!mounted) return;
      _loadPinned();
      if (data is Map) {
        final id = data['messageId']?.toString();
        final isPinned = data['isPinned'] == true;
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == id);
          if (idx != -1) _messages[idx] = _messages[idx].copyWith(isPinned: isPinned);
        });
      }
    };
    socket.on('dm-message-pinned', _onPinned!);
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
      final result = await MessageService.instance.getMessages(
        senderId: _myId,
        receiverId: widget.partnerId,
        page: 1,
      );
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
      final result = await MessageService.instance.getMessages(
        senderId: _myId,
        receiverId: widget.partnerId,
        page: _nextPage,
      );
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
      final pinned = await MessageService.instance.getPinned(widget.partnerId);
      if (mounted) setState(() => _pinned = pinned);
    } catch (_) {}
  }

  /// Scrolls to a pinned message. If it's not in the currently-loaded
  /// page(s), loads a few more older pages (bounded) before giving up.
  Future<void> _scrollToMessage(ChatMessage target) async {
    var attempts = 0;
    while (!_messages.any((m) => m.id == target.id) && _hasMore && attempts < 5) {
      await _loadMore();
      attempts++;
    }

    final key = _bubbleKeys[target.id];
    if (key?.currentContext != null) {
      setState(() => _highlightedMessageId = target.id);
      await Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 350),
        alignment: 0.5,
      );
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _highlightedMessageId = null);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't find that message — it may be further back in history.")),
      );
    }
  }

  Future<void> _handleSend(String text, File? attachment) async {
    setState(() => _sending = true);
    try {
      List<String> attachments = [];
      if (attachment != null) {
        final url = await UploadService.instance.uploadChatFile(attachment);
        attachments = [url];
      }
      await MessageService.instance.send(
        senderId: _myId,
        receiverId: widget.partnerId,
        message: text,
        replyTo: _replyingTo?.id,
        attachments: attachments,
      );
      setState(() => _replyingTo = null);
      // The server pushes 'new-message' back to us too (sender included),
      // so we don't optimistically insert here — avoids duplicate bubbles.
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
      await MessageService.instance.edit(messageId: message.id, newText: newText);
      // Update our own screen immediately — don't wait on the socket echo,
      // it's only needed to sync the OTHER person's screen.
      _patchMessage(message.id, (m) => m.copyWith(message: newText, editedAt: DateTime.now()));
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
        content: const Text('This deletes it for everyone in the conversation.'),
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
      await MessageService.instance.delete(message.id);
      _patchMessage(message.id, (m) => m.copyWith(isDeleted: true, message: 'This message was deleted'));
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
      final isPinnedNow = await MessageService.instance.togglePin(message.id);
      _patchMessage(message.id, (m) => m.copyWith(isPinned: isPinnedNow));
      _loadPinned();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Could not update pin.')),
        );
      }
    }
  }

  /// Replaces a message in [_messages] by id with the result of [update] —
  /// the shared helper behind every optimistic local edit/delete/pin above.
  void _patchMessage(String id, ChatMessage Function(ChatMessage) update) {
    if (!mounted) return;
    setState(() {
      final idx = _messages.indexWhere((m) => m.id == id);
      if (idx != -1) _messages[idx] = update(_messages[idx]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            AppAvatar(name: widget.partnerName, imageUrl: widget.partnerAvatar, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.partnerName, style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          PinnedBanner(pinned: _pinned, onUnpin: _handleTogglePin, onTapMessage: _scrollToMessage),
          Expanded(
            child: _isLoading
                ? const LoadingView()
                : _error != null
                    ? ErrorView(message: _error!, onRetry: _load)
                    : _messages.isEmpty
                        ? const EmptyView(message: 'No messages yet. Say hello!', icon: Icons.chat_bubble_outline)
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
                              final bubbleKey = _bubbleKeys.putIfAbsent(msg.id, () => GlobalKey());
                              final isHighlighted = _highlightedMessageId == msg.id;
                              return AnimatedContainer(
                                key: bubbleKey,
                                duration: const Duration(milliseconds: 300),
                                color: isHighlighted ? AppColors.warning.withValues(alpha: 0.15) : Colors.transparent,
                                child: MessageBubble(
                                message: msg,
                                isSelf: isSelf,
                                senderLabel: '',
                                onReply: () => setState(() => _replyingTo = msg),
                                onEdit: () => _handleEdit(msg),
                                onDelete: () => _handleDelete(msg),
                                onTogglePin: () => _handleTogglePin(msg),
                                ),
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