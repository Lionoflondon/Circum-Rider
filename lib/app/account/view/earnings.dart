import 'package:bot_toast/bot_toast.dart';
import 'package:circum_rider/app/account/bloc/account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../utils/theme/theme.dart';
import '../../rider_design/rider_ui.dart';
import 'bottom_sheets/withdrawal_bs.dart';
import 'earnings_chart.dart';

class EarningsView extends StatefulWidget {
  const EarningsView({Key? key}) : super(key: key);

  @override
  State<EarningsView> createState() => _EarningsViewState();
}

class _EarningsViewState extends State<EarningsView> {
  @override
  void initState() {
    super.initState();
    context.read<AccountBloc>().add(GetEarnings());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountBloc, AccountState>(builder: (context, state) {
      return Scaffold(
        backgroundColor: RiderPalette.background,
        appBar: AppBar(
          backgroundColor: RiderPalette.background,
          foregroundColor: Colors.white,
          elevation: 0,
          title: AppText.text('Earnings',
              fontSize: 18, fontWeight: FontWeight.bold),
          centerTitle: true,
        ),
        body: SafeArea(
            child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              RiderGlassCard(
                child: Column(
                  children: [
                    const RiderStatusBadge('CASH EARNINGS',
                        color: RiderPalette.green),
                    const SizedBox(height: 14),
                    RiderMoney(
                      state.earnings != null
                          ? '£${state.earnings!.accountBalance.toStringAsFixed(2)}'
                          : '—',
                      label: 'Available balance',
                      size: 38,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton.button(
                          minimumSize: Size(0.5.sw, 48),
                          widget: AppText.text('Request withdrawal',
                              fontWeight: FontWeight.w600),
                          onPressed: () async {
                            final withdReq =
                                await showWithdrawalBottomSheet(context);

                            if (withdReq == 'req-sent') {
                              BotToast.showCustomNotification(
                                  duration: const Duration(seconds: 8),
                                  toastBuilder: (_) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      margin: const EdgeInsets.all(20),
                                      decoration: const BoxDecoration(
                                        color: Color.fromARGB(255, 50, 152, 53),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.check_circle,
                                              color: Colors.white),
                                          const SizedBox(width: 4),
                                          AppText.text(
                                              'Request sent successfully',
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600),
                                        ],
                                      ),
                                    );
                                  });
                            }
                          }),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                        'Roth is separate and is never withdrawable cash.',
                        style:
                            TextStyle(color: RiderPalette.muted, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (state.status == AccountStatus.loading)
                const RiderGlassCard(
                    child: Center(child: CircularProgressIndicator()))
              else if (state.earnings != null)
                RiderGlassCard(
                  padding: const EdgeInsets.only(top: 20),
                  child: EarningsBarChartWidget(
                      weeklyEarnings: state.earnings!.weeklyEarnings),
                )
              else
                const RiderGlassCard(
                  child: Column(children: [
                    Icon(Icons.payments_outlined,
                        color: RiderPalette.muted, size: 32),
                    SizedBox(height: 12),
                    Text('Earnings are unavailable',
                        style: TextStyle(
                            color: RiderPalette.paper,
                            fontWeight: FontWeight.w700)),
                    SizedBox(height: 6),
                    Text('Pull to refresh or try again when you are online.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: RiderPalette.muted)),
                  ]),
                ),
              const SizedBox(height: 16),
              RiderGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const RiderSectionTitle('Overview'),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppText.text('No of trips', fontSize: 16),
                        const SizedBox(height: 16),
                        AppText.text(
                            state.earnings != null
                                ? '${state.earnings!.totalTrips}'
                                : '—',
                            fontSize: 16),
                      ],
                    ),
                    // const SizedBox(height: 16),
                    // Row(
                    //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //   children: [
                    //     AppText.text('Cancelled Trips', fontSize: 16),
                    //     const SizedBox(height: 16),
                    //     AppText.text('0', fontSize: 16),
                    //   ],
                    // ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppText.text('Earnings', fontSize: 16),
                        const SizedBox(height: 16),
                        AppText.text(
                            state.earnings != null
                                ? '£${state.earnings!.totalAmountEarned.toStringAsFixed(2)}'
                                : '—',
                            fontSize: 16),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
        )),
      );
    });
  }
}
