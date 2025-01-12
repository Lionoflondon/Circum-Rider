import 'dart:convert';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:circum_rider/app/account/bloc/account_bloc.dart';
// import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app.dart';
import 'app/authentication/bloc/auth_bloc.dart';
import 'app/bottom_nav/bloc/navbar_bloc.dart';
import 'app/home/bloc/home_bloc.dart';
import 'app/history/bloc/history_bloc.dart';
import 'app/support/bloc/support_bloc.dart';
import 'app/verification/bloc/verification_bloc.dart';
import 'helper/chats_help.dart';
import 'helper/notifications_helper.dart';
import 'utils/nav/nav_key.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:bot_toast/bot_toast.dart';

part './messaging.dart';

final NotificationService _notificationService = NotificationService();

final homeBloc = HomeBloc();

// Initialize notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

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

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
  );

  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Firebase.initializeApp();

  // Activate app check after initialization, but before
  // usage of any Firebase services.
  // await FirebaseAppCheck.instance
  //     // Your personal reCaptcha public key goes here:
  //     .activate(
  //   androidProvider: AndroidProvider.playIntegrity,
  //   appleProvider: AppleProvider.appAttest,
  // webProvider: ReCaptchaV3Provider(kWebRecaptchaSiteKey),
  // );

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

  //   print(permission);

  //   if (permission.isGranted) {
  //     print('Permission Granted');
  //   } else {
  //     print('Permission denied');
  //   }
  // }

  foregoundMessage();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FlutterNativeSplash.remove();

  // Lock app in portrait mode
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      // statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light));

  SystemChrome.setPreferredOrientations(
          [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown])
      .then((value) {
    Bloc.observer = SimpleBlocObserver();
    runApp(const CircumRider());
  });
}

class CircumRider extends StatelessWidget {
  const CircumRider({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        builder: (_, __) {
          final botToastBuilder = BotToastInit();
          return MaterialApp(
              // navigatorKey: NavKey.navKey,
              // onGenerateRoute: (_) => null,
              debugShowCheckedModeBanner: false,
              title: 'Circum Rider',
              builder: (context, child) {
                // ScreenUtil.setContext(context);
                child = botToastBuilder(context, child);
                return MediaQuery(
                  //Setting font does not change with system font size
                  data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
                  child: child,
                );
              },
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              navigatorObservers: [BotToastNavigatorObserver()],
              home: WillPopScope(
                onWillPop: () async =>
                    !await NavKey.navKey.currentState!.maybePop(),
                child: MultiBlocProvider(providers: [
                  BlocProvider<AuthBloc>(
                    create: (BuildContext context) =>
                        AuthBloc()..add(SortSessionState()),
                  ),
                  BlocProvider(
                    create: (context) => NavbarBloc(),
                  ),
                  BlocProvider(
                    create: (context) => VerificationBloc(),
                  ),
                  BlocProvider<HomeBloc>(
                    create: (BuildContext context) => homeBloc,
                  ),
                  BlocProvider<HistoryBloc>(
                    create: (BuildContext context) => HistoryBloc(),
                  ),
                  BlocProvider<SupportBloc>(
                    create: (BuildContext context) => SupportBloc(),
                  ),
                  BlocProvider<AccountBloc>(
                    create: (BuildContext context) => AccountBloc(),
                  ),
                ], child: const App()),
              ));
        });
  }
}

class SimpleBlocObserver extends BlocObserver {
  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    //   debugPrint('''
    //           Change: ${change.toString()},
    //           RuntimeType: ${bloc.runtimeType},
    //           ''');
  }

  @override
  void onEvent(Bloc bloc, Object? event) {
    super.onEvent(bloc, event);
    // print(event);
    // print(bloc);
  }

  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    // debugPrint('$transition');
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    // debugPrint('$error');
    super.onError(bloc, error, stackTrace);
  }
}
