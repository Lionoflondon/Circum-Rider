import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bot_toast/bot_toast.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:circum_rider/utils/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../utils/app_state/app_state.dart';
import '../../authentication/bloc/auth_bloc.dart';
import 'bottom_sheets/bottom_sheets.dart';
import 'bottom_sheets/image_bs.dart';

class AccountDetails extends StatefulWidget {
  const AccountDetails({Key? key}) : super(key: key);

  @override
  State<AccountDetails> createState() => _AccountDetailsState();
}

class _AccountDetailsState extends State<AccountDetails> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          title: AppText.text('Profile',
              fontSize: 16, fontWeight: FontWeight.bold),
          centerTitle: true,
        ),
        backgroundColor: AppColors.secondary,
        body: SafeArea(
            child: BlocListener<AuthBloc, AuthState>(
                listener: (context, state) {
                  if (state.currentState == AppState.unauthenticated) {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  }
                  if (state.errorMessage != null &&
                      state.errorMessage!.isNotEmpty) {
                    BotToast.showSimpleNotification(
                        title: state.errorMessage!,
                        backgroundColor: AppColors.secondary);
                    context
                        .read<AuthBloc>()
                        .add(const SetErrorMessage(errorMessage: ''));
                  }
                },
                child: Column(children: [
                  header(),
                  firstName(),
                  Divider(
                      height: 10,
                      thickness: 1,
                      color: Colors.white.withOpacity(0.15)),
                  surname(),
                  Divider(
                      height: 10,
                      thickness: 1,
                      color: Colors.white.withOpacity(0.15)),
                  email(),
                  phone(),
                  const Spacer(),
                  logout(),
                  deleteAccount(),
                ]))));
  }

  Widget header() {
    return BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
      final hasPhoto = state.profilePhoto != null &&
          state.profilePhoto!.trim().isNotEmpty &&
          state.profilePhoto != 'null';
      return Stack(
        children: [
          Container(height: 190),
          Container(
            height: 80,
            color: AppColors.primary,
          ),
          Positioned(
              bottom: 0,
              // left: (MediaQuery.of(context).size.width / 2) - 28,
              child: GestureDetector(
                  onTap: () => _pickProfilePhoto(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(width: MediaQuery.of(context).size.width),
                      Container(
                          height: 56,
                          width: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(100),
                            color: AppColors.input,
                          ),
                          child: hasPhoto
                              ? CachedNetworkImage(
                                  imageUrl: state.profilePhoto!,
                                  imageBuilder: (context, imageProvider) =>
                                      Container(
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
                                  errorWidget: (context, url, error) =>
                                      Icon(Icons.error),
                                )
                              : Stack(
                                  children: [
                                    SvgPicture.asset(
                                      'assets/svg/account.svg',
                                      height: 200,
                                    ),
                                    Align(
                                      alignment: Alignment.center,
                                      child: SvgPicture.asset(
                                          'assets/svg/user.svg'),
                                    )
                                  ],
                                )),
                      const SizedBox(height: 6),
                      AppText.text(
                        'Add a profile photo to help customers recognise you.',
                        color: AppColors.textGrey,
                        fontSize: 12,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: () => _pickProfilePhoto(context),
                            icon: SvgPicture.asset('assets/svg/edit.svg',
                                height: 14),
                            label: Text(
                                hasPhoto ? 'Replace photo' : 'Upload photo'),
                          ),
                          if (hasPhoto)
                            TextButton(
                              onPressed: () => context
                                  .read<AuthBloc>()
                                  .add(const RemoveUserProfilePhoto()),
                              child: const Text('Remove photo'),
                            ),
                        ],
                      )
                    ],
                  )))
        ],
      );
    });
  }

  Future<void> _pickProfilePhoto(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    final imageSource = await showImageBottomSheet(context);
    XFile? image;
    if (imageSource == 'library') {
      image = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 72, maxWidth: 1024);
    }
    if (imageSource == 'camera') {
      image = await picker.pickImage(
          source: ImageSource.camera, imageQuality: 72, maxWidth: 1024);
    }
    if (image == null || !context.mounted) return;
    final sourceBytes = await image.readAsBytes();
    if (!context.mounted) return;
    final croppedBytes = await showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProfilePhotoCropDialog(imageBytes: sourceBytes),
    );
    if (croppedBytes == null || !context.mounted) return;
    context.read<AuthBloc>().add(UpdateUserProfilePhoto(
          imagePath: image.path,
          imageBytes: croppedBytes,
          mimeType: image.mimeType,
        ));
  }

  Widget firstName() {
    return BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
      return TextButton(
          // backgroundColor: AppColors.secondary,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText.text('First name',
                      color: AppColors.textGrey, fontSize: 12),
                  AppText.text(
                      state.username != null
                          ? '${state.username}'.trim().split(' ').first
                          : '',
                      fontSize: 16,
                      color: AppColors.textGrey)
                ],
              ),
              Icon(
                Icons.keyboard_arrow_right_rounded,
                color: Colors.white.withOpacity(0.15),
              )
            ],
          ),
          onPressed: () async {
            String? newName = await showEditBottomSheet(context,
                title: 'First name',
                val: state.username != null
                    ? '${state.username}'.trim().split(' ').first
                    : '');

            if (newName != null) {
              // ignore: use_build_context_synchronously
              context.read<AuthBloc>().add(UpdateFirstName(value: newName));
            }
          });
    });
  }

  Widget surname() {
    return BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
      return TextButton(
          // borderSide: BorderSide.none,
          // backgroundColor: AppColors.secondary,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText.text('Surname',
                      color: AppColors.textGrey, fontSize: 12),
                  AppText.text(
                      state.username != null
                          ? '${state.username}'.trim().split(' ').last
                          : '',
                      fontSize: 16,
                      color: AppColors.textGrey)
                ],
              ),
              Icon(
                Icons.keyboard_arrow_right_rounded,
                color: Colors.white.withOpacity(0.15),
              )
            ],
          ),
          onPressed: () async {
            String? newName = await showEditBottomSheet(context,
                title: 'Surname',
                val: state.username != null
                    ? '${state.username}'.trim().split(' ').last
                    : '');

            if (newName != null) {
              // ignore: use_build_context_synchronously
              context.read<AuthBloc>().add(UpdateLastName(value: newName));
            }
          });
    });
  }

  Widget email() {
    return BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
      return state.email != null && state.email != ''
          ? TextButton(
              // borderSide: BorderSide.none,
              // backgroundColor: AppColors.secondary,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText.text('Email address',
                          color: AppColors.textGrey, fontSize: 12),
                      AppText.text('${state.email}',
                          fontSize: 16, color: AppColors.textGrey)
                    ],
                  ),
                  Icon(
                    Icons.keyboard_arrow_right_rounded,
                    color: Colors.white.withOpacity(0.15),
                  )
                ],
              ),
              onPressed: () {})
          : Container();
    });
  }

  Widget phone() {
    return BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
      return state.phoneNumber != null
          ? TextButton(
              // borderSide: BorderSide.none,
              // backgroundColor: AppColors.secondary,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText.text('Phone number',
                          color: AppColors.textGrey, fontSize: 12),
                      AppText.text('${state.phoneNumber}',
                          fontSize: 16, color: AppColors.textGrey)
                    ],
                  ),
                  Icon(
                    Icons.keyboard_arrow_right_rounded,
                    color: Colors.white.withOpacity(0.15),
                  )
                ],
              ),
              onPressed: () {})
          : Container();
    });
  }

  Widget logout() {
    return BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
      return Padding(
          padding: const EdgeInsets.only(bottom: 0),
          child: TextButton(
            style: TextButton.styleFrom(
                backgroundColor: AppColors.danger.withOpacity(0.5),
                shape: RoundedRectangleBorder(),
                padding: const EdgeInsets.symmetric(vertical: 20)),
            onPressed: () {
              context.read<AuthBloc>().add(SignOut());
            },
            child: Center(
                child: AppText.text('Logout',
                    color: Colors.white, fontWeight: FontWeight.w500)),
          ));
    });
  }

  Widget deleteAccount() {
    return BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
      return Padding(
          padding: const EdgeInsets.only(bottom: 0),
          child: TextButton(
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20)),
            onPressed: () async {
              final deleteAccount = await deleteAccountBottomSheet(context);

              if (deleteAccount == true) {
                // ignore: use_build_context_synchronously
                // context.read<AuthBloc>().add(DeleteAccount());
                await launchUrl(
                    Uri.parse('https://circumuk.com/delete-account'));

                BotToast.showCustomNotification(
                    duration: const Duration(seconds: 120),
                    toastBuilder: (_) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 20),
                        margin: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: AppText.text(
                                  'Deletions are reviewed before approval. We will notify you of further actions.',
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700),
                            )
                          ],
                        ),
                      );
                    });
              }
            },
            child: Center(
                child: AppText.text('Delete Account', color: AppColors.danger)),
          ));
    });
  }

  deleteAccountBottomSheet(context) {
    return showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.secondary,
            ),
            height: 260,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AppText.text('You cannot reverse this action!',
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 24),
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                        onPressed: () async {
                          Navigator.pop(context, true);
                        },
                        child: const Row(
                          children: [
                            Icon(Icons.delete_forever, color: Colors.red),
                            SizedBox(width: 12),
                            Text('Delete account',
                                style: TextStyle(color: Colors.red))
                          ],
                        )),
                    const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Divider()),
                    TextButton(
                        onPressed: () async {
                          Navigator.pop(context, false);
                        },
                        child: const Row(children: [
                          Icon(
                            Icons.close,
                            color: Colors.white,
                          ),
                          SizedBox(width: 6),
                          Text('Cancel', style: TextStyle(color: Colors.white))
                        ])),
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 20)
                  ],
                ),
              ],
            ),
          );
        });
  }
}

