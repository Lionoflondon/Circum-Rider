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
      'phone_verified',
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
