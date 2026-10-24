import '../../models/delivery_order.dart';
import '../../models/juice_product.dart';

abstract class DeliveryHttpListenerBase {
  bool get isRunning;
  int get port;

  Future<bool> start({
    int port = 8088,
    required Future<Map<String, dynamic>> Function(IncomingDeliveryOrder order) onOrderReceived,
    required List<JuiceProduct> Function() getCatalog,
  });

  Future<void> stop();
}
