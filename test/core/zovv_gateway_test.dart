import 'package:flutter_test/flutter_test.dart';
import 'package:zovv/core/config/zovv_gateway.dart';

void main() {
  test('endpoint builds URIs against the configured gateway', () {
    final uri = ZovvGateway.endpoint('/search', {'q': '荒年'});
    expect(uri.path, '/search');
    expect(uri.queryParameters['q'], '荒年');
    final defaults = Uri.parse('http://127.0.0.1:8765');
    expect(uri.scheme, defaults.scheme);
    expect(uri.host, defaults.host);
    expect(uri.port, defaults.port);
  });

  test('media URLs must belong to the configured gateway origin', () {
    final base = Uri.parse(ZovvGateway.baseUrl);
    final own = base.replace(path: '/media/${List.filled(48, 'a').join()}.mp4');
    expect(ZovvGateway.sameOrigin(own), isTrue);
    expect(
      ZovvGateway.sameOrigin(Uri.parse('http://example.com/media/a.mp4')),
      isFalse,
    );
    expect(
      ZovvGateway.sameOrigin(base.replace(port: base.port + 1, path: '/x')),
      isFalse,
    );
  });
}
