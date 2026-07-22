import 'package:circum_rider/app/rider_jobs/rider_job_offer_screen.dart';
import 'package:circum_rider/app/rider_jobs/rider_delivery_controller.dart';
import 'package:circum_rider/app/rider_jobs/rider_offer_card.dart';
import 'package:circum_rider/app/rider_jobs/rider_offer_stack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

class _BackendStageController implements RiderDeliveryController {
  _BackendStageController(this.results);

  final List<String> results;
  final List<String> actions = [];
  int irisConfirmationCalls = 0;

  @override
  Future<RiderDeliveryTransitionResult> transition({
    required String deliveryId,
    required String action,
    String? pin,
    Map<String, dynamic>? evidence,
    Map<String, dynamic>? issue,
  }) async {
    actions.add(action);
    final status = results.isEmpty ? 'accepted' : results.removeAt(0);
    return RiderDeliveryTransitionResult(status);
  }

  @override
  Future<Map<String, dynamic>> markNoShow({required String deliveryId}) async =>
      {'success': true};

  @override
  Future<Map<String, dynamic>> reportDiscrepancy({
    required String deliveryId,
    required String reason,
    required List<String> evidencePhotos,
    double? observedWeightKg,
    String? notes,
  }) async =>
      {'success': true};

  @override
  Future<Map<String, dynamic>> reportWaitingContext({
    required String deliveryId,
    required String type,
    String? note,
  }) async =>
      {'success': true};

  @override
  Future<Map<String, dynamic>> confirmIrisAssessment({
    required String deliveryId,
  }) async {
    irisConfirmationCalls += 1;
    return {
      'success': true,
      'acknowledgement': {
        'deliveryId': deliveryId,
        'acknowledgementStatus': 'confirmed',
      },
    };
  }
}

