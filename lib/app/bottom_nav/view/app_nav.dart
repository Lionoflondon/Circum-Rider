import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:circum_rider/app/authentication/bloc/auth_bloc.dart';
import 'package:circum_rider/app/home/bloc/home_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/svg.dart';
import '../../../helper/notifications_helper.dart';
import '../../../utils/theme/theme.dart';
import '../../account/view/account.dart';
import '../../authentication/view/enable_location.dart';
import '../../history/view/index.dart';
import '../../home/view/index.dart';
import '../../home/view/maps_view.dart';
import '../../rider_account/rider_home_state_banner.dart';
import '../../support/view/index.dart';
import '../bloc/navbar_bloc.dart';

class AppNavView extends StatefulWidget {
  AppNavView({Key? key}) : super(key: key);

  @override
  AppNavViewState createState() => AppNavViewState();
}

class AppNavViewState extends State<AppNavView> {
  FlutterSecureStorage storage = const FlutterSecureStorage();
  AuthBloc? authBloc;

  @override
  void initState() {
    super.initState();
    authBloc = context.read<AuthBloc>();
    // authBloc?.add(RequestLocationData());
    // checkForLocationData();
    Timer.periodic(
        const Duration(seconds: 200), (timer) => checkForLocationData());
  }

  checkForLocationData() async {
    final location = (await storage.readAll())["location"];
    if (location == null) {
      // ignore: use_build_context_synchronously
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const EnableLocation()));
    } else {
      authBloc?.add(RequestLocationData());
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthBloc authBloc = context.read<AuthBloc>();
    return BlocBuilder<NavbarBloc, NavbarState>(builder: (context, state) {
      return Scaffold(
        backgroundColor: AppColors.secondary,
        body: WillPopScope(
            // Intercept the back button press
            onWillPop: () async {
              return false;
            },
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                        child:
                            //  authBloc.state.locationData == null
                            //     ? Image(
                            //         width: MediaQuery.of(context).size.width,
                            //         image: const AssetImage(
                            //             'assets/images/maps_placeholder.png'),
                            //         fit: BoxFit.fitWidth,
                            //       )
                            //     :

                            MapsView()),
                    const SizedBox(height: 180),
                  ],
                ),
                if (state.currentNavIndex >= 0) userScreens(context, 0),
                // if (state.currentNavIndex == 0 &&
                //   authBloc.state.isLocationEnabled != true)
                // locationUnavailable(),
                if (state.currentNavIndex > 0)
                  Column(
                    children: [
                      Expanded(
                          child: userScreens(context, state.currentNavIndex)),
                    ],
                  ),
                if (state.currentNavIndex == 0)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: RiderHomeStateBanner(),
                  ),
                BlocBuilder<HomeBloc, HomeState>(builder: ((context, state) {
                  if (state.rideStatus == RideStatus.acceptedARide) {
                    return Positioned(
                        bottom: 0,
                        left: 0,
                        height: 4,
                        width: 1.sw,
                        child: const ConnectingToUser());
                  }
                  return Container();
                }))
              ],
            )),
        bottomNavigationBar: _buildBottomNavigation(),
      );
    });
  }

  Widget _buildBottomNavigation() => BlocBuilder<NavbarBloc, NavbarState>(
        builder: (context, state) => BottomNavigationBar(
          elevation: 0,
          backgroundColor: const Color(0xFF151A1C),
          // fixedColor: Colors.black,
          currentIndex: state.currentNavIndex,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.grey,
          selectedLabelStyle: const TextStyle(fontFamily: 'OpenSans'),
          unselectedLabelStyle: const TextStyle(fontFamily: 'OpenSans'),
          type: BottomNavigationBarType.fixed,
          onTap: (index) =>
              context.read<NavbarBloc>().add(ChangeTabIndex(index: index)),
          items: [
            BottomNavigationBarItem(
                // backgroundColor: Colors.white,
                label: 'Home',
                activeIcon: SvgPicture.asset(
                  'assets/svg/home.svg',
                  height: 22,
                ),
                icon: SvgPicture.asset(
                  'assets/svg/home.svg',
                  color: AppColors.grey,
                  height: 22,
                )),
            BottomNavigationBarItem(
                label: 'History',
                activeIcon: SvgPicture.asset(
                  'assets/svg/history.svg',
                  color: AppColors.primary,
                  height: 22,
                ),
                icon: SvgPicture.asset(
                  'assets/svg/history.svg',
                  height: 22,
                )),
            BottomNavigationBarItem(
                label: 'Live Chat',
                activeIcon: SvgPicture.asset(
                  'assets/svg/chat.svg',
                  color: AppColors.primary,
                  height: 22,
                ),
                icon: SvgPicture.asset(
                  'assets/svg/chat.svg',
                  height: 22,
                )),
            BottomNavigationBarItem(
              label: 'Account',
              icon: Container(
                height: 22,
                width: 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  color: AppColors.input,
                ),
                child: authBloc != null &&
                        authBloc!.state.profilePhoto != null &&
                        authBloc!.state.profilePhoto != ''
                    ? CachedNetworkImage(
                        imageUrl: authBloc!.state.profilePhoto!,
                        imageBuilder: (context, imageProvider) => Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(100),
                            image: DecorationImage(
                              image: imageProvider,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        placeholder: (context, url) => Container(),
                        //     CircularProgressIndicator(
                        //   color: Colors.grey,
                        // ),
                        errorWidget: (context, url, error) => Icon(Icons.error),
                      )
                    : SvgPicture.asset(
                        'assets/svg/account.svg',
                        height: 32,
                      ),
              ),
            ),
          ],
        ),
      );

  Widget userScreens(context, index) {
    List<Widget> children = [
      HomeView(),
      const HistoryView(),
      const SupportView(),
      const AccountView(),
    ];
    return children[index];
  }

  Widget locationUnavailable() {
    return Container(
      color: AppColors.secondary,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset('assets/svg/map_pin.svg'),
          const SizedBox(height: 64),
          AppText.text(
              'Get the most out of Circum by\nenabling location services.',
              textAlign: TextAlign.center,
              fontSize: 20,
              fontWeight: FontWeight.w600),
          const SizedBox(height: 48),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AppButton.button(
                  widget: Center(
                    child: AppText.text('Open settings',
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  onPressed: () async {
                    context.read<AuthBloc>().add(OpenSettingsApp());
                  })),
        ],
      ),
    );
  }
}
