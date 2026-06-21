import 'package:flutter/material.dart';

/// Tracks which bottom-nav tab is active inside [AppShell], and gives
/// every tab a way to open the shared drawer even though each tab has
/// its own nested Scaffold (Scaffold.of(context) would otherwise resolve
/// to the wrong, inner Scaffold).
class NavProvider extends ChangeNotifier {
  final GlobalKey<ScaffoldState>? scaffoldKey;

  NavProvider({this.scaffoldKey});

  int currentIndex = 0;

  void setIndex(int index) {
    if (currentIndex == index) return;
    currentIndex = index;
    notifyListeners();
  }

  void openDrawer() {
    scaffoldKey?.currentState?.openDrawer();
  }
}