void main() {
  test('offer earnings presentation has no bonus reward system', () {
    final source =
        File('lib/app/rider_jobs/rider_offer_card.dart').readAsStringSync();
    expect(source.toLowerCase(), isNot(contains('bonus')));
    expect(source, contains('Estimated earnings'));
    expect(source, contains('Trust Points'));
  });

  test('offer fallbacks use customer-facing route and parcel language', () {
    final source =
        File('lib/app/rider_jobs/rider_offer_card.dart').readAsStringSync();
    final deliverySource = File(
      'lib/app/rider_jobs/rider_job_offer_screen.dart',
    ).readAsStringSync();
    expect(source, contains('Calculating route'));
    expect(source, contains('Calculating arrival time'));
    expect(deliverySource, contains('Awaiting parcel check'));
    expect(source, isNot(contains('Distance pending')));
    expect(source, isNot(contains('ETA pending')));
    expect(deliverySource, isNot(contains('Backend pending')));
  });

  group('RiderOfferStack', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .views
          .first
          .physicalSize = const Size(390, 844);
      TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .views
          .first
          .devicePixelRatio = 1.0;
    });

    tearDown(() {
      TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .views
          .first
          .resetPhysicalSize();
      TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .views
          .first
          .resetDevicePixelRatio();
    });

    testWidgets('swiping changes visible offer without accepting or rejecting',
        (tester) async {
      var activeIndex = 0;
      var acceptCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: RiderOfferStack(
                offers: _offers,
                activeIndex: activeIndex,
                accepting: false,
                riderRank: 'Sentinel',
                onIndexChanged: (index) => setState(() => activeIndex = index),
                onAccept: (_) => acceptCount += 1,
              ),
            );
          },
        ),
      ));

      expect(find.text('CIR-ONE'), findsNothing);
      expect(find.text('Prescription box'), findsWidgets);
      expect(acceptCount, 0);

      await tester.drag(find.byType(RiderOfferStack), const Offset(-260, 0));
      await tester.pumpAndSettle();

      expect(activeIndex, 1);
      expect(find.text('Gift parcel'), findsWidgets);
      expect(acceptCount, 0);
      expect(find.textContaining('Reject'), findsNothing);
      expect(find.textContaining('Decline'), findsNothing);
      expect(find.textContaining('Skip'), findsNothing);
    });

    testWidgets('card fits mobile preview and shows required hierarchy',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RiderOfferCard(
            offer: _offers.first,
            riderRank: 'Sentinel',
            accepting: false,
            onAccept: () {},
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(find.text('£12.00'), findsOneWidget);
      expect(find.text('Sentinel'), findsOneWidget);
      expect(find.text('+6 Trust Points'), findsOneWidget);
      expect(find.text('Health+'), findsWidgets);
      expect(find.text('Vanguard'), findsOneWidget);
      expect(find.text('Bike minimum'), findsOneWidget);
      expect(find.text('Scheduled'), findsOneWidget);
      expect(find.text('Marylebone → Chelsea'), findsOneWidget);
      expect(find.text('3.4 mi'), findsOneWidget);
      expect(find.text('22 min'), findsOneWidget);
      expect(find.text('Prescription box'), findsOneWidget);
      expect(find.text('Vehicle: Bike'), findsOneWidget);
      expect(find.text('Weight: 0.2kg'), findsOneWidget);
      expect(find.text('Pickup: Scheduled'), findsOneWidget);
      expect(find.text('Accept Delivery'), findsOneWidget);
      expect(find.text(_offers.first.pickupAddress), findsNothing);
      expect(find.text(_offers.first.dropoffAddress), findsNothing);
      expect(find.textContaining('Roth bonus'), findsNothing);
      expect(find.textContaining('Roth Bonus'), findsNothing);
    });

    testWidgets('accepted job screen is navigation-first and collapsed',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: RiderAcceptedJobScreen(offer: _offers.first),
      ));

      expect(tester.takeException(), isNull);
      expect(find.text('Navigate to Pickup'), findsWidgets);
      expect(find.text('Navigate to Drop-off'), findsNothing);
      expect(find.text(_offers.first.dropoffAddress), findsNothing);
      expect(find.text('£12.00'), findsOneWidget);
      expect(find.text('Sentinel'), findsOneWidget);
      expect(find.text('+6 Trust'), findsOneWidget);
      expect(find.text('Marylebone → Chelsea'), findsOneWidget);
      expect(find.textContaining('Reject'), findsNothing);
      expect(find.textContaining('Decline'), findsNothing);
      expect(find.textContaining('Cancel Delivery'), findsNothing);
      expect(find.textContaining('Roth'), findsNothing);
      expect(find.textContaining('Admin'), findsNothing);
    });

    testWidgets('expanded accepted panel reveals operational detail',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: RiderAcceptedJobScreen(offer: _offers.first),
      ));

      await tester.tap(find.byKey(const Key('accepted_panel_toggle')));
      await tester.pumpAndSettle();

      expect(find.text(_offers.first.pickupAddress), findsWidgets);
      expect(find.text(_offers.first.dropoffAddress), findsOneWidget);
      expect(find.textContaining('Vanguard Protection'), findsOneWidget);
      expect(find.text('IRIS Brief'), findsOneWidget);
      expect(find.text('Pickup Verification'), findsOneWidget);
      expect(find.text('Photo verification'), findsOneWidget);
      expect(find.text('Verification'), findsOneWidget);
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);
      expect(find.textContaining('Vanguard Priority'), findsOneWidget);
    });

    testWidgets('gift pickup shows required verification from backend data',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: RiderAcceptedJobScreen(offer: _offers.last),
      ));

      await tester.tap(find.byKey(const Key('accepted_panel_toggle')));
      await tester.pumpAndSettle();

      expect(find.text('Pickup Workflow'), findsOneWidget);
      expect(find.text('IRIS Recommendation'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Report Difference'), findsOneWidget);
      expect(
          find.text(
              'Gift verification: photo required. Requirements are read from the delivery record.'),
          findsOneWidget);
      expect(find.textContaining('Vanguard Protection'), findsNothing);
    });

    testWidgets('IRIS confirmation acknowledges without advancing delivery',
        (tester) async {
      final controller = _BackendStageController([]);
      final base = _offers.last;
      final offer = RiderJobOffer(
        id: base.id,
        requestId: base.requestId,
        pickupArea: base.pickupArea,
        dropoffArea: base.dropoffArea,
        pickupAddress: base.pickupAddress,
        dropoffAddress: base.dropoffAddress,
        earnings: base.earnings,
        currency: base.currency,
        distanceText: base.distanceText,
        timeText: base.timeText,
        parcelGuidance: base.parcelGuidance,
        minimumVehicle: base.minimumVehicle,
        weightText: base.weightText,
        pickupTiming: base.pickupTiming,
        warningChips: base.warningChips,
        raw: {...base.raw, 'deliveryStage': 'arrived_at_pickup'},
      );
      await tester.pumpWidget(MaterialApp(
        home: RiderAcceptedJobScreen(
          offer: offer,
          deliveryController: controller,
        ),
      ));

      await tester.tap(find.byKey(const Key('accepted_panel_toggle')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Confirm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(controller.irisConfirmationCalls, 1);
      expect(controller.actions, isEmpty);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Report Difference'), findsOneWidget);

      await tester.tap(find.text('Confirmed'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(controller.irisConfirmationCalls, 1);
    });

    testWidgets('IRIS confirmation restores from backend delivery state',
        (tester) async {
      final base = _offers.last;
      final offer = RiderJobOffer(
        id: base.id,
        requestId: base.requestId,
        pickupArea: base.pickupArea,
        dropoffArea: base.dropoffArea,
        pickupAddress: base.pickupAddress,
        dropoffAddress: base.dropoffAddress,
        earnings: base.earnings,
        currency: base.currency,
        distanceText: base.distanceText,
        timeText: base.timeText,
        parcelGuidance: base.parcelGuidance,
        minimumVehicle: base.minimumVehicle,
        weightText: base.weightText,
        pickupTiming: base.pickupTiming,
        warningChips: base.warningChips,
        raw: {
          ...base.raw,
          'deliveryStage': 'arrived_at_pickup',
          'riderIrisAcknowledgement': {
            'riderId': 'preview-rider',
            'acknowledgementStatus': 'confirmed',
          },
        },
      );
      await tester.pumpWidget(MaterialApp(
        home: RiderAcceptedJobScreen(offer: offer),
      ));

      await tester.tap(find.byKey(const Key('accepted_panel_toggle')));
      await tester.pumpAndSettle();

      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Confirm'), findsNothing);
    });

    test(
        'Rider discrepancy states are backend-read and do not mutate authority',
        () {
      final source = File('lib/app/rider_jobs/rider_job_offer_screen.dart')
          .readAsStringSync();
      expect(source, contains('Submitted - awaiting Admin review'));
      expect(source, contains('More evidence requested'));
      expect(source, contains('Approved - awaiting sender payment'));
      expect(
          source,
          contains(
              'The adjustment was approved and the Sender completed payment.'));
      expect(source,
          contains('Hold collection until Circum reviews the evidence.'));
      expect(source,
          contains('Add the requested evidence before collection continues.'));
      expect(source, contains('Report Submitted'));
      expect(source, isNot(contains("collection('deliveryAdjustments').doc")));
      expect(source, isNot(contains(".update({'price'")));
    });

    testWidgets('pickup CTA renders backend-returned delivery stage',
        (tester) async {
      final controller = _BackendStageController([
        'arrived_at_pickup',
      ]);
      final offer = RiderJobOffer(
        id: _offers.first.id,
        requestId: _offers.first.requestId,
        pickupArea: _offers.first.pickupArea,
        dropoffArea: _offers.first.dropoffArea,
        pickupAddress: _offers.first.pickupAddress,
        dropoffAddress: _offers.first.dropoffAddress,
        earnings: _offers.first.earnings,
        currency: _offers.first.currency,
        distanceText: _offers.first.distanceText,
        timeText: _offers.first.timeText,
        parcelGuidance: _offers.first.parcelGuidance,
        minimumVehicle: _offers.first.minimumVehicle,
        weightText: _offers.first.weightText,
        pickupTiming: _offers.first.pickupTiming,
        warningChips: _offers.first.warningChips,
        raw: {
          ..._offers.first.raw,
          'deliveryStage': 'navigating_to_pickup',
        },
      );

      await tester.pumpWidget(MaterialApp(
        home: RiderAcceptedJobScreen(
          offer: offer,
          deliveryController: controller,
        ),
      ));

      expect(find.text('I\'ve Arrived'), findsWidgets);
      expect(find.text('Navigate to Drop-off'), findsNothing);

      await tester.tap(find.widgetWithText(ElevatedButton, 'I\'ve Arrived'));
      await tester.pumpAndSettle();

      expect(find.text('Verify Parcel'), findsWidgets);
      expect(find.text('Navigate to Drop-off'), findsNothing);
      expect(controller.actions, ['arrived_at_pickup']);
    });

    test('rider screen does not own delivery lifecycle or waiting policy', () {
      final source = File('lib/app/rider_jobs/rider_job_offer_screen.dart')
          .readAsStringSync();
      final controller =
          File('lib/app/rider_jobs/rider_delivery_controller.dart')
              .readAsStringSync();
      final legacyHome =
          File('lib/app/home/bloc/home_bloc.dart').readAsStringSync();
      final legacyEvents =
          File('lib/app/home/bloc/home_event.dart').readAsStringSync();

      expect(source, isNot(contains('transitionPatch')));
      expect(source, isNot(contains('waitingChargeRecord')));
      expect(source, isNot(contains('noShowAvailable(DateTime')));
      expect(source, isNot(contains('FieldValue.arrayUnion')));
      expect(source, contains('CallableRiderDeliveryController'));
      expect(controller, contains("httpsCallable('recordRiderArrival')"));
      expect(controller,
          contains("httpsCallable('updateDeliveryTrackingStatus')"));
      expect(controller, contains("httpsCallable('markRiderNoShow')"));
      expect(
          controller, contains("httpsCallable('confirmRiderIrisAssessment')"));
      expect(legacyHome, isNot(contains("'status': 'outForDelivery'")));
      expect(legacyHome, isNot(contains('HomeRepo().endTrip')));
      expect(legacyEvents, isNot(contains('class StartDelivery')));
      expect(legacyEvents, isNot(contains('class RideCompleted')));
    });
  });
}

const _offers = [
  RiderJobOffer(
    id: 'one',
    requestId: 'CIR-ONE',
    pickupArea: 'Marylebone',
    dropoffArea: 'Chelsea',
    pickupAddress: '12 Harley Street, Marylebone, London W1G 9PG',
    dropoffAddress: '41 King\'s Road, Chelsea, London SW3 4NB',
    earnings: 12,
    currency: 'GBP',
    distanceText: '3.4 mi',
    timeText: '22 min',
    parcelGuidance: 'Prescription box',
    minimumVehicle: 'Bike',
    weightText: '0.2kg',
    pickupTiming: 'Scheduled',
    warningChips: ['Health+', 'Vanguard', 'Scheduled'],
    raw: {'isHealthPlus': true, 'requiresVanguard': true, 'isScheduled': true},
  ),
  RiderJobOffer(
    id: 'two',
    requestId: 'CIR-TWO',
    pickupArea: 'Soho',
    dropoffArea: 'Battersea',
    pickupAddress: '18 Dean Street, Soho, London W1D 3RL',
    dropoffAddress: '7 Prince of Wales Drive, Battersea, London SW11 4FA',
    earnings: 15,
    currency: 'GBP',
    distanceText: '4.1 mi',
    timeText: '24 min',
    parcelGuidance: 'Gift parcel',
    minimumVehicle: 'Car',
    weightText: '1.4kg',
    pickupTiming: 'ASAP',
    warningChips: ['Gift'],
    raw: {'isGift': true},
  ),
];
