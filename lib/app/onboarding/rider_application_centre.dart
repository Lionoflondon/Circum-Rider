import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../communication/rider_conversation_view.dart';
import '../rider_account/rider_account_state.dart';
import '../rider_design/rider_ui.dart';
import 'rider_roth_onboarding.dart';

enum RiderApplicationSectionStatus {
  notStarted,
  inProgress,
  submitted,
  needsAttention,
  approved,
}

extension RiderApplicationSectionStatusCopy on RiderApplicationSectionStatus {
  String get label => switch (this) {
        RiderApplicationSectionStatus.notStarted => 'Not started',
        RiderApplicationSectionStatus.inProgress => 'In progress',
        RiderApplicationSectionStatus.submitted => 'Submitted',
        RiderApplicationSectionStatus.needsAttention => 'Needs attention',
        RiderApplicationSectionStatus.approved => 'Approved',
      };

  String get storageValue => switch (this) {
        RiderApplicationSectionStatus.notStarted => 'not_started',
        RiderApplicationSectionStatus.inProgress => 'in_progress',
        RiderApplicationSectionStatus.submitted => 'submitted',
        RiderApplicationSectionStatus.needsAttention => 'needs_attention',
        RiderApplicationSectionStatus.approved => 'approved',
      };

  Color get color => switch (this) {
        RiderApplicationSectionStatus.notStarted => RiderPalette.muted,
        RiderApplicationSectionStatus.inProgress => RiderPalette.blue,
        RiderApplicationSectionStatus.submitted => RiderPalette.amber,
        RiderApplicationSectionStatus.needsAttention => RiderPalette.red,
        RiderApplicationSectionStatus.approved => RiderPalette.green,
      };
}

RiderApplicationSectionStatus riderApplicationStatusFrom(Object? raw) {
  final value = '${raw ?? ''}'.trim().toLowerCase();
  return switch (value) {
    'approved' || 'verified' => RiderApplicationSectionStatus.approved,
    'needs_attention' ||
    'action_required' ||
    'rejected' =>
      RiderApplicationSectionStatus.needsAttention,
    'submitted' ||
    'under_review' ||
    'reviewing' =>
      RiderApplicationSectionStatus.submitted,
    'in_progress' || 'started' => RiderApplicationSectionStatus.inProgress,
    _ => RiderApplicationSectionStatus.notStarted,
  };
}

class RiderApplicationCentre extends StatefulWidget {
  const RiderApplicationCentre({super.key});

  static const applicationCollection = 'riderApplications';
  static const documentsCollection = 'riderDocuments';
  static const auditCollection = 'riderApplicationAudit';
  static const storageRoot = 'rider-applications';
  static const maxVehicles = 2;

  @override
  State<RiderApplicationCentre> createState() => _RiderApplicationCentreState();
}

class _RiderApplicationCentreState extends State<RiderApplicationCentre> {
  final _db = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  final _auth = FirebaseAuth.instance;
  final _roth = const RiderRothOnboarding();

  String? _message;
  bool _busy = false;

