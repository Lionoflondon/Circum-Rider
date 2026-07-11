part of '../home.dart';

class DispatchRequests extends StatefulWidget {
  DispatchRequests({Key? key}) : super(key: key);

  @override
  State<DispatchRequests> createState() => _DispatchRequestsState();
}

class _DispatchRequestsState extends State<DispatchRequests> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(builder: (context, state) {
      if (state.dispatchRequests.isEmpty &&
          state.requestStatus == RequestStatus.loading) {
        return const Expanded(child: RidesLoader());
      }

      if (state.dispatchRequests.isNotEmpty &&
          state.rideStatus != RideStatus.offline) {
        return SizedBox(
            width: double.maxFinite,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: AppText.text('Available jobs',
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                ExpandableCarousel(
                  options: ExpandableCarouselOptions(
                    floatingIndicator: false,
                  ),
                  items: state.dispatchRequests.asMap().entries.map((entry) {
                    int index = entry.key;
                    final item = entry.value;
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
                                color: const Color(0xF20D111C),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                    color: Colors.white.withOpacity(.09))),
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
                                              dashColor: AppColors.borderColor,
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
                                                    '${item.pickupData.address}',
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w600),
                                                AppText.text(
                                                    '${item.pickupData.subAddress}',
                                                    color: Color(0xFFC9D2D7)),
                                                const SizedBox(height: 20),
                                                AppText.text(
                                                    '${item.dropoffData.address}',
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w600),
                                                AppText.text(
                                                    '${item.dropoffData.subAddress}',
                                                    color: Color(0xFFC9D2D7)),
                                              ],
                                            )))
                                  ],
                                ),
                                const Divider(
                                  height: 32,
                                  color: AppColors.borderColor,
                                  thickness: 1,
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
                                        AppText.text(
                                            '${cSymbol(item.currency)}${item.price}',
                                            fontSize: 24,
                                            fontWeight: FontWeight.w600),
                                        AppText.text('Estimated earnings',
                                            color: Color(0xFFC9D2D7))
                                      ],
                                    ),
                                    SizedBox(width: 16),
                                  ],
                                ),
                                SizedBox(height: 16),
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: AppColors.borderColor,
                                ),
                                SizedBox(
                                  width: double.infinity,
                                  child: TextButton(
                                      // backgroundColor: Colors.transparent,
                                      style: TextButton.styleFrom(
                                        minimumSize: const Size(100, 55),
                                        shape: RoundedRectangleBorder(),
                                      ),
                                      child: AppText.text('Accept Delivery',
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                      onPressed: () {
                                        context.read<HomeBloc>().add(AcceptRide(
                                            topic: item.requestId,
                                            code: item.code,
                                            selectedRequestIndex: index));
                                      }),
                                )
                              ],
                            ));
                      },
                    );
                  }).toList(),
                ),
              ],
            ));
      }

      if (state.rideStatus != RideStatus.offline &&
          state.dispatchRequests.isEmpty &&
          state.requestStatus == RequestStatus.success) {
        return Expanded(
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText.text('Looking for nearby jobs',
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold),
                    const SizedBox(height: 36),
                    const LinearProgressIndicator(
                      minHeight: 4,
                      backgroundColor: Color(0xFF1F292E),
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 24),
                    AppButton.button(
                        widget: Center(
                          child: AppText.text('Refresh requests',
                              fontWeight: FontWeight.w600),
                        ),
                        onPressed: () {
                          context.read<HomeBloc>().add(GetAvailableRequests());
                        }),
                  ],
                )));
      }

      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/svg/message_request.svg',
              height: 70,
            ),
            const SizedBox(height: 8),
            AppText.text(
                'No jobs available right now.\nWe’ll keep looking while you’re online.',
                textAlign: TextAlign.center,
                fontSize: 14),
            const SizedBox(height: 18),
            Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: AppButton.button(
                    widget: Center(
                      child: AppText.text('Search for requests',
                          fontWeight: FontWeight.w600),
                    ),
                    onPressed: () {
                      context.read<HomeBloc>().add(GetAvailableRequests());
                    }))
          ],
        ),
      );
    });
  }
}
