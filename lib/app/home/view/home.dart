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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../utils/theme/theme.dart';
import '../../rider_design/rider_ui.dart';
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
      SchedulerBinding.instance.addPostFrameCallback((_) async {
        //yourcode
        if (state.rideStatus == RideStatus.delivered) {
          print('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>...');
          print('Delivered');
          print('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>...');
          context
              .read<HomeBloc>()
              .add(SetRideStatus(status: RideStatus.online));
          await Future.delayed(Duration(seconds: 1));
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
          minHeight: _sheetHeight(state),
          maxHeight: _sheetHeight(state),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          panel: Container(
              decoration: const BoxDecoration(
                color: Color(0xF20D111C),
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
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

  double _sheetHeight(HomeState state) {
    if (state.rideStatus == RideStatus.offline) return 350;
    if (state.rideStatus == RideStatus.online) {
      return state.dispatchRequests.isEmpty ? 270 : 610;
    }
    return 610;
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
          if (state.rideStatus == RideStatus.offline) ...[
            const _RiderStatPills(),
            const SizedBox(height: 20),
          ],
          if (state.rideStatus == RideStatus.offline &&
              !state.canGoOnline &&
              state.verificationChecklist.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF111B22),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText.text('Complete your verification to start earning.',
                      fontSize: 15, fontWeight: FontWeight.bold),
                  const SizedBox(height: 8),
                  ...state.verificationChecklist.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          children: [
                            const Icon(Icons.radio_button_unchecked,
                                color: AppColors.primary, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                                child: AppText.text(item,
                                    color: Colors.white.withOpacity(0.76),
                                    fontSize: 13)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],
          if (state.message != null &&
              state.rideStatus == RideStatus.offline) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppText.text(state.message!,
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ],
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
                      // print('Drag started');
                    },
                    onHorizontalDragEnd: (details) async {
                      print(details.primaryVelocity);
                      print(details.velocity);

                      if (details.primaryVelocity != null &&
                          (details.primaryVelocity!) > 100) {
                        // print('Dragged right');
                        if (state.rideStatus == RideStatus.online) {
                          final confirmed = await showCupertinoDialog(
                              barrierDismissible: true,
                              context: context,
                              builder: (_) {
                                return AlertDialog(
                                  shape: RoundedRectangleBorder(),
                                  backgroundColor:
                                      const Color.fromARGB(255, 255, 255, 255),
                                  title: AppText.text('Go offline?',
                                      fontSize: 18,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600),
                                  content: AppText.text(
                                    "You won’t receive new ride requests while offline.",
                                    fontSize: 16,
                                    color: Colors.black,
                                  ),
                                  actions: [
                                    AppButton.button(
                                        widget: AppText.text('confirm',
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600),
                                        onPressed: () {
                                          Navigator.pop(_, true);
                                        }),
                                    AppButton.button(
                                        backgroundColor: AppColors.danger,
                                        widget: AppText.text('cancel',
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600),
                                        onPressed: () {
                                          Navigator.pop(_, false);
                                        }),
                                  ],
                                );
                              });

                          if (confirmed == false) {
                            return;
                          }
                        }

                        if (context.read<AuthBloc>().state.locationData !=
                            null) {
                          // print('Location available');
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
                        // print('Dragged left');
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
                        onPressed: state.rideStatus == RideStatus.offline &&
                                !state.canGoOnline
                            ? null
                            : () => _toggleAvailability(state)))
              ],
            )
        ],
      );
    });
  }

  void _toggleAvailability(HomeState state) {
    if (context.read<AuthBloc>().state.locationData != null) {
      context.read<HomeBloc>().add(SetHomeLocationData(
          locationData: context.read<AuthBloc>().state.locationData!));
    }
    context.read<HomeBloc>().add(SetRideStatus(
        status: state.rideStatus == RideStatus.offline
            ? RideStatus.online
            : RideStatus.offline));
  }
}

class _RiderStatPills extends StatelessWidget {
  const _RiderStatPills();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('riders').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final rider = snapshot.data?.data() ?? const <String, dynamic>{};
        final earnings = rider['todayEarnings'];
        final trust = rider['trustPoints'];
        final rank = '${rider['riderRank'] ?? rider['rank'] ?? 'Agent'}';
        return Row(children: [
          Expanded(
              child: _RiderStat(
                  value:
                      earnings is num ? '£${earnings.toStringAsFixed(2)}' : '—',
                  label: 'TODAY')),
          const SizedBox(width: 8),
          Expanded(
              child: _RiderStat(
                  value: trust is num ? trust.toStringAsFixed(0) : '—',
                  label: 'TRUST PTS')),
          const SizedBox(width: 8),
          Expanded(child: _RiderStat(value: rank, label: 'RANK')),
        ]);
      },
    );
  }
}

class _RiderStat extends StatelessWidget {
  const _RiderStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 66),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.035),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(.09)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: RiderPalette.paper,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(
                  color: RiderPalette.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}
