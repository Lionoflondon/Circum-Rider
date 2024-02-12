import 'package:circum_rider/app/verification/bloc/verification_bloc.dart';
import 'package:circum_rider/app/verification/view/upload_id.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../utils/theme/theme.dart';

class VerificationView extends StatefulWidget {
  VerificationView({Key? key}) : super(key: key);

  @override
  State<VerificationView> createState() => _VerificationViewState();
}

class _VerificationViewState extends State<VerificationView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        elevation: 0,
        title: AppText.text('Verification',
            fontSize: 16, fontWeight: FontWeight.bold),
        centerTitle: true,
      ),
      body: SafeArea(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
              height: 1, thickness: 1, color: Colors.white.withOpacity(0.15)),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AppText.text('Choose a mode of verification',
                fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 36),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AppText.text('Personal identification',
                fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 19),
          TextButton(
              // borderSide: BorderSide.none,
              // backgroundColor: AppColors.secondary,
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SvgPicture.asset(
                        'assets/svg/unselected_radio.svg',
                        color: AppColors.borderColor,
                      ),
                      const SizedBox(width: 16),
                      AppText.text(
                        "Driver’s License",
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
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const UploadIDView(
                              idType: IdType.driversLicense,
                            )));
              }),
          Divider(
              height: 1, thickness: 1, color: Colors.white.withOpacity(0.15)),
          TextButton(
              // borderSide: BorderSide.none,
              // backgroundColor: AppColors.secondary,
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SvgPicture.asset(
                        'assets/svg/unselected_radio.svg',
                        color: AppColors.borderColor,
                      ),
                      const SizedBox(width: 16),
                      AppText.text(
                        "International Passport",
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
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const UploadIDView(
                              idType: IdType.internationalPassport,
                            )));
              }),
          Divider(
              height: 1, thickness: 1, color: Colors.white.withOpacity(0.15)),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AppText.text('Work Eligibility',
                fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 19),
          TextButton(
              // borderSide: BorderSide.none,
              // backgroundColor: AppColors.secondary,
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SvgPicture.asset(
                        'assets/svg/unselected_radio.svg',
                        color: AppColors.borderColor,
                      ),
                      const SizedBox(width: 16),
                      AppText.text(
                        "Right to work permit",
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
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const UploadIDView(
                              idType: IdType.workPermit,
                            )));
              }),
          Divider(
              height: 1, thickness: 1, color: Colors.white.withOpacity(0.15)),
        ],
      )),
    );
  }
}
