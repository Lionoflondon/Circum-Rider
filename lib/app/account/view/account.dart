import 'package:cached_network_image/cached_network_image.dart';
import 'package:circum_rider/app/authentication/bloc/auth_bloc.dart';
import 'package:circum_rider/app/verification/view/verification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../utils/theme/theme.dart';
import '../../rider_design/rider_ui.dart';
import '../../schedule/rider_schedule_view.dart';
import '../../notifications/rider_notifications_view.dart';
import '../bloc/account_bloc.dart';
import 'account_details.dart';
import 'earnings.dart';

class AccountView extends StatelessWidget {
  const AccountView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: RiderPalette.background,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            appBar(context),
            const SizedBox(height: 18),
            const _RiderProfileSummary(),
            const SizedBox(height: 24),
            options(),
          ]),
        ),
      ),
    );
  }

  Widget appBar(context) {
    return BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
      return Container(
          width: double.maxFinite,
          child: Row(
            children: [
              Container(
                height: 32,
                width: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  color: AppColors.input,
                ),
                child: state.profilePhoto != null && state.profilePhoto != ''
                    ? CachedNetworkImage(
                        imageUrl: state.profilePhoto!,
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
              const SizedBox(width: 16),
              AppText.text(
                  state.username != null
                      ? '${state.username}'.trim().split(' ').first
                      : '',
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold),
            ],
          ));
    });
  }

  Widget options() {
    return BlocBuilder<AccountBloc, AccountState>(builder: (context, state) {
      return RiderGlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              AppButton.button(
                  // borderSide: BorderSide.none,
                  backgroundColor: AppColors.secondary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  widget: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          SvgPicture.asset('assets/svg/profile.svg'),
                          const SizedBox(width: 16),
                          AppText.text(
                            'Profile',
                          )
                        ],
                      ),
                      Icon(
                        Icons.keyboard_arrow_right_rounded,
                        color: Colors.white.withOpacity(0.15),
                      )
                    ],
                  ),
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AccountDetails()));
                  }),
              Divider(
                  height: 1,
                  thickness: 1,
                  color:
                      const Color.fromRGBO(255, 255, 255, 1).withOpacity(0.15)),
              AppButton.button(
                  // borderSide: BorderSide.none,
                  backgroundColor: AppColors.secondary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  widget: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          SvgPicture.asset('assets/svg/earnings.svg'),
                          const SizedBox(width: 16),
                          AppText.text(
                            'Earnings',
                          )
                        ],
                      ),
                      Icon(
                        Icons.keyboard_arrow_right_rounded,
                        color: Colors.white.withOpacity(0.15),
                      )
                    ],
                  ),
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EarningsView()));
                  }),
              Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.white.withOpacity(0.15)),
              _nativeOption(
                context,
                icon: Icons.calendar_month_outlined,
                label: 'Schedule',
                page: const RiderScheduleView(),
              ),
              Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.white.withOpacity(0.15)),
              _nativeOption(
                context,
                icon: Icons.notifications_none_rounded,
                label: 'Notifications',
                page: const RiderNotificationsView(),
              ),
              Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.white.withOpacity(0.15)),
              AppButton.button(
                  // borderSide: BorderSide.none,
                  backgroundColor: AppColors.secondary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  widget: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          SvgPicture.asset('assets/svg/share.svg'),
                          const SizedBox(width: 16),
                          AppText.text(
                            'Share',
                          )
                        ],
                      ),
                      Icon(
                        Icons.keyboard_arrow_right_rounded,
                        color: Colors.white.withOpacity(0.15),
                      )
                    ],
                  ),
                  onPressed: () async {
                    await Share.share(
                        'Get anything to anyone, instantly. https://circumuk.com',
                        subject: 'Take a look at Circum');
                  }),
              Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.white.withOpacity(0.15)),
              AppButton.button(
                  // borderSide: BorderSide.none,
                  backgroundColor: AppColors.secondary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  widget: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          SvgPicture.asset('assets/svg/legal.svg'),
                          const SizedBox(width: 16),
                          AppText.text(
                            'Legal',
                          )
                        ],
                      ),
                      Icon(
                        Icons.keyboard_arrow_right_rounded,
                        color: Colors.white.withOpacity(0.15),
                      )
                    ],
                  ),
                  onPressed: () async {
                    await launchUrl(Uri.parse('https://circumuk.com/terms'));
                  }),
              Divider(
                  height: 1,
                  thickness: 1,
                  color:
                      const Color.fromRGBO(255, 255, 255, 1).withOpacity(0.15)),
              AppButton.button(
                  // borderSide: BorderSide.none,
                  backgroundColor: AppColors.secondary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  widget: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          SvgPicture.asset('assets/svg/legal.svg'),
                          const SizedBox(width: 16),
                          AppText.text(
                            'Verification',
                          )
                        ],
                      ),
                      Icon(
                        Icons.keyboard_arrow_right_rounded,
                        color: Colors.white.withOpacity(0.15),
                      )
                    ],
                  ),
                  onPressed: () async {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => VerificationView()));
                  }),
            ],
          ));
    });
  }

  Widget _nativeOption(BuildContext context,
      {required IconData icon, required String label, required Widget page}) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: const RoundedRectangleBorder(),
      ),
      onPressed: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      child: Row(children: [
        Icon(icon, color: RiderPalette.muted, size: 22),
        const SizedBox(width: 16),
        Expanded(
            child:
                Text(label, style: const TextStyle(color: RiderPalette.paper))),
        const Icon(Icons.keyboard_arrow_right_rounded,
            color: Color(0x4DFFFFFF)),
      ]),
    );
  }
}

