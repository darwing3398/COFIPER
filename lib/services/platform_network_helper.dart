export 'platform_network_stub.dart'
    if (dart.library.io) 'platform_network_io.dart'
    if (dart.library.js_interop) 'platform_network_web.dart';
