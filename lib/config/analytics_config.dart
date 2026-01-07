/// Analytics configuration for Batch-20260107-083440-platformer-01
class AnalyticsConfig {
  AnalyticsConfig._();

  /// Game identifier
  static const String gameId = '0f3d4e16-71f4-42b8-8bef-da0f88305821';
  
  /// App version
  static const String appVersion = '1.0.0';
  
  /// Backend URL for event forwarding
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://api.gamefactory.com',
  );
  
  /// API key for backend authentication
  static const String apiKey = String.fromEnvironment(
    'API_KEY',
    defaultValue: '',
  );
  
  /// Whether to forward events to backend
  static const bool forwardToBackend = true;
  
  /// Debug mode logging
  static const bool debugLogging = bool.fromEnvironment('DEBUG', defaultValue: false);
}
