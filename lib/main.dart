import 'dart:convert';
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'app/authentication/view/index_page.dart';
import 'app/security/circum_app_check.dart';
import 'app/home/bloc/home_bloc.dart';
import 'helper/notifications_helper.dart';
import 'rider_app.dart';

part './messaging.dart';

HomeBloc? _homeBloc;
HomeBloc get homeBloc => _homeBloc ??= HomeBloc();

// Initialize notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final NotificationService _notificationService =
    NotificationService(flutterLocalNotificationsPlugin);

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification settings
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/launcher_icon');

  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings();

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Firebase.initializeApp();
  if (!await initializeCircumAppCheck()) {
    FlutterNativeSplash.remove();
    runApp(
      RiderStartupApp(
        initializer: initializeCircumAppCheck,
        appBuilder: (_) => CircumRider(homeBloc: homeBloc),
      ),
    );
    return;
  }

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true, // Required to display a heads up notification
    badge: true,
    sound: true,
  );
  // var status = await Permission.appTrackingTransparency.status;
  // if (status.isDenied || status.isPermanentlyDenied) {
  //   // We didn't ask for permission yet or the permission has been denied before but not permanently.
  //   PermissionStatus permission =
  //       await Permission.appTrackingTransparency.request();

  //   if (permission.isGranted) {
  //   } else {
  //   }
  // }

  foregoundMessage();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FlutterNativeSplash.remove();

  // Lock app in portrait mode
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      // statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((value) {
    Bloc.observer = SimpleBlocObserver();
    runApp(CircumRider(homeBloc: homeBloc));
  });
}

class RiderStartupApp extends StatefulWidget {
  const RiderStartupApp({
    super.key,
    required this.initializer,
    required this.appBuilder,
    this.timeout = const Duration(seconds: 20),
  });

  final Future<void> Function() initializer;
  final WidgetBuilder appBuilder;
  final Duration timeout;

  @override
  State<RiderStartupApp> createState() => _RiderStartupAppState();
}

class _RiderStartupAppState extends State<RiderStartupApp> {
  Object? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _ready = false;
    });
    try {
      await widget.initializer().timeout(widget.timeout);
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.appBuilder(context);
    if (_error == null) return const _RiderStartupHold();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        backgroundColor: const Color(0xFF07090F),
        body: SafeArea(
          child: Center(
            child: Semantics(
              liveRegion: true,
              label: _error == null
                  ? 'Starting Circum Rider'
                  : 'Circum Rider could not start',
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFF87171),
                        size: 34,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Something went wrong.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFF5F7FB),
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'We could not start Rider. Check your connection and try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF9CA8B8),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Reference: RDR-START-001',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _start,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RiderStartupHold extends StatelessWidget {
  const _RiderStartupHold();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: IndexPage(),
    );
  }
}

class RiderStartupFailure extends StatelessWidget {
  const RiderStartupFailure({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        backgroundColor: const Color(0xFF07090F),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Security verification is unavailable.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => main(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SimpleBlocObserver extends BlocObserver {
  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
  }

  @override
  void onEvent(Bloc bloc, Object? event) {
    super.onEvent(bloc, event);
  }

  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
  }
}
