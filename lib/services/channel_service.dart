import 'dart:io';
import 'package:dio/dio.dart';
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

  /// Creates a new channel — you're automatically added as owner + member
  /// server-side, on top of whatever [memberIds] you pick.
  Future<String> createChannel({
    required String name,
    String description = '',
    List<String> memberIds = const [],
  }) async {
    final res = await _api.post(ApiConstants.channelCreate, data: {
      'name': name,
      'description': description,
      'members': memberIds,
    });
    final channel = res['channel'] is Map ? Map<String, dynamic>.from(res['channel']) : res;
    return (channel['_id'] ?? '').toString();
  }

  /// Updates a channel's name/description. Backend note: owner-only,
  /// regardless of Admin/SuperAdmin status — see [removeMember]'s comment.
  Future<void> updateChannelInfo({
    required String channelId,
    String? name,
    String? description,
  }) async {
    await _api.put(ApiConstants.channelUpdate(channelId), data: {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
    });
  }

  /// Uploads a new channel logo via the dedicated channel-image endpoint
  /// (separate from the generic chat-attachment upload — this one stores
  /// under Cloudinary's "channel_images" folder). Owner-only on the
  /// backend. Returns the new image URL.
  Future<String> uploadChannelImage(String channelId, File imageFile) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(imageFile.path, filename: imageFile.path.split('/').last),
    });
    final res = await ApiClient.instance.dio.post(ApiConstants.channelImageUpload(channelId), data: formData);
    final data = res.data is Map ? Map<String, dynamic>.from(res.data) : {};
    return data['image']?.toString() ?? '';
  }

  /// Returns a shareable join link for this channel. The backend returns
  /// a relative path (e.g. "/join/abc123") meant to be opened on the web
  /// app's domain, not the API domain.
  Future<String> getInviteLink(String channelId) async {
    final res = await _api.get(ApiConstants.channelInvite(channelId));
    final relativePath = res['inviteLink']?.toString() ?? '';
    return 'https://digitalmitro.info$relativePath';
  }

  /// Backend note: both add and remove are owner-only — even an Admin or
  /// SuperAdmin gets a 403 ("Only the channel owner can remove members" /
  /// "Not authorized to update this channel") if they aren't the specific
  /// channel's owner. There's no separate "any admin can manage members"
  /// permission on the backend for this.
  Future<void> removeMember(String channelId, String memberId) async {
    await _api.post(ApiConstants.channelRemoveMember(channelId), data: {'memberId': memberId});
  }

  /// No dedicated "add one member" endpoint exists — the only way to add
  /// someone is to PUT the channel's complete new members array, so this
  /// fetches the current list and appends to it.
  Future<void> addMember(String channelId, String newMemberId) async {
    final detail = await getDetail(channelId);
    final memberIds = detail.members.map((m) => m.id).toSet();
    memberIds.add(newMemberId);
    await _api.put(ApiConstants.channelUpdate(channelId), data: {'members': memberIds.toList()});
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
