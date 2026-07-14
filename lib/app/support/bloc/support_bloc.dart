import 'package:bloc/bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../communication/rider_communication_service.dart';
import '../../home/models/message.m.dart';

part 'support_event.dart';
part 'support_state.dart';

class SupportBloc extends Bloc<SupportEvent, SupportState> {
  SupportBloc() : super(SupportState()) {
    FirebaseAuth auth = FirebaseAuth.instance;
    final communication = RiderCommunicationService();

    on<SetNewSupportMessage>(
      (event, emit) {
        emit(state.copyWith(message: event.value));
      },
    );

    on<IncomingSupportMessage>(
      (event, emit) async {
        final chatMessages = [...state.chatMessages];

        final newMessage = Message.fromJson(event.data);
        chatMessages.add(newMessage);

        emit(state.copyWith(
            chatMessages: chatMessages, chatStatus: ChatStatus.newMessage));
      },
    );

    on<MessageSupport>(
      (event, emit) async {
        try {
          final User? user = auth.currentUser;
          String msg = event.message;

          emit(state.copyWith(message: ''));
          final chatId = 'admin_rider_${user!.uid}_general';
          await communication.sendText(chatId: chatId, message: msg);
        } catch (_) {
          emit(state.copyWith(message: event.message));
        }
      },
    );

    on<LoadSupportChatMessages>(
      (event, emit) async {},
    );
  }
}
