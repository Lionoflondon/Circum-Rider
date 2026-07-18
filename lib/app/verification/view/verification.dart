import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../onboarding/rider_application_centre.dart';
import '../../rider_account/rider_account_state.dart';
import '../../rider_design/rider_ui.dart';
import '../../rider_shell/rider_profile_details_view.dart';
import '../bloc/verification_bloc.dart';
import 'upload_id.dart';

class VerificationView extends StatelessWidget {
  const VerificationView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: RiderPalette.background,
        body: RiderEmptyState(
          icon: Icons.lock_outline,
          title: 'Sign in required',
          message: 'Sign in to view your verification documents.',
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('riders')
          .doc(user.uid)
          .snapshots(),
      builder: (context, riderSnapshot) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('riderApplications')
              .doc(user.uid)
              .snapshots(),
          builder: (context, applicationSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('riderDocuments')
                  .where('uid', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, documentsSnapshot) {
                if (riderSnapshot.hasError ||
                    applicationSnapshot.hasError ||
                    documentsSnapshot.hasError) {
                  return const _VerificationError();
                }
                if (!riderSnapshot.hasData ||
                    !applicationSnapshot.hasData ||
                    !documentsSnapshot.hasData) {
                  return const _VerificationLoading();
                }
                final state = _VerificationState.fromBackend(
                  rider: riderSnapshot.data?.data() ?? const {},
                  application: applicationSnapshot.data?.data() ?? const {},
                  documents: documentsSnapshot.data!.docs
                      .map((doc) => {
                            ...doc.data(),
                            'documentId': doc.id,
                          })
                      .toList(),
                  profilePhotoRoute: RiderPersonalDetailsView(user: user),
                );
                return _VerificationCentre(state: state);
              },
            );
          },
        );
      },
    );
  }
}

class _VerificationCentre extends StatelessWidget {
  const _VerificationCentre({required this.state});

  final _VerificationState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RiderPalette.background,
      appBar: AppBar(
        title: const Text('Verification Centre'),
        backgroundColor: RiderPalette.background,
        foregroundColor: RiderPalette.paper,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
        children: [
          _VerificationHero(state: state),
          const SizedBox(height: 18),
          for (var i = 0; i < state.cards.length; i++) ...[
            _VerificationCard(
              card: state.cards[i],
              index: i,
              onTap: () => _openDetail(context, state.cards[i]),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 6),
          _VerificationSummary(state: state),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => _openPrimary(context, state),
            style: FilledButton.styleFrom(
              backgroundColor: RiderPalette.blue,
              foregroundColor: RiderPalette.paper,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(state.primaryActionLabel),
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context, _VerificationCardData card) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _VerificationDetailPage(card: card)),
    );
  }

  void _openPrimary(BuildContext context, _VerificationState state) {
    final next = state.cards.firstWhere(
      (card) => card.status.needsAction,
      orElse: () => state.cards.first,
    );
    _openDetail(context, next);
  }
}

class _VerificationHero extends StatelessWidget {
  const _VerificationHero({required this.state});

  final _VerificationState state;

