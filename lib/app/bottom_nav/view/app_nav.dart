import 'dart:async';
import 'dart:ui';

import 'package:circum_rider/app/authentication/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_maps_widget/google_maps_widget.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';

// 2 mark okoye road

import '../../../helper/google_map_controller.dart';
import '../../../utils/theme/theme.dart';
import '../../account/view/account.dart';
import '../../history/view/index.dart';
import '../../home/view/index.dart';
import '../../support/view/index.dart';
import '../bloc/navbar_bloc.dart';

class AppNavView extends StatefulWidget {
  AppNavView({Key? key}) : super(key: key);

  @override
  AppNavViewState createState() => AppNavViewState();
}

class AppNavViewState extends State<AppNavView> {
  AuthBloc? authBloc;
  @override
  void initState() {
    super.initState();
    authBloc = context.read<AuthBloc>();
    authBloc?.add(RequestLocationData());
    Timer.periodic(const Duration(seconds: 20),
        (timer) => authBloc?.add(RequestLocationData()));
  }

  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

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
                        child: authBloc.state.locationData == null
                            ? Image(
                                width: MediaQuery.of(context).size.width,
                                image: const AssetImage(
                                    'assets/images/maps_placeholder.png'),
                                fit: BoxFit.fitWidth,
                              )
                            : GoogleMap(
                                mapType: MapType.normal,
                                initialCameraPosition: CameraPosition(
                                  target: LatLng(
                                      authBloc.state.locationData!.latitude,
                                      authBloc.state.locationData!.longitude),
                                  zoom: 14.4746,
                                ),
                                onMapCreated: !_controller.isCompleted
                                    ? (GoogleMapController controller) {
                                        MapControllerSingleton()
                                            .setController(controller);
                                      }
                                    : null,
                              )),
                    const SizedBox(height: 180),
                  ],
                ),
                if (state.currentNavIndex >= 0) userScreens(context, 0),
                if (state.currentNavIndex == 0 &&
                    authBloc.state.isLocationEnabled != true)
                  locationUnavailable(),
                if (state.currentNavIndex > 0)
                  Column(
                    children: [
                      Expanded(
                          child: userScreens(context, state.currentNavIndex)),
                    ],
                  )
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
              icon: SvgPicture.asset(
                'assets/svg/account.svg',
                height: 22,
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