  String? get _uid => _auth.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    if (uid == null) {
      return const Scaffold(
        backgroundColor: RiderPalette.background,
        body: SafeArea(
          child: RiderEmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'Sign in required',
            message: 'Sign in to continue your Rider application.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: RiderPalette.background,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _db
              .collection(RiderApplicationCentre.applicationCollection)
              .doc(uid)
              .snapshots(),
          builder: (context, applicationSnapshot) {
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _db.collection('riders').doc(uid).snapshots(),
              builder: (context, riderSnapshot) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _db
                      .collection(RiderApplicationCentre.documentsCollection)
                      .where('riderId', isEqualTo: uid)
                      .snapshots(),
                  builder: (context, documentSnapshot) {
                    final rider = riderSnapshot.data?.data() ?? const {};
                    final application =
                        applicationSnapshot.data?.data() ?? const {};
                    final documents = documentSnapshot.data?.docs
                            .map((doc) => {'id': doc.id, ...doc.data()})
                            .toList() ??
                        const <Map<String, dynamic>>[];
                    final progress = RiderApprovalProgress.fromBackend(
                      accountExists: true,
                      firebaseEmailVerified:
                          _auth.currentUser?.emailVerified == true,
                      rider: {...application, ...rider},
                    );
                    return RefreshIndicator(
                      color: RiderPalette.blue,
                      backgroundColor: RiderPalette.panel,
                      onRefresh: () async => setState(() {}),
                      child: CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                            sliver: SliverList.list(
                              children: [
                                _TopBar(
                                    onBack: () => Navigator.maybePop(context)),
                                const SizedBox(height: 16),
                                _ApplicationHero(
                                  progress: progress,
                                  status: _overallStatus(application, rider),
                                  busy: _busy,
                                  onSubmit: () => _submitApplication(uid),
                                ),
                                if (_message != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    _message!,
                                    style: const TextStyle(
                                      color: RiderPalette.amber,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 18),
                                for (final section in _sections(
                                  rider: rider,
                                  application: application,
                                  documents: documents,
                                )) ...[
                                  _ApplicationSectionRow(
                                    section: section,
                                    onTap: () => _openSection(uid, section),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                const SizedBox(height: 12),
                                _ProgressChecklist(progress: progress),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _overallStatus(
      Map<String, dynamic> application, Map<String, dynamic> rider) {
    final state = RiderAccountStateResolver.resolve({...application, ...rider});
    return switch (state) {
      RiderAccountState.approved => 'Approved and ready',
      RiderAccountState.moreInformationRequired => 'Changes requested',
      RiderAccountState.submitted => 'Application submitted',
      RiderAccountState.pendingReview => 'Admin review in progress',
      RiderAccountState.rejected => 'Application rejected',
      RiderAccountState.suspended => 'Suspended review',
      _ => 'Continue application',
    };
  }

  List<_ApplicationSection> _sections({
    required Map<String, dynamic> rider,
    required Map<String, dynamic> application,
    required List<Map<String, dynamic>> documents,
  }) {
    final statuses = application['sectionStatus'] is Map
        ? Map<String, dynamic>.from(application['sectionStatus'] as Map)
        : const <String, dynamic>{};
    return [
      _ApplicationSection(
        key: 'personal_details',
        title: 'Personal details',
        subtitle: 'Legal name, date of birth, emergency contact',
        icon: Icons.person_outline_rounded,
        status: _statusFor(
          explicit: statuses['personal_details'],
          complete: '${rider['legalFirstName'] ?? rider['firstName'] ?? ''}'
                  .trim()
                  .isNotEmpty &&
              '${rider['legalSurname'] ?? rider['lastName'] ?? ''}'
                  .trim()
                  .isNotEmpty,
        ),
      ),
      _ApplicationSection(
        key: 'home_address',
        title: 'Home address',
        subtitle: 'Residential address for Rider records',
        icon: Icons.home_outlined,
        status: _statusFor(
          explicit: statuses['home_address'],
          complete: '${rider['homeAddress'] ?? rider['address'] ?? ''}'
              .trim()
              .isNotEmpty,
        ),
      ),
      _ApplicationSection(
        key: 'contact_details',
        title: 'Contact details',
        subtitle: 'Verified phone and email',
        icon: Icons.phone_iphone_rounded,
        status: _statusFor(
          explicit: statuses['contact_details'],
          complete: '${rider['phone'] ?? _auth.currentUser?.phoneNumber ?? ''}'
                  .trim()
                  .isNotEmpty ||
              '${rider['email'] ?? _auth.currentUser?.email ?? ''}'
                  .trim()
                  .isNotEmpty,
        ),
      ),
      _documentSection(
        key: 'identity_verification',
        title: 'Identity verification',
        subtitle: 'Passport, driving licence, ID card or selfie',
        icon: Icons.verified_user_outlined,
        documents: documents,
        match: const {
          'passport',
          'drivers_license',
          'driving_licence',
          'national_identity_card',
          'identity_selfie',
        },
      ),
      _documentSection(
        key: 'right_to_work',
        title: 'Right-to-work information',
        subtitle: 'Share code or accepted evidence',
        icon: Icons.badge_outlined,
        documents: documents,
        match: const {'right_to_work', 'work_permit', 'share_code'},
      ),
      _ApplicationSection(
        key: 'vehicle_details',
        title: 'Vehicle details',
        subtitle: 'Up to two vehicles, primary vehicle and capability',
        icon: Icons.two_wheeler_outlined,
        status: _statusFor(
          explicit: statuses['vehicle_details'],
          complete: _vehicleList(rider).isNotEmpty ||
              '${rider['vehicleType'] ?? ''}'.trim().isNotEmpty,
        ),
      ),
      _documentSection(
        key: 'vehicle_documents',
        title: 'Vehicle documents',
        subtitle: 'V5C or MOT now; insurance can be supplied later',
        icon: Icons.description_outlined,
        documents: documents,
        match: const {
          'vehicle_registration',
          'v5c',
          'mot',
          'insurance',
          'vehicle_supporting_document',
        },
      ),
      _ApplicationSection(
        key: 'payout_details',
        title: 'Payout details',
        subtitle: 'Cash earnings payout setup status',
        icon: Icons.account_balance_wallet_outlined,
        status: _statusFor(
          explicit: statuses['payout_details'],
          complete: rider['payoutSetupComplete'] == true ||
              rider['stripeConnectReady'] == true,
        ),
      ),
      _ApplicationSection(
        key: 'roth_wallet_setup',
        title: 'Roth wallet setup',
        subtitle: 'Separate, non-withdrawable Roth wallet',
        icon: Icons.savings_outlined,
        status: _statusFor(
          explicit: statuses['roth_wallet_setup'],
          complete: RiderRothOnboarding.needsOnboarding(rider) == false,
        ),
      ),
      const _ApplicationSection(
        key: 'application_messages',
        title: 'Application messages',
        subtitle: 'Message Admin and reply to review requests',
        icon: Icons.chat_bubble_outline_rounded,
        status: RiderApplicationSectionStatus.inProgress,
      ),
      _ApplicationSection(
        key: 'review_status',
        title: 'Review status',
        subtitle: _overallStatus(application, rider),
        icon: Icons.fact_check_outlined,
        status: _statusFor(
          explicit: statuses['review_status'],
          complete:
              RiderAccountStateResolver.resolve({...application, ...rider}) ==
                  RiderAccountState.approved,
        ),
      ),
    ];
  }

  _ApplicationSection _documentSection({
    required String key,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Map<String, dynamic>> documents,
    required Set<String> match,
  }) {
    final docs = documents.where((doc) {
      final type =
          _normalise(doc['documentType'] ?? doc['idType'] ?? doc['type']);
      return match.contains(type);
    }).toList();
    final hasAttention = docs.any((doc) =>
        riderApplicationStatusFrom(
            doc['status'] ?? doc['verificationStatus']) ==
        RiderApplicationSectionStatus.needsAttention);
    final approved = docs.isNotEmpty &&
        docs.any((doc) =>
            riderApplicationStatusFrom(
                doc['status'] ?? doc['verificationStatus']) ==
            RiderApplicationSectionStatus.approved);
    return _ApplicationSection(
      key: key,
      title: title,
      subtitle: docs.isEmpty ? subtitle : '${docs.length} document saved',
      icon: icon,
      status: hasAttention
          ? RiderApplicationSectionStatus.needsAttention
          : approved
              ? RiderApplicationSectionStatus.approved
              : docs.isEmpty
                  ? RiderApplicationSectionStatus.notStarted
                  : RiderApplicationSectionStatus.submitted,
    );
  }

  RiderApplicationSectionStatus _statusFor({
    required Object? explicit,
    required bool complete,
  }) {
    final status = riderApplicationStatusFrom(explicit);
    if (status != RiderApplicationSectionStatus.notStarted) return status;
    return complete
        ? RiderApplicationSectionStatus.submitted
        : RiderApplicationSectionStatus.notStarted;
  }

  Future<void> _openSection(String uid, _ApplicationSection section) async {
    switch (section.key) {
      case 'personal_details':
      case 'home_address':
      case 'contact_details':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _PersonalApplicationForm(
              sectionKey: section.key,
              title: section.title,
              save: (patch) => _saveApplicationPatch(uid, section.key, patch),
            ),
          ),
        );
      case 'vehicle_details':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _VehicleApplicationForm(
              load: () async {
                final rider = await _db.collection('riders').doc(uid).get();
                return _vehicleList(rider.data() ?? const {});
              },
              save: (vehicles) => _saveVehicles(uid, vehicles),
            ),
          ),
        );
      case 'identity_verification':
      case 'right_to_work':
      case 'vehicle_documents':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _DocumentUploadSection(
              section: section,
              upload: (type, file) =>
                  _uploadDocument(uid, section.key, type, file),
            ),
          ),
        );
      case 'roth_wallet_setup':
        await _runGuard(() async {
          await _roth.ensureWalletForRider(
            riderId: uid,
            email: _auth.currentUser?.email,
          );
          await _saveSectionStatus(
            uid,
            section.key,
            RiderApplicationSectionStatus.submitted,
          );
        }, success: 'Roth wallet connected.');
      case 'application_messages':
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RiderConversationView(
              chatId: 'admin_rider_${uid}_application',
              title: 'Application messages',
              subtitle: 'Admin review conversation',
            ),
          ),
        );
      case 'payout_details':
        await _runGuard(() async {
          await _saveSectionStatus(
            uid,
            section.key,
            RiderApplicationSectionStatus.inProgress,
          );
        }, success: 'Payout setup status will update from Stripe Connect.');
      case 'review_status':
        await _submitApplication(uid);
    }
  }

  Future<void> _saveApplicationPatch(
    String uid,
    String section,
    Map<String, dynamic> patch,
  ) async {
    await _runGuard(() async {
      final data = {
        ...patch,
        'section': section,
      };
      await _functions.httpsCallable('updateRiderProfile').call(data);
      await _saveSectionStatus(
        uid,
        section,
        RiderApplicationSectionStatus.submitted,
      );
    }, success: 'Section saved for review.');
  }

  Future<void> _saveVehicles(
    String uid,
    List<Map<String, dynamic>> vehicles,
  ) async {
    await _runGuard(() async {
      final capped = vehicles.take(RiderApplicationCentre.maxVehicles).toList();
      final primary = capped.firstWhere(
        (vehicle) => vehicle['primary'] == true,
        orElse: () => capped.isEmpty ? const {} : capped.first,
      );
      await _functions.httpsCallable('updateRiderProfile').call({
        'vehicles': capped,
        if (primary.isNotEmpty) 'vehicle': primary,
        if (primary['type'] != null) 'vehicleType': primary['type'],
        if (primary['registration'] != null)
          'vehicleRegistration': primary['registration'],
      });
      await _saveSectionStatus(
        uid,
        'vehicle_details',
        RiderApplicationSectionStatus.submitted,
      );
    }, success: 'Vehicle details saved.');
  }

  Future<void> _uploadDocument(
    String uid,
    String section,
    String documentType,
    XFile file,
  ) async {
    await _runGuard(() async {
      final name = file.name;
      final extension = name.split('.').last.toLowerCase();
      const allowed = {'jpg', 'jpeg', 'png', 'webp', 'pdf'};
      if (!allowed.contains(extension)) {
        throw StateError('Please upload JPG, PNG, WEBP or PDF files.');
      }
      final length = await file.length();
      if (length > 10 * 1024 * 1024) {
        throw StateError('Document must be smaller than 10MB.');
      }
      final bytes = await file.readAsBytes();
      final safeType = _normalise(documentType);
      await _functions.httpsCallable('submitRiderDocument').call({
        'section': section,
        'documentType': safeType,
        'displayName': _documentLabel(safeType),
        'fileName': name,
        'contentType': extension == 'pdf'
            ? 'application/pdf'
            : 'image/${extension == 'jpg' ? 'jpeg' : extension}',
        'fileBase64': base64Encode(bytes),
      });
      await _saveSectionStatus(
        uid,
        section,
        RiderApplicationSectionStatus.submitted,
      );
    }, success: 'Document uploaded for Admin review.');
  }

  Future<void> _submitApplication(String uid) async {
    await _runGuard(() async {
      await _functions.httpsCallable('submitRiderApplication').call({
        'rightToWorkConfirmed': true,
        'sealedPackageConsent': true,
        'idempotencyKey': 'rider-application:$uid',
      });
    }, success: 'Application submitted for Admin review.');
  }

  Future<void> _saveSectionStatus(
    String uid,
    String section,
    RiderApplicationSectionStatus status,
  ) async {
    await _functions.httpsCallable('updateRiderApplicationSection').call({
      'section': section,
      'status': status.storageValue,
    });
  }

  Future<void> _runGuard(
    Future<void> Function() action, {
    required String success,
  }) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (mounted) setState(() => _message = success);
    } catch (error) {
      if (mounted) {
        setState(
            () => _message = error.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static List<Map<String, dynamic>> _vehicleList(Map<String, dynamic> rider) {
    if (rider['vehicles'] is Iterable) {
      return List<Map<String, dynamic>>.from(
        (rider['vehicles'] as Iterable).whereType<Map>().map(
              (item) => Map<String, dynamic>.from(item),
            ),
      );
    }
    if (rider['vehicle'] is Map) {
      return [Map<String, dynamic>.from(rider['vehicle'] as Map)];
    }
    if ('${rider['vehicleType'] ?? ''}'.trim().isNotEmpty) {
      return [
        {
          'type': rider['vehicleType'],
          'makeModel': rider['vehicleMakeModel'],
          'colour': rider['vehicleColour'],
          'registration': rider['vehicleRegistration'],
          'primary': true,
        }
      ];
    }
    return const [];
  }

  static String _normalise(Object? value) => '${value ?? ''}'
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+$'), '');

  static String _documentLabel(String type) => switch (type) {
        'passport' => 'Passport',
        'drivers_license' || 'driving_licence' => 'Driving licence',
        'national_identity_card' => 'National identity card',
        'right_to_work' || 'work_permit' => 'Right-to-work evidence',
        'proof_of_address' => 'Proof of address',
        'identity_selfie' => 'Selfie verification image',
        'vehicle_registration' || 'v5c' || 'mot' => 'V5C or MOT evidence',
        'insurance' => 'Insurance evidence',
        _ => type
            .split('_')
            .map((part) => part.isEmpty
                ? part
                : '${part[0].toUpperCase()}${part.substring(1)}')
            .join(' '),
      };
}

class _ApplicationSection {
  const _ApplicationSection({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.status,
  });

  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final RiderApplicationSectionStatus status;
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          color: RiderPalette.paper,
        ),
        const Expanded(
          child: Text(
            'Rider Application Centre',
            style: TextStyle(
              color: RiderPalette.paper,
              fontFamily: RiderTypography.heading,
              fontSize: 25,
            ),
          ),
        ),
      ],
    );
  }
}

class _ApplicationHero extends StatelessWidget {
  const _ApplicationHero({
    required this.progress,
    required this.status,
    required this.busy,
    required this.onSubmit,
  });

