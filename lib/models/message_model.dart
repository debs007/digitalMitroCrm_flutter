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

/// One chat message — used for both DM (DirectMessage) and Channel
/// (ChannelMessage) since the two schemas are almost identical.
/// [channelId] is null for DMs; [receiverId] is null for channel messages.
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
    required this.createdAt,
  });

  bool get isEdited => editedAt != null;
  bool get hasAttachments => attachments.isNotEmpty;

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
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
    );
  }
}
