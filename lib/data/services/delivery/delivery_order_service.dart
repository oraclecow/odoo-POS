import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/delivery_order.dart';
import '../../models/juice_product.dart';
import '../../models/modifier.dart';
import '../../models/order.dart';
import '../../repositories/juice_pos_repository.dart';
import '../odoo_client.dart';
import '../printer/printer_service.dart';
import 'delivery_http_listener.dart';
import 'product_fuzzy_matcher.dart';

class DeliveryOrderService extends ChangeNotifier {
  static const _prefPort = 'delivery_listener_port';
  static const _prefAutoAccept = 'delivery_auto_accept';
  static const _prefAutoPrint = 'delivery_auto_print';
  static const _prefEnabled = 'delivery_listener_enabled';

  static const _platformChannel = MethodChannel('com.arawali.pos/delivery');

  final DeliveryHttpListener _httpListener = DeliveryHttpListener();

  int _port = 8088;
  int get port => _port;

  bool _isEnabled = true;
  bool get isEnabled => _isEnabled;

  bool _autoAccept = false;
  bool get autoAccept => _autoAccept;

  bool _autoPrint = true;
  bool get autoPrint => _autoPrint;

  bool get isServerRunning => _httpListener.isRunning;

  final List<IncomingDeliveryOrder> _pendingOrders = [];
  List<IncomingDeliveryOrder> get pendingOrders => List.unmodifiable(_pendingOrders);

  final List<IncomingDeliveryOrder> _recentOrders = [];
  List<IncomingDeliveryOrder> get recentOrders => List.unmodifiable(_recentOrders);

  // Stream for notifying UI of incoming orders in real-time
  final _newOrderStreamController = StreamController<IncomingDeliveryOrder>.broadcast();
  Stream<IncomingDeliveryOrder> get onNewOrder => _newOrderStreamController.stream;

  JuicePosRepository? _repository;

  Future<void> init(JuicePosRepository repository) async {
    _repository = repository;
    final prefs = await SharedPreferences.getInstance();
    _port = prefs.getInt(_prefPort) ?? 8088;
    _isEnabled = prefs.getBool(_prefEnabled) ?? true;
    _autoAccept = prefs.getBool(_prefAutoAccept) ?? false;
    _autoPrint = prefs.getBool(_prefAutoPrint) ?? true;

    if (_isEnabled) {
      await startServer();
    }
    notifyListeners();
  }

  Future<bool> startServer() async {
    if (_repository == null) return false;

    final success = await _httpListener.start(
      port: _port,
      onOrderReceived: (order) => processIncomingOrder(order),
      getCatalog: () => _repository!.getProducts(),
    );

    notifyListeners();
    return success;
  }

  Future<void> stopServer() async {
    await _httpListener.stop();
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, enabled);

