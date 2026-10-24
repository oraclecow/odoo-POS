import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../models/delivery_order.dart';
import '../../models/juice_product.dart';
import 'delivery_http_listener_base.dart';

class DeliveryHttpListener implements DeliveryHttpListenerBase {
  HttpServer? _server;
  int _port = 8088;

  @override
  bool get isRunning => _server != null;

  @override
  int get port => _port;

  @override
  Future<bool> start({
    int port = 8088,
    required Future<Map<String, dynamic>> Function(IncomingDeliveryOrder order) onOrderReceived,
    required List<JuiceProduct> Function() getCatalog,
  }) async {
    if (_server != null) {
      await stop();
    }
    _port = port;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      debugPrint('[DeliveryListener] Listening on http://0.0.0.0:$_port');

      _server!.listen((HttpRequest request) async {
        _handleCors(request);

        if (request.method == 'OPTIONS') {
          request.response.statusCode = HttpStatus.noContent;
          await request.response.close();
          return;
        }

        final path = request.uri.path;

        try {
          if (request.method == 'GET' && (path == '/health' || path == '/api/status')) {
            await _respondJson(request, HttpStatus.ok, {
              'status': 'ok',
              'service': 'PAJ POS Delivery Listener',
              'port': _port,
              'timestamp': DateTime.now().toIso8601String(),
            });
          } else if (request.method == 'GET' && path == '/api/catalog') {
            final catalog = getCatalog().map((p) => {
              'id': p.id,
              'name': p.name,
              'price': p.price,
              'category': p.category,
            }).toList();
            await _respondJson(request, HttpStatus.ok, {
              'count': catalog.length,
              'products': catalog,
            });
          } else if (request.method == 'POST' && (path == '/api/delivery/order' || path == '/api/order')) {
            final content = await utf8.decoder.bind(request).join();
            if (content.trim().isEmpty) {
              await _respondJson(request, HttpStatus.badRequest, {
                'success': false,
                'error': 'Empty request body',
              });
              return;
            }

            final Map<String, dynamic> body;
            try {
              body = jsonDecode(content) as Map<String, dynamic>;
            } catch (e) {
              await _respondJson(request, HttpStatus.badRequest, {
                'success': false,
                'error': 'Invalid JSON format: $e',
              });
              return;
            }

            final order = IncomingDeliveryOrder.fromJson(body);
            debugPrint('[DeliveryListener] Received order ${order.orderId} from ${order.channelLabel}');

            final result = await onOrderReceived(order);
            await _respondJson(request, HttpStatus.ok, {
              'success': true,
              'order_id': order.orderId,
              'platform': order.channelLabel,
              ...result,
            });
          } else {
            await _respondJson(request, HttpStatus.notFound, {
              'error': 'Endpoint not found',
              'valid_endpoints': ['GET /api/status', 'GET /api/catalog', 'POST /api/delivery/order'],
            });
          }
        } catch (e, stack) {
          debugPrint('[DeliveryListener] Error processing request: $e\n$stack');
          try {
            await _respondJson(request, HttpStatus.internalServerError, {
              'success': false,
              'error': e.toString(),
            });
          } catch (_) {}
        }
      });

      return true;
    } catch (e) {
      debugPrint('[DeliveryListener] Failed to bind port $_port: $e');
      _server = null;
      return false;
    }
  }

  @override
  Future<void> stop() async {
    if (_server != null) {
      try {
        await _server!.close(force: true);
        debugPrint('[DeliveryListener] Server stopped');
      } catch (e) {
        debugPrint('[DeliveryListener] Error stopping server: $e');
      } finally {
        _server = null;
      }
    }
  }

  void _handleCors(HttpRequest request) {
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Origin, Content-Type, Accept');
  }

  Future<void> _respondJson(HttpRequest request, int statusCode, Map<String, dynamic> data) async {
    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(data));
    await request.response.close();
  }
}
