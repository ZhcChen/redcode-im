import 'dart:async';
import 'dart:convert';
import 'dart:io';

final class NetworkFaultProxy {
  NetworkFaultProxy({
    required this.listenPort,
    required this.controlPort,
    required this.upstreamHost,
    required this.upstreamPort,
  });

  final int listenPort;
  final int controlPort;
  final String upstreamHost;
  final int upstreamPort;

  final Set<Socket> _sockets = <Socket>{};
  ServerSocket? _server;
  HttpServer? _controlServer;
  bool _enabled = true;

  Future<void> start() async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, listenPort);
    _controlServer = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      controlPort,
    );
    _server!.listen(_handleClient);
    _controlServer!.listen(_handleControlRequest);
    stdout.writeln(
      'NETWORK_FAULT_PROXY_READY listen=$listenPort control=$controlPort '
      'upstream=$upstreamHost:$upstreamPort',
    );
  }

  Future<void> close() async {
    _closeActiveSockets();
    await _server?.close();
    await _controlServer?.close(force: true);
  }

  Future<void> _handleClient(Socket client) async {
    _track(client);
    if (!_enabled) {
      client.destroy();
      return;
    }

    Socket upstream;
    try {
      upstream = await Socket.connect(upstreamHost, upstreamPort);
    } catch (_) {
      client.destroy();
      return;
    }
    _track(upstream);

    client.listen(
      upstream.add,
      onError: (_) => _destroyPair(client, upstream),
      onDone: () => _destroyPair(client, upstream),
      cancelOnError: true,
    );
    upstream.listen(
      client.add,
      onError: (_) => _destroyPair(client, upstream),
      onDone: () => _destroyPair(client, upstream),
      cancelOnError: true,
    );
  }

  Future<void> _handleControlRequest(HttpRequest request) async {
    switch (request.uri.path) {
      case '/disable':
        _enabled = false;
        _closeActiveSockets();
      case '/enable':
        _enabled = true;
      case '/status':
        break;
      default:
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
    }
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode(<String, Object>{
        'enabled': _enabled,
        'active_sockets': _sockets.length,
      }),
    );
    await request.response.close();
  }

  void _track(Socket socket) {
    _sockets.add(socket);
    unawaited(_removeWhenDone(socket));
  }

  Future<void> _removeWhenDone(Socket socket) async {
    try {
      await socket.done;
    } catch (_) {
      // 故障注入会主动销毁 socket，完成 future 可能携带连接错误。
    } finally {
      _sockets.remove(socket);
    }
  }

  void _destroyPair(Socket first, Socket second) {
    first.destroy();
    second.destroy();
    _sockets.remove(first);
    _sockets.remove(second);
  }

  void _closeActiveSockets() {
    for (final socket in _sockets.toList()) {
      socket.destroy();
    }
    _sockets.clear();
  }
}

Future<void> main(List<String> arguments) async {
  if (arguments.length != 4) {
    stderr.writeln(
      'usage: dart run network_fault_proxy.dart '
      '<listen-port> <control-port> <upstream-host> <upstream-port>',
    );
    exitCode = 64;
    return;
  }

  final proxy = NetworkFaultProxy(
    listenPort: int.parse(arguments[0]),
    controlPort: int.parse(arguments[1]),
    upstreamHost: arguments[2],
    upstreamPort: int.parse(arguments[3]),
  );
  await proxy.start();

  final done = Completer<void>();
  void complete() {
    if (!done.isCompleted) done.complete();
  }

  final interruptSubscription = ProcessSignal.sigint.watch().listen(
    (_) => complete(),
  );
  final terminateSubscription = ProcessSignal.sigterm.watch().listen(
    (_) => complete(),
  );
  await done.future;
  await interruptSubscription.cancel();
  await terminateSubscription.cancel();
  await proxy.close();
}
