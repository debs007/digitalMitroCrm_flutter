import 'package:flutter/material.dart';
import '../services/task_service.dart';
import '../services/concern_service.dart';
import '../services/lead_service.dart';
import '../models/lead_model.dart';

/// Index of the Chat tab in AppShell's bottom nav — used to know when to
/// auto-clear the unread badge. (Home=0, Tasks=1, Attendance=2, Chat=3 —
/// Notifications was removed from the bottom nav.)
const int kChatTabIndex = 3;

/// Tracks which bottom-nav tab is active inside [AppShell], and gives
/// every tab a way to open the shared drawer even though each tab has
/// its own nested Scaffold (Scaffold.of(context) would otherwise resolve
/// to the wrong, inner Scaffold).
class NavProvider extends ChangeNotifier {
  final GlobalKey<ScaffoldState>? scaffoldKey;

  NavProvider({this.scaffoldKey});

  int currentIndex = 0;

  /// Unread count shown as a badge on the Chat tab's icon. Cleared the
  /// moment the user taps into the Chat tab — individual conversations
  /// still show their own unread badges in the chat list until opened.
  int chatUnreadCount = 0;

  // Sidebar badge counts — "un-actioned items" per drawer item. Tasks and
  // Callback/Sale/Transfer are scoped automatically by the underlying
  // endpoint (admin sees company-wide, employee sees their own); Concern
  // is admin-only since only an admin can actually action one.
  int taskCount = 0;
  int concernCount = 0;
  int callbackCount = 0;
  int saleCount = 0;
  int transferCount = 0;
  bool _refreshingBadges = false;

  void setIndex(int index) {
    if (currentIndex == index) return;
    currentIndex = index;
    notifyListeners();
  }

  void setChatUnreadCount(int count) {
    if (chatUnreadCount == count) return;
    chatUnreadCount = count;
    notifyListeners();
  }

  /// True when the Chat tab's badge should actually be drawn — hidden
  /// while the user is already sitting on that tab, even if the
  /// underlying count is nonzero (e.g. new messages arrived while they
  /// were looking at the chat list).
  bool get showChatBadge => chatUnreadCount > 0 && currentIndex != kChatTabIndex;

  /// Refreshes every sidebar badge count in parallel. Safe to call
  /// repeatedly (e.g. on every relevant soft-refresh socket event) — a
  /// call already in flight is skipped rather than stacking up.
  Future<void> refreshBadgeCounts({required bool isAdmin}) async {
    if (_refreshingBadges) return;
    _refreshingBadges = true;
    try {
      final results = await Future.wait([
        TaskService.instance.getPendingCount(),
        isAdmin ? ConcernService.instance.getPendingCount() : Future.value(0),
        isAdmin
            ? LeadService.instance.getAll(LeadType.callback, limit: 1).then((r) => r.total)
            : LeadService.instance.getMine(LeadType.callback, limit: 1).then((r) => r.total),
        isAdmin
            ? LeadService.instance.getAll(LeadType.sale, limit: 1).then((r) => r.total)
            : LeadService.instance.getMine(LeadType.sale, limit: 1).then((r) => r.total),
        isAdmin
            ? LeadService.instance.getAll(LeadType.transfer, limit: 1).then((r) => r.total)
            : LeadService.instance.getMine(LeadType.transfer, limit: 1).then((r) => r.total),
      ]);
      taskCount = results[0];
      concernCount = results[1];
      callbackCount = results[2];
      saleCount = results[3];
      transferCount = results[4];
      notifyListeners();
    } catch (_) {
      // Non-fatal — badges just keep showing their last-known values.
    } finally {
      _refreshingBadges = false;
    }
  }

  void openDrawer() {
    scaffoldKey?.currentState?.openDrawer();
  }
}
