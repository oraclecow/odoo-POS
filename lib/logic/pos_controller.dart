import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/juice_product.dart';
import '../data/models/modifier.dart';
import '../data/models/customer.dart';
import '../data/models/order.dart';
import '../data/models/floating_order.dart';
import 'package:http/http.dart' as http;
import '../data/repositories/juice_pos_repository.dart';
import '../data/services/odoo_client.dart';

final odooClientProvider = Provider<OdooClient>((ref) => OdooClient());

final juicePosRepositoryProvider = Provider((ref) {
  final client = ref.watch(odooClientProvider);
  return JuicePosRepository(odooClient: client);
});

final posControllerProvider = ChangeNotifierProvider((ref) {
  final repo = ref.watch(juicePosRepositoryProvider);
  return PosController(repo);
});

class PosController extends ChangeNotifier {
  final JuicePosRepository _repository;

  final Map<String, JuiceProduct> _barcodeMap = {};
  final Map<String, JuiceProduct> _skuMap = {};

  bool _showProductImages = true;
  bool get showProductImages => _showProductImages;

  String _imageBaseUrl = 'http://127.0.0.1:8089';
  String get imageBaseUrl {
    if (kIsWeb) {
      // In web, route through serve_pos.py reverse proxy at origin
      return '';
    }
    // In native Windows / Linux, route to local proxy (127.0.0.1:8089) for instant SSD caching
    return _imageBaseUrl;
  }

  PosController(this._repository) {
    _categories = _repository.getCategories();
    _allProducts = _repository.getProducts();
    _rebuildProductMaps();
    _selectedCategory = _categories.isNotEmpty ? _categories.first : '';
    _floatingOrders.add(PosFloatingOrder(orderNumber: _nextOrderNumber++));
    _initAndSync();
  }

