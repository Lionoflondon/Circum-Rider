import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../authentication/bloc/auth_bloc.dart';
import '../authentication/view/add_details.dart';
import '../authentication/view/widgets/rider_onboarding_shell.dart';
import 'rider_account_state.dart';
import '../support/view/support.dart';

class RiderAccountStatusView extends StatelessWidget {
  const RiderAccountStatusView({super.key, required this.accountState});

  final RiderAccountState accountState;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('riders').doc(uid).snapshots(),
      builder: (context, riderSnapshot) =>
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('riderProfiles')
            .doc(uid)
            .snapshots(),
        builder: (context, profileSnapshot) {
          final data = <String, dynamic>{
            ...?riderSnapshot.data?.data(),
            ...?profileSnapshot.data?.data(),
          };
          final content = _content(accountState, data);
          return RiderOnboardingShell(
            currentStep:
                accountState == RiderAccountState.moreInformationRequired
                    ? 5
                    : 6,
            title: content.$1,
            subtitle: content.$2,
            showBackButton: false,
            child: RiderGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(content.$3, color: content.$4, size: 38),
                  const SizedBox(height: 18),
                  Text(content.$5,
                      style: const TextStyle(
                          color: Color(0xFFD1D5DB), height: 1.45)),
                  const SizedBox(height: 22),
                  if (accountState == RiderAccountState.moreInformationRequired)
                    RiderPrimaryButton(
                      label: 'Continue application',
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AddDetailsView()),
                      ),
                    ),
                  if (accountState == RiderAccountState.rejected)
                    RiderPrimaryButton(
                      label: 'Resubmit documents',
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AddDetailsView()),
                      ),
                    ),
                  if (accountState == RiderAccountState.closed)
                    RiderPrimaryButton(
                      label: 'Sign out',
                      onPressed: () => context.read<AuthBloc>().add(SignOut()),
                    ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SupportView()),
                    ),
                    child: const Text('Contact Circum Support'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  (String, String, IconData, Color, String) _content(
      RiderAccountState state, Map<String, dynamic> data) {
    final rejectionReason =
        '${data['rejectionReason'] ?? data['adminRejectionReason'] ?? ''}'
            .trim();
    final requested = data['requestedInformation'] is Iterable
        ? (data['requestedInformation'] as Iterable).join(', ')
        : '${data['moreInformationReason'] ?? ''}'.trim();
    return switch (state) {
      RiderAccountState.rejected => (
          'Application update',
          'Your Rider application was not approved.',
          Icons.cancel_outlined,
          const Color(0xFFF87171),
          rejectionReason.isEmpty
              ? 'Contact support if you need help understanding this decision.'
              : rejectionReason
        ),
      RiderAccountState.suspended => (
          'Account suspended',
          'Your Rider account is paused by Circum Support.',
          Icons.pause_circle_outline,
          const Color(0xFFFBBF24),
          'You cannot go online or accept work while your account is suspended.'
        ),
      RiderAccountState.frozen => (
          'Account frozen',
          'Your Rider account is under review.',
          Icons.lock_outline,
          const Color(0xFF60A5FA),
          'Please contact Circum Support for the next steps.'
        ),
      RiderAccountState.closed => (
          'Account closed',
          'This Rider account is no longer active.',
          Icons.person_off_outlined,
          const Color(0xFF9CA3AF),
          'Sign out, or contact Circum Support if you believe this is incorrect.'
        ),
      RiderAccountState.moreInformationRequired => (
          'More information needed',
          'Your application needs a little more information before review can continue.',
          Icons.assignment_late_outlined,
          const Color(0xFFA78BFA),
          requested.isEmpty
              ? 'Continue your saved application. Your existing details will be kept.'
              : 'Requested: $requested'
        ),
      _ => (
          'Application status',
          'Your Rider account is being reviewed.',
          Icons.schedule_outlined,
          const Color(0xFF60A5FA),
          'We will notify you when there is an update.'
        ),
    };
  }
}
