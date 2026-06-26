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

  /// Every user in the company as {id, name, avatar} — works for any
  /// logged-in user (employee, admin, ...), unlike EmployeeService.getAll()
  /// which is admin-only. Used for the "start a new DM" picker.
  Future<List<DmPickerUser>> getAllUsersForDm() async {
    final res = await _api.get(ApiConstants.allUsersLight);
    final list = res['users'];
    if (list is List) {
      return list.map((u) => DmPickerUser.fromJson(Map<String, dynamic>.from(u))).toList();
    }
    return [];
  }
}

class DmPickerUser {
  final String id;
  final String name;
  final String avatar;
  DmPickerUser({required this.id, required this.name, required this.avatar});
  factory DmPickerUser.fromJson(Map<String, dynamic> json) => DmPickerUser(
        id: (json['_id'] ?? '').toString(),
        name: json['name']?.toString() ?? '',
        avatar: json['avatar']?.toString() ?? '',
      );
}
