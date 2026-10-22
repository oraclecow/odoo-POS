import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/app_mode.dart';
import '../../core/models/odoo_pos_models.dart';
import '../../modules/pos_receipt/receipt_config.dart';
import '../models/juice_product.dart';
import '../models/modifier.dart';
import '../models/customer.dart';
import '../models/order.dart';

export '../../core/config/app_mode.dart';
export '../../core/models/odoo_pos_models.dart';


class OdooClient {
  String baseUrl;
  String database;
  OdooCompanyProfile profile;
  final http.Client _httpClient;
  final _uuid = const Uuid();
  int? _uid;
  int? _activeSessionId;
  String? _activeSessionName;
  PosCashier? _activeCashier;
  StorePaymentRegistry? _paymentRegistry;

  OdooClient({
    this.baseUrl = 'http://localhost:8069',
    this.database = 'odoo',
    OdooCompanyProfile? profile,
    http.Client? httpClient,
  })  : profile = profile ?? OdooCompanyProfile.defaultDemoProfile,
        _httpClient = httpClient ?? http.Client();

  int get currentUid => _uid ?? 0;
  int? get activeSessionId => _activeSessionId;
  String? get activeSessionName => _activeSessionName;
  PosCashier? get activeCashier => _activeCashier;
  StorePaymentRegistry? get paymentRegistry => _paymentRegistry;

  void setActiveCashier(PosCashier? cashier) {
    _activeCashier = cashier;
  }

  void switchProfile(OdooCompanyProfile newProfile) {
    profile = newProfile;
    _uid = null;
    _activeSessionId = null;
    _activeSessionName = null;
    _activeCashier = null;
    _paymentRegistry = null;
  }

  void switchDatabase(String newDb) {
    database = newDb;
    _uid = null;
    _activeSessionId = null;
    _activeSessionName = null;
    _paymentRegistry = null;
  }

  /// Fetches live receipt header/footer and company info from Odoo 19 `pos.config` and `res.company`.
  Future<OdooReceiptMetadata> fetchPosReceiptMetadata({int? configId}) async {
    final targetConfigId = configId ?? profile.posConfigId;
    try {
      final configData = await executeKw(
        'pos.config',
        'read',
        [
          [targetConfigId],
          ['is_header_or_footer', 'receipt_header', 'receipt_footer', 'company_id'],
        ],
      );
      if (configData is! List || configData.isEmpty) {
        return const OdooReceiptMetadata();
      }
      final cfg = configData.first as Map<String, dynamic>;
      final isHeaderOrFooter = cfg['is_header_or_footer'] == true;
      final header = cfg['receipt_header'] is String ? (cfg['receipt_header'] as String).trim() : '';
      final footer = cfg['receipt_footer'] is String ? (cfg['receipt_footer'] as String).trim() : '';

      String companyName = '';
      String street = '';
      String city = '';
      String phone = '';
      String vat = '';
      String email = '';
      String website = '';

      final compField = cfg['company_id'];
      final int compId = (compField is List && compField.isNotEmpty)
          ? (compField.first as num).toInt()
          : profile.companyId;

      final compData = await executeKw(
        'res.company',
        'read',
        [
          [compId],
          ['name', 'street', 'city', 'phone', 'vat', 'email', 'website'],
        ],
      );
      if (compData is List && compData.isNotEmpty) {
        final comp = compData.first as Map<String, dynamic>;
        companyName = comp['name'] is String ? (comp['name'] as String).trim() : '';
        street = comp['street'] is String ? (comp['street'] as String).trim() : '';
        city = comp['city'] is String ? (comp['city'] as String).trim() : '';
        phone = comp['phone'] is String ? (comp['phone'] as String).trim() : '';
        vat = comp['vat'] is String ? (comp['vat'] as String).trim() : '';
        email = comp['email'] is String ? (comp['email'] as String).trim() : '';
        website = comp['website'] is String ? (comp['website'] as String).trim() : '';
      }

      return OdooReceiptMetadata(
        companyName: companyName,
        street: street,
        city: city,
        phone: phone,
        vat: vat,
        email: email,
        website: website,
        isHeaderOrFooter: isHeaderOrFooter,
        receiptHeader: header,
        receiptFooter: footer,
      );
    } catch (_) {
      return const OdooReceiptMetadata();
    }
  }


  Future<StorePaymentRegistry> fetchPaymentMethods({int? configId}) async {
    final targetConfigId = configId ?? profile.posConfigId;
    final configData = await executeKw(
      'pos.config',
      'read',
      [
        [targetConfigId],
        ['payment_method_ids'],
      ],
    );

    if (configData is! List || configData.isEmpty) {
      final reg = StorePaymentRegistry(posConfigId: targetConfigId, methods: const []);
      if (configId == null || configId == profile.posConfigId) {
        _paymentRegistry = reg;
      }
      return reg;
    }

    final pmIds = List<int>.from(configData[0]['payment_method_ids'] ?? []);
    if (pmIds.isEmpty) {
      final reg = StorePaymentRegistry(posConfigId: targetConfigId, methods: const []);
      if (configId == null || configId == profile.posConfigId) {
        _paymentRegistry = reg;
      }
      return reg;
    }

    final methodsData = await executeKw(
      'pos.payment.method',
      'read',
      [
        pmIds,
        ['id', 'name', 'is_cash_count', 'type'],
      ],
    );

    final list = <PosPaymentMethodInfo>[];
    if (methodsData is List) {
      for (final item in methodsData) {
        if (item is Map<String, dynamic>) {
          list.add(PosPaymentMethodInfo.fromMap(item));
        }
      }
    }

    final reg = StorePaymentRegistry(posConfigId: targetConfigId, methods: list);
    if (configId == null || configId == profile.posConfigId) {
      _paymentRegistry = reg;
    }
    return reg;
  }

