import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/state_views.dart';

/// In-app PDF viewer for chat attachments and payslips. Chat attachment
/// PDFs are public Cloudinary URLs (no auth header needed) so this uses a
/// plain Dio instance rather than the authenticated ApiClient.
class PdfPreviewScreen extends StatefulWidget {
  final String url;
  final String title;

  const PdfPreviewScreen({super.key, required this.url, this.title = 'Document'});

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  String? _localPath;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = Dio();
      final response = await dio.get(widget.url, options: Options(responseType: ResponseType.bytes));
      final dir = await getTemporaryDirectory();
      final fileName = 'preview_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(response.data as List<int>);
      setState(() {
        _localPath = file.path;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load document.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _isLoading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _download)
              : PDFView(
                  filePath: _localPath!,
                  enableSwipe: true,
                  swipeHorizontal: false,
                  autoSpacing: true,
                  pageFling: true,
                  onError: (error) {
                    setState(() => _error = 'Could not render document.');
                  },
                ),
      backgroundColor: AppColors.background,
    );
  }
}
