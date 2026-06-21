import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/message_model.dart';

class MessageService {
  MessageService._();
  static final MessageService instance = MessageService._();

  final ApiClient _api = ApiClient.instance;

  /// Paginated DM history between [senderId] (you) and [receiverId].
  /// page=1 is the most recent page; messages within a page are
  /// oldest-first so they render top-to-bottom correctly.
  Future<({List<ChatMessage> messages, bool hasMore, int nextPage})> getMessages({
    required String senderId,
    required String receiverId,
    int page = 1,
    int limit = 30,
  }) async {
    final res = await _api.get(
      ApiConstants.dmMessages(senderId, receiverId),
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
    required String receiverId,
    required String message,
    String? replyTo,
    List<String> attachments = const [],
  }) async {
    await _api.post(ApiConstants.sendMessage, data: {
      'sender': senderId,
      'receiver': receiverId,
      'message': message,
      if (replyTo != null) 'replyTo': replyTo,
      if (attachments.isNotEmpty) 'attachments': attachments,
    });
  }

  Future<void> edit({required String messageId, required String newText}) async {
    await _api.patch(ApiConstants.editDmMessage(messageId), data: {'message': newText});
  }

  Future<void> delete(String messageId) async {
    await _api.delete(ApiConstants.deleteDmMessage(messageId));
  }

  Future<bool> togglePin(String messageId) async {
    final res = await _api.patch(ApiConstants.pinDmMessage(messageId));
    return res['isPinned'] == true;
  }

  Future<List<ChatMessage>> getPinned(String otherUserId) async {
    final res = await _api.get(ApiConstants.pinnedDmMessages, queryParameters: {'with': otherUserId});
    final list = res['pinned'];
    if (list is List) {
      return list.map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m))).toList();
    }
    return [];
  }

  Future<void> markAsRead(String senderId) async {
    await _api.post(ApiConstants.markDmRead, data: {'senderId': senderId});
  }
}