  Future<void> loadSavedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('odoo_base_url');
      final savedDb = prefs.getString('odoo_database');
      final profileJson = prefs.getString('odoo_active_profile');

      if (savedUrl != null && savedUrl.isNotEmpty) baseUrl = savedUrl;
      if (savedDb != null && savedDb.isNotEmpty) database = savedDb;
      if (profileJson != null && profileJson.isNotEmpty) {
        profile = OdooCompanyProfile.fromMap(jsonDecode(profileJson));
      }
    } catch (_) {}
  }

  Future<void> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('odoo_base_url', baseUrl);
      await prefs.setString('odoo_database', database);
      await prefs.setString('odoo_active_profile', jsonEncode(profile.toMap()));
    } catch (_) {}
  }

  Future<int> authenticate() async {
    final response = await _callJsonRpc('common', 'authenticate', [
      database,
      profile.login,
      profile.password,
      {},
    ]);

    if (response is int && response > 0) {
      _uid = response;
      await fetchActiveSession();
      return response;
    }
    throw Exception('Authentication failed for user ${profile.login} on db $database');
  }

  Future<dynamic> _callJsonRpc(String service, String method, List<dynamic> args) async {
    // In web mode, route through same-origin /jsonrpc to avoid browser CORS restrictions
    final Uri uri = kIsWeb
        ? Uri.parse('${Uri.base.origin}/jsonrpc')
        : Uri.parse('$baseUrl/jsonrpc');

    final payload = {
      'jsonrpc': '2.0',
      'method': 'call',
      'params': {
        'service': service,
        'method': method,
        'args': args,
      },
      'id': DateTime.now().millisecondsSinceEpoch,
    };

    final resp = await _httpClient.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (resp.statusCode != 200) {
      throw Exception('Odoo server HTTP error: ${resp.statusCode}');
    }

    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    if (decoded.containsKey('error')) {
      final err = decoded['error'];
      throw Exception('Odoo RPC Error: ${err is Map ? (err['data']?['message'] ?? err['message']) : err}');
    }

    return decoded['result'];
  }

  Future<dynamic> executeKw(String model, String method, List<dynamic> args, [Map<String, dynamic>? kwargs]) async {
    if (_uid == null) {
      await authenticate();
    }

    return await _callJsonRpc('object', 'execute_kw', [
      database,
      _uid,
      profile.password,
      model,
      method,
      args,
      kwargs ?? {},
    ]);
  }

  // Find active open pos.session
  Future<int?> fetchActiveSession() async {
    final sessions = await executeKw(
      'pos.session',
      'search_read',
      [
        [
          ['state', '=', 'opened'],
          ['config_id', '=', profile.posConfigId],
        ]
      ],
      {
        'fields': ['id', 'name', 'config_id', 'start_at'],
        'limit': 1,
      },
    ) as List<dynamic>;

    if (sessions.isNotEmpty) {
      final s = sessions.first;
      _activeSessionId = s['id'] as int;
      _activeSessionName = s['name'] as String;
      return _activeSessionId;
    }
    _activeSessionId = null;
    _activeSessionName = null;
    return null;
  }

  // Fetch expected opening cash from Odoo 19 (pos.config.last_session_closing_cash or last closed session)
  Future<double> fetchExpectedOpeningCash() async {
    if (_uid == null) {
      await authenticate();
    }

    try {
      // 1. Check pos.config for last_session_closing_cash
      final configs = await executeKw(
        'pos.config',
        'search_read',
        [
          [
            ['id', '=', profile.posConfigId]
          ]
        ],
        {
          'fields': ['id', 'name', 'last_session_closing_cash'],
          'limit': 1,
        },
      ) as List<dynamic>;

      if (configs.isNotEmpty && configs.first['last_session_closing_cash'] != null) {
        final val = configs.first['last_session_closing_cash'];
        if (val is num && val > 0) {
          return val.toDouble();
        }
      }

      // 2. Fallback to last closed pos.session for cash_register_balance_end_real
      final sessions = await executeKw(
        'pos.session',
        'search_read',
        [
          [
            ['config_id', '=', profile.posConfigId],
            ['state', '=', 'closed'],
          ]
        ],
        {
          'fields': ['cash_register_balance_end_real'],
          'order': 'stop_at desc, id desc',
          'limit': 1,
        },
      ) as List<dynamic>;

      if (sessions.isNotEmpty && sessions.first['cash_register_balance_end_real'] != null) {
        final val = sessions.first['cash_register_balance_end_real'];
        if (val is num && val > 0) {
          return val.toDouble();
        }
      }
    } catch (e) {
      debugPrint('Error fetching expected opening cash from Odoo: $e');
    }

    return 0.0;
  }

  // Open or ensure an active pos.session in Odoo 19
  Future<int> openNewSession({double openingCash = 0.0, String notes = 'Opened from Open Odoo POS'}) async {
    if (_uid == null) {
      await authenticate();
    }

    // 1. Check if already opened
    final openedSessions = await executeKw(
      'pos.session',
      'search_read',
      [
        [
          ['config_id', '=', profile.posConfigId],
          ['state', '=', 'opened'],
        ]
      ],
      {
        'fields': ['id', 'name'],
        'limit': 1,
      },
    ) as List<dynamic>;

    if (openedSessions.isNotEmpty) {
      _activeSessionId = openedSessions.first['id'] as int;
      _activeSessionName = openedSessions.first['name'] as String;
      return _activeSessionId!;
    }

    // 2. Check if a session in 'opening_control' already exists
    final openingSessions = await executeKw(
      'pos.session',
      'search_read',
      [
        [
          ['config_id', '=', profile.posConfigId],
          ['state', '=', 'opening_control'],
        ]
      ],
      {
        'fields': ['id', 'name'],
        'limit': 1,
      },
    ) as List<dynamic>;

    int sessionId;
    if (openingSessions.isNotEmpty) {
      sessionId = openingSessions.first['id'] as int;
    } else {
      // 3. Create new session
      final created = await executeKw(
        'pos.session',
        'create',
        [
          {
            'config_id': profile.posConfigId,
            'user_id': _uid,
          }
        ],
      );
      sessionId = created is int ? created : (created as List).first as int;
    }

    // 4. Transition to 'opened' via set_opening_control
    try {
      await executeKw(
        'pos.session',
        'set_opening_control',
        [
          [sessionId],
          openingCash,
          notes,
        ],
      );
    } catch (e) {
      debugPrint('set_opening_control note: $e');
    }

    _activeSessionId = sessionId;
    await fetchActiveSession();
    return _activeSessionId ?? sessionId;
  }

  void clearActiveSession() {
    _activeSessionId = null;
    _activeSessionName = null;
  }

  // Fetch live closing control reconciliation data from Odoo 19
  Future<PosClosingControlData> fetchClosingControlData({int? sessionId}) async {
    final targetId = sessionId ?? _activeSessionId ?? await fetchActiveSession();
    if (targetId == null) {
      throw Exception('No active session found in Odoo for this store.');
    }

    final raw = await executeKw(
      'pos.session',
      'get_closing_control_data',
      [[targetId]],
    );

    if (raw is! Map<String, dynamic>) {
      throw Exception('Invalid response received from Odoo get_closing_control_data');
    }

    return PosClosingControlData.fromJson(raw);
  }

  // Close POS session in Odoo 19: posts counted cash and executes close_session_from_ui
  Future<void> closeSession({
    required int sessionId,
    required double countedCash,
  }) async {
    // 1. Post counted cash details to Odoo
    final postRes = await executeKw(
      'pos.session',
      'post_closing_cash_details',
      [[sessionId], countedCash],
    );
    if (postRes is Map && postRes['successful'] == false) {
      throw Exception(postRes['message'] ?? 'Failed to post closing cash details in Odoo.');
    }

    // 2. Validate & close session from UI
    final closeRes = await executeKw(
      'pos.session',
      'close_session_from_ui',
      [[sessionId]],
    );

    if (closeRes is Map && closeRes['successful'] == false) {
      final openOrderIds = (closeRes['open_order_ids'] as List<dynamic>?)?.cast<int>() ?? [];
      if (openOrderIds.isNotEmpty) {
        // Automatically purge draft unsubmitted/failed test orders if any
        try {
          await executeKw('pos.order', 'unlink', [openOrderIds]);
          final retryRes = await executeKw('pos.session', 'close_session_from_ui', [[sessionId]]);
          if (retryRes is Map && retryRes['successful'] == true) {
            _activeSessionId = null;
            _activeSessionName = null;
            return;
          }
        } catch (_) {}
      }
      throw Exception(closeRes['message'] ?? 'Failed to close POS session in Odoo.');
    }

    _activeSessionId = null;
    _activeSessionName = null;
  }

  // Fetch list of cashiers from pos.config and hr.employee.public
  Future<List<PosCashier>> fetchCashiers() async {
    if (_uid == null) {
      await authenticate();
    }

    try {
      final configs = await executeKw(
        'pos.config',
        'read',
        [
          [profile.posConfigId]
        ],
        {
          'fields': ['basic_employee_ids', 'advanced_employee_ids'],
        },
      ) as List<dynamic>;

      final empIds = <int>{};
      if (configs.isNotEmpty) {
        final cfg = configs.first as Map<String, dynamic>;
        final basic = (cfg['basic_employee_ids'] as List<dynamic>?) ?? [];
        final adv = (cfg['advanced_employee_ids'] as List<dynamic>?) ?? [];
        empIds.addAll(basic.cast<int>());
        empIds.addAll(adv.cast<int>());
      }

      if (empIds.isEmpty) {
        return [
          PosCashier(
            id: 0,
            name: profile.displayName.replaceAll(RegExp(r'\(.*?\)'), '').trim(),
            userId: _uid,
          ),
        ];
      }

      final emps = await executeKw(
        'hr.employee.public',
        'read',
        [empIds.toList()],
        {
          'fields': ['id', 'name', 'user_id'],
        },
      ) as List<dynamic>;

      final list = <PosCashier>[];
      for (final e in emps) {
        final id = e['id'] as int;
        final name = (e['name'] as String).trim();
        final userVal = e['user_id'];
        int? uId;
        if (userVal is List && userVal.isNotEmpty) {
          uId = userVal[0] as int;
        }
        final hasPin = name.toLowerCase().contains('admin');
        list.add(PosCashier(
          id: id,
          name: name,
          userId: uId,
          hasPin: hasPin,
          pin: hasPin ? '1212' : null,
        ));
      }

      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    } catch (e) {
      debugPrint('Error fetching cashiers: $e');
      return [
        PosCashier(
          id: 0,
          name: profile.displayName.replaceAll(RegExp(r'\(.*?\)'), '').trim(),
          userId: _uid,
        ),
      ];
    }
  }

  // Fetch Live POS Categories & Product Mapping
  static const List<String> excludedCategoryKeywords = [
    'archived',
  ];

  static bool isCategoryExcluded(String categoryName) {
    return false;
  }

  static int categorySortPriority(String cat) {
    final upper = cat.toUpperCase();
    if (upper == 'SEMUA') return 0;
    return 10;
  }

  /// F&B mode: resolves delivery-channel pricelists (name contains "grab"/"shopee").
  Future<Map<String, Map<int, int>>> fetchPricelistMaps() async {
    final map = <String, Map<int, int>>{'grab': {}, 'shopee': {}};
    if (profile.isRetail) return map;
    try {
      final lists = await executeKw(
        'product.pricelist',
        'search_read',
        [[]],
        {'fields': ['id', 'name'], 'limit': 100},
      ) as List<dynamic>;
      final idToChannel = <int, String>{};
      for (final l in lists) {
        final n = (l['name'] ?? '').toString().toLowerCase();
        if (n.contains('grab')) idToChannel[l['id'] as int] = 'grab';
        if (n.contains('shopee')) idToChannel[l['id'] as int] = 'shopee';
      }
      if (idToChannel.isEmpty) return map;
      final items = await executeKw(
        'product.pricelist.item',
        'search_read',
        [[['pricelist_id', 'in', idToChannel.keys.toList()]]],
        {'fields': ['pricelist_id', 'product_tmpl_id', 'product_id', 'fixed_price'], 'limit': 2000},
      ) as List<dynamic>;
      for (final it in items) {
        final plRaw = it['pricelist_id'];
        final plId = plRaw is List ? (plRaw[0] as int) : (plRaw as int? ?? 0);
        final channel = idToChannel[plId];
        if (channel == null) continue;
        final price = ((it['fixed_price'] as num?) ?? 0).toInt();
        final prodRaw = it['product_id'];
        final tmplRaw = it['product_tmpl_id'];
        if (prodRaw is List && prodRaw.isNotEmpty) {
          map[channel]![prodRaw[0] as int] = price;
        } else if (tmplRaw is List && tmplRaw.isNotEmpty) {
          map[channel]![tmplRaw[0] as int] = price;
        }
      }
    } catch (e) {
      debugPrint('[OdooClient] Note: error fetching pricelist items: $e');
    }
    return map;
  }

  // Fetch Live POS Categories & Product Mapping
  Future<Map<int, String>> fetchCategoryMap() async {
    List<int> allowedCatIds = [];
    try {
      final configs = await executeKw(
        'pos.config',
        'read',
        [
          [profile.posConfigId]
        ],
        {
          'fields': ['limit_categories', 'iface_available_categ_ids'],
        },
      ) as List<dynamic>;

      if (configs.isNotEmpty) {
        final cfg = configs.first as Map<String, dynamic>;
        final limit = cfg['limit_categories'] == true;
        final categs = (cfg['iface_available_categ_ids'] as List<dynamic>?) ?? [];
        if (limit && categs.isNotEmpty) {
          allowedCatIds = categs.cast<int>();
        }
      }
    } catch (_) {}

    final domain = <dynamic>[
      ['name', 'not ilike', 'ARCHIVED'],
    ];

    if (allowedCatIds.isNotEmpty) {
      domain.add(['id', 'in', allowedCatIds]);
    }

    final result = await executeKw(
      'pos.category',
      'search_read',
      [domain],
      {
        'fields': ['id', 'name'],
        'order': 'sequence asc, id asc',
      },
    ) as List<dynamic>;

    final map = <int, String>{};
    for (final row in result) {
      final name = (row['name'] as String).trim();
      map[row['id'] as int] = name;
    }
    return map;
  }

  Future<List<String>> fetchPosCategories([List<JuiceProduct>? products]) async {
    final categoryCounts = <String, int>{};

    if (products != null && products.isNotEmpty) {
      for (final p in products) {
        categoryCounts[p.category] = (categoryCounts[p.category] ?? 0) + 1;
      }
    } else {
      final prods = await fetchPosProducts();
      for (final p in prods) {
        categoryCounts[p.category] = (categoryCounts[p.category] ?? 0) + 1;
      }
    }

    final categories = <String>[];
    final nonZeroCats = categoryCounts.keys.toList();
    nonZeroCats.sort();
    for (final c in nonZeroCats) {
      if (c != 'Semua' && c != 'All' && !categories.contains(c)) {
        categories.add(c);
      }
    }
    return categories;
  }

  // Fetch Live Available POS Products with Real Category Assignments & Kit Detection
  Future<List<JuiceProduct>> fetchPosProducts() async {
    final catMap = await fetchCategoryMap();
    final pricelists = await fetchPricelistMaps();
    final grabMap = pricelists['grab'] ?? {};
    final shopeeMap = pricelists['shopee'] ?? {};

    // Check phantom / kit BOMs so we do not show stock for kits
    final kitProductIds = <int>{};
    final kitTmplIds = <int>{};
    try {
      final boms = await executeKw(
        'mrp.bom',
        'search_read',
        [[['type', '=', 'phantom']]],
        {
          'fields': ['id', 'product_id', 'product_tmpl_id'],
          'limit': 500,
        },
      ) as List<dynamic>;

      for (final bom in boms) {
        final p = bom['product_id'];
        if (p is List && p.isNotEmpty) kitProductIds.add(p[0] as int);
        final t = bom['product_tmpl_id'];
        if (t is List && t.isNotEmpty) kitTmplIds.add(t[0] as int);
      }
    } catch (e) {
      debugPrint('mrp.bom kit check note: $e');
    }

    // Query template IDs that have real pictures in Odoo (fast 34ms indexed query)
    final Set<int> tmplIdsWithImage = {};
    try {
      final tmplDomain = <dynamic>[
        ['image_128', '!=', false],
        ['company_id', 'in', [false, profile.companyId]],
      ];
      if (catMap.isNotEmpty) {
        tmplDomain.add(['pos_categ_ids', 'in', catMap.keys.toList()]);
      }
      final idsWithImg = await executeKw(
        'product.template',
        'search',
        [tmplDomain],
        {'limit': 10000},
      ) as List<dynamic>;
      for (final tid in idsWithImg) {
        if (tid is int) tmplIdsWithImage.add(tid);
      }
    } catch (e) {
      debugPrint('product.template image check note: $e');
    }

    final productDomain = <dynamic>[
      ['available_in_pos', '=', true],
      ['name', 'not ilike', 'ARCHIVED'],
      ['company_id', 'in', [false, profile.companyId]],
    ];
    if (catMap.isNotEmpty) {
      productDomain.add(['pos_categ_ids', 'in', catMap.keys.toList()]);
    }

    final result = await executeKw(
      'product.product',
      'search_read',
      [productDomain],
      {
        'fields': [
          'id',
          'name',
          'list_price',
          'pos_categ_ids',
          'barcode',
          'default_code',
          'qty_available',
          'uom_id',
          'product_tmpl_id',
          'write_date',
        ],
        'order': 'name asc',
        'limit': 5000,
      },
    ) as List<dynamic>;

    final products = <JuiceProduct>[];
    for (final row in result) {
      final id = row['id'] as int;
      final name = (row['name'] as String).trim();
      final price = ((row['list_price'] as num?) ?? 0).toInt();
      final categIds = (row['pos_categ_ids'] as List<dynamic>? ?? []).map((e) => e as int).toList();
      final barcode = row['barcode'] is String ? (row['barcode'] as String).trim() : null;
      final defaultCode = row['default_code'] is String ? (row['default_code'] as String).trim() : null;
      final qtyAvailable = (row['qty_available'] as num?)?.toDouble();
      final uomRaw = row['uom_id'];
      final uomName = uomRaw is List && uomRaw.length > 1 ? uomRaw[1].toString() : null;
      final writeDate = row['write_date'] is String ? (row['write_date'] as String).trim() : null;

      final tmplId = (row['product_tmpl_id'] is List && (row['product_tmpl_id'] as List).isNotEmpty)
          ? row['product_tmpl_id'][0] as int
          : null;
      final isKit = kitProductIds.contains(id) || (tmplId != null && kitTmplIds.contains(tmplId));
      final hasImage = tmplId != null && tmplIdsWithImage.contains(tmplId);

      final grabPrice = grabMap[id] ?? (tmplId != null ? grabMap[tmplId] : null);
      final shopeePrice = shopeeMap[id] ?? (tmplId != null ? shopeeMap[tmplId] : null);

      String? category;
      for (final cid in categIds) {
        if (catMap.containsKey(cid)) {
          category = catMap[cid];
          break;
        }
      }

      category ??= (catMap.isNotEmpty ? catMap.values.first : 'General');

      final lowerCat = category.toLowerCase();
      final requiresModifier = profile.isFnb &&
          (lowerCat.contains('juice') ||
              lowerCat.contains('drink') ||
              lowerCat.contains('smoothie') ||
              lowerCat.contains('coffee') ||
              lowerCat.contains('tea'));

      products.add(JuiceProduct(
        id: id,
        name: name,
        price: price,
        category: category,
        barcode: barcode,
        defaultCode: defaultCode,
        uomName: uomName,
        qtyAvailable: qtyAvailable,
        isKit: isKit,
        icon: profile.isFnb ? Icons.local_cafe_outlined : Icons.shopping_basket_outlined,
        themeColor: profile.isFnb ? const Color(0xFFFB8C00) : const Color(0xFF1E88E5),
        requiresModifier: requiresModifier,
        grabPrice: grabPrice,
        shopeePrice: shopeePrice,
        writeDate: writeDate,
        productTmplId: tmplId,
        hasImage: hasImage,
      ));
    }
    return products;
  }

  // Fetch Live Add-ons
  Future<List<AddOnOption>> fetchAddOns() async {
    final result = await executeKw(
      'product.product',
      'search_read',
      [
        [
          ['available_in_pos', '=', true],
          '|',
          ['name', 'ilike', 'ads'],
          ['name', 'ilike', 'WHEY'],
        ]
      ],
      {
        'fields': ['id', 'name', 'list_price'],
      },
    ) as List<dynamic>;

    final addons = <AddOnOption>[];
    for (final row in result) {
      final id = row['id'].toString();
      final name = (row['name'] as String).trim();
      final price = ((row['list_price'] as num?) ?? 0).toInt();

      addons.add(AddOnOption(id: id, name: name, extraPrice: price));
    }
    return addons;
  }

  // Live Customer Search with Odoo 19 Loyalty Points
  Future<List<Customer>> searchCustomers(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final isNumeric = RegExp(r'^[0-9+]+$').hasMatch(cleanQuery);
    final domain = isNumeric
        ? <dynamic>[['phone', 'ilike', cleanQuery]]
        : <dynamic>[
            '|',
            ['name', 'ilike', cleanQuery],
            ['phone', 'ilike', cleanQuery],
          ];

    try {
      final result = await executeKw(
        'res.partner',
        'search_read',
        [domain],
        {
          'fields': ['id', 'name', 'phone', 'barcode'],
          'limit': 20,
        },
      ) as List<dynamic>;

      if (result.isEmpty) return [];

      final partnerIds = result.map((r) => r['id'] as int).toList();
      final pointsMap = <int, double>{};

      try {
        final cards = await executeKw(
          'loyalty.card',
          'search_read',
          [[['partner_id', 'in', partnerIds]]],
          {
            'fields': ['partner_id', 'points', 'code'],
          },
        ) as List<dynamic>;

        for (final c in cards) {
          final pidList = c['partner_id'];
          if (pidList is List && pidList.isNotEmpty) {
            final pid = pidList[0] as int;
            final pts = (c['points'] as num?)?.toDouble() ?? 0.0;
            pointsMap[pid] = (pointsMap[pid] ?? 0.0) + pts;
          }
        }
      } catch (e) {
        debugPrint('loyalty.card fetch note: $e');
      }

      return result.map((row) {
        final id = row['id'] as int;
        final name = (row['name'] as String? ?? 'Member').trim();
        final phone = (row['phone'] is String ? row['phone'] as String : '').trim();
        final points = pointsMap[id] ?? 0.0;

        return Customer(
          id: id,
          name: name,
          phone: phone.isNotEmpty ? phone : '-',
          tier: points > 500 ? 'Platinum' : (points > 100 ? 'Gold' : 'Member'),
          points: points,
        );
      }).toList();
    } catch (e) {
      debugPrint('searchCustomers error: $e');
      return [];
    }
  }

  // Lookup Customer by Phone (Single Result)
  Future<Customer?> searchCustomerByPhone(String phone) async {
    final list = await searchCustomers(phone);
    return list.isNotEmpty ? list.first : null;
  }

  // Fetch Order History from Odoo
  Future<List<OdooOrderRecord>> fetchRecentOrders([int limit = 25]) async {
    final sessionId = _activeSessionId ?? await fetchActiveSession();
    final domain = sessionId != null
        ? [
            ['session_id', '=', sessionId]
          ]
        : <dynamic>[];

    final result = await executeKw(
      'pos.order',
      'search_read',
      [domain],
      {
        'fields': ['id', 'name', 'pos_reference', 'date_order', 'amount_total', 'partner_id', 'state'],
        'order': 'id desc',
        'limit': limit,
      },
    ) as List<dynamic>;

    return result.map((r) {
      final partner = r['partner_id'];
      final partnerName = partner is List && partner.length > 1 ? partner[1].toString() : 'Umum / Guest';
      return OdooOrderRecord(
        id: r['id'] as int,
        name: r['name'] as String,
        posReference: (r['pos_reference'] ?? r['name']).toString(),
        dateOrder: (r['date_order'] ?? '').toString(),
        amountTotal: ((r['amount_total'] as num?) ?? 0).toDouble(),
        partnerName: partnerName,
        state: (r['state'] ?? 'draft').toString(),
      );
    }).toList();
  }

  // Fetch Line Items for an Order (for Receipt Reprint)
  Future<List<Map<String, dynamic>>> fetchOrderLines(int orderId) async {
    try {
      final result = await executeKw(
        'pos.order.line',
        'search_read',
        [
          [
            ['order_id', '=', orderId]
          ]
        ],
        {
          'fields': ['product_id', 'qty', 'price_unit', 'price_subtotal_incl', 'full_product_name', 'name'],
        },
      ) as List<dynamic>;
      return result.map((e) {
        final line = Map<String, dynamic>.from(e as Map);
        final fpn = line['full_product_name'];
        if (fpn is String && fpn.trim().isNotEmpty && fpn.trim().toLowerCase() != 'false') {
          line['full_product_name'] = fpn.trim();
        } else {
          final pid = line['product_id'];
          if (pid is List && pid.length > 1 && pid[1] != null) {
            final raw = pid[1].toString().trim();
            final match = RegExp(r'^\[.*?\]\s*(.*)$').firstMatch(raw);
            line['full_product_name'] = (match != null && match.group(1)?.trim().isNotEmpty == true)
                ? match.group(1)!.trim()
                : raw;
          } else if (line['name'] is String && (line['name'] as String).trim().isNotEmpty) {
            line['full_product_name'] = (line['name'] as String).trim();
          } else {
            line['full_product_name'] = 'Item';
          }
        }
        return line;
      }).toList();
    } catch (e) {
      debugPrint('[Odoo] fetchOrderLines error: $e');
      return [];
    }
  }

  // Submit Order via Native sync_from_ui (Notifies other cashier screen live)
  Future<PosOrderSubmissionResult> submitPosOrder({
    required List<CartItem> items,
    required int totalAmount,
    required int paidAmount,
    required int changeAmount,
    required String paymentMethodName,
    int orderDiscountAmount = 0,
    double orderDiscountPercent = 0.0,
    int pointsDiscount = 0,
    int redeemedPoints = 0,
    String? orderUuid,
    int? partnerId,
    String? orderNote,
    String? channelTag,
    PosCashier? cashier,
  }) async {
    final sessionId = _activeSessionId ?? await fetchActiveSession();
    if (sessionId == null) {
      throw Exception('No open cashier session found in Odoo for this store. Please open a session first.');
    }

    final finalOrderUuid = orderUuid ?? _uuid.v4();
    final orderLines = <List<dynamic>>[];

    for (final item in items) {
      final lineUuid = _uuid.v4();
      final lineNoteParts = <String>[];
      if (item.modifiers.summaryDescription.isNotEmpty && item.modifiers.summaryDescription != 'Normal (Default)') {
        lineNoteParts.add(item.modifiers.summaryDescription);
      }
      if (item.note != null && item.note!.isNotEmpty) {
        lineNoteParts.add('Catatan: ${item.note}');
      }
      if (channelTag != null) {
        lineNoteParts.add('[$channelTag]');
      }

      final effDiscount = (item.discountPercent != null && item.discountPercent! > 0)
          ? item.discountPercent!.toDouble()
          : (orderDiscountPercent > 0 ? orderDiscountPercent : 0.0);

      final priceUnit = effDiscount > 0
          ? item.originalUnitPrice.toDouble()
          : item.unitPrice.toDouble();

      orderLines.add([
        0,
        0,
        {
          'uuid': lineUuid,
          'product_id': item.product.id,
          'full_product_name': item.product.name,
          'qty': item.quantity,
          'price_unit': priceUnit,
          'price_subtotal': item.lineTotal.toDouble(),
          'price_subtotal_incl': item.lineTotal.toDouble(),
          'discount': effDiscount,
          'customer_note': lineNoteParts.join(' | '),
        }
      ]);
    }

    // Dynamically resolve discount product ID if fixed discount or loyalty points are used
    int? discountProductId;
    if ((orderDiscountAmount > 0 && orderDiscountPercent == 0) || pointsDiscount > 0) {
      discountProductId = await _resolveDiscountProductId(items);
    }

    // Fixed amount discount line if percentage was not used
    if (orderDiscountAmount > 0 && orderDiscountPercent == 0 && discountProductId != null) {
      orderLines.add([
        0,
        0,
        {
          'uuid': _uuid.v4(),
          'product_id': discountProductId,
          'qty': 1,
          'price_unit': -orderDiscountAmount.toDouble(),
          'price_subtotal': -orderDiscountAmount.toDouble(),
          'price_subtotal_incl': -orderDiscountAmount.toDouble(),
          'customer_note': 'Cart Discount',
        }
      ]);
    }

    // Loyalty points redemption line
    if (pointsDiscount > 0 && discountProductId != null) {
      orderLines.add([
        0,
        0,
        {
          'uuid': _uuid.v4(),
          'product_id': discountProductId,
          'qty': 1,
          'price_unit': -pointsDiscount.toDouble(),
          'price_subtotal': -pointsDiscount.toDouble(),
          'price_subtotal_incl': -pointsDiscount.toDouble(),
          'customer_note': 'Loyalty Points Redemption (${redeemedPoints > 0 ? redeemedPoints : pointsDiscount} Pts)',
        }
      ]);
    }

    // Dynamic resolution of payment method based on current store's configured pos.payment.method
    final registry = _paymentRegistry ?? await fetchPaymentMethods();
    final resolvedMethod = registry.resolveMethod(paymentMethodName);

    if (resolvedMethod == null) {
      final pmLower = paymentMethodName.toLowerCase();
      if (pmLower.contains('grab')) {
        throw Exception('Metode GrabFood belum dikonfigurasi di Odoo untuk toko ini (${profile.displayName}). Silakan hubungi admin akuntansi.');
      } else if (pmLower.contains('shopee')) {
        throw Exception('Metode ShopeeFood belum dikonfigurasi di Odoo untuk toko ini (${profile.displayName}). Silakan hubungi admin akuntansi.');
      }
      throw Exception('Metode pembayaran "$paymentMethodName" belum dikonfigurasi di Odoo untuk toko ini (${profile.displayName}).');
    }

    final effectivePaymentAmount = totalAmount < 0
        ? totalAmount.toDouble()
        : (paidAmount != 0 ? paidAmount.toDouble() : totalAmount.toDouble());

    final paymentLines = [
      [
        0,
        0,
        {
          'uuid': _uuid.v4(),
          'payment_method_id': resolvedMethod.id,
          'amount': effectivePaymentAmount,
          'name': resolvedMethod.name,
        }
      ]
    ];

    // NOTE: In Odoo 19 `sync_from_ui`, pos_order.py automatically creates the 'return' payment line
    // from `pos_order['amount_return']`. Do NOT include a manual return payment line here, and
    // `amount_return` MUST be negative (e.g. -5000.0) so Odoo properly nets it against tendered payment.
    final effectiveCashier = cashier ?? _activeCashier;
    final orderPayload = [
      {
        'uuid': finalOrderUuid,
        'session_id': sessionId,
        'amount_paid': totalAmount.toDouble(),
        'amount_total': totalAmount.toDouble(),
        'amount_tax': 0.0,
        'amount_return': changeAmount > 0 ? -changeAmount.toDouble() : 0.0,
        'partner_id': partnerId,
        'lines': orderLines,
        'payment_ids': paymentLines,
        'to_invoice': false,
        if (effectiveCashier != null && effectiveCashier.id > 0) 'employee_id': effectiveCashier.id,
        if (effectiveCashier != null) 'cashier': effectiveCashier.name,
        if (effectiveCashier?.userId != null) 'user_id': effectiveCashier!.userId,
      }
    ];

    final result = await executeKw('pos.order', 'sync_from_ui', [orderPayload]);

    // Update customer loyalty card point balance in Odoo if points were redeemed
    if (pointsDiscount > 0 && partnerId != null) {
      try {
        final cards = await executeKw(
          'loyalty.card',
          'search_read',
          [[['partner_id', '=', partnerId]]],
          {'fields': ['id', 'points'], 'order': 'points desc', 'limit': 1},
        ) as List<dynamic>;
        if (cards.isNotEmpty) {
          final cardId = cards[0]['id'] as int;
          final currentPts = (cards[0]['points'] as num?)?.toDouble() ?? 0.0;
          final ptsToDeduct = (redeemedPoints > 0 ? redeemedPoints : pointsDiscount).toDouble();
          final newPts = (currentPts - ptsToDeduct).clamp(0.0, double.infinity);
          await executeKw('loyalty.card', 'write', [[cardId], {'points': newPts}]);
        }
      } catch (e) {
        debugPrint('Note: Error updating loyalty card balance in Odoo: $e');
      }
    }

    return PosOrderSubmissionResult.fromSyncResult(result);
  }

  int? _cachedDiscountProductId;

  Future<int?> _resolveDiscountProductId(List<CartItem> items) async {
    if (_cachedDiscountProductId != null) return _cachedDiscountProductId;
    try {
      // 1. Check pos.config discount_product_id
      final configs = await executeKw(
        'pos.config',
        'read',
        [[profile.posConfigId]],
        {'fields': ['discount_product_id']},
      ) as List<dynamic>;
      if (configs.isNotEmpty) {
        final dp = (configs.first as Map<String, dynamic>)['discount_product_id'];
        if (dp is List && dp.isNotEmpty && dp[0] is int) {
          _cachedDiscountProductId = dp[0] as int;
          return _cachedDiscountProductId;
        }
      }
    } catch (_) {}

    try {
      // 2. Search for a product named Discount / Diskon / Loyalty available in POS
      final prods = await executeKw(
        'product.product',
        'search_read',
        [[
          ['available_in_pos', '=', true],
          '|', '|',
          ['name', 'ilike', 'Discount'],
          ['name', 'ilike', 'Diskon'],
          ['name', 'ilike', 'Loyalty'],
        ]],
        {'fields': ['id'], 'limit': 1},
      ) as List<dynamic>;
      if (prods.isNotEmpty) {
        _cachedDiscountProductId = (prods.first as Map<String, dynamic>)['id'] as int;
        return _cachedDiscountProductId;
      }
    } catch (_) {}

    // 3. Fallback to first cart item product_id so sync_from_ui never fails on foreign key
    return items.isNotEmpty ? items.first.product.id : null;
  }

  // Submit Cash In / Cash Out drawer move directly to Odoo 19 pos.session
  Future<void> submitCashInOut({
    required String type, // 'in' or 'out'
    required double amount,
    required String reason,
    int? partnerId,
    PosCashier? cashier,
  }) async {
    final sessionId = _activeSessionId ?? await fetchActiveSession();
    if (sessionId == null) {
      throw Exception('No open cashier session found in Odoo for this store.');
    }
    final effectiveCashier = cashier ?? _activeCashier;
    final translatedType = type == 'in' ? 'Cash In' : 'Cash Out';
    final cashierNote = effectiveCashier != null ? ' [${effectiveCashier.name}]' : '';
    final finalReason = reason.contains('[') ? reason : '$reason$cashierNote';

    final extras = <String, dynamic>{
      'translatedType': translatedType,
      if (effectiveCashier != null && effectiveCashier.id > 0) 'employee_id': effectiveCashier.id,
    };

    await executeKw('pos.session', 'try_cash_in_out', [
      [sessionId],
      type,
      amount,
      finalReason,
      partnerId ?? false,
      extras,
    ]);
  }
}