  Future<void> loadProductImageSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _showProductImages = prefs.getBool('pos_show_product_images') ?? true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggleShowProductImages(bool value) async {
    _showProductImages = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pos_show_product_images', value);
    } catch (_) {}
  }

  void _rebuildProductMaps() {
    _barcodeMap.clear();
    _skuMap.clear();
    for (final p in _allProducts) {
      if (p.barcode != null && p.barcode!.trim().isNotEmpty) {
        final b = p.barcode!.trim().toLowerCase();
        _barcodeMap[b] = p;
        if (b.startsWith('0')) {
          _barcodeMap[b.replaceFirst(RegExp(r'^0+'), '')] = p;
        }
      }
      if (p.defaultCode != null && p.defaultCode!.trim().isNotEmpty) {
        final sku = p.defaultCode!.trim().toLowerCase();
        _skuMap[sku] = p;
        if (sku.startsWith('0')) {
          _skuMap[sku.replaceFirst(RegExp(r'^0+'), '')] = p;
        }
      }
    }
  }

  Future<void> _checkLocalProxy() async {
    if (kIsWeb) return;
    try {
      final res = await http.get(Uri.parse('http://127.0.0.1:8089/')).timeout(const Duration(milliseconds: 400));
      if (res.statusCode == 200) {
        _imageBaseUrl = 'http://127.0.0.1:8089';
        return;
      }
    } catch (_) {}
    _imageBaseUrl = _repository.odooClient?.baseUrl ?? 'http://localhost:8069';
  }

  Future<void> _initAndSync() async {
    try {
      await loadProductImageSettings();
      await _repository.odooClient?.loadSavedSettings();
      await _checkLocalProxy();
      await loadCashiers();
      await checkSession();
    } catch (_) {}
    await syncOdooCatalog();
  }

  Future<void> syncOdooCatalog() async {
    await _repository.syncWithOdoo();
    _categories = _repository.getCategories();
    _allProducts = _repository.getProducts();
    _rebuildProductMaps();
    if (!_categories.contains(_selectedCategory)) {
      _selectedCategory = _categories.isNotEmpty ? _categories.first : '';
    }
    await checkSession();
    try {
      await _repository.odooClient?.fetchPaymentMethods();
    } catch (e) {
      debugPrint('Error syncing payment methods: $e');
    }
    notifyListeners();
  }

  // Cashier & Session State
  PosCashier? _activeCashier;
  PosCashier? get activeCashier => _activeCashier;

  List<PosCashier> _cashiers = [];
  List<PosCashier> get cashiers => _cashiers;

  int? _activeSessionId;
  int? get activeSessionId => _activeSessionId;

  String? _activeSessionName;
  String? get activeSessionName => _activeSessionName;

  bool get isSessionOpen => _activeSessionId != null;

  Future<void> loadCashiers() async {
    final client = _repository.odooClient;
    if (client == null) return;
    try {
      _cashiers = await client.fetchCashiers();
      if (_cashiers.isNotEmpty && _activeCashier == null) {
        _activeCashier = _cashiers.firstWhere(
          (c) => !c.name.toLowerCase().contains('admin'),
          orElse: () => _cashiers.first,
        );
        client.setActiveCashier(_activeCashier);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading cashiers: $e');
    }
  }

  void setActiveCashier(PosCashier cashier) {
    _activeCashier = cashier;
    _repository.odooClient?.setActiveCashier(cashier);
    notifyListeners();
  }

  Future<void> checkSession() async {
    final client = _repository.odooClient;
    if (client == null) return;
    try {
      _activeSessionId = await client.fetchActiveSession();
      _activeSessionName = client.activeSessionName;
      notifyListeners();
    } catch (e) {
      debugPrint('Error checking session: $e');
    }
  }

  Future<void> switchRegisterProfile(OdooCompanyProfile newProfile) async {
    final client = _repository.odooClient;
    if (client == null) return;
    client.switchProfile(newProfile);
    await _checkLocalProxy();
    await client.authenticate();
    await checkSession();
    await syncOdooCatalog();
    await client.saveSettings();
    notifyListeners();
  }

  OdooClient? get odooClient => _repository.odooClient;

  Future<double> fetchExpectedOpeningCash() async {
    final client = _repository.odooClient;
    if (client == null) return 0.0;
    return await client.fetchExpectedOpeningCash();
  }

  Future<int> openSession({double openingCash = 0.0, String notes = 'Opened from Open Odoo POS'}) async {
    final client = _repository.odooClient;
    if (client == null) {
      throw Exception('Odoo client not configured');
    }
    final sId = await client.openNewSession(
      openingCash: openingCash,
      notes: notes,
    );
    _activeSessionId = sId;
    _activeSessionName = client.activeSessionName;
    notifyListeners();
    return sId;
  }

  Future<PosClosingControlData> fetchClosingControlData() async {
    final client = _repository.odooClient;
    if (client == null) {
      throw Exception('Odoo client not configured');
    }
    return await client.fetchClosingControlData(sessionId: _activeSessionId);
  }

  Future<void> closeSession({required double countedCash}) async {
    final client = _repository.odooClient;
    if (client == null) {
      throw Exception('Odoo client not configured');
    }
    if (_activeSessionId == null) {
      throw Exception('No active POS session to close');
    }
    await client.closeSession(
      sessionId: _activeSessionId!,
      countedCash: countedCash,
    );
    _activeSessionId = null;
    _activeSessionName = null;
    notifyListeners();
  }

  // Session & Header State
  String _activeTab = 'Register';
  String get activeTab => _activeTab;

  // Floating Orders (Multiple Concurrent Carts - Odoo 19 Native Workflow)
  int _nextOrderNumber = 1001;
  final List<PosFloatingOrder> _floatingOrders = [];
  int _activeOrderIndex = 0;

  List<PosFloatingOrder> get floatingOrders => List.unmodifiable(_floatingOrders);
  int get activeOrderIndex => _activeOrderIndex;

  PosFloatingOrder get currentOrder {
    if (_floatingOrders.isEmpty) {
      _floatingOrders.add(PosFloatingOrder(orderNumber: _nextOrderNumber++));
      _activeOrderIndex = 0;
    }
    if (_activeOrderIndex >= _floatingOrders.length) {
      _activeOrderIndex = _floatingOrders.length - 1;
    }
    return _floatingOrders[_activeOrderIndex];
  }

  int get orderNumber => currentOrder.orderNumber;
  OrderChannel get channel => currentOrder.channel;
  Customer? get customer => currentOrder.customer;
  String? get orderNote => currentOrder.orderNote;

  // Catalog State
  late List<String> _categories;
  List<String> get categories => _categories;

  late List<JuiceProduct> _allProducts;

  String _selectedCategory = '';
  String get selectedCategory => _selectedCategory;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    final clean = query.trim().toLowerCase();
    if (_searchQuery == clean) return;
    _searchQuery = clean;
    notifyListeners();
  }

  JuiceProduct? handleBarcodeScan(String rawBarcode) {
    final code = rawBarcode.trim().toLowerCase();
    if (code.isEmpty) return null;

    // 1. Fast O(1) dictionary lookup
    JuiceProduct? matched = _barcodeMap[code] ?? _skuMap[code];
    if (matched == null && code.startsWith('0')) {
      final noZero = code.replaceFirst(RegExp(r'^0+'), '');
      matched = _barcodeMap[noZero] ?? _skuMap[noZero];
    }

    // 2. Snapshot fallback
    if (matched == null) {
      final snapshot = List<JuiceProduct>.from(_allProducts);
      for (final p in snapshot) {
        final b = p.barcode?.trim().toLowerCase();
        final s = p.defaultCode?.trim().toLowerCase();
        if (b == code || s == code) {
          matched = p;
          break;
        }
      }
    }

    if (matched != null) {
      addProductDirectly(matched, 1);
      return matched;
    }
    return null;
  }

  void addProductDirectly(JuiceProduct product, [int qty = 1]) {
    final existingIdx = currentOrder.items.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingIdx >= 0) {
      currentOrder.items[existingIdx].quantity += qty;
    } else {
      final lineId = '${product.id}_${DateTime.now().millisecondsSinceEpoch}';
      currentOrder.items.add(CartItem(
        lineId: lineId,
        product: product,
        modifiers: const SelectedModifiers(),
        quantity: qty,
      ));
    }
    notifyListeners();
  }

  void addJuiceItem(JuiceProduct product, SelectedModifiers modifiers, [int qty = 1]) {
    final lineId = '${product.id}_${DateTime.now().millisecondsSinceEpoch}';
    currentOrder.items.add(CartItem(
      lineId: lineId,
      product: product,
      modifiers: modifiers,
      quantity: qty,
    ));
    notifyListeners();
  }

  List<JuiceProduct> get filteredProducts {
    Iterable<JuiceProduct> prods = _allProducts;
    if (_selectedCategory.isNotEmpty && _selectedCategory != 'Semua' && _selectedCategory != 'All') {
      prods = prods.where((p) => p.category == _selectedCategory);
    }
    if (_searchQuery.isNotEmpty) {
      prods = prods.where((p) =>
        p.name.toLowerCase().contains(_searchQuery) ||
        (p.barcode != null && p.barcode!.toLowerCase().contains(_searchQuery)) ||
        (p.defaultCode != null && p.defaultCode!.toLowerCase().contains(_searchQuery))
      );
    }
    return prods.toList();
  }

  // Cart State & Idempotency - Delegated to currentOrder
  String get currentOrderUuid => currentOrder.id;
  List<CartItem> get cartItems => List.unmodifiable(currentOrder.items);

  // Discount & Loyalty Points State - Delegated to currentOrder
  double get orderDiscountPercent => currentOrder.orderDiscountPercent;
  int get orderDiscountAmount => currentOrder.orderDiscountAmount;
  int get orderDiscountTotal => currentOrder.orderDiscountTotal;
  int get redeemedPoints => currentOrder.redeemedPoints;
  int get pointsDiscount => currentOrder.pointsDiscount;

  void setOrderDiscount({double? percent, int? amount}) {
    if (percent != null) {
      currentOrder.orderDiscountPercent = percent.clamp(0.0, 100.0);
      currentOrder.orderDiscountAmount = 0;
    } else if (amount != null) {
      currentOrder.orderDiscountAmount = amount.clamp(0, subtotal > 0 ? subtotal : 0);
      currentOrder.orderDiscountPercent = 0.0;
    }
    notifyListeners();
  }

  void clearOrderDiscount() {
    currentOrder.orderDiscountPercent = 0.0;
    currentOrder.orderDiscountAmount = 0;
    notifyListeners();
  }

  void setRedeemedPoints(int points) {
    final maxPts = customer != null ? customer!.points.toInt() : points;
    final maxAllowed = subtotal > 0 ? (maxPts < subtotal ? maxPts : subtotal) : 0;
    currentOrder.redeemedPoints = points.clamp(0, maxAllowed);
    notifyListeners();
  }

  void clearRedeemedPoints() {
    currentOrder.redeemedPoints = 0;
    notifyListeners();
  }

  bool get isReturnOrder => currentOrder.isReturnOrder;

  void addReturnItem(JuiceProduct product, int qty, {int? unitPrice, String? returnRef}) {
    final negativeQty = -qty.abs();
    final lineId = 'return_${product.id}_${DateTime.now().millisecondsSinceEpoch}';
    final note = returnRef != null && returnRef.isNotEmpty ? 'Retur: $returnRef' : 'Retur Barang';

    currentOrder.items.add(CartItem(
      lineId: lineId,
      product: product,
      modifiers: const SelectedModifiers(),
      quantity: negativeQty,
      customUnitPrice: unitPrice,
      note: note,
    ));
    notifyListeners();
  }

  int get subtotal => currentOrder.subtotal;
  int get tax => currentOrder.tax;
  int get total => currentOrder.total;

  int get memberPointsEarned => currentOrder.memberPointsEarned;
  int get loyaltyPointsEarned => memberPointsEarned;

  @visibleForTesting
  void setProductsForTesting(List<JuiceProduct> products) {
    _allProducts = products;
    _rebuildProductMaps();
    notifyListeners();
  }

  // Actions
  void setActiveTab(String tab) {
    _activeTab = tab;
    notifyListeners();
  }

  void selectCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setOrderChannel(OrderChannelType type, [String? pin]) {
    currentOrder.channel = OrderChannel(type: type, deliveryPin: pin);
    notifyListeners();
  }

  void setCustomer(Customer? customer) {
    currentOrder.customer = customer;
    notifyListeners();
  }

  void setOrderNote(String? note) {
    currentOrder.orderNote = note;
    notifyListeners();
  }

  int get totalLineDiscounts => currentOrder.totalLineDiscounts;

  void setLineQuantity(String lineId, int qty) {
    final index = currentOrder.items.indexWhere((item) => item.lineId == lineId);
    if (index >= 0) {
      if (qty <= 0) {
        currentOrder.items.removeAt(index);
      } else {
        currentOrder.items[index].quantity = qty;
      }
      notifyListeners();
    }
  }

  void setLineNote(String lineId, String? note) {
    final idx = currentOrder.items.indexWhere((it) => it.lineId == lineId);
    if (idx >= 0) {
      currentOrder.items[idx] = currentOrder.items[idx].copyWith(
        note: note,
        clearNote: note == null || note.trim().isEmpty,
      );
      notifyListeners();
    }
  }

  void applyLineDiscount(String lineId, double percent) {
    final idx = currentOrder.items.indexWhere((it) => it.lineId == lineId);
    if (idx >= 0) {
      currentOrder.items[idx] = currentOrder.items[idx].copyWith(
        discountPercent: percent > 0 ? percent : null,
        clearDiscount: percent <= 0,
      );
      notifyListeners();
    }
  }

  void updateQuantity(String lineId, int delta) {
    final index = currentOrder.items.indexWhere((item) => item.lineId == lineId);
    if (index >= 0) {
      final current = currentOrder.items[index];
      if (current.quantity < 0) {
        // Return item with negative quantity: delta > 0 decreases return qty towards 0 (removal)
        final newQty = current.quantity + delta;
        if (newQty >= 0) {
          currentOrder.items.removeAt(index);
        } else {
          current.quantity = newQty;
        }
      } else {
        // Regular item
        final newQty = current.quantity + delta;
        if (newQty <= 0) {
          currentOrder.items.removeAt(index);
        } else {
          current.quantity = newQty;
        }
      }
      notifyListeners();
    }
  }

  void removeItem(String lineId) {
    currentOrder.items.removeWhere((item) => item.lineId == lineId);
    notifyListeners();
  }

  // --- FLOATING ORDERS MANAGEMENT (Odoo 19 Native Workflow) ---

  /// Creates a new floating order (puts current order aside and opens a fresh cart)
  void newFloatingOrder() {
    final newOrder = PosFloatingOrder(orderNumber: _nextOrderNumber++);
    _floatingOrders.add(newOrder);
    _activeOrderIndex = _floatingOrders.length - 1;
    notifyListeners();
  }

  /// Selects a floating order by its index in the tab bar
  void selectFloatingOrder(int index) {
    if (index >= 0 && index < _floatingOrders.length) {
      _activeOrderIndex = index;
      notifyListeners();
    }
  }

  /// Selects a floating order by its UUID
  void selectFloatingOrderByUuid(String uuid) {
    final idx = _floatingOrders.indexWhere((o) => o.id == uuid);
    if (idx >= 0) {
      _activeOrderIndex = idx;
      notifyListeners();
    }
  }

  /// Removes/discards an open floating order.
  /// If it is the only remaining order, resets it to a clean empty cart.
  void removeFloatingOrder(int index) {
    if (index < 0 || index >= _floatingOrders.length) return;

    if (_floatingOrders.length <= 1) {
      _floatingOrders[0] = PosFloatingOrder(orderNumber: _nextOrderNumber++);
      _activeOrderIndex = 0;
    } else {
      _floatingOrders.removeAt(index);
      if (_activeOrderIndex >= _floatingOrders.length) {
        _activeOrderIndex = _floatingOrders.length - 1;
      }
    }
    notifyListeners();
  }

  /// Completes and finalizes current order after payment.
  /// If other floating carts are parked, auto-selects the next parked cart;
  /// otherwise, initializes a fresh empty cart with the next order number.
  void completeCurrentOrder() => clearCart();

  void clearCart() {
    if (_floatingOrders.length > 1) {
      _floatingOrders.removeAt(_activeOrderIndex);
      if (_activeOrderIndex >= _floatingOrders.length) {
        _activeOrderIndex = _floatingOrders.length - 1;
      }
    } else {
      _floatingOrders[0] = PosFloatingOrder(orderNumber: _nextOrderNumber++);
      _activeOrderIndex = 0;
    }
    notifyListeners();
  }
}
