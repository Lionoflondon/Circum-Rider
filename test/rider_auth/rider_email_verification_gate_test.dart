import 'package:circum_rider/app.dart';
import 'package:circum_rider/app/authentication/bloc/auth_bloc.dart';
import 'package:circum_rider/app/authentication/view/verify_email.dart';
import 'package:circum_rider/utils/app_state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestAuthBloc extends Bloc<AuthEvent, AuthState> implements AuthBloc {
  _TestAuthBloc(super.initialState) {
    on<AuthEvent>((event, emit) {
      if (event is SignOut) signOutRequested = true;
    });
  }
  bool signOutRequested = false;
  void showState(AuthState value) => emit(value);
}

void main() {
  const pending = AuthState(
    currentState: AppState.authenticated,
    authenticatedStatus: AuthenticatedStatus.emailVerificationRequired,
    status: Status.unverifiedEmail,
  );
  test('verification requirement survives transient operation statuses', () {
    for (final status in Status.values) {
      expect(
          pending.copyWith(status: status).requiresEmailVerification, isTrue);
    }
    expect(
        pending
            .copyWith(currentState: AppState.unauthenticated)
            .requiresEmailVerification,
        isFalse);
    expect(
        pending
            .copyWith(authenticatedStatus: AuthenticatedStatus.authenticated)
            .requiresEmailVerification,
        isFalse);
  });

  testWidgets(
      'verification screen survives loading and failed operations and offers sign-out',
      (tester) async {
    final bloc = _TestAuthBloc(pending);
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, child) => MaterialApp(
        home: BlocProvider<AuthBloc>.value(value: bloc, child: const App()),
      ),
    ));
    await tester.pump();
    expect(find.byType(VerifyEmailView), findsOneWidget);
    bloc.showState(pending.copyWith(status: Status.loading));
    await tester.pump();
    expect(find.byType(VerifyEmailView), findsOneWidget);
    bloc.showState(pending.copyWith(
        status: Status.failure,
        errorMessage: 'Verification could not be checked.'));
    await tester.pump();
    expect(find.byType(VerifyEmailView), findsOneWidget);
    expect(find.text('Verification could not be checked.'), findsOneWidget);
    bloc.showState(pending.copyWith(status: Status.success));
    await tester.pump();
    expect(find.byType(VerifyEmailView), findsOneWidget);
    await tester.ensureVisible(find.text('Sign out'));
    await tester.tap(find.text('Sign out'));
    await tester.pump();
    expect(bloc.signOutRequested, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await bloc.close();
  });
}
