import 'dart:io';

import 'package:circum_rider/app/communication/rider_communication_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rider canonical communication contract', () {
    final serviceSource =
        File('lib/app/communication/rider_communication_service.dart')
            .readAsStringSync();
    final conversationSource =
        File('lib/app/communication/rider_conversation_view.dart')
            .readAsStringSync();
    final supportBloc =
        File('lib/app/support/bloc/support_bloc.dart').readAsStringSync();
    final homeBloc =
        File('lib/app/home/bloc/home_bloc.dart').readAsStringSync();
    final supportView =
        File('lib/app/support/view/support.dart').readAsStringSync();
    final acceptedDelivery =
        File('lib/app/rider_jobs/rider_job_offer_screen.dart')
            .readAsStringSync();

    test('Rider sends messages through canonical communication callables', () {
      expect(serviceSource, contains("httpsCallable('sendCircumMessage')"));
      expect(serviceSource, contains("httpsCallable('setConversationTyping')"));
      expect(serviceSource, contains("httpsCallable('markConversationRead')"));
      expect(supportBloc, contains('communication.sendText'));
      expect(homeBloc, contains('_communicationService.sendText'));
      expect(
          homeBloc,
          isNot(contains(
              'MessagingServer().sendMessage(data: {\n        "type": "message"')));
    });

    test(
        'new Rider chat writes do not use legacy direct Firestore message writes',
        () {
      expect(supportBloc, isNot(contains("collection('messages')")));
      expect(supportBloc, isNot(contains('.doc().set(messageData)')));
      expect(homeBloc, isNot(contains('sendRiderUpdate')));
      expect(serviceSource, contains("collection('chats')"));
      expect(serviceSource, contains(".collection('messages')"));
    });

    test('delivery and support entries open canonical conversation view', () {
      expect(supportView, contains('RiderConversationView'));
      expect(supportView, contains('admin_rider_'));
      expect(acceptedDelivery, contains('RiderConversationView'));
      expect(acceptedDelivery, contains('chatId: offer.requestId'));
      expect(acceptedDelivery, isNot(contains('RideChatPageView')));
    });

    test('completed chat is read-only in the Rider UI', () {
      expect(conversationSource, contains('conversation.readOnly'));
      expect(conversationSource, contains('This delivery is complete.'));
      expect(
          conversationSource, contains('onPressed: sending ? null : onSend'));
      expect(conversationSource,
          contains('Message failed. Check your connection and retry.'));
    });

    test('support conversation exposes recoverable load and send failures', () {
      expect(conversationSource, contains('_ConversationLoading'));
      expect(conversationSource, contains('_ConversationLoadError'));
      expect(conversationSource, contains('_retryConversation'));
      expect(
          conversationSource, contains('We could not load this conversation.'));
      expect(conversationSource, contains("const Text('Retry')"));
      expect(
          conversationSource, contains('onPressed: _sending ? null : _send'));
      expect(conversationSource, contains('_input.clear();'));
      expect(conversationSource, contains('SharedPreferences.getInstance()'));
      expect(conversationSource, contains('_restoreDraft()'));
      expect(conversationSource, contains('_saveDraft(value)'));
      expect(conversationSource, contains('await _clearDraft();'));
      expect(
        conversationSource.indexOf('_input.clear();'),
        greaterThan(conversationSource.indexOf('await _service.sendText')),
      );
    });

    test('typing and read receipts are controlled and not high-frequency', () {
      expect(serviceSource, contains('class RiderTypingController'));
      expect(serviceSource,
          contains('debounce = const Duration(milliseconds: 900)'));
      expect(serviceSource, contains('idle = const Duration(seconds: 4)'));
      expect(serviceSource, contains('void dispose() => clear();'));
      expect(conversationSource, contains('_markReadOnce'));
    });

    test('notification categories normalize actual backend variants', () {
      expect(normalizeNotificationCategory('chat_message'), 'messages');
      expect(normalizeNotificationCategory('delivery_completed'), 'deliveries');
      expect(normalizeNotificationCategory('wallet_payout_failed'), 'earnings');
      expect(normalizeNotificationCategory('document_required'), 'account');
      expect(normalizeNotificationCategory('scheduled_pickup'), 'schedule');
      expect(normalizeNotificationCategory('new_delivery'), 'jobs');
    });

    test('Rider push payload parsing is recoverable and diagnostic', () {
      final messaging = File('lib/messaging.dart').readAsStringSync();

      expect(messaging, contains('_decodeRiderCommunicationPayload'));
      expect(messaging, contains('_logRecoverableRiderPushPayload'));
      expect(messaging, contains('Recoverable Rider push payload discarded'));
      expect(
          messaging,
          isNot(contains(
              "Map<String, dynamic> msg = jsonDecode(message.data['data'])")));
    });
  });

  group('Rider Notification Centre contract', () {
    final notificationSource =
        File('lib/app/notifications/rider_notifications_view.dart')
            .readAsStringSync();
    final dashboard = File('lib/app/rider_shell/rider_dashboard_view.dart')
        .readAsStringSync();
    final profile =
        File('lib/app/rider_shell/rider_profile_view.dart').readAsStringSync();

    test('Notification Centre supports categories and actions', () {
      for (final label in [
        'All',
        'Jobs',
        'Deliveries',
        'Messages',
        'Schedule',
        'Earnings',
        'Account',
        'System',
      ]) {
        expect(notificationSource, contains("'$label'"));
      }
      expect(notificationSource, contains('markAllNotificationsRead'));
      expect(notificationSource, contains('archiveNotification'));
      expect(notificationSource, contains('deleteNotification'));
      expect(notificationSource, contains('markNotificationRead'));
    });

    test('Notification Centre routes to Rider destinations', () {
      expect(notificationSource, contains('RiderConversationView'));
      expect(notificationSource, contains("return 1"));
      expect(notificationSource, contains("return 2"));
      expect(notificationSource, contains("return 3"));
      expect(notificationSource, contains("return 4"));
      expect(
          notificationSource, contains('This update is no longer available'));
    });

    test('Home badge uses same unread notification source', () {
      expect(dashboard, contains('watchUnreadNotificationCount'));
      expect(dashboard, contains('RiderNotificationsView'));
      expect(dashboard,
          contains('RiderNotificationsView(onNavigateTab: onSelectTab)'));
      expect(profile, contains('RiderNotificationsView'));
      expect(profile, contains('onNavigateTab: onSelectTab'));
    });

    test('Notification Centre uses grouped glass presentation', () {
      expect(notificationSource, contains('_groupNotifications'));
      expect(notificationSource, contains("'Today'"));
      expect(notificationSource, contains("'Yesterday'"));
      expect(notificationSource, contains("'Earlier'"));
      expect(notificationSource, contains('_DayGroup'));
      expect(notificationSource, contains('RiderGlassSurface'));
      expect(notificationSource,
          contains('edgeColor: unread ? RiderPalette.blue : accent'));
      expect(notificationSource, contains('_NotificationEmptyState'));
    });

    test('Notification Centre preserves semantic icon colours', () {
      expect(notificationSource, contains('RiderPalette.green'));
      expect(notificationSource, contains('RiderPalette.amber'));
      expect(notificationSource, contains('RiderPalette.purple'));
      expect(notificationSource, contains('RiderPalette.red'));
      expect(notificationSource, contains('Icons.work_outline_rounded'));
      expect(notificationSource, contains('Icons.route_rounded'));
      expect(notificationSource, contains('Icons.chat_bubble_outline_rounded'));
      expect(notificationSource, contains('Icons.calendar_month_outlined'));
      expect(notificationSource,
          contains('Icons.account_balance_wallet_outlined'));
      expect(notificationSource, contains('Icons.person_outline_rounded'));
    });
  });
}