  @override
  Widget build(BuildContext context) {
    return RiderGlassSurface(
      radius: 30,
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            tween: Tween(begin: 0, end: state.progress),
            builder: (context, value, _) => Semantics(
              label: 'Verification progress ${(value * 100).round()} percent',
              child: CustomPaint(
                painter: _ProgressRingPainter(value, state.eligibilityColor),
                child: SizedBox(
                  width: 94,
                  height: 94,
                  child: Center(
                    child: Text(
                      '${(value * 100).round()}%',
                      style: const TextStyle(
                        color: RiderPalette.paper,
                        fontFamily: RiderTypography.mono,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Verification Centre',
                  style: TextStyle(
                    color: RiderPalette.paper,
                    fontFamily: RiderTypography.heading,
                    fontSize: 29,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Complete your verification to unlock deliveries.',
                  style: TextStyle(color: RiderPalette.muted, height: 1.35),
                ),
                const SizedBox(height: 12),
                Text(
                  '${state.completedCount} of ${state.totalCount} verifications completed',
                  style: const TextStyle(
                    color: RiderPalette.paper,
                    fontFamily: RiderTypography.mono,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                _StatusBadge(
                  label: state.eligibilityLabel,
                  color: state.eligibilityColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({
    required this.card,
    required this.index,
    required this.onTap,
  });

  final _VerificationCardData card;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final content = Semantics(
      button: true,
      label: '${card.title}. ${card.status.label}. ${card.subtitle}',
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: RiderGlassSurface(
          radius: 24,
          borderColor: card.status.color.withValues(
            alpha: card.status.isVerified ? .34 : .14,
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: card.status.color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: card.status.color.withValues(alpha: .24),
                  ),
                ),
                child: Icon(card.icon, color: card.status.color, size: 25),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      style: const TextStyle(
                        color: RiderPalette.paper,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      card.subtitle,
                      style: const TextStyle(
                        color: RiderPalette.muted,
                        height: 1.35,
                      ),
                    ),
                    if (card.detailLine.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        card.detailLine,
                        style: const TextStyle(
                          color: RiderPalette.paper,
                          fontFamily: RiderTypography.mono,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _StatusBadge(
                      label: card.status.label,
                      color: card.status.color,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: .45),
              ),
            ],
          ),
        ),
      ),
    );
    if (reduceMotion) return content;
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 220 + index * 50),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
      child: content,
    );
  }
}

class _VerificationSummary extends StatelessWidget {
  const _VerificationSummary({required this.state});

  final _VerificationState state;

  @override
  Widget build(BuildContext context) {
    return RiderGlassSurface(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verification Summary',
            style: TextStyle(
              color: RiderPalette.paper,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          for (final card in state.cards)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      card.summaryLabel,
                      style: const TextStyle(color: RiderPalette.paper),
                    ),
                  ),
                  _StatusBadge(
                    label: card.status.summaryLabel,
                    color: card.status.color,
                    compact: true,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _VerificationDetailPage extends StatelessWidget {
  const _VerificationDetailPage({required this.card});

  final _VerificationCardData card;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final body = ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
      children: [
        RiderGlassSurface(
          radius: 28,
          borderColor: card.status.color.withValues(alpha: .18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(card.icon, color: card.status.color, size: 54),
              const SizedBox(height: 14),
              Text(
                card.title,
                style: const TextStyle(
                  color: RiderPalette.paper,
                  fontFamily: RiderTypography.heading,
                  fontSize: 32,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                card.explanation,
                style: const TextStyle(color: RiderPalette.muted, height: 1.45),
              ),
              const SizedBox(height: 14),
              _StatusBadge(label: card.status.label, color: card.status.color),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _DetailInfoCard(card: card),
        const SizedBox(height: 14),
        _SubmissionCard(card: card),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openUpload(context, card),
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(card.status.hasSubmission ? 'Resubmit' : 'Upload'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _openCamera(context, card),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Camera'),
                style: FilledButton.styleFrom(
                  backgroundColor: RiderPalette.blue,
                  foregroundColor: RiderPalette.paper,
                ),
              ),
            ),
          ],
        ),
      ],
    );
    return Scaffold(
      backgroundColor: RiderPalette.background,
      appBar: AppBar(
        title: Text(card.title),
        backgroundColor: RiderPalette.background,
        foregroundColor: RiderPalette.paper,
      ),
      body: card.status.isRejected && !reduceMotion
          ? TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 380),
              curve: Curves.elasticOut,
              tween: Tween(begin: 1, end: 0),
              builder: (context, value, child) => Transform.translate(
                offset: Offset(math.sin(value * math.pi * 8) * 4, 0),
                child: child,
              ),
              child: body,
            )
          : body,
    );
  }

  void _openUpload(BuildContext context, _VerificationCardData card) {
    final route = card.uploadRoute;
    if (route != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => route));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RiderApplicationCentre()),
    );
  }

  void _openCamera(BuildContext context, _VerificationCardData card) {
    _openUpload(context, card);
  }
}

class _DetailInfoCard extends StatelessWidget {
  const _DetailInfoCard({required this.card});

  final _VerificationCardData card;

