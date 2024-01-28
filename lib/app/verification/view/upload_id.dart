import 'dart:io';

import 'package:circum_rider/app/authentication/bloc/auth_bloc.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';

import '../../../utils/theme/theme.dart';
import '../bloc/verification_bloc.dart';
import '../bottom_sheets/image_bs.dart';

class UploadIDView extends StatefulWidget {
  final IdType idType;

  const UploadIDView({Key? key, required this.idType}) : super(key: key);

  @override
  State<UploadIDView> createState() => _UploadIDViewState();
}

class _UploadIDViewState extends State<UploadIDView> {
  String? frontPageImagePath;
  String? backPageImagePath;
  String? workPermitImagePath;
  String? activeImage;
  int activePage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        elevation: 0,
        title: AppText.text(
            widget.idType == IdType.workPermit
                ? 'Upload right to work permit'
                : 'Upload ID',
            fontSize: 16,
            fontWeight: FontWeight.bold),
        centerTitle: true,
      ),
      body: SafeArea(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
              height: 1, thickness: 1, color: Colors.white.withOpacity(0.15)),
          if (widget.idType != IdType.workPermit)
            Container(
              margin:
                  const EdgeInsets.symmetric(horizontal: 24).copyWith(top: 16),
              padding: const EdgeInsets.all(4),
              decoration:
                  BoxDecoration(border: Border.all(color: AppColors.grey)),
              child: Row(
                children: [
                  Expanded(
                      child: GestureDetector(
                          onTap: () {
                            setState(() {
                              activeImage = frontPageImagePath;
                              activePage = 0;
                            });
                          },
                          child: Container(
                              color: activePage == 0
                                  ? AppColors.grey
                                  : AppColors.secondary,
                              height: 50,
                              child: Center(
                                child: AppText.text('Front Page',
                                    fontWeight: FontWeight.w600),
                              )))),
                  Expanded(
                      child: GestureDetector(
                          onTap: () {
                            setState(() {
                              activeImage = backPageImagePath;
                              activePage = 1;
                            });
                          },
                          child: Container(
                              color: activePage == 0
                                  ? AppColors.secondary
                                  : AppColors.grey,
                              height: 50,
                              child: Center(
                                child: AppText.text('Back Page',
                                    fontWeight: FontWeight.w600),
                              )))),
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
                    onPressed: () async {
                      if (activeImage == null) {
                        final ImagePicker picker = ImagePicker();
                        final imageSource = await showImageBottomSheet(context);
                        if (imageSource == 'library') {
                          XFile? image = await picker.pickImage(
                              source: ImageSource.gallery, imageQuality: 50);
                          if (image != null) {
                            if (widget.idType != IdType.workPermit) {
                              if (activePage == 0) {
                                setState(() {
                                  frontPageImagePath = image.path;
                                  activeImage = frontPageImagePath;
                                });
                                // await Future.delayed(Duration(seconds: 2));
                                // setState(() {
                                //   activeImage = null;
                                //   activePage = 1;
                                // });
                              } else {
                                setState(() {
                                  backPageImagePath = image.path;
                                  activeImage = backPageImagePath;
                                });
                              }
                            } else {
                              setState(() {
                                workPermitImagePath = image.path;
                                activeImage = workPermitImagePath;
                              });
                            }
                          }
                        }
                        if (imageSource == 'camera') {
                          XFile? image = await picker.pickImage(
                              source: ImageSource.camera, imageQuality: 50);
                          if (image != null) {
                            if (widget.idType != IdType.workPermit) {
                              if (frontPageImagePath == null) {
                                setState(() {
                                  frontPageImagePath = image.path;
                                  activeImage = frontPageImagePath;
                                });
                                await Future.delayed(Duration(seconds: 2));
                                setState(() {
                                  activeImage = null;
                                });
                              } else {
                                setState(() {
                                  backPageImagePath = image.path;
                                  activeImage = backPageImagePath;
                                });
                              }
                            } else {
                              setState(() {
                                workPermitImagePath = image.path;
                                activeImage = workPermitImagePath;
                              });
                            }
                          }
                        }
                      }
                    },
                    style: TextButton.styleFrom(
                        fixedSize: Size(1.sw - 48, 1.sw - 48)),
                    child: activeImage != null
                        ? Container(
                            height: double.maxFinite,
                            width: double.maxFinite,
                            decoration: BoxDecoration(
                                image: DecorationImage(
                                    image: FileImage(File(activeImage!)),
                                    fit: BoxFit.contain)),
                          )
                        : Column(
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
                  backgroundColor:
                      frontPageImagePath != null && backPageImagePath != null
                          ? null
                          : AppColors.input,
                  widget: Center(
                    child: AppText.text('Submit Document For Review',
                        color: frontPageImagePath != null &&
                                backPageImagePath != null
                            ? Colors.white
                            : const Color.fromARGB(255, 101, 112, 119),
                        fontWeight: FontWeight.w600),
                  ),
                  onPressed: () {
                    if (widget.idType == IdType.driversLicense &&
                        frontPageImagePath != null &&
                        backPageImagePath != null) {
                      context.read<AuthBloc>().add(SubmitVerificationDocuments(
                          frontImagePath: frontPageImagePath!,
                          backImagePath: backPageImagePath!,
                          idType: 'drivers license'));
                    }

                    if (widget.idType == IdType.internationalPassport &&
                        frontPageImagePath != null &&
                        backPageImagePath != null) {
                      context.read<AuthBloc>().add(SubmitVerificationDocuments(
                          frontImagePath: frontPageImagePath!,
                          backImagePath: backPageImagePath!,
                          idType: 'international passport'));
                    }

                    if (widget.idType == IdType.workPermit &&
                        workPermitImagePath != null) {
                      context.read<AuthBloc>().add(SubmitVerificationDocuments(
                          workPermitPath: workPermitImagePath!,
                          idType: 'work permit'));
                    }
                  })),
          const SizedBox(height: 36),
        ],
      )),
    );
  }
}
