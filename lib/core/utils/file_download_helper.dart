import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';

/// Downloads a public chat-attachment URL (no auth needed — these are
/// Cloudinary URLs) and hands it to the OS share sheet so the user can
/// "Save to Photos" / "Save to Files" / "Save to Downloads" themselves —
/// this avoids needing storage permissions or platform-specific gallery
/// APIs, and works the same way for images, videos, and any other file.
Future<void> downloadAttachment(BuildContext context, String url, String fileName) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(const SnackBar(content: Text('Downloading...'), duration: Duration(seconds: 2)));

  try {
    final dio = Dio();
    final response = await dio.get(url, options: Options(responseType: ResponseType.bytes));
    final dir = await getTemporaryDirectory();
    final safeName = fileName.isNotEmpty ? fileName : 'download_${DateTime.now().millisecondsSinceEpoch}';
    final file = File('${dir.path}/$safeName');
    await file.writeAsBytes(response.data as List<int>);

    await Share.shareXFiles([XFile(file.path)]);
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('Download failed. Please try again.')));
  }
}
