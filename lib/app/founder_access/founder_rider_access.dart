import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

abstract final class FounderRiderAccess {
  static Future<bool> enabled({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final token = await user.getIdTokenResult(forceRefresh);
    return token.claims?['founderRider'] == true;
  }
}

class FounderRiderBadge extends StatelessWidget {
  const FounderRiderBadge({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: FounderRiderAccess.enabled(),
        builder: (context, snapshot) => snapshot.data == true
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x22A78BFA),
                  border: Border.all(color: const Color(0x66A78BFA)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('Test access',
                    style: TextStyle(
                        color: Color(0xFFA78BFA),
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              )
            : const SizedBox.shrink(),
      );
}
