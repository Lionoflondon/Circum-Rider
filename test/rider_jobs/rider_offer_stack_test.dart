import 'package:circum_rider/app/rider_jobs/rider_job_offer_screen.dart';
import 'package:circum_rider/app/rider_jobs/rider_offer_card.dart';
import 'package:circum_rider/app/rider_jobs/rider_offer_stack.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

void main() {
  test('offer earnings presentation has no bonus reward system', () {
    final source =
        File('lib/app/rider_jobs/rider_offer_card.dart').readAsStringSync();
    expect(source.toLowerCase(), isNot(contains('bonus')));
    expect(source, contains('Estimated earnings'));
    expect(source, contains('Trust Points'));
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

    testWidgets('standard pickup stays lightweight', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: RiderAcceptedJobScreen(offer: _offers.last),
      ));

      await tester.tap(find.byKey(const Key('accepted_panel_toggle')));
      await tester.pumpAndSettle();

      expect(find.text('Pickup Workflow'), findsOneWidget);
      expect(find.text('Confirm parcel matches booking'), findsOneWidget);
      expect(find.text('Pickup Verification'), findsNothing);
      expect(find.textContaining('Vanguard Protection'), findsNothing);
    });

    testWidgets('pickup CTA progresses sequentially', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: RiderAcceptedJobScreen(offer: _offers.first),
      ));

      expect(find.text('Navigate to Pickup'), findsWidgets);
      expect(find.text('I\'ve Arrived'), findsNothing);

      await tester
          .tap(find.widgetWithText(ElevatedButton, 'Navigate to Pickup'));
      await tester.pumpAndSettle();

      expect(find.text('I\'ve Arrived'), findsWidgets);
      expect(find.text('Navigate to Drop-off'), findsNothing);

      await tester.tap(find.widgetWithText(ElevatedButton, 'I\'ve Arrived'));
      await tester.pumpAndSettle();

      expect(find.text('Verify Parcel'), findsWidgets);
      expect(find.text('Navigate to Drop-off'), findsNothing);
    });

    test('stage policy blocks invalid and unassigned transitions', () {
      final delivery = {'riderId': 'rider-one'};
      expect(
        RiderDeliveryStagePolicy.canAdvance(
          riderId: 'rider-one',
          delivery: delivery,
          current: RiderDeliveryStage.accepted,
          target: RiderDeliveryStage.navigatingToPickup,
          verificationRequired: true,
          pinRequired: true,
        ),
        isTrue,
      );
      expect(
        RiderDeliveryStagePolicy.canAdvance(
          riderId: 'rider-one',
          delivery: delivery,
          current: RiderDeliveryStage.accepted,
          target: RiderDeliveryStage.navigatingToDropoff,
          verificationRequired: true,
          pinRequired: true,
        ),
        isFalse,
      );
      expect(
        RiderDeliveryStagePolicy.canAdvance(
          riderId: 'other-rider',
          delivery: delivery,
          current: RiderDeliveryStage.accepted,
          target: RiderDeliveryStage.navigatingToPickup,
          verificationRequired: true,
          pinRequired: true,
        ),
        isFalse,
      );
      expect(
        RiderDeliveryStagePolicy.nextStage(
          RiderDeliveryStage.arrivedAtPickup,
          verificationRequired: true,
          pinRequired: true,
        ),
        RiderDeliveryStage.pickupVerification,
      );
      expect(
        RiderDeliveryStagePolicy.nextStage(
          RiderDeliveryStage.arrivedAtDropoff,
          verificationRequired: true,
          pinRequired: true,
        ),
        RiderDeliveryStage.waiting,
      );
      expect(
        RiderDeliveryStagePolicy.nextStage(
          RiderDeliveryStage.waiting,
          verificationRequired: true,
          pinRequired: true,
        ),
        RiderDeliveryStage.pinRequired,
      );
    });

    test('arrival backend patch starts wait timer and notification', () {
      final now = DateTime.utc(2026, 7, 4, 12);
      final patch = RiderDeliveryStagePolicy.transitionPatch(
        deliveryId: 'delivery-1',
        riderId: 'rider-one',
        from: RiderDeliveryStage.navigatingToPickup,
        to: RiderDeliveryStage.arrivedAtPickup,
        now: now,
        arrivalLocation: const {'lat': 51.5, 'lng': -0.1},
      );

      expect(patch['state'], 'arrived_at_pickup');
      expect(patch['updatedBy'], 'rider-one');
      expect(patch['arrivalLocation'], {'lat': 51.5, 'lng': -0.1});
      expect(patch['pickupArrivedAt'], isA<Timestamp>());
      expect(patch['waiting']['active'], isTrue);
      expect(patch['waiting']['freeWaitMinutes'], 3);
      expect(patch['waiting']['freeWaitEndsAt'], isA<Timestamp>());
      expect(patch['pendingNotification']['recipient'], 'sender');
      expect(
        patch['pendingNotification']['message'],
        'Your rider is outside.',
      );
      expect(patch['history'], isA<FieldValue>());
    });

    test('dropoff arrival notifies receiver and starts backend wait', () {
      final now = DateTime.utc(2026, 7, 4, 12);
      final patch = RiderDeliveryStagePolicy.transitionPatch(
        deliveryId: 'delivery-1',
        riderId: 'rider-one',
        from: RiderDeliveryStage.navigatingToDropoff,
        to: RiderDeliveryStage.arrivedAtDropoff,
        now: now,
      );

      expect(patch['state'], 'arrived_at_dropoff');
      expect(patch['dropoffArrivedAt'], isA<Timestamp>());
      expect(patch['waiting']['phase'], 'dropoff');
      expect(patch['pendingNotification']['recipient'], 'receiver');
      expect(
        patch['pendingNotification']['message'],
        'Your rider is outside.',
      );
    });

    test('no-show and waiting charge only unlock after free wait', () {
      final arrived = DateTime.utc(2026, 7, 4, 12);
      final before = arrived.add(const Duration(minutes: 2, seconds: 59));
      final after = arrived.add(const Duration(minutes: 4));

      expect(RiderDeliveryStagePolicy.noShowAvailable(arrived, before), false);
      expect(RiderDeliveryStagePolicy.noShowAvailable(arrived, after), true);
      expect(
        RiderDeliveryStagePolicy.waitingChargeRecord(
          deliveryId: 'delivery-1',
          riderId: 'rider-one',
          arrivedAt: arrived,
          now: before,
          amountPennies: 150,
        ),
        isNull,
      );

      final charge = RiderDeliveryStagePolicy.waitingChargeRecord(
        deliveryId: 'delivery-1',
        riderId: 'rider-one',
        arrivedAt: arrived,
        now: after,
        amountPennies: 150,
      );
      expect(charge, isNotNull);
      expect(charge!['chargeType'], 'waiting');
      expect(charge['amount'], 150);
      expect(charge['auditEvent']['state'], 'waiting_charge_recorded');
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