  final RiderApprovalProgress progress;
  final String status;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final complete = [
      progress.accountCreated,
      progress.phoneVerified,
      progress.documentsSubmitted,
      progress.vehicleDetails,
      progress.rothWalletSetup,
      progress.payoutSetup,
      progress.applicationSubmitted,
      progress.underReview,
      progress.approved,
    ].where((item) => item).length;
    return RiderGlassSurface(
      radius: 26,
      blur: 14,
      opacity: .62,
      padding: const EdgeInsets.all(18),
      edgeColor: RiderPalette.blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            status,
            style: const TextStyle(
              color: RiderPalette.paper,
              fontFamily: RiderTypography.heading,
              fontSize: 27,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Complete each section, submit documents securely, and message Admin if review changes are requested.',
            style: TextStyle(
                color: RiderPalette.muted, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: complete / 9,
            minHeight: 6,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: Colors.white.withValues(alpha: .10),
            color: RiderPalette.blue,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy ? null : onSubmit,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: const Text('Submit application'),
            style: FilledButton.styleFrom(
              backgroundColor: RiderPalette.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicationSectionRow extends StatelessWidget {
  const _ApplicationSectionRow({
    required this.section,
    required this.onTap,
  });

  final _ApplicationSection section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RiderGlassSurface(
      onTap: onTap,
      radius: 18,
      blur: 10,
      opacity: .54,
      padding: const EdgeInsets.all(15),
      edgeColor: section.status.color,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: section.status.color.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(section.icon, color: section.status.color, size: 20),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.title,
                  style: const TextStyle(
                    color: RiderPalette.paper,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${section.status.label} · ${section.subtitle}',
                  style: const TextStyle(
                    color: RiderPalette.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: RiderPalette.muted),
        ],
      ),
    );
  }
}

class _ProgressChecklist extends StatelessWidget {
  const _ProgressChecklist({required this.progress});

  final RiderApprovalProgress progress;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Account created', progress.accountCreated),
      ('Phone verified', progress.phoneVerified),
      ('Identity and documents', progress.documentsSubmitted),
      ('Vehicle details', progress.vehicleDetails),
      ('Roth wallet setup', progress.rothWalletSetup),
      ('Payout setup', progress.payoutSetup),
      ('Application submitted', progress.applicationSubmitted),
      ('Admin review', progress.underReview),
      ('Approved', progress.approved),
    ];
    return RiderGlassSurface(
      radius: 20,
      blur: 10,
      opacity: .54,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Application progress',
            style: TextStyle(
              color: RiderPalette.paper,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    item.$2
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: item.$2 ? RiderPalette.green : RiderPalette.muted,
                    size: 17,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      item.$1,
                      style: TextStyle(
                        color:
                            item.$2 ? RiderPalette.paper : RiderPalette.muted,
                        fontSize: 12.5,
                        fontWeight: item.$2 ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PersonalApplicationForm extends StatefulWidget {
  const _PersonalApplicationForm({
    required this.sectionKey,
    required this.title,
    required this.save,
  });

  final String sectionKey;
  final String title;
  final Future<void> Function(Map<String, dynamic> patch) save;

  @override
  State<_PersonalApplicationForm> createState() =>
      _PersonalApplicationFormState();
}

class _PersonalApplicationFormState extends State<_PersonalApplicationForm> {
  final _controllers = <String, TextEditingController>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final fields = switch (widget.sectionKey) {
      'home_address' => ['homeAddress'],
      'contact_details' => ['phone', 'email'],
      _ => [
          'legalFirstName',
          'legalSurname',
          'preferredName',
          'dateOfBirth',
          'emergencyContactName',
          'emergencyContactPhone',
          'accessibilityNeeds',
        ],
    };
    for (final field in fields) {
      _controllers[field] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: widget.title,
      child: Column(
        children: [
          for (final entry in _controllers.entries) ...[
            TextField(
              controller: entry.value,
              style: const TextStyle(color: RiderPalette.paper),
              decoration: InputDecoration(
                labelText: _fieldLabel(entry.key),
                labelStyle: const TextStyle(color: RiderPalette.muted),
                enabledBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: .12)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: RiderPalette.blue),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    await widget.save({
                      for (final entry in _controllers.entries)
                        if (entry.value.text.trim().isNotEmpty)
                          entry.key: entry.value.text.trim(),
                    });
                    if (context.mounted) Navigator.pop(context);
                  },
            child: Text(_saving ? 'Saving…' : 'Save and continue'),
          ),
        ],
      ),
    );
  }

  String _fieldLabel(String key) => switch (key) {
        'legalFirstName' => 'Legal first name',
        'legalSurname' => 'Legal surname',
        'preferredName' => 'Preferred name',
        'dateOfBirth' => 'Date of birth',
        'homeAddress' => 'Home address',
        'emergencyContactName' => 'Emergency contact name',
        'emergencyContactPhone' => 'Emergency contact phone',
        'accessibilityNeeds' => 'Optional accessibility needs',
        _ => key,
      };
}

class _VehicleApplicationForm extends StatefulWidget {
  const _VehicleApplicationForm({
    required this.load,
    required this.save,
  });

  final Future<List<Map<String, dynamic>>> Function() load;
  final Future<void> Function(List<Map<String, dynamic>> vehicles) save;

  @override
  State<_VehicleApplicationForm> createState() =>
      _VehicleApplicationFormState();
}

class _VehicleApplicationFormState extends State<_VehicleApplicationForm> {
  final _vehicles = <Map<String, TextEditingController>>[];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    widget.load().then((vehicles) {
      if (!mounted) return;
      setState(() {
        for (final vehicle
            in vehicles.take(RiderApplicationCentre.maxVehicles)) {
          _vehicles.add(_controllersFor(vehicle));
        }
        if (_vehicles.isEmpty) _vehicles.add(_controllersFor(const {}));
      });
    });
  }

  @override
  void dispose() {
    for (final vehicle in _vehicles) {
      for (final controller in vehicle.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: 'Vehicle details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Add up to two vehicles. V5C or MOT evidence can satisfy the initial vehicle evidence requirement; insurance can be supplied later unless Admin requests it.',
            style: TextStyle(color: RiderPalette.muted, height: 1.45),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < _vehicles.length; i++) ...[
            Text('Vehicle ${i + 1}',
                style: const TextStyle(
                    color: RiderPalette.paper, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            for (final key in [
              'type',
              'make',
              'model',
              'colour',
              'registration',
              'year',
              'ownershipStatus',
            ]) ...[
              TextField(
                controller: _vehicles[i][key],
                style: const TextStyle(color: RiderPalette.paper),
                decoration: InputDecoration(
                  labelText: _vehicleLabel(key),
                  labelStyle: const TextStyle(color: RiderPalette.muted),
                ),
              ),
              const SizedBox(height: 9),
            ],
            const SizedBox(height: 12),
          ],
          if (_vehicles.length < RiderApplicationCentre.maxVehicles)
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _vehicles.add(_controllersFor(const {}));
              }),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add second vehicle'),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    await widget.save([
                      for (var i = 0; i < _vehicles.length; i++)
                        {
                          for (final entry in _vehicles[i].entries)
                            if (entry.value.text.trim().isNotEmpty)
                              entry.key: entry.value.text.trim(),
                          'primary': i == 0,
                        }
                    ]);
                    if (context.mounted) Navigator.pop(context);
                  },
            child: Text(_saving ? 'Saving…' : 'Save vehicles'),
          ),
        ],
      ),
    );
  }

  Map<String, TextEditingController> _controllersFor(
      Map<String, dynamic> data) {
    return {
      for (final key in [
        'type',
        'make',
        'model',
        'colour',
        'registration',
        'year',
        'ownershipStatus',
      ])
        key: TextEditingController(text: '${data[key] ?? ''}'),
    };
  }

  String _vehicleLabel(String key) => switch (key) {
        'type' => 'Vehicle type',
        'ownershipStatus' => 'Ownership status',
        _ => '${key[0].toUpperCase()}${key.substring(1)}',
      };
}

