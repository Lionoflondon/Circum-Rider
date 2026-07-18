import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

import '../../../helper/chats_help.dart';
import '../../communication/rider_communication_service.dart';
import '../../home/models/message.m.dart';

part 'support_event.dart';
part 'support_state.dart';

class SupportBloc extends Bloc<SupportEvent, SupportState> {
  SupportBloc() : super(SupportState()) {
    FirebaseAuth auth = FirebaseAuth.instance;
    final communication = RiderCommunicationService();
    on<SupportEvent>((event, emit) {
      // TODO: implement event handler
    });

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
          final messageData = {
            "requestId": "support",
            'senderId': user.uid,
            'message': msg,
            'timeStamp': '${DateTime.now()}'
          };

          add(IncomingSupportMessage(data: messageData));

          ChatsHelper().storeChat(messageData);
        } catch (_) {}
      },
    );

    on<LoadSupportChatMessages>(
      (event, emit) async {
        final directory = await getApplicationDocumentsDirectory();
        final chats = File('${directory.path}/support.json');

        if (await chats.exists()) {
          final contents = await chats.readAsString();
          // print(contents);
          final jsonData = await jsonDecode(contents) as List;

          final messagesList =
              jsonData.map((e) => Message.fromJson(e)).toList();
          emit(state.copyWith(
              chatMessages: messagesList, chatStatus: ChatStatus.newMessage));
        }
      },
    );
  }
}
