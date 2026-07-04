import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';

/// Shared "download this note" flow used by both the employee's own
/// notepad and the admin's read-only view of someone else's notes.
/// Generates the file fresh on-device (nothing round-trips to the
/// backend) and hands it to the OS share sheet, same pattern as every
/// other download in this app — avoids needing storage permissions.
class NoteExportHelper {
  static Future<void> showExportSheet(BuildContext context, {required String text, required String title}) async {
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to download yet — this note is empty.')),
      );
      return;
    }

    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Download note as', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF document'),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Plain text (.txt)'),
              onTap: () => Navigator.pop(ctx, 'txt'),
            ),
          ],
        ),
      ),
    );

    if (choice == null || !context.mounted) return;

    try {
      if (choice == 'pdf') {
        await _exportPdf(text: text, title: title);
      } else {
        await _exportTxt(text: text, title: title);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create the file. Please try again.')),
        );
      }
    }
  }

  static String _safeFileBaseName(String title) {
    final cleaned = title.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
    return cleaned.isEmpty ? 'note' : cleaned.replaceAll(' ', '_');
  }

  static Future<void> _exportTxt({required String text, required String title}) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_safeFileBaseName(title)}.txt');
    await file.writeAsString(text);
    await Share.shareXFiles([XFile(file.path)]);
  }

  static Future<void> _exportPdf({required String text, required String title}) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Text(
            'Exported ${DateFormat('d MMM yyyy, hh:mm a').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          pw.Text(text, style: const pw.TextStyle(fontSize: 12)),
        ],
      ),
    );
    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_safeFileBaseName(title)}.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)]);
  }
}
