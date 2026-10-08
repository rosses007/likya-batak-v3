import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  static const String baseUrl = String.fromEnvironment('WS_BASE_URL',
      defaultValue: 'wss://api.bataknoir.com/ws');

  static Uri endpoint(String clientId) {
    final base = Uri.parse(baseUrl);
    if (const bool.fromEnvironment('dart.vm.product') && base.scheme != 'wss') {
      throw StateError('Release WS_BASE_URL must use WSS');
    }
    return Uri.parse('$baseUrl/matchmaking/${Uri.encodeComponent(clientId)}');
  }

  // Singleton pattern (Uygulamada tek bir instance olsun)
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  
  // Gelen verileri dinleyecek olan callback (UI bu fonksiyona abone olacak)
  Function(Map<String, dynamic>)? onMessageReceived;

  /// Sunucuya bağlanır ve client_id'yi iletir
  void connect(String clientId) {
    final wsUrl = endpoint(clientId);
    
    _channel = WebSocketChannel.connect(wsUrl);
    debugPrint("WebSocket bağlantısı başlatıldı: $clientId");

    // Sunucudan gelen mesajları sürekli dinle
    _channel!.stream.listen(
      (message) {
        final decodedData = jsonDecode(message);
        if (onMessageReceived != null) {
          onMessageReceived!(decodedData);
        }
      },
      onError: (error) {
        debugPrint('WebSocket Hatası: $error');
      },
      onDone: () {
        debugPrint('WebSocket bağlantısı kapandı.');
      },
    );
  }

  /// Sunucuya hamle gönderir (Örn: Kart atma, ihale verme)
  void sendAction(Map<String, dynamic> actionData) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(actionData));
    }
  }

  /// Bağlantıyı sonlandırır (Oyundan çıkarken)
  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