class _DocumentUploadSection extends StatefulWidget {
  const _DocumentUploadSection({
    required this.section,
    required this.upload,
  });

  final _ApplicationSection section;
  final Future<void> Function(String type, XFile file) upload;

  @override
  State<_DocumentUploadSection> createState() => _DocumentUploadSectionState();
}

class _DocumentUploadSectionState extends State<_DocumentUploadSection> {
  String _type = 'passport';
  XFile? _file;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _type = _types.first;
  }

  List<String> get _types => switch (widget.section.key) {
        'right_to_work' => ['right_to_work', 'share_code'],
        'vehicle_documents' => [
            'vehicle_registration',
            'v5c',
            'mot',
            'insurance',
            'vehicle_supporting_document',
          ],
        _ => [
            'passport',
            'drivers_license',
            'national_identity_card',
            'proof_of_address',
            'identity_selfie',
          ],
      };

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: widget.section.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Accepted formats: JPG, PNG, WEBP or PDF up to 10MB. Documents are uploaded to your secure Rider application path for Admin review.',
            style: TextStyle(color: RiderPalette.muted, height: 1.45),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _type,
            dropdownColor: RiderPalette.panel,
            decoration: const InputDecoration(labelText: 'Document type'),
            items: [
              for (final type in _types)
                DropdownMenuItem(value: type, child: Text(type)),
            ],
            onChanged: (value) => setState(() => _type = value ?? _type),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final file = await ImagePicker().pickMedia();
              if (file != null) setState(() => _file = file);
            },
            icon: const Icon(Icons.upload_file_rounded),
            label: Text(_file == null ? 'Choose document' : _file!.name),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _file == null || _uploading
                ? null
                : () async {
                    setState(() => _uploading = true);
                    await widget.upload(_type, _file!);
                    if (context.mounted) Navigator.pop(context);
                  },
            child: Text(_uploading ? 'Uploading…' : 'Submit document'),
          ),
        ],
      ),
    );
  }
}

class _SectionScaffold extends StatelessWidget {
  const _SectionScaffold({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RiderPalette.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: RiderPalette.paper,
                    ),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: RiderPalette.paper,
                          fontFamily: RiderTypography.heading,
                          fontSize: 25,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                RiderGlassSurface(
                  radius: 22,
                  blur: 12,
                  opacity: .60,
                  padding: const EdgeInsets.all(18),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
