import 'package:flutter/material.dart';

/// Index of the Chat tab in AppShell's bottom nav — used to know when to
/// auto-clear the unread badge.
const int kChatTabIndex = 4;

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

  void openDrawer() {
    scaffoldKey?.currentState?.openDrawer();
  }
}