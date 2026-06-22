import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/channel_model.dart';

class ChatListService {
  ChatListService._();
  static final ChatListService instance = ChatListService._();

  final ApiClient _api = ApiClient.instance;

  /// Channels visible to the logged-in user, with unread counts + last
  /// message — already scope-filtered server-side for admins with
  /// selective channel access.
  Future<List<ChannelModel>> getChannels() async {
    final res = await _api.get(ApiConstants.mobileChannels);
    final list = res['channels'];
    if (list is List) {
      return list.map((c) => ChannelModel.fromJson(Map<String, dynamic>.from(c))).toList();
    }
    return [];
  }

  /// DM conversations with unread counts + last message preview.
  Future<List<DmConversation>> getConversations() async {
    final res = await _api.get(ApiConstants.mobileDms);
    final list = res['conversations'];
    if (list is List) {
      return list.map((c) => DmConversation.fromJson(Map<String, dynamic>.from(c))).toList();
    }
    return [];
  }

  /// Combined unread count across every channel + DM — used for the
  /// bottom-nav Chat tab's badge.
  Future<int> getTotalUnreadCount() async {
    final results = await Future.wait([getChannels(), getConversations()]);
    final channels = results[0] as List<ChannelModel>;
    final conversations = results[1] as List<DmConversation>;
    final channelTotal = channels.fold<int>(0, (sum, c) => sum + c.unreadCount);
    final dmTotal = conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
    return channelTotal + dmTotal;
  }
}