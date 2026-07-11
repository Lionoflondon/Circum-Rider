enum RiderAccountState {
  onboardingNotStarted,
  onboardingInProgress,
  submitted,
  pendingReview,
  moreInformationRequired,
  approved,
  rejected,
  suspended,
  frozen,
  closed,
}

/// Translates the existing Rider records without requiring a schema migration.
/// Operational access is deliberately opt-in: only an explicitly approved,
/// active record can enter the Rider home experience.
class RiderAccountStateResolver {
  static RiderAccountState resolveRecords({
    Map<String, dynamic>? rider,
    Map<String, dynamic>? riderProfile,
  }) {
    final reconciled = <String, dynamic>{...?rider};
    const adminReviewFields = {
      'approvalStatus',
      'verificationStatus',
      'onboardingStatus',
      'profileCompletionStatus',
      'driverStatus',
      'approvedAt',
      'onboardingReviewedAt',
      'onboardingComplete',
      'onboardingCompleted',
    };
    for (final field in adminReviewFields) {
      final value = riderProfile?[field];
      if (value != null) reconciled[field] = value;
    }
    return resolve(reconciled);
  }

  static RiderAccountState resolve(Map<String, dynamic>? rider) {
    if (rider == null || rider.isEmpty) {
      return RiderAccountState.onboardingNotStarted;
    }

    final approval = _value(rider, 'approvalStatus', 'verificationStatus');
    final onboarding =
        _value(rider, 'onboardingStatus', 'profileCompletionStatus');
    final operational = _value(rider, 'riderStatus', 'driverStatus', 'status');

    if (_bool(rider, 'isClosed', 'closed') ||
        _matches(operational, {'closed'})) {
      return RiderAccountState.closed;
    }
    if (_bool(rider, 'isFrozen', 'frozen') ||
        _matches(operational, {'frozen'})) {
      return RiderAccountState.frozen;
    }
    if (_bool(rider, 'isSuspended', 'suspended') ||
        _matches(operational, {'suspended'})) {
      return RiderAccountState.suspended;
    }
    if (_matches(approval, {'rejected', 'declined'})) {
      return RiderAccountState.rejected;
    }
    if (_matches(approval, {
          'more_information_required',
          'information_required',
          'action_required'
        }) ||
        _matches(onboarding,
            {'more_information_required', 'information_required'})) {
      return RiderAccountState.moreInformationRequired;
    }
    if (_matches(approval, {'approved', 'verified'}) &&
        !_matches(operational, {'pending', 'inactive'})) {
      return RiderAccountState.approved;
    }
    if (_matches(approval, {'submitted'}) ||
        _matches(onboarding, {'application_submitted', 'submitted'})) {
      return RiderAccountState.submitted;
    }
    if (_matches(onboarding, {
      'profile_started',
      'email_verified',
      'in_progress',
      'started',
    })) {
      return RiderAccountState.onboardingInProgress;
    }
    if (_matches(
            approval, {'pending', 'under_review', 'verification_pending'}) ||
        _matches(onboarding,
            {'profile_complete', 'verification_pending', 'under_review'})) {
      return RiderAccountState.pendingReview;
    }
    return RiderAccountState.onboardingNotStarted;
  }

  static bool canOperate(RiderAccountState state) =>
      state == RiderAccountState.approved;

  static String storageValue(RiderAccountState state) => switch (state) {
        RiderAccountState.onboardingNotStarted => 'onboarding_not_started',
        RiderAccountState.onboardingInProgress => 'onboarding_in_progress',
        RiderAccountState.submitted => 'submitted',
        RiderAccountState.pendingReview => 'pending_review',
        RiderAccountState.moreInformationRequired =>
          'more_information_required',
        RiderAccountState.approved => 'approved',
        RiderAccountState.rejected => 'rejected',
        RiderAccountState.suspended => 'suspended',
        RiderAccountState.frozen => 'frozen',
        RiderAccountState.closed => 'closed',
      };

  static String _value(Map<String, dynamic> data, String first, String second,
      [String? third]) {
    final values = [data[first], data[second], if (third != null) data[third]];
    return values
        .map((value) => '${value ?? ''}'.trim().toLowerCase())
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
  }

  static bool _bool(Map<String, dynamic> data, String first, String second) =>
      data[first] == true || data[second] == true;

  static bool _matches(String value, Set<String> values) =>
      values.contains(value);
}

class RiderApprovalProgress {
  const RiderApprovalProgress({
    required this.accountCreated,
    required this.emailVerified,
    required this.applicationSubmitted,
    required this.underReview,
    required this.approved,
    required this.readyToDeliver,
  });

  final bool accountCreated;
  final bool emailVerified;
  final bool applicationSubmitted;
  final bool underReview;
  final bool approved;
  final bool readyToDeliver;

  factory RiderApprovalProgress.fromBackend({
    required bool accountExists,
    required bool firebaseEmailVerified,
    required Map<String, dynamic> rider,
  }) {
    final approval = _normalised(
      rider['approvalStatus'] ?? rider['verificationStatus'],
    );
    final onboarding = _normalised(
      rider['onboardingStatus'] ?? rider['profileCompletionStatus'],
    );
    final approved = approval == 'approved' || rider['approvedAt'] != null;
    final applicationSubmitted = rider['applicationSubmittedAt'] != null ||
        rider['submittedAt'] != null ||
        const {
          'submitted',
          'pending',
          'pending_review',
          'under_review',
          'reviewing',
          'approved',
        }.contains(approval) ||
        const {'application_submitted', 'submitted'}.contains(onboarding);
    final underReview = rider['reviewStartedAt'] != null ||
        rider['reviewedAt'] != null ||
        const {
          'pending',
          'pending_review',
          'under_review',
          'reviewing',
          'approved'
        }.contains(approval);
    final onboardingComplete = rider['onboardingComplete'] == true ||
        rider['onboardingCompleted'] == true ||
        const {'complete', 'completed', 'profile_complete'}
            .contains(onboarding);

    return RiderApprovalProgress(
      accountCreated: accountExists,
      emailVerified: firebaseEmailVerified,
      applicationSubmitted: applicationSubmitted,
      underReview: underReview,
      approved: approved,
      readyToDeliver: approved && onboardingComplete,
    );
  }

  static String _normalised(Object? value) =>
      '${value ?? ''}'.trim().toLowerCase().replaceAll(' ', '_');
}
