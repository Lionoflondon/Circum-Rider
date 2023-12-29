part of '../home.dart';

class SelectedRequest extends StatefulWidget {
  SelectedRequest({Key? key}) : super(key: key);

  @override
  State<SelectedRequest> createState() => _SelectedRequestState();
}

class _SelectedRequestState extends State<SelectedRequest> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(builder: (context, state) {
      return SizedBox(
          width: double.maxFinite,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                  padding: const EdgeInsets.only(left: 24, right: 24),
                  child: Container(
                    decoration: BoxDecoration(
                        border: Border.all(color: AppColors.borderColor)),
                    child: Row(
                      children: [
                        Expanded(
                            child: TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  minimumSize: const Size(0, 50),
                                ),
                                child: AppText.text('Current Trip',
                                    fontSize: 16, fontWeight: FontWeight.bold),
                                onPressed: () {})),
                        const SizedBox(
                          height: 50,
                          child: VerticalDivider(
                              color: AppColors.borderColor,
                              thickness: 1,
                              width: 10),
                        ),
                        Expanded(
                            child: TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  minimumSize: const Size(0, 50),
                                ),
                                child: AppText.text('Requests',
                                    fontSize: 16, fontWeight: FontWeight.bold),
                                onPressed: () {})),
                      ],
                    ),
                  )),
              const SizedBox(height: 14),
              // jfjj
              Padding(
                  padding: const EdgeInsets.only(left: 24, right: 24),
                  child: AppButton.button(
                      backgroundColor: Color(0xFF415058),
                      widget: Row(
                        children: [
                          AppText.text('Messsage User',
                              fontWeight: FontWeight.w600, color: Colors.white),
                          const Spacer(),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                          )
                        ],
                      ),
                      onPressed: () {})),
              const SizedBox(height: 14),
              Container(
                  width: MediaQuery.of(context).size.width,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                  ).copyWith(bottom: 30),
                  padding: const EdgeInsets.symmetric(vertical: 16)
                      .copyWith(bottom: 0),
                  decoration: BoxDecoration(
                      border: Border.all(color: AppColors.borderColor)),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                              padding: const EdgeInsets.only(left: 16),
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
                                          '${state.activeRequest!.pickupData.address}',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600),
                                      AppText.text(
                                          '${state.activeRequest!.pickupData.subAddress}',
                                          color: Color(0xFFC9D2D7)),
                                      const SizedBox(height: 20),
                                      AppText.text(
                                          '${state.activeRequest!.dropoffData.address}',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600),
                                      AppText.text(
                                          '${state.activeRequest!.dropoffData.subAddress}',
                                          color: Color(0xFFC9D2D7)),
                                    ],
                                  )))
                        ],
                      ),
                      Divider(
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
                              image: AssetImage('assets/images/bike.png')),
                          Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              AppText.text(
                                  '${cSymbol(state.activeRequest!.currency)}${state.activeRequest!.price}',
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
                    ],
                  )),
              const SizedBox(height: 12),
              Opacity(
                opacity:
                    state.actionButtonStatus == ActionButtonStatus.initialized
                        ? 0.4
                        : 1,
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: AppButton.button(
                        widget: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (state.actionButtonStatus ==
                                ActionButtonStatus.initialized)
                              AppText.text('Trip in progress',
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            if (state.actionButtonStatus ==
                                ActionButtonStatus.goingToPickupLocation)
                              AppText.text('Arrived pickup location',
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            if (state.actionButtonStatus ==
                                ActionButtonStatus.arrivedPickupLocation)
                              AppText.text('Start delivery',
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            if (state.actionButtonStatus ==
                                ActionButtonStatus.outForDelivery)
                              AppText.text('Delivery completed',
                                  fontSize: 16, fontWeight: FontWeight.bold),
                          ],
                        ),
                        onPressed: () async {
                          final confirmed = await showCupertinoDialog(
                              barrierDismissible: true,
                              context: context,
                              builder: (_) {
                                return AlertDialog(
                                  backgroundColor: Colors.white,
                                  title: AppText.text('Confirmation',
                                      fontSize: 18,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600),
                                  content: AppText.text(
                                    'Please confirm your selection to proceed',
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

                          if (confirmed == true) {
                            print('confirmed');
                            if (state.actionButtonStatus ==
                                ActionButtonStatus.goingToPickupLocation) {
                              // ignore: use_build_context_synchronously
                              context
                                  .read<HomeBloc>()
                                  .add(ArrivedAtPickUpLocation());
                            }

                            if (state.actionButtonStatus ==
                                ActionButtonStatus.arrivedPickupLocation) {
                              // ignore: use_build_context_synchronously
                              context.read<HomeBloc>().add(StartDelivery());
                            }

                            if (state.actionButtonStatus ==
                                ActionButtonStatus.outForDelivery) {
                              // ignore: use_build_context_synchronously
                              context.read<HomeBloc>().add(RideCompleted());
                            }
                          }
                        })),
              )
            ],
          ));
    });
  }
}
