import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

import '../../../utils/theme/theme.dart';
import '../../communication/rider_conversation_view.dart';
import '../../rider_design/rider_ui.dart';
import '../bloc/support_bloc.dart';

class SupportView extends StatelessWidget {
  const SupportView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: RiderPalette.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [appBar(context), const SizedBox(height: 40), options()],
      ),
    );
  }

  Widget appBar(context) {
    return Container(
      margin: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 20, left: 24),
      width: double.maxFinite,
      child: AppText.text('Support',
          color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
    );
  }

  Widget options() {
    return BlocBuilder<SupportBloc, SupportState>(builder: (context, state) {
      return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: RiderGlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  TextButton(
                      // borderSide: BorderSide.none,
                      // backgroundColor: AppColors.secondary,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        shape: const RoundedRectangleBorder(),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SvgPicture.asset('assets/svg/support.svg'),
                              const SizedBox(width: 16),
                              AppText.text(
                                'Live Chat',
                              )
                            ],
                          ),
                          Icon(
                            Icons.keyboard_arrow_right_rounded,
                            color: Colors.white.withValues(alpha: 0.15),
                          )
                        ],
                      ),
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => RiderConversationView(
                                      chatId:
                                          'admin_rider_${FirebaseAuth.instance.currentUser?.uid ?? 'unknown'}_general',
                                      title: 'Circum Support',
                                      subtitle: 'Rider support conversation',
                                    )));
                      }),
                ],
              )));
    });
  }
}
