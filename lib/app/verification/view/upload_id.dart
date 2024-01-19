import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../utils/theme/theme.dart';
import '../bloc/verification_bloc.dart';

class UploadIDView extends StatefulWidget {
  final IdType idType;

  const UploadIDView({Key? key, required this.idType}) : super(key: key);

  @override
  State<UploadIDView> createState() => _UploadIDViewState();
}

class _UploadIDViewState extends State<UploadIDView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        elevation: 0,
        title: AppText.text('Upload ID',
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
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(4),
            decoration:
                BoxDecoration(border: Border.all(color: AppColors.grey)),
            child: Row(
              children: [
                Expanded(
                    child: AppButton.button(
                        backgroundColor: AppColors.grey,
                        widget: AppText.text('Front Page',
                            fontWeight: FontWeight.w600),
                        onPressed: () {})),
                Expanded(
                    child: AppButton.button(
                        backgroundColor: AppColors.secondary,
                        widget: AppText.text('Back Page',
                            color: AppColors.textMutedDark,
                            fontWeight: FontWeight.w600),
                        onPressed: () {})),
              ],
            ),
          ),
          const SizedBox(height: 68),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: DottedBorder(
                borderType: BorderType.RRect,
                color: AppColors.grey,
                strokeWidth: 2,
                radius: const Radius.circular(12),
                padding: const EdgeInsets.all(6),
                dashPattern: const [10],
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  child: TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                        fixedSize: Size(1.sw - 48, 1.sw - 48)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset('assets/svg/camera.svg'),
                        const SizedBox(height: 12),
                        AppText.text('Take a photo or upload')
                      ],
                    ),
                  ),
                ),
              )),
          const Spacer(),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AppButton.button(
                  backgroundColor: AppColors.input,
                  widget: Center(
                    child: AppText.text('Review Document',
                        color: Color.fromARGB(255, 101, 112, 119),
                        fontWeight: FontWeight.w600),
                  ),
                  onPressed: () {})),
          const SizedBox(height: 36),
        ],
      )),
    );
  }
}
