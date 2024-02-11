import 'package:circum_rider/app/account/bloc/account_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../utils/theme/theme.dart';
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
        backgroundColor: AppColors.secondary,
        appBar: AppBar(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          elevation: 0,
          title: AppText.text('Earnings',
              fontSize: 16, fontWeight: FontWeight.bold),
          centerTitle: true,
        ),
        body: SafeArea(
            child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                width: double.maxFinite,
                decoration: const BoxDecoration(color: Color(0xFf1F292E)),
                child: Column(
                  children: [
                    AppText.text('Wallet Balance'),
                    const SizedBox(height: 4),
                    AppText.text(
                        state.earnings != null
                            ? '£${state.earnings!.accountBalance}'
                            : '--',
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                    const SizedBox(height: 16),
                    AppButton.button(
                        minimumSize: Size(0.5.sw, 40),
                        widget: AppText.text('Withdraw',
                            fontWeight: FontWeight.w600),
                        onPressed: () {
                          showWithdrawalBottomSheet(context);
                        })
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                  padding: const EdgeInsets.only(top: 20),
                  color: const Color(0xFF1F292E),
                  child: EarningsBarChartWidget(
                    weeklyEarnings: state.earnings?.weeklyEarnings,
                  )),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
                width: double.maxFinite,
                decoration: const BoxDecoration(color: Color(0xFf1F292E)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText.text('Overview',
                        fontSize: 20, fontWeight: FontWeight.w600),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppText.text('No of trips', fontSize: 16),
                        const SizedBox(height: 16),
                        AppText.text(
                            state.earnings != null
                                ? '${state.earnings!.totalTrips}'
                                : '',
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
                                ? '£${state.earnings!.totalAmountEarned}'
                                : '',
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