class _ProfilePhotoCropDialog extends StatefulWidget {
  const _ProfilePhotoCropDialog({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<_ProfilePhotoCropDialog> createState() =>
      _ProfilePhotoCropDialogState();
}

class _ProfilePhotoCropDialogState extends State<_ProfilePhotoCropDialog> {
  final _cropKey = GlobalKey();
  final _transform = TransformationController();
  bool _saving = false;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Future<void> _useCrop() async {
    setState(() => _saving = true);
    try {
      final boundary =
          _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Crop preview is not ready.');
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted) return;
      Navigator.of(context).pop(bytes?.buffer.asUint8List());
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final cropSize = (size.width - 64).clamp(240.0, 320.0);
    return Dialog(
      backgroundColor: AppColors.secondary,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppText.text(
              'Crop profile photo',
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            const SizedBox(height: 8),
            AppText.text(
              'Pinch to zoom and drag to reposition.',
              color: AppColors.textGrey,
              fontSize: 12,
            ),
            const SizedBox(height: 16),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(cropSize / 2),
                child: RepaintBoundary(
                  key: _cropKey,
                  child: SizedBox.square(
                    dimension: cropSize,
                    child: InteractiveViewer(
                      transformationController: _transform,
                      minScale: 1,
                      maxScale: 4,
                      boundaryMargin: EdgeInsets.all(cropSize),
                      child: Image.memory(
                        widget.imageBytes,
                        width: cropSize,
                        height: cropSize,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _useCrop,
                    child: Text(_saving ? 'Preparing...' : 'Use photo'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
