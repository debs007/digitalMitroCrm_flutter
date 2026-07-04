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

  /// Toggles your own reaction on a channel message — same rule as DMs:
  /// a new emoji replaces your previous one, the same emoji again clears it.
  Future<List<MessageReaction>> toggleReaction({required String messageId, required String emoji}) async {
    final res = await _api.patch(ApiConstants.reactChannelMessage(messageId), data: {'emoji': emoji});
    final list = res['reactions'];
    if (list is List) {
      return list.map((r) => MessageReaction.fromJson(Map<String, dynamic>.from(r))).toList();
    }
    return [];
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

  /// Updates a channel's editable fields. Backend note: owner-only,
  /// regardless of Admin/SuperAdmin status — see [removeMember]'s comment.
  /// Pass only the fields you want to change; omitted ones are left as-is
  /// server-side. statusTag must be one of Active/Archived/Paused/Closed.
  /// tags is capped at 2 entries server-side.
  Future<void> updateChannelInfo({
    required String channelId,
    String? name,
    String? description,
    String? statusTag,
    List<String>? tags,
    ChannelExtraDetails? channelDetails,
  }) async {
    await _api.put(ApiConstants.channelUpdate(channelId), data: {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (statusTag != null) 'statusTag': statusTag,
      if (tags != null) 'tags': tags,
      if (channelDetails != null) 'channelDetails': channelDetails.toJson(),
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

  /// Lists all monthly reports for a channel — newest first.
  Future<List<ChannelReport>> listReports(String channelId) async {
    final res = await _api.get(ApiConstants.channelReports(channelId));
    final list = res['reports'];
    if (list is List) {
      return list.map((r) => ChannelReport.fromJson(Map<String, dynamic>.from(r))).toList();
    }
    return [];
  }

  /// Uploads a report PDF for a specific month/year. Admin only.
  Future<ChannelReport> uploadReport({
    required String channelId,
    required File file,
    required int year,
    required int month,
    String title = '',
    String note = '',
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: file.path.split('/').last),
      'year': year.toString(),
      'month': month.toString(),
      if (title.isNotEmpty) 'title': title,
      if (note.isNotEmpty) 'note': note,
    });
    final res = await _api.dio.post(ApiConstants.channelReports(channelId), data: formData);
    if (res.data is Map && res.data['report'] is Map) {
      return ChannelReport.fromJson(Map<String, dynamic>.from(res.data['report']));
    }
    throw Exception('Unexpected response from report upload.');
  }

  Future<void> deleteReport(String channelId, String reportId) async {
    await _api.delete(ApiConstants.channelReportDelete(channelId, reportId));
  }
}

/// A single monthly task report attached to a channel.
class ChannelReport {
  final String id;
  final String channelId;
  final int year;
  final int month;
  final String fileUrl;
  final String fileName;
  final String title;
  final String note;

  ChannelReport({
    required this.id,
    required this.channelId,
    required this.year,
    required this.month,
    required this.fileUrl,
    required this.fileName,
    required this.title,
    required this.note,
  });

  factory ChannelReport.fromJson(Map<String, dynamic> json) => ChannelReport(
        id: (json['_id'] ?? '').toString(),
        channelId: (json['channelId'] ?? '').toString(),
        year: (json['year'] is num) ? (json['year'] as num).toInt() : 0,
        month: (json['month'] is num) ? (json['month'] as num).toInt() : 0,
        fileUrl: json['fileUrl']?.toString() ?? '',
        fileName: json['fileName']?.toString() ?? 'report.pdf',
        title: json['title']?.toString() ?? '',
        note: json['note']?.toString() ?? '',
      );

  String get monthLabel => [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ][(month - 1).clamp(0, 11)];
}