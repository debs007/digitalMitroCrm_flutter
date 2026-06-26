import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';

/// Renders [text] as plain text with any http(s) URLs turned into tappable
/// links — mirrors the web app's tokenizeMessage behaviour so multiple
/// links separated by spaces/newlines each become their own clickable link.
class LinkifyText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Color? linkColor;

  LinkifyText({super.key, required this.text, this.style, this.linkColor});

  static final _urlRegex = RegExp(r'((?:https?:\/\/|www\.)[^\s<>"]+)', caseSensitive: false);

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final resolvedLinkColor = linkColor ?? AppColors.info;
    final matches = _urlRegex.allMatches(text);

    if (matches.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final spans = <InlineSpan>[];
    int cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final rawUrl = match.group(0)!;
      final trimmedUrl = rawUrl.replaceAll(RegExp(r'[.,!?;:]+$'), '');
      final fullUrl = trimmedUrl.startsWith('http') ? trimmedUrl : 'https://$trimmedUrl';
      spans.add(
        TextSpan(
          text: trimmedUrl,
          style: TextStyle(color: resolvedLinkColor, decoration: TextDecoration.underline),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              final uri = Uri.tryParse(fullUrl);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return RichText(text: TextSpan(style: baseStyle, children: spans));
  }
}
