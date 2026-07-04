import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/navigation/navigation_service.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash/splash_screen.dart';
import 'services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Must be registered here at startup, before runApp — this is what lets
  // a notification be received and shown by the OS even while the app is
  // fully closed or backgrounded, not just while it's open.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const DigitalMitroApp());
}

class DigitalMitroApp extends StatelessWidget {
  const DigitalMitroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..loadSaved()),
      ],
      // Consumer here is what makes dark mode actually work: AppColors's
      // colours are static getters checked at build time, not something
      // Theme.of(context) tracks — so flipping the mode needs SOMETHING
      // above the whole tree to rebuild on notifyListeners. Wrapping the
      // entire MaterialApp in this Consumer does exactly that; every
      // descendant's build() re-runs and re-reads AppColors fresh.
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            // Lets push-notification tap handling navigate from outside
            // the widget tree (no BuildContext available there).
            navigatorKey: NavigationService.navigatorKey,
            // Most screens read colours from AppColors' static getters
            // inside their own build() methods, not via Theme.of(context)
            // — so a normal Provider rebuild doesn't reach them; only
            // widgets that explicitly watch ThemeProvider (like the
            // Settings toggle itself) update immediately. Keying the
            // WHOLE MaterialApp to the current mode forces Flutter to
            // discard and remount the entire tree (Navigator and all)
            // whenever it flips, guaranteeing every screen repaints with
            // the right colours instead of needing a manual navigate
            // away-and-back. AuthProvider's state lives in the
            // MultiProvider above this key boundary, so login state
            // survives the remount — only the visible screen briefly
            // replays the splash screen.
            key: ValueKey(themeProvider.isDark),
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.current,
            // Always light here on purpose — AppTheme.current already
            // adapts internally via AppColors.isDark, so we don't want
            // MaterialApp ALSO trying to auto-pick between theme/darkTheme
            // based on the device's system brightness.
            themeMode: ThemeMode.light,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
