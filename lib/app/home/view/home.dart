// ignore_for_file: prefer_const_constructors

import 'dart:async';

import 'package:circum_rider/app/authentication/bloc/auth_bloc.dart';
import 'package:circum_rider/app/home/bloc/home_bloc.dart';
import 'package:currency_symbols/currency_symbols.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../utils/theme/theme.dart';
import 'parts/requests_loader.dart';
import 'ratings.dart';
import 'ride_chats.dart';

part 'parts/dispatch_requests.dart';
part 'parts/selected_request.dart';
part 'parts/connecting.dart';

class HomeView extends StatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  PanelController panelController = PanelController();
  @override
  void initState() {
    super.initState();
    context.read<HomeBloc>().add(CheckForPushToken());
    context.read<HomeBloc>().add(CheckForActiveRequest());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(builder: (context, state) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        //yourcode
        if (state.rideStatus == RideStatus.delivered) {
          print('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>...');
          print('Delivered');
          print('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>...');
          context
              .read<HomeBloc>()
              .add(SetRideStatus(status: RideStatus.online));
          Navigator.push(
              context, MaterialPageRoute(builder: (_) => RatingsView()));
        }
      });
      if (state.panelControlStatus == PanelControlStatus.isOpened) {
        panelController.animatePanelToPosition(1);
        context
            .read<HomeBloc>()
            .add(SetPanelControlStatus(status: PanelControlStatus.initialized));
      }
      if (state.panelControlStatus == PanelControlStatus.isClosed) {
        print('hits here');
        panelController.animatePanelToPosition(0);
        context
            .read<HomeBloc>()
            .add(SetPanelControlStatus(status: PanelControlStatus.initialized));
      }
      return SlidingUpPanel(
          controller: panelController,
          minHeight: state.minDrawerHeight,
          maxHeight: state
              .maxDrawerHeight, // MediaQuery.of(context).size.height * 0.75,
          panel: Container(
              color: AppColors.secondary,
              child: Column(
                children: [
                  if (state.rideStatus != RideStatus.offline)
                    Container(
                      height: 5,
                      width: 50,
                      margin: EdgeInsets.only(top: 10),
                      decoration: BoxDecoration(
                          color: const Color(0xFF415058),
                          borderRadius: BorderRadius.circular(5)),
                    ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.only(left: 24, right: 24),
                    child: onlinePresenceButton(),
                  ),
                  if (state.rideStatus == RideStatus.online ||
                      state.rideStatus == RideStatus.offline)
                    const SizedBox(height: 36),
                  if (state.rideStatus == RideStatus.online) DispatchRequests(),
                  if (state.rideStatus == RideStatus.acceptedARide ||
                      state.rideStatus == RideStatus.arrivedAtPickupLocation ||
                      state.rideStatus == RideStatus.userConfirmedRide ||
                      state.rideStatus == RideStatus.outForDelivery)
                    SelectedRequest(),
                  // const SizedBox(height: 24),
                ],
              )));
    });
  }

  Widget onlinePresenceButton() {
    return BlocBuilder<HomeBloc, HomeState>(builder: (context, state) {
      return Column(
        children: [
          state.rideStatus == RideStatus.offline
              ? Row(
                  children: [
                    SvgPicture.asset('assets/svg/offline_indicator.svg'),
                    const SizedBox(width: 12),
                    AppText.text("You're currently offline", fontSize: 16)
                  ],
                )
              : Row(
                  children: [
                    SvgPicture.asset('assets/svg/online_indicator.svg'),
                    const SizedBox(width: 12),
                    AppText.text("You’re currently online", fontSize: 16)
                  ],
                ),
          const SizedBox(height: 32),
          if (state.rideStatus == RideStatus.online ||
              state.rideStatus == RideStatus.offline)
            Stack(
              children: [
                Shimmer.fromColors(
                  baseColor: state.rideStatus == RideStatus.offline
                      ? const Color(0xFF0F823D)
                      : const Color(0xFF415058),
                  highlightColor: state.rideStatus == RideStatus.offline
                      ? const Color(0xFF18BC5A)
                      : const Color(0xFF2D4E60),
                  child: Container(
                    height: 50,
                    width: double.maxFinite,
                    color: Colors.white,
                  ),
                ),
                GestureDetector(
                    onHorizontalDragStart: (details) {
                      print('Drag started');
                    },
                    onHorizontalDragEnd: (details) {
                      print(details.primaryVelocity);
                      print(details.velocity);

                      if (details.primaryVelocity != null &&
                          (details.primaryVelocity!) > 100) {
                        print('Dragged right');

                        if (context.read<AuthBloc>().state.locationData !=
                            null) {
                          print('Location available');
                          context.read<HomeBloc>().add(SetHomeLocationData(
                              locationData: context
                                  .read<AuthBloc>()
                                  .state
                                  .locationData!));
                        }

                        if (state.rideStatus == RideStatus.offline) {
                          context
                              .read<HomeBloc>()
                              .add(SetRideStatus(status: RideStatus.online));
                        } else {
                          context
                              .read<HomeBloc>()
                              .add(SetRideStatus(status: RideStatus.offline));
                        }
                      }

                      if (details.primaryVelocity != null &&
                          (details.primaryVelocity!) < -100) {
                        print('Dragged left');
                      }
                    },
                    child: TextButton(
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(),
                        ),
                        child: Row(
                          children: [
                            // const SizedBox(width: 5),
                            const SizedBox(width: 16),
                            AppText.text(
                                state.rideStatus == RideStatus.offline
                                    ? 'Swipe to go online'
                                    : 'Swipe to go offline',
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                            const Spacer(),
                            SvgPicture.asset(
                                'assets/svg/double_arrow_right.svg'),
                            const SizedBox(width: 16),
                          ],
                        ),
                        onPressed: () {
                          // Navigator.push(
                          //     context,
                          //     MaterialPageRoute(
                          //         builder: (_) => const ChooseAddressView()));
                        }))
              ],
            )
        ],
      );
    });
  }
}
