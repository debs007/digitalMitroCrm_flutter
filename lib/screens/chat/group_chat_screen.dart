import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/socket_service.dart';
import '../../models/message_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/channel_service.dart';
import '../../services/upload_service.dart';
import '../../widgets/chat_input_bar.dart';
import '../../widgets/channel_logo.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/pinned_banner.dart';
import '../../widgets/state_views.dart';
import '../channel/channel_members_screen.dart';
import '../channel/channel_tasks_screen.dart';
import '../channel/edit_channel_screen.dart';
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
  final Map<String, GlobalKey> _bubbleKeys = {};
  String? _highlightedMessageId;

  late String _myId;
  bool _isAdmin = false;
  String? _displayName;
  Map<String, String> _memberNames = {};
  Map<String, String> _memberAvatars = {};
  String? _channelImage;
  String _channelStatus = 'Active';
  bool _sharing = false;
  void Function(dynamic)? _onNewMessage;
  void Function(dynamic)? _onMessageUpdated;
  void Function(dynamic)? _onPinned;
  void Function(dynamic)? _onReacted;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _myId = user?.id ?? '';
    _isAdmin = user?.isAdmin ?? false;
    _scrollController.addListener(_onScroll);
    SocketService.instance.joinChannel(widget.channelId);
    _registerSocketListeners();
    _load();
    _loadChannelDetail();
    ChannelService.instance.markAsRead(widget.channelId);
  }

  Future<void> _loadChannelDetail() async {
    try {
      final detail = await ChannelService.instance.getDetail(widget.channelId);
      if (!mounted) return;
      setState(() {
        _memberNames = {for (final m in detail.members) m.id: m.name};
        _memberAvatars = {for (final m in detail.members) m.id: m.avatar};
        _channelImage = detail.image;
        _displayName = detail.name;
        _channelStatus = detail.statusTag;
      });
    } catch (_) {
      // Non-fatal — sender labels/avatars and the header logo just fall
      // back to defaults if this fails.
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    final socket = SocketService.instance;
    if (_onNewMessage != null) socket.off('new-channel-message', _onNewMessage);
    if (_onMessageUpdated != null) socket.off('channel-message-updated', _onMessageUpdated);
    if (_onPinned != null) socket.off('channel-message-pinned', _onPinned);
    if (_onReacted != null) socket.off('channel-message-reacted', _onReacted);
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
      if (data is Map) {
        final id = data['messageId']?.toString();
        final isPinned = data['isPinned'] == true;
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == id);
          if (idx != -1) _messages[idx] = _messages[idx].copyWith(isPinned: isPinned);
        });
      }
    };
    socket.on('channel-message-pinned', _onPinned!);

    _onReacted = (data) {
      if (!mounted || data is! Map) return;
      final id = data['messageId']?.toString();
      final rawReactions = data['reactions'];
      if (rawReactions is! List) return;
      final reactions = rawReactions
          .map((r) => MessageReaction.fromJson(Map<String, dynamic>.from(r)))
          .toList();
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == id);
        if (idx != -1) _messages[idx] = _messages[idx].copyWith(reactions: reactions);
      });
    };
    socket.on('channel-message-reacted', _onReacted!);
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

  /// Scrolls to a pinned message, loading a few more older pages
  /// (bounded) first if it isn't currently loaded.
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
        content: const Text('This deletes it for everyone in the channel.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ChannelService.instance.delete(message.id);
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
      final isPinnedNow = await ChannelService.instance.togglePin(message.id);
      _patchMessage(message.id, (m) => m.copyWith(isPinned: isPinnedNow));
      await _loadPinned();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Could not update pin.')),
        );
      }
    }
  }

  Future<void> _handleToggleReaction(ChatMessage message, String emoji) async {
    try {
      final reactions = await ChannelService.instance.toggleReaction(messageId: message.id, emoji: emoji);
      _patchMessage(message.id, (m) => m.copyWith(reactions: reactions));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Could not react.')),
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

  Future<void> _handleShare() async {
    setState(() => _sharing = true);
    try {
      final link = await ChannelService.instance.getInviteLink(widget.channelId);
      await Share.share(link, subject: 'Join #${widget.channelName} on Digital Mitro');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Could not get invite link.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _handleReports() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ChannelReportsSheet(
        channelId: widget.channelId,
        channelName: _displayName ?? widget.channelName,
        isAdmin: _isAdmin,
      ),
    );
  }

  Future<void> _handleEditChannel() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditChannelScreen(channelId: widget.channelId),
      ),
    );
    if (saved == true) _loadChannelDetail();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveName = _displayName ?? widget.channelName;

    return Scaffold(
      backgroundColor: AppColors.primarySoft,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                ChannelLogo(imageUrl: _channelImage, size: 36),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _channelStatus == 'Active' ? AppColors.success : AppColors.danger,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(effectiveName, style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          if (_sharing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'members') {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ChannelMembersScreen(channelId: widget.channelId, channelName: effectiveName),
                ));
              } else if (value == 'tasks') {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ChannelTasksScreen(channelId: widget.channelId, channelName: effectiveName),
                ));
              } else if (value == 'create_task') {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CreateTaskScreen(channelId: widget.channelId, channelName: effectiveName),
                ));
              } else if (value == 'reports') {
                _handleReports();
              } else if (value == 'share') {
                _handleShare();
              } else if (value == 'edit') {
                _handleEditChannel();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'members', child: Text('View members')),
              const PopupMenuItem(value: 'tasks', child: Text('View tasks')),
              const PopupMenuItem(value: 'create_task', child: Text('Create task')),
              PopupMenuItem(
                value: 'reports',
                child: Row(children: [
                  Icon(Icons.upload_file_outlined, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text('Task Reports'),
                ]),
              ),
              const PopupMenuItem(value: 'share', child: Text('Share')),
              if (_isAdmin) const PopupMenuItem(value: 'edit', child: Text('Edit channel')),
            ],
          ),
        ],
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
                              final bubbleKey = _bubbleKeys.putIfAbsent(msg.id, () => GlobalKey());
                              final isHighlighted = _highlightedMessageId == msg.id;
                              return AnimatedContainer(
                                key: bubbleKey,
                                duration: const Duration(milliseconds: 300),
                                color: isHighlighted ? AppColors.warning.withValues(alpha: 0.15) : Colors.transparent,
                                child: MessageBubble(
                                message: msg,
                                isSelf: isSelf,
                                senderLabel: isSelf ? '' : (_memberNames[msg.senderId] ?? 'Unknown'),
                                senderAvatar: isSelf ? null : _memberAvatars[msg.senderId],
                                currentUserId: _myId,
                                onReply: () => setState(() => _replyingTo = msg),
                                onEdit: () => _handleEdit(msg),
                                onDelete: () => _handleDelete(msg),
                                onTogglePin: () => _handleTogglePin(msg),
                                onReact: (emoji) => _handleToggleReaction(msg, emoji),
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

// ─── Channel Reports Sheet ───────────────────────────────────────────────────
class _ChannelReportsSheet extends StatefulWidget {
  final String channelId;
  final String channelName;
  final bool isAdmin;

  const _ChannelReportsSheet({
    required this.channelId,
    required this.channelName,
    required this.isAdmin,
  });

  @override
  State<_ChannelReportsSheet> createState() => _ChannelReportsSheetState();
}

class _ChannelReportsSheetState extends State<_ChannelReportsSheet> {
  List<ChannelReport> _reports = [];
  bool _loading = true;
  bool _uploading = false;
  String? _error;

  File? _pickedFile;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  final _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final reports = await ChannelService.instance.listReports(widget.channelId);
      if (mounted) setState(() { _reports = reports; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e is ApiException ? e.message : 'Could not load reports.'; _loading = false; });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result?.files.first.path != null) {
      setState(() => _pickedFile = File(result!.files.first.path!));
    }
  }

  Future<void> _upload() async {
    if (_pickedFile == null) return;
    setState(() { _uploading = true; _error = null; });
    try {
      await ChannelService.instance.uploadReport(
        channelId: widget.channelId,
        file: _pickedFile!,
        year: _year,
        month: _month,
        title: _titleController.text.trim(),
      );
      _pickedFile = null;
      _titleController.clear();
      await _load();
    } catch (e) {
      setState(() { _error = e is ApiException ? e.message : 'Upload failed.'; _uploading = false; });
    }
  }

  static const List<String> _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Row(
              children: [
                Expanded(child: Text('Task Reports — ${widget.channelName}', style: AppText.h3, overflow: TextOverflow.ellipsis)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),

          if (widget.isAdmin) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _month,
                          decoration: const InputDecoration(labelText: 'Month', isDense: true),
                          items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_months[i]))),
                          onChanged: (v) => setState(() => _month = v ?? _month),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _year,
                          decoration: const InputDecoration(labelText: 'Year', isDense: true),
                          items: List.generate(5, (i) => DateTime.now().year - i)
                              .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
                              .toList(),
                          onChanged: (v) => setState(() => _year = v ?? _year),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Title (optional)', isDense: true),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickFile,
                          icon: const Icon(Icons.attach_file, size: 18),
                          label: Text(_pickedFile != null ? _pickedFile!.path.split('/').last : 'Pick PDF', overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: (_pickedFile == null || _uploading) ? null : _upload,
                        child: _uploading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Upload'),
                      ),
                    ],
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_error!, style: TextStyle(color: AppColors.danger, fontSize: 12)),
                    ),
                ],
              ),
            ),
            const Divider(height: 20),
          ],

          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: AppColors.loader))
                : _reports.isEmpty
                    ? Center(child: Text('No reports uploaded yet.', style: AppText.bodyMuted))
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: _reports.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final r = _reports[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(10)),
                              child: Icon(Icons.picture_as_pdf, color: AppColors.danger, size: 20),
                            ),
                            title: Text(r.title.isNotEmpty ? r.title : r.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${r.monthLabel} ${r.year}', style: AppText.caption),
                            trailing: widget.isAdmin
                                ? IconButton(
                                    icon: Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                                    onPressed: () async {
                                      await ChannelService.instance.deleteReport(widget.channelId, r.id);
                                      _load();
                                    },
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