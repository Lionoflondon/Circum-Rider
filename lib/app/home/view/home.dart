// ignore_for_file: prefer_const_constructors

import 'package:circum_rider/app/authentication/bloc/auth_bloc.dart';
import 'package:circum_rider/app/home/bloc/home_bloc.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../utils/theme/theme.dart';

class HomeView extends StatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  @override
  void initState() {
    super.initState();
    context.read<HomeBloc>().add(CheckForPushToken());
  }

  @override
  Widget build(BuildContext context) {
    return SlidingUpPanel(
        minHeight: 180,
        maxHeight: MediaQuery.of(context).size.height * 0.75,
        panel: Container(
            color: AppColors.secondary,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  height: 5,
                  width: 50,
                  decoration: BoxDecoration(
                      color: const Color(0xFF415058),
                      borderRadius: BorderRadius.circular(5)),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(left: 24, right: 24),
                  child: onlinePresenceButton(),
                ),
                const SizedBox(height: 36),
                requests(),
                const SizedBox(height: 24),
              ],
            )));
  }

  Widget onlinePresenceButton() {
    return BlocBuilder<HomeBloc, HomeState>(builder: (context, state) {
      return Column(
        children: [
          state.isOffline == true
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
          Stack(
            children: [
              Shimmer.fromColors(
                  baseColor: state.isOffline
                      ? const Color(0xFF0F823D)
                      : const Color(0xFF415058),
                  highlightColor: state.isOffline
                      ? const Color(0xFF18BC5A)
                      : const Color(0xFF2D4E60),
                  child: AppButton.button(
                      backgroundColor: AppColors.input,
                      widget: const Center(),
                      onPressed: () {
                        // Navigator.push(
                        //     context,
                        //     MaterialPageRoute(
                        //         builder: (_) => const ChooseAddressView()));
                      })),
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

                      if (context.read<AuthBloc>().state.locationData != null) {
                        print('Location available');
                        context.read<HomeBloc>().add(SetHomeLocationData(
                            locationData:
                                context.read<AuthBloc>().state.locationData!));
                      }

                      context
                          .read<HomeBloc>()
                          .add(SetOnlinePresence(isOffline: !state.isOffline));
                    }

                    if (details.primaryVelocity != null &&
                        (details.primaryVelocity!) < -100) {
                      print('Dragged left');
                    }
                  },
                  child: TextButton(
                      child: Row(
                        children: [
                          // const SizedBox(width: 5),
                          const SizedBox(width: 16),
                          AppText.text(
                              state.isOffline == true
                                  ? 'Swipe to go online'
                                  : 'Swipe to go offline',
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                          const Spacer(),
                          SvgPicture.asset('assets/svg/double_arrow_right.svg'),
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

  Widget requests() {
    return BlocBuilder<HomeBloc, HomeState>(builder: (context, state) {
      if (state.dispatchRequests != null &&
          state.dispatchRequests!.length > 0) {
        return SizedBox(
            width: double.maxFinite,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: AppText.text('Requests',
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                ExpandableCarousel(
                  options: CarouselOptions(
                    floatingIndicator: false,
                  ),
                  items: state.dispatchRequests!.map((i) {
                    return Builder(
                      builder: (BuildContext context) {
                        return Container(
                            width: MediaQuery.of(context).size.width,
                            margin: EdgeInsets.symmetric(
                              horizontal: 5.0,
                            ).copyWith(bottom: 30),
                            padding: EdgeInsets.symmetric(vertical: 16)
                                .copyWith(bottom: 0),
                            decoration: BoxDecoration(
                                border:
                                    Border.all(color: const Color(0xFF1F292E))),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                        padding: EdgeInsets.only(left: 16),
                                        height: 85,
                                        child: const Column(
                                          children: [
                                            Icon(
                                              Icons.circle,
                                              color: Color(0xFF2D89D4),
                                              size: 10,
                                            ),
                                            Expanded(
                                                child: DottedLine(
                                              direction: Axis.vertical,
                                              dashColor: Color(0xFF1F292E),
                                            )),
                                            Icon(
                                              Icons.circle,
                                              size: 10,
                                              color: Color(0xFF65C436),
                                            ),
                                          ],
                                        )),
                                    const SizedBox(width: 14),
                                    Expanded(
                                        child: Padding(
                                            padding: EdgeInsets.only(right: 16),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                AppText.text(
                                                    '${i.pickupData.address}',
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w600),
                                                AppText.text(
                                                    '${i.pickupData.subAddress}',
                                                    color: Color(0xFFC9D2D7)),
                                                const SizedBox(height: 20),
                                                AppText.text(
                                                    '${i.dropoffData.address}',
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w600),
                                                AppText.text(
                                                    '${i.dropoffData.subAddress}',
                                                    color: Color(0xFFC9D2D7)),
                                              ],
                                            )))
                                  ],
                                ),
                                Divider(
                                  height: 32,
                                  color: Color(0xFF1F292E),
                                ),
                                Row(
                                  children: [
                                    SizedBox(width: 16),
                                    Image(
                                        height: 52,
                                        width: 52,
                                        image: AssetImage(
                                            'assets/images/bike.png')),
                                    Spacer(),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        AppText.text('\$20',
                                            fontSize: 24,
                                            fontWeight: FontWeight.w600),
                                        AppText.text('Delivery Price',
                                            color: Color(0xFFC9D2D7))
                                      ],
                                    ),
                                    SizedBox(width: 16),
                                  ],
                                ),
                                SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                        child: TextButton(
                                            // backgroundColor: Colors.transparent,
                                            style: TextButton.styleFrom(
                                                minimumSize:
                                                    const Size(100, 55),
                                                shape:
                                                    const RoundedRectangleBorder(
                                                        side: BorderSide(
                                                            color: Color(
                                                                0xFF1F292E)))),
                                            child: AppText.text('Accept',
                                                color: AppColors.primary,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold),
                                            onPressed: () {
                                              context.read<HomeBloc>().add(
                                                  AcceptRide(
                                                      topic: i.requestId,
                                                      code: i.code));
                                            })),
                                    Expanded(
                                        child: TextButton(
                                            // backgroundColor: Colors.transparent,
                                            style: TextButton.styleFrom(
                                                minimumSize:
                                                    const Size(100, 55),
                                                shape:
                                                    const RoundedRectangleBorder(
                                                        side: BorderSide(
                                                            color: Color(
                                                                0xFF1F292E)))),
                                            child: AppText.text('Decline',
                                                color: const Color(0xFFA75248),
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold),
                                            onPressed: () {})),
                                  ],
                                )
                              ],
                            ));
                      },
                    );
                  }).toList(),
                )
              ],
            ));
      }

      if (state.isOffline == false && state.dispatchRequests == null) {
        return Expanded(
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText.text('Awaiting requests',
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold),
                    const SizedBox(height: 36),
                    const LinearProgressIndicator(
                      minHeight: 4,
                      backgroundColor: Color(0xFF1F292E),
                      color: AppColors.primary,
                    ),
                  ],
                )));
      }

      return Container();
    });
  }
}
