/// Short embedded reply preview, shared shape on both DirectMessage and
/// ChannelMessage (`replyPreview: {message, sender, senderName}`).
class ReplyPreview {
  final String? message;
  final String? senderId;
  final String? senderName;

  ReplyPreview({this.message, this.senderId, this.senderName});

  factory ReplyPreview.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ReplyPreview();
    return ReplyPreview(
      message: json['message']?.toString(),
      senderId: json['sender']?.toString(),
      senderName: json['senderName']?.toString(),
    );
  }
}

/// Snapshot of a task at the moment a system message was posted about it
/// (created, completed, status/priority/deadline changed) — lets the chat
/// UI render a rich task card instead of a plain text bubble.
class TaskSnapshot {
  final String taskId;
  final String taskNumber;
  final String title;
  final String status;
  final String priority;
  final DateTime? deadline;
  final String? assignedToName;

  TaskSnapshot({
    required this.taskId,
    required this.taskNumber,
    required this.title,
    required this.status,
    required this.priority,
    this.deadline,
    this.assignedToName,
  });

  factory TaskSnapshot.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    return TaskSnapshot(
      taskId: (json['taskId'] ?? '').toString(),
      taskNumber: json['taskNumber']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      priority: json['priority']?.toString() ?? '',
      deadline: parseDate(json['deadline']),
      assignedToName: json['assignedToName']?.toString(),
    );
  }
}

/// One chat message — used for both DM (DirectMessage) and Channel
/// (ChannelMessage) since the two schemas are almost identical.
/// [channelId] is null for DMs; [receiverId] is null for channel messages.
/// One person's reaction on a message. Backend enforces one reaction per
/// user per message — picking a new emoji replaces their old one.
class MessageReaction {
  final String emoji;
  final String userId;
  final String userName;

  MessageReaction({required this.emoji, required this.userId, required this.userName});

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    final rawUserId = json['userId'];
    return MessageReaction(
      emoji: json['emoji']?.toString() ?? '',
      userId: rawUserId is Map ? (rawUserId['_id']?.toString() ?? '') : (rawUserId?.toString() ?? ''),
      userName: json['userName']?.toString() ?? '',
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String? receiverId; // DM only
  final String? channelId; // Channel only
  final String message;
  final List<String> attachments;
  final List<String> mentions;
  final bool isPinned;
  final String? pinnedBy;
  final DateTime? pinnedAt;
  final ReplyPreview? replyPreview;
  final String? replyTo;
  final bool seen; // DM only — `seen` field
  final List<String> seenBy; // Channel only — `seenBy` array
  final DateTime? editedAt;
  final bool isDeleted;
  final bool isSystem;
  final TaskSnapshot? taskSnapshot;
  final List<MessageReaction> reactions;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    this.receiverId,
    this.channelId,
    required this.message,
    required this.attachments,
    required this.mentions,
    required this.isPinned,
    this.pinnedBy,
    this.pinnedAt,
    this.replyPreview,
    this.replyTo,
    required this.seen,
    required this.seenBy,
    this.editedAt,
    required this.isDeleted,
    required this.isSystem,
    this.taskSnapshot,
    this.reactions = const [],
    required this.createdAt,
  });

  bool get isEdited => editedAt != null;
  bool get hasAttachments => attachments.isNotEmpty;
  bool get hasReactions => reactions.isNotEmpty;

  /// Groups [reactions] by emoji, preserving first-seen order — what the
  /// UI actually renders (one pill per distinct emoji, with a count).
  Map<String, List<MessageReaction>> get reactionsByEmoji {
    final map = <String, List<MessageReaction>>{};
    for (final r in reactions) {
      (map[r.emoji] ??= []).add(r);
    }
    return map;
  }

  /// The emoji the given user reacted with, if any — null if they haven't
  /// reacted (only one reaction per user is possible, enforced server-side).
  String? myReaction(String userId) {
    for (final r in reactions) {
      if (r.userId == userId) return r.emoji;
    }
    return null;
  }

  /// Mirrors the web app's 2-hour edit/delete window.
  bool get isWithinEditWindow => DateTime.now().difference(createdAt).inHours < 2;

  static String _idOf(dynamic v) {
    if (v == null) return '';
    if (v is Map) return v['_id']?.toString() ?? '';
    return v.toString();
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    return ChatMessage(
      id: (json['_id'] ?? '').toString(),
      senderId: _idOf(json['sender']),
      receiverId: json['receiver'] != null ? _idOf(json['receiver']) : null,
      channelId: json['channelId'] != null ? _idOf(json['channelId']) : null,
      message: json['message']?.toString() ?? '',
      attachments: (json['attachments'] is List) ? List<String>.from(json['attachments']) : [],
      mentions: (json['mentions'] is List)
          ? (json['mentions'] as List).map((m) => _idOf(m)).toList()
          : [],
      isPinned: json['isPinned'] == true,
      pinnedBy: json['pinnedBy'] != null ? _idOf(json['pinnedBy']) : null,
      pinnedAt: parseDate(json['pinnedAt']),
      replyPreview: json['replyPreview'] is Map
          ? ReplyPreview.fromJson(Map<String, dynamic>.from(json['replyPreview']))
          : null,
      replyTo: json['replyTo'] != null ? _idOf(json['replyTo']) : null,
      seen: json['seen'] == true,
      seenBy: (json['seenBy'] is List) ? (json['seenBy'] as List).map((s) => _idOf(s)).toList() : [],
      editedAt: parseDate(json['editedAt']),
      isDeleted: json['isDeleted'] == true,
      isSystem: json['isSystem'] == true,
      taskSnapshot: (json['taskSnapshot'] is Map && (json['taskSnapshot'] as Map)['taskId'] != null)
          ? TaskSnapshot.fromJson(Map<String, dynamic>.from(json['taskSnapshot']))
          : null,
      reactions: (json['reactions'] is List)
          ? (json['reactions'] as List)
              .map((r) => MessageReaction.fromJson(Map<String, dynamic>.from(r)))
              .toList()
          : [],
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
    );
  }

  /// Used for optimistic local updates right after a successful edit/
  /// delete/pin/react API call — don't wait on the socket echo to update
  /// your own screen, only rely on sockets for changes from other devices/users.
  ChatMessage copyWith({
    String? message,
    bool? isPinned,
    DateTime? editedAt,
    bool? isDeleted,
    List<MessageReaction>? reactions,
  }) {
    return ChatMessage(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      channelId: channelId,
      message: message ?? this.message,
      attachments: attachments,
      mentions: mentions,
      isPinned: isPinned ?? this.isPinned,
      pinnedBy: pinnedBy,
      pinnedAt: pinnedAt,
      replyPreview: replyPreview,
      replyTo: replyTo,
      seen: seen,
      seenBy: seenBy,
      editedAt: editedAt ?? this.editedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      isSystem: isSystem,
      taskSnapshot: taskSnapshot,
      reactions: reactions ?? this.reactions,
      createdAt: createdAt,
    );
  }
}
