import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app.dart';
import 'app/account/bloc/account_bloc.dart';
import 'app/authentication/bloc/auth_bloc.dart';
import 'app/bottom_nav/bloc/navbar_bloc.dart';
import 'app/history/bloc/history_bloc.dart';
import 'app/home/bloc/home_bloc.dart';
import 'app/rider_jobs/rider_job_offer_screen.dart';
import 'app/stripe/rider_stripe_return.dart';
import 'app/support/bloc/support_bloc.dart';
import 'app/verification/bloc/verification_bloc.dart';
import 'utils/nav/nav_key.dart';

class CircumRider extends StatefulWidget {
  const CircumRider({super.key, this.homeBloc, this.stripeReturnIntent});

  final HomeBloc? homeBloc;
  final RiderStripeReturnIntent? stripeReturnIntent;

  @override
  State<CircumRider> createState() => _CircumRiderState();
}

class _CircumRiderState extends State<CircumRider> {
  late final HomeBloc _homeBloc = widget.homeBloc ?? HomeBloc();
  late RiderStripeReturnIntent? _stripeReturnIntent = widget.stripeReturnIntent;

  @override
  void dispose() {
    if (widget.homeBloc == null) _homeBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      builder: (_, __) {
        final botToastBuilder = BotToastInit();
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Circum Rider',
          builder: (context, child) => botToastBuilder(context, child),
          themeMode: ThemeMode.dark,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF07090F),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF3B82F6),
              surface: Color(0xFF0D111C),
              error: Color(0xFFF87171),
            ),
            fontFamily: 'Inter',
            navigationBarTheme: const NavigationBarThemeData(
              labelTextStyle: WidgetStatePropertyAll(
                TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          navigatorObservers: [BotToastNavigatorObserver()],
          routes: {
            RiderJobOfferScreen.routeName: (_) => const RiderJobOfferScreen(),
          },
          // The nested Rider navigator still uses the legacy async pop
          // contract; migrate it separately without changing mobile back
          // behavior as part of this Web return-path repair.
          // ignore: deprecated_member_use
          home: WillPopScope(
            onWillPop: () async {
              final popped =
                  await NavKey.navKey.currentState?.maybePop() ?? false;
              return !popped;
            },
            child: MultiBlocProvider(
              providers: [
                BlocProvider<AuthBloc>(
                  create: (_) => AuthBloc()..add(SortSessionState()),
                ),
                BlocProvider(create: (_) => NavbarBloc()),
                BlocProvider(create: (_) => VerificationBloc()),
                BlocProvider<HomeBloc>.value(value: _homeBloc),
                BlocProvider(create: (_) => HistoryBloc()),
                BlocProvider(create: (_) => SupportBloc()),
                BlocProvider(create: (_) => AccountBloc()),
              ],
              child: App(
                stripeReturnIntent: _stripeReturnIntent,
                onStripeReturnComplete: () {
                  if (!mounted) return;
                  setState(() => _stripeReturnIntent = null);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
