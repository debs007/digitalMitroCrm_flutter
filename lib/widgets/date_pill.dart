import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/ist_time.dart';

/// A WhatsApp-style rounded date label ("Today" / "Yesterday" /
/// "23 Jul 2026") shown between messages from different calendar days.
/// Mirrors the web app's date-divider pill (same "Today"/"Yesterday"/
/// "DD MMM YYYY" rules), grouped by IST day for consistency with the rest
/// of the app rather than the device's own timezone.
class DatePill extends StatelessWidget {
  final DateTime date;
  const DatePill({super.key, required this.date});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String labelFor(DateTime date) {
    final d = date.toIst;
    final now = DateTime.now().toUtc().toIst;
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return 'Today';
    if (day == yesterday) return 'Yesterday';
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  /// True when `a` and `b` fall on different IST calendar days — used to
  /// decide whether a pill belongs between two adjacent messages.
  static bool isDifferentDay(DateTime a, DateTime b) {
    final ai = a.toIst;
    final bi = b.toIst;
    return ai.year != bi.year || ai.month != bi.month || ai.day != bi.day;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.neutralBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            labelFor(date),
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
