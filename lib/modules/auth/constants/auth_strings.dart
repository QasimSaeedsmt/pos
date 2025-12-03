class AuthStrings {
  // Login Screen
  static const String welcomeBack = 'Welcome Back';
  static const String signInToContinue = 'Sign in to continue your journey';
  static const String emailAddress = 'Email Address';
  static const String password = 'Password';
  static const String keepMeLoggedIn = 'Keep me logged in';
  static const String forgotPassword = 'Forgot Password?';
  static const String signIn = 'Sign In';
  static const String newToPlatform = 'New to our platform?';
  static const String createAccount = 'Create account';

  // Validation
  static const String pleaseEnterEmail = 'Please enter your email';
  static const String pleaseEnterValidEmail = 'Please enter a valid email';
  static const String pleaseEnterPassword = 'Please enter your password';
  static const String passwordTooShort = 'Password must be at least 6 characters';

  // Errors
  static const String loginFailed = 'Login failed';
  static const String userNotFound = 'No user found with this email';
  static const String incorrectPassword = 'Incorrect password';
  static const String invalidEmail = 'Invalid email address';
  static const String userDisabled = 'This account has been disabled';
  static const String tooManyAttempts = 'Too many attempts. Please try again later';
  static const String networkError = 'Network error. Please check your connection';
  static const String failedLoadUserData = 'Failed to load user data';

  // Forgot Password
  static const String resetYourPassword = 'Reset Your Password';
  static const String resetInstructions = 'Enter your email and we\'ll send you a password reset link.';
  static const String howItWorks = 'How it works:';
  static const String resetSteps = '1. Enter your email below\n'
      '2. Check your inbox for the reset link\n'
      '3. Click the link to set a new password\n'
      '4. Return here to login with your new password';
  static const String sendResetLink = 'Send Reset Link';
  static const String backToLogin = 'Back to Login';
  static const String resetEmailSent = 'Password reset email sent! Check your inbox for the reset link.';
  static const String passwordResetSuccess = 'Password reset successfully! You can now login with your new password.';

  // App Lock
  static const String appLocked = 'App Locked';
  static const String authenticateToContinue = 'Authenticate to continue';
  static const String authenticating = 'Authenticating...';
  static const String touchFingerprint = 'Touch the fingerprint sensor';
  static const String tryAgain = 'Try Again';
  static const String useDifferentAccount = 'Use Different Account';
  static const String authenticateNow = 'Authenticate Now';

  // Account Disabled
  static const String accountDisabled = 'Account Disabled';
  static const String accountDisabledMessage = 'Your account has been disabled. Please contact your administrator or check your subscription status.';
  static const String returnToLogin = 'Return to Login';

  // Settings
  static const String securitySettings = 'Security Settings';
  static const String biometricStatus = 'Biometric Status';
  static const String availableBiometricMethods = 'Available biometric methods:';
  static const String noBiometricMethods = 'No biometric methods available';
  static const String enableAppLock = 'Enable App Lock';
  static const String appLockDescription = 'Require biometric authentication to open the app';
  static const String autoLockTimeout = 'Auto Lock Timeout';
  static const String autoLockDescription = 'Set when the app automatically locks';
  static const String lastUnlock = 'Last Unlock';
  static const String neverUnlocked = 'Never unlocked';
  static const String securityFeatures = 'Security Features';
  static const String requireBiometricOnResume = 'Require Biometric on App Resume';
  static const String requireBiometricDescription = 'Always require biometric when app comes from background';
  static const String biometricFallbackToPin = 'Biometric Fallback to PIN';
  static const String fallbackDescription = 'Allow PIN entry if biometric fails multiple times';
  static const String quickActions = 'Quick Actions';
  static const String testBiometricNow = 'Test Biometric Now';
  static const String testBiometricDescription = 'Verify your biometric authentication is working';
  static const String forceAppLock = 'Force App Lock Now';
  static const String forceAppLockDescription = 'Immediately lock the app for testing';
  static const String appLockActive = 'App Lock Active';
  static const String appLockActiveDescription = 'Your app is protected with biometric authentication. You will need to authenticate when:';
  static const String appLockCondition1 = 'Opening the app after it was closed';
  static const String appLockCondition2 = 'Returning to the app after timeout period';

  // Biometric Types
  static const String faceId = 'Face ID';
  static const String fingerprint = 'Fingerprint';
  static const String irisScan = 'Iris Scan';
  static const String strongBiometric = 'Strong Biometric';
  static const String weakBiometric = 'Weak Biometric';

  // Messages
  static const String biometricTestSuccess = 'Biometric test successful!';
  static const String biometricTestFailed = 'Biometric test failed';
  static const String appLockEnabled = 'App lock enabled';
  static const String appLockDisabled = 'App lock disabled';
  static const String reauthenticatedSuccess = 'Re-authenticated successfully';
  static const String reauthenticatedFailed = 'Re-authentication failed';
  static const String featureComingSoon = 'Feature coming soon';
  static const String appWillLock = 'App will lock on next open';
}