class _RiderProfileSummary extends StatelessWidget {
  const _RiderProfileSummary();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('riders').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final rider = snapshot.data?.data() ?? const <String, dynamic>{};
        final rank = '${rider['riderRank'] ?? rider['rank'] ?? 'Agent'}';
        final trust = rider['trustPoints'];
        final rating = rider['averageRating'] ?? rider['rating'];
        final deliveries = rider['completedDeliveries'] ?? rider['totalTrips'];
        final vehicle = rider['vehicle'] is Map
            ? Map<String, dynamic>.from(rider['vehicle'] as Map)
            : const <String, dynamic>{};
        final vehicleLabel =
            '${rider['vehicleType'] ?? vehicle['type'] ?? ''}'.trim();
        return RiderGlassCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              RiderStatusBadge(rank.toUpperCase(), color: _rankColor(rank)),
              const Spacer(),
              if (rating is num)
                Text('★ ${rating.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: RiderPalette.amber,
                        fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                  child: _ProfileStat(
                      value: trust is num ? trust.toStringAsFixed(0) : '—',
                      label: 'Trust points')),
              Expanded(
                  child: _ProfileStat(
                      value: deliveries is num ? '$deliveries' : '—',
                      label: 'Deliveries')),
            ]),
            if (vehicleLabel.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(children: [
                const Icon(Icons.two_wheeler_rounded,
                    color: RiderPalette.muted, size: 19),
                const SizedBox(width: 9),
                Expanded(
                    child: Text(vehicleLabel,
                        style: const TextStyle(color: RiderPalette.muted))),
              ]),
            ],
          ]),
        );
      },
    );
  }

  static Color _rankColor(String rank) => switch (rank.toLowerCase()) {
        'sentinel' => RiderPalette.blue,
        'warden' => RiderPalette.green,
        'knight' => RiderPalette.purple,
        'veteran' => RiderPalette.amber,
        _ => RiderPalette.muted,
      };
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: const TextStyle(
                color: RiderPalette.paper,
                fontSize: 22,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(color: RiderPalette.muted, fontSize: 12)),
      ]);
}