  @override
  Widget build(BuildContext context) {
    return RiderGlassSurface(
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(label: 'Accepted formats', value: card.acceptedFormats),
          _DetailRow(label: 'Maximum file size', value: card.maxFileSize),
          _DetailRow(label: 'Estimated review', value: card.reviewTime),
          if (card.expiryText.isNotEmpty)
            _DetailRow(label: 'Expiry', value: card.expiryText),
          if (card.reviewerComment.isNotEmpty)
            _DetailRow(label: 'Reviewer comments', value: card.reviewerComment),
        ],
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({required this.card});

  final _VerificationCardData card;

  @override
  Widget build(BuildContext context) {
    return RiderGlassSurface(
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current submission',
            style: TextStyle(
              color: RiderPalette.paper,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (!card.status.hasSubmission)
            const Text(
              'No document has been submitted yet.',
              style: TextStyle(color: RiderPalette.muted, height: 1.4),
            )
          else ...[
            _DetailRow(label: 'File', value: card.fileName),
            _DetailRow(label: 'Submission date', value: card.submissionDate),
            _DetailRow(label: 'Review history', value: card.reviewHistory),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(
                color: RiderPalette.muted,
                fontFamily: RiderTypography.mono,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not available' : value,
              style: const TextStyle(color: RiderPalette.paper, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    this.compact = false,
  });

  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect.deflate(8),
      -math.pi / 2,
      math.pi * 2,
      false,
      stroke..color = Colors.white.withValues(alpha: .08),
    );
    canvas.drawArc(
      rect.deflate(8),
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0, 1),
      false,
      stroke..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _VerificationState {
  const _VerificationState({
    required this.cards,
    required this.eligibilityLabel,
    required this.eligibilityColor,
  });

  final List<_VerificationCardData> cards;
  final String eligibilityLabel;
  final Color eligibilityColor;

  int get totalCount => cards.length;
  int get completedCount =>
      cards.where((card) => card.status.isVerified).length;
  double get progress => totalCount == 0 ? 0 : completedCount / totalCount;

  String get primaryActionLabel => cards.any((card) => card.status.needsAction)
      ? 'Continue Verification'
      : 'View Submitted Documents';

  static _VerificationState fromBackend({
    required Map<String, dynamic> rider,
    required Map<String, dynamic> application,
    required List<Map<String, dynamic>> documents,
    required Widget profilePhotoRoute,
  }) {
    final docs = documents.where((doc) => doc['active'] != false).toList();
    final byType = <String, Map<String, dynamic>>{};
    for (final doc in docs) {
      final type =
          _normalise(doc['documentType'] ?? doc['idType'] ?? doc['type']);
      if (type.isEmpty) continue;
      byType[type] = doc;
    }
    Map<String, dynamic>? firstOf(Iterable<String> types) {
      for (final type in types) {
        final doc = byType[_normalise(type)];
        if (doc != null) return doc;
      }
      return null;
    }

    final identityDoc = firstOf(const [
      'drivers_license',
      'drivers license',
      'driving_licence',
      'international_passport',
      'passport',
      'national_identity_card',
    ]);
    final identityType = _identityTitle(identityDoc, rider);
    final rightToWorkDoc = firstOf(const [
      'right_to_work',
      'work_permit',
      'share_code',
      'visa',
    ]);
    final vehicleDoc = firstOf(const [
      'vehicle_registration',
      'vehicle registration',
      'v5c',
      'mot',
      'road_tax',
    ]);
    final insuranceDoc = firstOf(const ['insurance', 'vehicle_insurance']);
    final profilePhotoUrl =
        '${rider['profilePhotoUrl'] ?? rider['photoURL'] ?? rider['photoUrl'] ?? ''}'
            .trim();
    final profilePhotoStatus = _statusFrom(
      rider['profilePhotoStatus'] ??
          rider['photoReviewStatus'] ??
          (profilePhotoUrl.isNotEmpty ? 'uploaded' : null),
    );

    final cards = [
      _VerificationCardData(
        key: 'identity',
        title: identityType,
        summaryLabel: 'Identity',
        subtitle: 'Confirm your legal identity for Rider operations.',
        detailLine: _documentName(identityDoc),
        explanation:
            'Upload a clear government identity document so Circum can verify your Rider account.',
        icon: Icons.badge_outlined,
        status: _statusFromDoc(identityDoc),
        document: identityDoc,
        acceptedFormats: 'JPG, PNG, WEBP or PDF',
        maxFileSize: '10 MB',
        reviewTime: 'Usually within 24 hours',
        uploadRoute: identityType == "Driver's Licence"
            ? const UploadIDView(idType: IdType.driversLicense)
            : const UploadIDView(idType: IdType.internationalPassport),
      ),
      _VerificationCardData(
        key: 'right_to_work',
        title: 'Right to Work',
        summaryLabel: 'Right to Work',
        subtitle: _rightToWorkSubtitle(rightToWorkDoc, rider),
        detailLine: _documentName(rightToWorkDoc),
        explanation:
            'Provide your right-to-work evidence so Admin can review your eligibility.',
        icon: Icons.work_outline_rounded,
        status: _statusFromDoc(rightToWorkDoc),
        document: rightToWorkDoc,
        acceptedFormats: 'JPG, PNG, WEBP or PDF',
        maxFileSize: '10 MB',
        reviewTime: 'Usually within 24 hours',
        uploadRoute: const UploadIDView(idType: IdType.workPermit),
      ),
      _VerificationCardData(
        key: 'vehicle',
        title: 'Vehicle',
        summaryLabel: 'Vehicle',
        subtitle: _vehicleSubtitle(vehicleDoc, rider),
        detailLine: _vehicleDetailLine(vehicleDoc, rider),
        explanation:
            'Upload V5C, MOT or road tax evidence for the vehicle you use on deliveries.',
        icon: Icons.two_wheeler_outlined,
        status: _statusFromDoc(vehicleDoc),
        document: vehicleDoc,
        acceptedFormats: 'JPG, PNG, WEBP or PDF',
        maxFileSize: '10 MB',
        reviewTime: 'Usually within 24 hours',
        uploadRoute: const UploadIDView(idType: IdType.vehicleRegistration),
      ),
      _VerificationCardData(
        key: 'insurance',
        title: 'Insurance',
        summaryLabel: 'Insurance',
        subtitle: _insuranceSubtitle(insuranceDoc, rider),
        detailLine: _insuranceDetailLine(insuranceDoc, rider),
        explanation:
            'Keep your insurance evidence current. Admin may request this before some deliveries.',
        icon: Icons.policy_outlined,
        status: _statusFromDoc(insuranceDoc),
        document: insuranceDoc,
        acceptedFormats: 'JPG, PNG, WEBP or PDF',
        maxFileSize: '10 MB',
        reviewTime: 'Usually within 24 hours',
      ),
      _VerificationCardData(
        key: 'profile_photo',
        title: 'Profile Photo',
        summaryLabel: 'Profile Photo',
        subtitle: 'A clear rider profile photo used across active deliveries.',
        detailLine: profilePhotoUrl.isEmpty ? '' : 'Photo submitted',
        explanation:
            'Your profile photo helps senders and operations identify you during deliveries.',
        icon: Icons.account_circle_outlined,
        status: profilePhotoStatus,
        acceptedFormats: 'JPG, PNG or HEIC',
        maxFileSize: '10 MB',
        reviewTime: 'Usually within 2 hours',
        uploadRoute: profilePhotoRoute,
      ),
    ];

    final merged = {...application, ...rider};
    final accountState = RiderAccountStateResolver.resolve(merged);
    final hasRejected = cards.any((card) => card.status.isRejected);
    final hasReview = cards.any((card) => card.status.isReviewing);
    final verified = cards.every((card) => card.status.isVerified);
    final label = accountState == RiderAccountState.approved || verified
        ? 'Ready for Deliveries'
        : hasRejected
            ? 'Verification Required'
            : hasReview
                ? 'Verification Under Review'
                : 'Verification Required';
    final color = label == 'Ready for Deliveries'
        ? RiderPalette.green
        : label == 'Verification Under Review'
            ? RiderPalette.amber
            : RiderPalette.red;
    return _VerificationState(
      cards: cards,
      eligibilityLabel: label,
      eligibilityColor: color,
    );
  }
}

class _VerificationCardData {
  const _VerificationCardData({
    required this.key,
    required this.title,
    required this.summaryLabel,
    required this.subtitle,
    required this.detailLine,
    required this.explanation,
    required this.icon,
    required this.status,
    required this.acceptedFormats,
    required this.maxFileSize,
    required this.reviewTime,
    this.document,
    this.uploadRoute,
  });

  final String key;
  final String title;
  final String summaryLabel;
  final String subtitle;
  final String detailLine;
  final String explanation;
  final IconData icon;
  final _VerificationStatus status;
  final String acceptedFormats;
  final String maxFileSize;
  final String reviewTime;
  final Map<String, dynamic>? document;
  final Widget? uploadRoute;

  String get fileName =>
      '${document?['filename'] ?? document?['displayName'] ?? document?['documentType'] ?? ''}'
          .trim();
  String get submissionDate => _dateText(
        document?['submittedAt'] ??
            document?['uploadedAt'] ??
            document?['createdAt'],
      );
  String get reviewHistory {
    final history = document?['statusHistory'];
    if (history is List && history.isNotEmpty) {
      return '${history.length} status update${history.length == 1 ? '' : 's'}';
    }
    return status.hasSubmission ? status.label : 'No review history yet';
  }

  String get reviewerComment =>
      '${document?['rejectionReason'] ?? document?['reviewerComment'] ?? document?['adminComment'] ?? ''}'
          .trim();

  String get expiryText => _dateText(
        document?['expiryDate'] ??
            document?['expiresAt'] ??
            document?['policyExpiry'],
      );
}

class _VerificationStatus {
  const _VerificationStatus({
    required this.label,
    required this.color,
    required this.summaryLabel,
    required this.hasSubmission,
    this.isVerified = false,
    this.isRejected = false,
    this.isReviewing = false,
  });

  final String label;
  final Color color;
  final String summaryLabel;
  final bool hasSubmission;
  final bool isVerified;
  final bool isRejected;
  final bool isReviewing;

  bool get needsAction => !isVerified && !isReviewing;
}

class _VerificationLoading extends StatelessWidget {
  const _VerificationLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: RiderPalette.background,
      body: Center(child: CircularProgressIndicator(color: RiderPalette.blue)),
    );
  }
}

class _VerificationError extends StatelessWidget {
  const _VerificationError();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: RiderPalette.background,
      body: RiderEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Verification could not load',
        message: 'Check your connection and try again.',
      ),
    );
  }
}

_VerificationStatus _statusFromDoc(Map<String, dynamic>? doc) {
  if (doc == null) return _statusFrom(null);
  return _statusFrom(doc['status'] ?? doc['verificationStatus']);
}

_VerificationStatus _statusFrom(Object? value) {
  final raw = _normalise(value);
  if (raw.isEmpty || raw == 'not_started') {
    return const _VerificationStatus(
      label: 'Awaiting Upload',
      color: RiderPalette.muted,
      summaryLabel: 'Pending',
      hasSubmission: false,
    );
  }
  if (raw == 'uploading') {
    return const _VerificationStatus(
      label: 'Uploading',
      color: RiderPalette.blue,
      summaryLabel: 'Uploading',
      hasSubmission: true,
      isReviewing: true,
    );
  }
  if (raw == 'uploaded' || raw == 'submitted') {
    return const _VerificationStatus(
      label: 'Uploaded',
      color: RiderPalette.blue,
      summaryLabel: 'Uploaded',
      hasSubmission: true,
      isReviewing: true,
    );
  }
  if (raw == 'under_review' || raw == 'pending_review' || raw == 'review') {
    return const _VerificationStatus(
      label: 'Under Review',
      color: RiderPalette.amber,
      summaryLabel: 'Under Review',
      hasSubmission: true,
      isReviewing: true,
    );
  }
  if (raw == 'verified' || raw == 'approved') {
    return const _VerificationStatus(
      label: 'Verified',
      color: RiderPalette.green,
      summaryLabel: '✓',
      hasSubmission: true,
      isVerified: true,
    );
  }
  if (raw == 'rejected' || raw == 'declined') {
    return const _VerificationStatus(
      label: 'Rejected',
      color: RiderPalette.red,
      summaryLabel: 'Rejected',
      hasSubmission: true,
      isRejected: true,
    );
  }
  if (raw == 'expired') {
    return const _VerificationStatus(
      label: 'Expired',
      color: RiderPalette.red,
      summaryLabel: 'Expired',
      hasSubmission: true,
      isRejected: true,
    );
  }
  if (raw == 'requires_update' || raw == 'needs_attention') {
    return const _VerificationStatus(
      label: 'Requires Update',
      color: RiderPalette.red,
      summaryLabel: 'Requires Update',
      hasSubmission: true,
      isRejected: true,
    );
  }
  return _VerificationStatus(
    label: _pretty(raw),
    color: RiderPalette.amber,
    summaryLabel: _pretty(raw),
    hasSubmission: true,
    isReviewing: true,
  );
}

String _identityTitle(Map<String, dynamic>? doc, Map<String, dynamic> rider) {
  final type = _normalise(
      doc?['documentType'] ?? doc?['idType'] ?? rider['identityDocumentType']);
  if (type.contains('passport')) return 'Passport';
  if (type.contains('national_identity')) return 'National Identity Card';
  return "Driver's Licence";
}

String _rightToWorkSubtitle(
    Map<String, dynamic>? doc, Map<String, dynamic> rider) {
  final type = _normalise(
      doc?['documentType'] ?? doc?['idType'] ?? rider['rightToWorkType']);
  if (type.contains('uk_citizen')) return 'UK Citizen';
  if (type.contains('visa')) return 'Visa';
  if (type.contains('permit')) return 'Right to Work Permit';
  if (type.contains('share_code')) return 'Share code evidence';
  return 'UK Citizen, permit or visa evidence';
}

String _vehicleSubtitle(Map<String, dynamic>? doc, Map<String, dynamic> rider) {
  final vehicle = rider['vehicle'] is Map ? rider['vehicle'] as Map : const {};
  final registration =
      '${vehicle['registration'] ?? rider['vehicleRegistration'] ?? ''}'.trim();
  return registration.isEmpty
      ? 'Vehicle Registration, MOT, V5C and Road Tax'
      : 'Vehicle Registration $registration';
}

String _vehicleDetailLine(
    Map<String, dynamic>? doc, Map<String, dynamic> rider) {
  final type = _normalise(doc?['documentType'] ?? doc?['type']);
  if (type.contains('mot')) return 'MOT evidence';
  if (type.contains('v5c')) return 'V5C evidence';
  if (type.contains('tax')) return 'Road Tax evidence';
  return _documentName(doc);
}

String _insuranceSubtitle(
    Map<String, dynamic>? doc, Map<String, dynamic> rider) {
  final company =
      '${doc?['insuranceCompany'] ?? rider['insuranceCompany'] ?? ''}'.trim();
  return company.isEmpty ? 'Insurance Company and Policy Expiry' : company;
}

String _insuranceDetailLine(
    Map<String, dynamic>? doc, Map<String, dynamic> rider) {
  final expiry =
      doc?['policyExpiry'] ?? doc?['expiryDate'] ?? rider['insuranceExpiry'];
  final text = _dateText(expiry);
  if (text.isEmpty) return _documentName(doc);
  final date = _dateFromAny(expiry);
  if (date != null && date.difference(DateTime.now()).inDays <= 30) {
    return 'Policy expiry $text · expires soon';
  }
  return 'Policy expiry $text';
}

String _documentName(Map<String, dynamic>? doc) {
  if (doc == null) return '';
  return '${doc['displayName'] ?? doc['filename'] ?? doc['documentType'] ?? ''}'
      .trim();
}

String _normalise(Object? value) => '${value ?? ''}'
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

String _pretty(String value) {
  if (value.isEmpty) return '';
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _dateText(Object? value) {
  final date = _dateFromAny(value);
  if (date == null) return '';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

DateTime? _dateFromAny(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
