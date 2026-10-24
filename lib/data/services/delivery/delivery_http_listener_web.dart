import 'package:flutter/foundation.dart';
import '../../models/delivery_order.dart';
import '../../models/juice_product.dart';
import 'delivery_http_listener_base.dart';

class DeliveryHttpListener implements DeliveryHttpListenerBase {
  @override
  bool get isRunning => false;

  @override
  int get port => 8088;

  @override
  Future<bool> start({
    int port = 8088,
    required Future<Map<String, dynamic>> Function(IncomingDeliveryOrder order) onOrderReceived,
    required List<JuiceProduct> Function() getCatalog,
  }) async {
    debugPrint('[DeliveryListener] Local HTTP server is only supported on native devices (Android/Linux/Windows).');
    return false;
  }

  @override
  Future<void> stop() async {}
}
