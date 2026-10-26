/// Where the source gateway lives.
///
/// Local development keeps the default (`http://127.0.0.1:8765` over `adb
/// reverse`). A packaged build points at a deployed gateway:
///
/// ```powershell
/// flutter build apk --release `
///   --dart-define=ZOVV_GATEWAY=https://api.example.com `
///   --dart-define=ZOVV_GATEWAY_TOKEN=... # optional shared token
/// ```
abstract final class ZovvGateway {
  static const String baseUrl = String.fromEnvironment(
    'ZOVV_GATEWAY',
    defaultValue: 'http://127.0.0.1:8765',
  );
  static const String token = String.fromEnvironment('ZOVV_GATEWAY_TOKEN');
  static final Uri base = Uri.parse(baseUrl);

  static bool get isLoopback =>
      base.host == '127.0.0.1' || base.host == 'localhost';

  static Uri endpoint(String path, Map<String, String> query) =>
      base.replace(path: path, queryParameters: query.isEmpty ? null : query);

  /// True when [uri] points at this gateway (used to accept its media URLs).
  static bool sameOrigin(Uri uri) =>
      uri.scheme == base.scheme &&
      uri.host == base.host &&
      uri.port == base.port;

  static Map<String, String> get headers =>
      token.isEmpty ? const {} : {'Authorization': 'Bearer $token'};
}
