import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:circum_rider/app/authentication/bloc/auth_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../utils/theme/theme.dart';
import '../bloc/verification_bloc.dart';
import '../rider_document_selection.dart';

class UploadIDView extends StatefulWidget {
  const UploadIDView({super.key, required this.idType});

  final IdType idType;

  @override
  State<UploadIDView> createState() => _UploadIDViewState();
}

class _UploadIDViewState extends State<UploadIDView> {
  final _imagePicker = ImagePicker();
  final String _idempotencyKey = const Uuid().v4();
  RiderDocumentDraft _draft = const RiderDocumentDraft();
  RiderDocumentSide _activeSide = RiderDocumentSide.front;
  String? _message;

  bool get _requiresFrontAndBack => widget.idType == IdType.driversLicense;

  RiderDocumentSide get _selectionSide =>
      _requiresFrontAndBack ? _activeSide : RiderDocumentSide.primary;

  String get _title => switch (widget.idType) {
        IdType.workPermit => 'Upload right to work evidence',
        IdType.vehicleRegistration => 'Upload vehicle document',
        IdType.insurance => 'Upload insurance document',
        _ => 'Upload identity document',
      };

  String get _documentType => switch (widget.idType) {
        IdType.driversLicense => 'drivers license',
        IdType.internationalPassport => 'international passport',
        IdType.workPermit => 'work permit',
        IdType.vehicleRegistration => 'vehicle registration',
        IdType.insurance => 'insurance',
      };

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
        allowMultiple: false,
        withData: false,
      );
      if (result == null) return;
      final picked = result.files.single;
      final path = picked.path;
      if (path == null) {
        _showMessage('The selected file could not be opened. Choose it again.');
        return;
      }
      await _acceptSelection(path, fileName: picked.name);
    } on RiderDocumentSelectionException catch (error) {
      _showMessage(error.message);
    } on PlatformException {
      _showMessage('The document picker could not open. Please try again.');
    } catch (_) {
      _showMessage('The document could not be selected. Please try again.');
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (image == null) return;
      await _acceptSelection(image.path, fileName: image.name);
    } on RiderDocumentSelectionException catch (error) {
      _showMessage(error.message);
    } on PlatformException catch (error) {
      final denied = error.code.toLowerCase().contains('denied') ||
          error.code.toLowerCase().contains('permission');
      _showMessage(denied
          ? source == ImageSource.camera
              ? 'Camera access is unavailable. Allow camera access in Settings or upload a document instead.'
              : 'Photo access is unavailable. Allow photo access in Settings or upload a document instead.'
          : source == ImageSource.camera
              ? 'The camera is unavailable. Upload an existing document instead.'
              : 'The photo library could not open. Please try again.');
    } catch (_) {
      _showMessage('The photo could not be selected. Please try again.');
    }
  }

  Future<void> _acceptSelection(String path, {String? fileName}) async {
    final selection = await RiderDocumentSelection.fromPath(
      path,
      fileName: fileName,
    );
    if (!mounted) return;
    setState(() {
      _draft = _draft.select(_selectionSide, selection);
      _message = null;
    });
  }

  Future<void> _choosePhotoSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Photos'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source != null && mounted) await _pickPhoto(source);
  }

  void _showMessage(String message) {
    if (mounted) setState(() => _message = message);
  }

  void _submit(AuthState state) {
    if (state.verificationUploadStatus == VerificationUploadStatus.loading ||
        !_draft.complete(requiresFrontAndBack: _requiresFrontAndBack)) {
      return;
    }
    context.read<AuthBloc>().add(
          SubmitVerificationDocuments(
            idType: _documentType,
            idempotencyKey: _idempotencyKey,
            frontImagePath: _draft.front?.path,
            backImagePath: _draft.back?.path,
            workPermitPath: _draft.primary?.path,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous.verificationUploadStatus != current.verificationUploadStatus,
      listener: (context, state) {
        if (state.verificationUploadStatus ==
            VerificationUploadStatus.uploaded) {
          context.read<AuthBloc>().add(
                const SetVerificationUploadStatus(
                  status: VerificationUploadStatus.initialized,
                ),
              );
          BotToast.showSimpleNotification(
            title: 'Verification submitted for review.',
            backgroundColor: AppColors.success,
          );
          Navigator.pop(context);
        } else if (state.verificationUploadStatus ==
            VerificationUploadStatus.failure) {
          _showMessage(
            state.errorMessage?.trim().isNotEmpty == true
                ? state.errorMessage!
                : 'The document could not be submitted. Please try again.',
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.secondary,
        appBar: AppBar(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          title: Text(_title),
        ),
        body: SafeArea(
          child: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              final uploading = state.verificationUploadStatus ==
                  VerificationUploadStatus.loading;
              final complete = _draft.complete(
                requiresFrontAndBack: _requiresFrontAndBack,
              );
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Text(
                    'Upload JPG, PNG, WEBP or PDF files up to 8 MiB. Your submission is sent securely for review.',
                    style: TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  if (_requiresFrontAndBack) ...[
                    const SizedBox(height: 20),
                    SegmentedButton<RiderDocumentSide>(
                      segments: [
                        ButtonSegment(
                          value: RiderDocumentSide.front,
                          label: Text(
                            _draft.front == null ? 'Front' : 'Front selected',
                          ),
                        ),
                        ButtonSegment(
                          value: RiderDocumentSide.back,
                          label: Text(
                            _draft.back == null ? 'Back' : 'Back selected',
                          ),
                        ),
                      ],
                      selected: {_activeSide},
                      onSelectionChanged: uploading
                          ? null
                          : (selection) =>
                              setState(() => _activeSide = selection.single),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _DocumentPreview(selection: _draft.forSide(_selectionSide)),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: uploading ? null : _pickDocument,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Upload Document'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: uploading ? null : _choosePhotoSource,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Photo / Camera'),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _message!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed:
                        complete && !uploading ? () => _submit(state) : null,
                    child: Text(uploading
                        ? 'Submitting...'
                        : 'Submit Document For Review'),
                  ),
                  if (uploading) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DocumentPreview extends StatelessWidget {
  const _DocumentPreview({required this.selection});

  final RiderDocumentSelection? selection;

  @override
  Widget build(BuildContext context) {
    final selected = selection;
    return Container(
      height: 260,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: selected == null
          ? const Center(
              child: Text(
                'No document selected',
                style: TextStyle(color: Colors.white60),
              ),
            )
          : selected.isPdf
              ? _SelectedFileLabel(
                  icon: Icons.picture_as_pdf_outlined,
                  fileName: selected.fileName,
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(selected.path),
                      key: ValueKey(selected.path),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _SelectedFileLabel(
                        icon: Icons.broken_image_outlined,
                        fileName: selected.fileName,
                      ),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: _FileNameChip(fileName: selected.fileName),
                    ),
                  ],
                ),
    );
  }
}

class _SelectedFileLabel extends StatelessWidget {
  const _SelectedFileLabel({required this.icon, required this.fileName});

  final IconData icon;
  final String fileName;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: Colors.white70),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                fileName,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
}

class _FileNameChip extends StatelessWidget {
  const _FileNameChip({required this.fileName});

  final String fileName;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(
            fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
}
