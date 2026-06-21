import 'package:socket_io_client/socket_io_client.dart' as io;
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

/// Wraps socket_io_client to match utils/socket.js on the backend exactly:
///
/// - Auth: the raw JWT goes in `auth: {'token': token}` — NOT prefixed with
///   "Bearer ", because the server calls `jwt.verify(token, ...)` directly
///   on whatever string arrives in `socket.handshake.auth.token`.
/// - DMs need no "join" step — the server tracks userId → socketId itself
///   and pushes `new-message` / `direct-message-updated` / `dm-message-pinned`
///   straight to your socket(s) once you're connected.
/// - Channels DO need a join: emit `joinChannel` with the channelId as a
///   plain string (not wrapped in an object) before you'll receive
///   `new-channel-message` / `channel-message-updated` / `channel-message-pinned`
///   for that channel.
class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  io.Socket? _socket;
  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (_socket != null && isConnected) return;

    final token = await SecureStorage.instance.getToken();
    if (token == null || token.isEmpty) return;

    _socket = io.io(
      ApiConstants.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );
  }

  void joinChannel(String channelId) {
    _socket?.emit('joinChannel', channelId);
  }

  void requestOnlineUsers() {
    _socket?.emit('getOnlineUsers');
  }

  void on(String event, void Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  void off(String event, [void Function(dynamic)? handler]) {
    if (handler != null) {
      _socket?.off(event, handler);
    } else {
      _socket?.off(event);
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
