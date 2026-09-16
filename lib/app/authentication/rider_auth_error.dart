class RiderAuthError {
  const RiderAuthError._();

  static String messageFor(String code) {
    switch (code) {
      case 'wrong-surface':
        return 'This account belongs to another Circum app. Sign in with a Rider account.';
      case 'email-already-in-use':
        return 'Account creation could not be completed. If you already have an account, sign in or reset your password.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'wrong-password':
      case 'invalid-credential':
      case 'user-not-found':
        return 'Email or password is incorrect.';
      case 'user-disabled':
        return 'This Rider account is disabled. Contact Circum Support.';
      case 'network-request-failed':
        return 'Check your connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a moment or reset your password.';
      default:
        return 'Sign in could not be completed. Please try again.';
    }
  }
}
