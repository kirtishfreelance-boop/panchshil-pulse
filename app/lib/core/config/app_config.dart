/// Environment configuration.
///
/// Override at build time without touching source:
///   flutter run --dart-define=PULSE_API_BASE=https://pulse-api.example.com
abstract final class AppConfig {
  static const appName = 'Panchshil Pulse';

  /// 10.0.2.2 is the host machine as seen from the Android emulator.
  /// Use your LAN IP for a physical device, and localhost for iOS simulator.
  static const apiBaseUrl = String.fromEnvironment(
    'PULSE_API_BASE',
    defaultValue: 'http://10.0.2.2:4000',
  );

  static const supportWhatsApp = '+918380027272';
  static const supportEmail = 'pulse@panchshil.com';

  /// Generous on purpose: free hosting tiers idle the container after ~15
  /// minutes, and the first request afterwards waits for a cold start.
  static const connectTimeout = Duration(seconds: 60);
  static const receiveTimeout = Duration(seconds: 90);

  /// True when the API is not on the same machine as the app, i.e. the splash
  /// should warm the server before the first real call.
  static bool get isRemoteApi => !apiBaseUrl.contains('10.0.2.2') &&
      !apiBaseUrl.contains('localhost') &&
      !apiBaseUrl.contains('127.0.0.1');

  /// The dev backend echoes the OTP so the login screen can pre-fill it.
  static const prefillOtpInDebug = true;
}
