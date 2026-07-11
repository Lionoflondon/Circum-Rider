import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../utils/theme/theme.dart';
import '../../onboarding/rider_guide_view.dart';
import '../../rider_account/rider_account_state.dart';
import '../bloc/auth_bloc.dart';

class ApplicationSubmittedView extends StatelessWidget {
  const ApplicationSubmittedView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('riders')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final progress = RiderApprovalProgress.fromBackend(
          accountExists: snapshot.data?.exists == true,
          firebaseEmailVerified: user.emailVerified,
          rider: snapshot.data?.data() ?? const <String, dynamic>{},
        );
        return _buildScreen(context, progress);
      },
    );
  }

  Widget _buildScreen(BuildContext context, RiderApprovalProgress progress) {
    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText.text(
                'Welcome to Circum.',
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
              const SizedBox(height: 12),
              AppText.text(
                "Your rider application has been received. Our team will review your details and notify you once you're approved.",
                color: AppColors.textGrey,
                fontSize: 16,
              ),
              const SizedBox(height: 24),
              RiderGuideEntryCard(
                progress: progress,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RiderGuideView(
                      authenticated: true,
                      progress: progress,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              RiderGuideProgressCard(progress: progress),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color:
                                    AppColors.warning.withValues(alpha: 0.4)),
                          ),
                          child: AppText.text(
                            'Pending Review',
                            color: AppColors.warning,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _timeline('Account Created', progress.accountCreated),
                        _timeline('Email Verified', progress.emailVerified),
                        _timeline('Application Submitted',
                            progress.applicationSubmitted),
                        _timeline('Under Review', progress.underReview),
                        _timeline('Approved', progress.approved),
                        _timeline('Ready to Deliver', progress.readyToDeliver),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              AppButton.button(
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                onPressed: () => context.read<AuthBloc>().add(SignOut()),
                widget: AppText.text(
                  'Sign out',
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeline(String label, bool complete) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(
            complete ? Icons.check_circle : Icons.radio_button_unchecked,
            color: complete ? AppColors.success : AppColors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          AppText.text(
            label,
            color: complete ? Colors.white : AppColors.textGrey,
            fontWeight: complete ? FontWeight.w800 : FontWeight.w600,
          ),
        ],
      ),
    );
  }
}
