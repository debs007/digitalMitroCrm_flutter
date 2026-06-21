import 'dart:io';
import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';

class UploadService {
  UploadService._();
  static final UploadService instance = UploadService._();

  /// Uploads a single file (image/document) for use as a chat attachment.
  /// Returns the Cloudinary URL to include in a message's `attachments`.
  Future<String> uploadChatFile(File file) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: file.path.split('/').last),
      });
      final res = await ApiClient.instance.dio.post(ApiConstants.fileUpload, data: formData);
      final data = res.data is Map ? Map<String, dynamic>.from(res.data) : {};
      final url = data['fileUrl']?.toString();
      if (url == null || url.isEmpty) {
        throw ApiException('Upload failed — no file URL returned.');
      }
      return url;
    } on DioException catch (e) {
      throw ApiException(e.response?.data?['message']?.toString() ?? 'Upload failed.');
    }
  }
}
