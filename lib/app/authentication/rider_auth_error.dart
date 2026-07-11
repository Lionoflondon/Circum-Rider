class RiderAuthError {
  const RiderAuthError._();

  static String messageFor(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'wrong-password':
        return 'The password is incorrect. Try again or reset it.';
      case 'invalid-credential':
        return 'The email or password is incorrect.';
      case 'user-not-found':
        return 'No Rider account was found for that email.';
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
