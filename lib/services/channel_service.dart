import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/message_model.dart';
import '../models/channel_detail_model.dart';

class ChannelService {
  ChannelService._();
  static final ChannelService instance = ChannelService._();

  final ApiClient _api = ApiClient.instance;

  Future<({List<ChatMessage> messages, bool hasMore, int nextPage})> getMessages({
    required String channelId,
    int page = 1,
    int limit = 30,
  }) async {
    final res = await _api.get(
      ApiConstants.channelMessages(channelId),
      queryParameters: {'page': page, 'limit': limit},
    );
    final list = res['messages'];
    final messages = (list is List)
        ? list.map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m))).toList()
        : <ChatMessage>[];
    final pagination = res['pagination'] is Map ? Map<String, dynamic>.from(res['pagination']) : {};
    return (
      messages: messages,
      hasMore: pagination['hasMore'] == true,
      nextPage: (pagination['nextPage'] is num) ? (pagination['nextPage'] as num).toInt() : page,
    );
  }

  Future<void> send({
    required String senderId,
    required String channelId,
    required String message,
    String? replyTo,
    List<String> mentions = const [],
    List<String> attachments = const [],
  }) async {
    await _api.post(ApiConstants.sendChannelMessage, data: {
      'sender': senderId,
      'channelId': channelId,
      'message': message,
      if (replyTo != null) 'replyTo': replyTo,
      if (mentions.isNotEmpty) 'mentions': mentions,
      if (attachments.isNotEmpty) 'attachments': attachments,
    });
  }

  Future<void> edit({required String messageId, required String newText}) async {
    await _api.patch(ApiConstants.editChannelMessage(messageId), data: {'message': newText});
  }

  Future<void> delete(String messageId) async {
    await _api.delete(ApiConstants.deleteChannelMessage(messageId));
  }

  Future<bool> togglePin(String messageId) async {
    final res = await _api.patch(ApiConstants.pinChannelMessage(messageId));
    return res['isPinned'] == true;
  }

  Future<List<ChatMessage>> getPinned(String channelId) async {
    final res = await _api.get(ApiConstants.pinnedChannelMessages(channelId));
    final list = res['pinned'];
    if (list is List) {
      return list.map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m))).toList();
    }
    return [];
  }

  Future<void> markAsRead(String channelId) async {
    await _api.post(ApiConstants.markChannelRead(channelId));
  }

  /// Full channel detail with members resolved to {name, avatar, email}.
  Future<ChannelDetail> getDetail(String channelId) async {
    // This endpoint returns the raw channel object directly, not wrapped.
    final res = await _api.get(ApiConstants.channelDetail(channelId));
    return ChannelDetail.fromJson(res);
  }

  Future<List<ChannelMember>> getMentionCandidates(String channelId) async {
    final res = await _api.get(ApiConstants.mentionCandidates(channelId));
    final list = res['candidates'];
    if (list is List) {
      return list.map((c) => ChannelMember.fromJson(Map<String, dynamic>.from(c))).toList();
    }
    return [];
  }
}
