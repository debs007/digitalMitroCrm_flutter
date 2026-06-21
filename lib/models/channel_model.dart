/// A channel with unread count + last message preview, as returned by
/// GET /mobile/channels.
class ChannelModel {
  final String id;
  final String name;
  final String description;
  final String image;
  final int unreadCount;
  final String? lastMessageText;
  final String? lastMessageSender;
  final DateTime? lastMessageAt;

  ChannelModel({
    required this.id,
    required this.name,
    required this.description,
    required this.image,
    required this.unreadCount,
    this.lastMessageText,
    this.lastMessageSender,
    this.lastMessageAt,
  });

  factory ChannelModel.fromJson(Map<String, dynamic> json) {
    final lastMessage = json['lastMessage'];
    DateTime? lastAt;
    String? lastText;
    String? lastSender;
    if (lastMessage is Map) {
      lastText = lastMessage['message']?.toString();
      lastSender = lastMessage['sender']?.toString();
      try {
        lastAt = lastMessage['createdAt'] != null
            ? DateTime.parse(lastMessage['createdAt'].toString())
            : null;
      } catch (_) {}
    }

    return ChannelModel(
      id: (json['_id'] ?? '').toString(),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      unreadCount: (json['unreadCount'] is num) ? (json['unreadCount'] as num).toInt() : 0,
      lastMessageText: lastText,
      lastMessageSender: lastSender,
      lastMessageAt: lastAt,
    );
  }

  String get initial => name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '#';
}

/// A DM partner reference embedded in a conversation summary.
class DmPartner {
  final String id;
  final String name;
  final String avatar;
  final String? email;

  DmPartner({required this.id, required this.name, required this.avatar, this.email});

  factory DmPartner.fromJson(Map<String, dynamic>? json) {
    if (json == null) return DmPartner(id: '', name: 'Unknown', avatar: '');
    return DmPartner(
      id: (json['_id'] ?? '').toString(),
      name: json['name']?.toString() ?? 'Unknown',
      avatar: json['avatar']?.toString() ?? '',
      email: json['email']?.toString(),
    );
  }
}

/// A DM conversation summary, as returned by GET /mobile/dms.
class DmConversation {
  final String partnerId;
  final DmPartner partner;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final int unreadCount;

  DmConversation({
    required this.partnerId,
    required this.partner,
    this.lastMessageText,
    this.lastMessageAt,
    required this.unreadCount,
  });

  factory DmConversation.fromJson(Map<String, dynamic> json) {
    final lastMessage = json['lastMessage'];
    String? text;
    DateTime? at;
    if (lastMessage is Map) {
      text = lastMessage['message']?.toString();
      try {
        at = lastMessage['createdAt'] != null
            ? DateTime.parse(lastMessage['createdAt'].toString())
            : null;
      } catch (_) {}
    }

    return DmConversation(
      partnerId: (json['partnerId'] ?? '').toString(),
      partner: DmPartner.fromJson(
        json['partner'] is Map ? Map<String, dynamic>.from(json['partner']) : null,
      ),
      lastMessageText: text,
      lastMessageAt: at,
      unreadCount: (json['unreadCount'] is num) ? (json['unreadCount'] as num).toInt() : 0,
    );
  }
}
