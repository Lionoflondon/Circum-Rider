import 'package:flutter_test/flutter_test.dart';

import '../../lib/app/rider_jobs/rider_job_offer_screen.dart';

void main() {
  test('adjustment states never become an actionable pickup stage', () {
    for (final value in [
      'awaiting_adjustment_review',
      'awaiting_admin_review',
      'more_evidence_requested',
      'awaiting_sender_adjustment',
      'rejected_by_admin',
      'future_backend_state',
    ]) {
      expect(
        RiderDeliveryStagePolicy.fromRaw(value),
        RiderDeliveryStage.issueReported,
      );
    }
  });
}
