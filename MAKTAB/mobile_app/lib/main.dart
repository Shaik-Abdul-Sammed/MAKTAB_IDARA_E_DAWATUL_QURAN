import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:maktab_app/providers/locale_provider.dart';
import 'package:maktab_app/providers/message_provider.dart';
import 'package:maktab_app/config/router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:maktab_app/l10n/app_localizations.dart';

import 'package:maktab_app/services/notification_service.dart';

import 'dart:io' show Platform, File;
import 'package:maktab_app/utils/logger.dart';

Future<bool> _isDeviceRooted() async {
  if (!Platform.isAndroid) return false;
  final paths = [
    '/system/app/Superuser.apk',
    '/sbin/su',
    '/system/bin/su',
    '/system/xbin/su',
    '/data/local/xbin/su',
    '/data/local/bin/su',
    '/system/sd/xbin/su',
    '/system/bin/failsafe/su',
    '/data/local/su'
  ];
  for (var path in paths) {
    try {
      if (await File(path).exists()) return true;
    } catch (_) {}
  }
  return false;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase.initializeApp note: $e');
  }
  
  // Global error boundary for UI errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    appLogger.e('UI Error Caught', error: details.exception, stackTrace: details.stack);
  };

  // Global error boundary for async/background errors
  PlatformDispatcher.instance.onError = (error, stack) {
    appLogger.e('Async Error Caught', error: error, stackTrace: stack);
    return true; // Prevent default error handling
  };

  // Custom Error Widget for Release Mode
  ErrorWidget.builder = (FlutterErrorDetails details) {
    bool inDebug = false;
    assert(() {
      inDebug = true;
      return true;
    }());
    if (inDebug) {
      return ErrorWidget(details.exception);
    }
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 50),
            const SizedBox(height: 10),
            const Text('Oops! Something went wrong.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('Please restart the app or contact support.'),
          ],
        ),
      ),
    );
  };
  
  // Security checks
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      bool jailbroken = await _isDeviceRooted();
      if (jailbroken) {
        // Halt execution on rooted devices
        runApp(const MaterialApp(
          home: Scaffold(
            body: Center(child: Text("App cannot run on rooted/jailbroken devices for security reasons.", textAlign: TextAlign.center)),
          ),
        ));
        return;
      }
      
      // Native window manager security flags are now set in MainActivity.kt
    } catch (e) {
      debugPrint('Jailbreak detection error: $e');
    }
  }

  // Initialize AuthProvider
  final authProvider = AuthProvider();
  await authProvider.initialize();

  // Initialize Notifications
  final notifService = NotificationService();
  await notifService.init();
  await notifService.requestPermissions();
  await notifService.scheduleDailyChecklistReminder();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => MessageProvider()),
      ],
      child: MaktabApp(authProvider: authProvider),
    ),
  );
}

class MaktabApp extends StatefulWidget {
  final AuthProvider authProvider;

  const MaktabApp({super.key, required this.authProvider});

  @override
  State<MaktabApp> createState() => _MaktabAppState();
}

class _MaktabAppState extends State<MaktabApp> with WidgetsBindingObserver {
  Timer? _inactivityTimer;
  final int _timeoutMinutes = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetInactivityTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    if (widget.authProvider.isAuthenticated) {
      _inactivityTimer = Timer(Duration(minutes: _timeoutMinutes), () {
        widget.authProvider.logout();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resetInactivityTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appRouter = AppRouter(widget.authProvider).router;
    final localeProvider = Provider.of<LocaleProvider>(context);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _resetInactivityTimer,
      onPanDown: (_) => _resetInactivityTimer(),
      child: MaterialApp.router(
        title: 'MAKTAB - Idara-e-Dawatul Qur\'an',
        debugShowCheckedModeBanner: false,
        locale: localeProvider.locale,
        supportedLocales: const [
          Locale('en', ''),
          Locale('te', ''),
          Locale('ur', ''),
        ],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF004D40),
            primary: const Color(0xFF004D40),
            secondary: const Color(0xFFFFD700),
            surface: const Color(0xFFF9FBE7),
          ),
          scaffoldBackgroundColor: const Color(0xFFF9FBE7),
          textTheme: GoogleFonts.outfitTextTheme(Theme.of(context).textTheme),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF004D40), // Dark green
            foregroundColor: Colors.white,
            centerTitle: true,
            elevation: 0,
          ),
          splashColor: const Color(0xFFFFD700).withValues(alpha: 0.12),
          highlightColor: Colors.transparent,
          cardTheme: CardThemeData(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          inputDecorationTheme: InputDecorationTheme(
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF004D40), width: 2),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black26),
            ),
          ),
          scrollbarTheme: ScrollbarThemeData(
            thickness: WidgetStateProperty.all(6.0),
            radius: const Radius.circular(8),
            thumbColor: WidgetStateProperty.all(const Color(0xFF004D40).withValues(alpha: 0.5)),
          ),
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: CupertinoPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
          ),
        ),
        routerConfig: appRouter,
        builder: (context, child) {

          final mediaQueryData = MediaQuery.of(context);
          final scale = mediaQueryData.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.2);
          return MediaQuery(
            data: mediaQueryData.copyWith(textScaler: scale),
            child: child!,
          );
        },
      ),
    );
  }
}