    if (enabled) {
      await startServer();
    } else {
      await stopServer();
    }
    notifyListeners();
  }

  Future<void> setAutoAccept(bool val) async {
    _autoAccept = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAutoAccept, val);
    notifyListeners();
  }

  Future<void> setAutoPrint(bool val) async {
    _autoPrint = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAutoPrint, val);
    notifyListeners();
  }

  Future<void> setPort(int newPort) async {
    if (newPort < 1024 || newPort > 65535) return;
    _port = newPort;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefPort, newPort);

    if (_isEnabled) {
      await stopServer();
      await startServer();
    }
    notifyListeners();
  }

  /// Check Android Accessibility Service status (for dormant on-device listener)
  Future<bool> isAccessibilityServiceEnabled() async {
    if (kIsWeb) return false;
    try {
      final bool? enabled = await _platformChannel.invokeMethod('isAccessibilityEnabled');
      return enabled ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Open Android Accessibility Settings to let user activate on-device listener
  Future<void> openAccessibilitySettings() async {
    if (kIsWeb) return;
    try {
      await _platformChannel.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      debugPrint('[DeliveryOrderService] Error opening accessibility settings: $e');
    }
  }

  /// Handles incoming order, matches catalog, and pushes to queue
  Future<Map<String, dynamic>> processIncomingOrder(IncomingDeliveryOrder rawOrder) async {
    final catalog = _repository?.getProducts() ?? [];

    // 1. Run Fuzzy Matching for each line item
    final matchedItems = <IncomingDeliveryItem>[];
    for (final item in rawOrder.items) {
      final match = ProductFuzzyMatcher.findBestMatch(item.rawName, catalog);
      if (match != null) {
        matchedItems.add(item.copyWith(
          matchedProductId: match.product.id,
          matchedProductName: match.product.name,
          matchConfidence: match.score,
        ));
      } else {
        matchedItems.add(item.copyWith(matchConfidence: 0.0));
      }
    }

    final enrichedOrder = IncomingDeliveryOrder(
      id: rawOrder.id,
      orderId: rawOrder.orderId,
      channelType: rawOrder.channelType,
      customerName: rawOrder.customerName,
      customerPhone: rawOrder.customerPhone,
      orderNotes: rawOrder.orderNotes,
      items: matchedItems,
      estimatedTotal: rawOrder.estimatedTotal,
      receivedAt: rawOrder.receivedAt,
      source: rawOrder.source,
    );

    // 2. Queue into pending
    _pendingOrders.insert(0, enrichedOrder);
    _recentOrders.insert(0, enrichedOrder);
    if (_recentOrders.length > 50) {
      _recentOrders.removeLast();
    }

    notifyListeners();

    // 3. Emit event to UI (e.g. sound chime + pop-up dialog)
    _newOrderStreamController.add(enrichedOrder);

    return {
      'status': 'received',
      'items_count': enrichedOrder.items.length,
      'matched_count': enrichedOrder.items.where((i) => i.isMatched).length,
    };
  }

  void dismissPendingOrder(String id) {
    _pendingOrders.removeWhere((o) => o.id == id);
    notifyListeners();
  }

  /// Build CartItems from an IncomingDeliveryOrder
  List<CartItem> convertToCartItems(IncomingDeliveryOrder order, List<JuiceProduct> catalog) {
    final cartItems = <CartItem>[];

    for (final item in order.items) {
      JuiceProduct? product;
      if (item.matchedProductId != null) {
        product = catalog.firstWhere(
          (p) => p.id == item.matchedProductId,
          orElse: () => _createGenericDeliveryProduct(item),
        );
      } else {
        product = _createGenericDeliveryProduct(item);
      }

      final lineId = '${product.id}_${DateTime.now().millisecondsSinceEpoch}_${cartItems.length}';
      final channelPrice = item.price ?? product.getPriceForChannel(order.channelType);

      final noteParts = <String>[];
      if (item.modifiers != null && item.modifiers!.isNotEmpty) {
        noteParts.add(item.modifiers!);
      }
      if (item.note != null && item.note!.isNotEmpty) {
        noteParts.add(item.note!);
      }
      final combinedNote = noteParts.isNotEmpty ? noteParts.join(', ') : null;

      cartItems.add(CartItem(
        lineId: lineId,
        product: product,
        modifiers: const SelectedModifiers(),
        quantity: item.quantity,
        note: combinedNote,
        customUnitPrice: channelPrice,
      ));
    }

    return cartItems;
  }

  JuiceProduct _createGenericDeliveryProduct(IncomingDeliveryItem item) {
    return JuiceProduct(
      id: 999999,
      name: item.rawName,
      category: 'MAKANAN',
      price: item.price ?? 15000,
      stock: 999,
    );
  }

  /// Completes an incoming delivery order: submits to Odoo 19 and prints kitchen slip
  Future<Map<String, dynamic>> acceptAndCommitOrder({
    required IncomingDeliveryOrder order,
    required OdooClient odooClient,
    required PrinterService printerService,
    String? cashierName,
  }) async {
    final catalog = _repository?.getProducts() ?? [];
    final items = convertToCartItems(order, catalog);

    final totalAmount = items.fold(0, (sum, it) => sum + it.lineTotal);
    final orderUuid = 'delivery_${order.channelLabel.toLowerCase()}_${order.orderId}_${DateTime.now().millisecondsSinceEpoch}';

    final pricelistId = order.channelType == OrderChannelType.grabFood ? 15 : 16;
    final paymentMethod = order.channelType == OrderChannelType.grabFood ? 'GrabFood' : 'ShopeeFood';

    // 1. Submit to Odoo 19 POS
    PosOrderSubmissionResult? subResult;
    try {
      subResult = await odooClient.submitPosOrder(
        items: items,
        totalAmount: totalAmount,
        paidAmount: totalAmount,
        changeAmount: 0,
        paymentMethodName: paymentMethod,
        orderUuid: orderUuid,
        partnerId: null,
        orderNote: order.orderNotes,
        channelTag: '${order.channelLabel} #${order.orderId}',
        pricelistId: pricelistId,
      );
    } catch (e) {
      debugPrint('[DeliveryOrderService] Odoo sync warning: $e');
    }

    // 2. Print Kitchen Slip if autoPrint is true
    Map<String, dynamic> printResult = {'success': false, 'reason': 'Auto-print disabled'};
    if (_autoPrint) {
      try {
        final orderNumber = int.tryParse(order.orderId.replaceAll(RegExp(r'[^\d]'), '')) ?? 9001;
        printResult = await printerService.printKitchenSlip(
          orderNumber: orderNumber,
          items: items,
          channelName: '${order.channelLabel} #${order.orderId}',
          posReference: subResult?.posReference,
          trackingNumber: subResult?.trackingNumber ?? order.orderId,
          note: order.orderNotes,
          cashierName: cashierName ?? 'Online Order',
        );
      } catch (e) {
        printResult = {'success': false, 'error': e.toString()};
      }
    }

    // 3. Remove from pending queue
    dismissPendingOrder(order.id);

    return {
      'success': true,
      'order_id': order.orderId,
      'pos_reference': subResult?.posReference,
      'tracking_number': subResult?.trackingNumber,
      'print_result': printResult,
    };
  }

  @override
  void dispose() {
    _httpListener.stop();
    _newOrderStreamController.close();
    super.dispose();
  }
}
