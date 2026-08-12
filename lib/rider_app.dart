import 'package:circum_rider/app/account/bloc/account_bloc.dart';
import 'package:circum_rider/app.dart';
import 'package:circum_rider/app/authentication/bloc/auth_bloc.dart';
import 'package:circum_rider/app/bottom_nav/bloc/navbar_bloc.dart';
import 'package:circum_rider/app/history/bloc/history_bloc.dart';
import 'package:circum_rider/app/home/bloc/home_bloc.dart';
import 'package:circum_rider/app/rider_jobs/rider_job_offer_screen.dart';
import 'package:circum_rider/app/rider_design/rider_ui.dart';
import 'package:circum_rider/app/support/bloc/support_bloc.dart';
import 'package:circum_rider/app/verification/bloc/verification_bloc.dart';
import 'package:circum_rider/utils/nav/nav_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:bot_toast/bot_toast.dart';

class CircumRider extends StatelessWidget {
  const CircumRider({super.key, this.homeBloc});

  final HomeBloc? homeBloc;

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
          theme: RiderTypography.theme().copyWith(
            navigationBarTheme: const NavigationBarThemeData(
              labelTextStyle: WidgetStatePropertyAll(TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
              )),
            ),
          ),
          navigatorObservers: [BotToastNavigatorObserver()],
          routes: {
            RiderJobOfferScreen.routeName: (_) => const RiderJobOfferScreen(),
          },
          home: WillPopScope(
            onWillPop: () async =>
                !await NavKey.navKey.currentState!.maybePop(),
            child: MultiBlocProvider(
              providers: [
                BlocProvider<AuthBloc>(
                  create: (context) => AuthBloc()..add(SortSessionState()),
                ),
                BlocProvider(create: (context) => NavbarBloc()),
                BlocProvider(create: (context) => VerificationBloc()),
                BlocProvider<HomeBloc>.value(value: homeBloc ?? HomeBloc()),
                BlocProvider(create: (context) => HistoryBloc()),
                BlocProvider(create: (context) => SupportBloc()),
                BlocProvider(create: (context) => AccountBloc()),
              ],
              child: const App(),
            ),
          ),
        );
      },
    );
  }
}
