import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Live metadata synced from Odoo `pos.config` and `res.company`
class OdooReceiptMetadata {
  final String companyName;
  final String street;
  final String city;
  final String phone;
  final String vat;
  final String email;
  final String website;
  final bool isHeaderOrFooter;
  final String receiptHeader;
  final String receiptFooter;

  const OdooReceiptMetadata({
    this.companyName = '',
    this.street = '',
    this.city = '',
    this.phone = '',
    this.vat = '',
    this.email = '',
    this.website = '',
    this.isHeaderOrFooter = false,
    this.receiptHeader = '',
    this.receiptFooter = '',
  });

  factory OdooReceiptMetadata.fromJson(Map<String, dynamic> json) {
    return OdooReceiptMetadata(
      companyName: json['company_name']?.toString() ?? '',
      street: json['street']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      vat: json['vat']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      website: json['website']?.toString() ?? '',
      isHeaderOrFooter: json['is_header_or_footer'] == true,
      receiptHeader: json['receipt_header']?.toString() ?? '',
      receiptFooter: json['receipt_footer']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'company_name': companyName,
        'street': street,
        'city': city,
        'phone': phone,
        'vat': vat,
        'email': email,
        'website': website,
        'is_header_or_footer': isHeaderOrFooter,
        'receipt_header': receiptHeader,
        'receipt_footer': receiptFooter,
      };
}

class CustomerReceiptConfig {
  final String storeName;
  final String subtitle;
  final String footer;
  final String fnbStoreName;
  final String fnbSubtitle;
  final String fnbFooter;
  final bool showSubtitle;
  final bool showCashier;
  final bool showCustomer;
  final bool showLoyaltyPoints;
  final bool showFooter;

  const CustomerReceiptConfig({
    this.storeName = 'ARAWALI',
    this.subtitle = 'Bima Kota NTB 0811-3909-800',
    this.footer = 'Penukaran MAX 1x24 Jam',
    this.fnbStoreName = 'Pick A Juice',
    this.fnbSubtitle = 'Jl. Kartini No. 10 - Kota Bima\nIG: @pickajuiceid | WA: 0878-4519-3760',
    this.fnbFooter = 'Terima kasih atas kunjungan anda\nTunjukkan Resi untuk parkir gratis',
    this.showSubtitle = true,
    this.showCashier = true,
    this.showCustomer = true,
    this.showLoyaltyPoints = true,
    this.showFooter = true,
  });

  factory CustomerReceiptConfig.fromJson(Map<String, dynamic> json) {
    return CustomerReceiptConfig(
      storeName: json['store_name'] as String? ?? 'ARAWALI',
      subtitle: json['subtitle'] as String? ?? 'Bima Kota NTB 0811-3909-800',
      footer: json['footer'] as String? ?? 'Penukaran MAX 1x24 Jam',
      fnbStoreName: json['fnb_store_name'] as String? ?? 'Pick A Juice',
      fnbSubtitle: json['fnb_subtitle'] as String? ??
          'Jl. Kartini No. 10 - Kota Bima\nIG: @pickajuiceid | WA: 0878-4519-3760',
      fnbFooter: json['fnb_footer'] as String? ??
          'Terima kasih atas kunjungan anda\nTunjukkan Resi untuk parkir gratis',
      showSubtitle: json['show_subtitle'] as bool? ?? true,
      showCashier: json['show_cashier'] as bool? ?? true,
      showCustomer: json['show_customer'] as bool? ?? true,
      showLoyaltyPoints: json['show_loyalty_points'] as bool? ?? true,
      showFooter: json['show_footer'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'store_name': storeName,
        'subtitle': subtitle,
        'footer': footer,
        'fnb_store_name': fnbStoreName,
        'fnb_subtitle': fnbSubtitle,
        'fnb_footer': fnbFooter,
        'show_subtitle': showSubtitle,
        'show_cashier': showCashier,
        'show_customer': showCustomer,
        'show_loyalty_points': showLoyaltyPoints,
        'show_footer': showFooter,
      };
}

class CashMoveReceiptConfig {
  final bool showVoucherBanner;
  final String header;
  final bool showCashier;
  final bool showReason;
  final bool showSignature;
  final String footer;

  const CashMoveReceiptConfig({
    this.showVoucherBanner = false,
    this.header = 'ARAWALI - KOTA BIMA',
    this.showCashier = true,
    this.showReason = true,
    this.showSignature = false,
    this.footer = '',
  });

  factory CashMoveReceiptConfig.fromJson(Map<String, dynamic> json) {
    return CashMoveReceiptConfig(
      showVoucherBanner: json['show_voucher_banner'] as bool? ?? false,
      header: json['header'] as String? ?? 'ARAWALI - KOTA BIMA',
      showCashier: json['show_cashier'] as bool? ?? true,
      showReason: json['show_reason'] as bool? ?? true,
      showSignature: json['show_signature'] as bool? ?? false,
      footer: json['footer'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'show_voucher_banner': showVoucherBanner,
        'header': header,
        'show_cashier': showCashier,
        'show_reason': showReason,
        'show_signature': showSignature,
        'footer': footer,
      };
}

class SessionCloseReceiptConfig {
  final String header;
  final String title;
  final String subtitle;
  final bool showAddress;
  final String address;
  final bool showSalesSummary;
  final bool showCashControl;
  final bool showNonCashQris;
  final bool showSignature;
  final String footer;

  const SessionCloseReceiptConfig({
    this.header = 'ARAWALI',
    this.title = 'LAPORAN PENUTUPAN KASIR',
    this.subtitle = '',
    this.showAddress = false,
    this.address = '',
    this.showSalesSummary = true,
    this.showCashControl = true,
    this.showNonCashQris = true,
    this.showSignature = false,
    this.footer = '',
  });

  factory SessionCloseReceiptConfig.fromJson(Map<String, dynamic> json) {
    return SessionCloseReceiptConfig(
      header: json['header'] as String? ?? 'ARAWALI',
      title: json['title'] as String? ?? 'LAPORAN PENUTUPAN KASIR',
      subtitle: json['subtitle'] as String? ?? '',
      showAddress: json['show_address'] as bool? ?? false,
      address: json['address'] as String? ?? '',
      showSalesSummary: json['show_sales_summary'] as bool? ?? true,
      showCashControl: json['show_cash_control'] as bool? ?? true,
      showNonCashQris: json['show_non_cash_qris'] as bool? ?? true,
      showSignature: json['show_signature'] as bool? ?? false,
      footer: json['footer'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'header': header,
        'title': title,
        'subtitle': subtitle,
        'show_address': showAddress,
        'address': address,
        'show_sales_summary': showSalesSummary,
        'show_cash_control': showCashControl,
        'show_non_cash_qris': showNonCashQris,
        'show_signature': showSignature,
        'footer': footer,
      };
}

class KitchenReceiptConfig {
  final String header;
  final bool showCashier;
  final bool showNote;

  const KitchenReceiptConfig({
    this.header = '*** PAJ KITCHEN / BARISTA ***',
    this.showCashier = true,
    this.showNote = true,
  });

  factory KitchenReceiptConfig.fromJson(Map<String, dynamic> json) {
    return KitchenReceiptConfig(
      header: json['header'] as String? ?? '*** PAJ KITCHEN / BARISTA ***',
      showCashier: json['show_cashier'] as bool? ?? true,
      showNote: json['show_note'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'header': header,
        'show_cashier': showCashier,
        'show_note': showNote,
      };
}

/// Master modular receipt configuration.
/// Can be loaded dynamically from `receipt_config.json` or overridden by Odoo `pos.config`.
class ReceiptConfig {
  final bool useOdooOriginalFormat;
  final bool syncHeaderFooterFromOdoo;
  final CustomerReceiptConfig customerReceipt;
  final CashMoveReceiptConfig cashMove;
  final SessionCloseReceiptConfig sessionClose;
  final KitchenReceiptConfig kitchen;
  final OdooReceiptMetadata odooMeta;

  const ReceiptConfig({
    this.useOdooOriginalFormat = false,
    this.syncHeaderFooterFromOdoo = false,
    this.customerReceipt = const CustomerReceiptConfig(),
    this.cashMove = const CashMoveReceiptConfig(),
    this.sessionClose = const SessionCloseReceiptConfig(),
    this.kitchen = const KitchenReceiptConfig(),
    this.odooMeta = const OdooReceiptMetadata(),
  });

  ReceiptConfig copyWith({
    bool? useOdooOriginalFormat,
    bool? syncHeaderFooterFromOdoo,
    CustomerReceiptConfig? customerReceipt,
    CashMoveReceiptConfig? cashMove,
    SessionCloseReceiptConfig? sessionClose,
    KitchenReceiptConfig? kitchen,
    OdooReceiptMetadata? odooMeta,
  }) {
    return ReceiptConfig(
      useOdooOriginalFormat: useOdooOriginalFormat ?? this.useOdooOriginalFormat,
      syncHeaderFooterFromOdoo: syncHeaderFooterFromOdoo ?? this.syncHeaderFooterFromOdoo,
      customerReceipt: customerReceipt ?? this.customerReceipt,
      cashMove: cashMove ?? this.cashMove,
      sessionClose: sessionClose ?? this.sessionClose,
      kitchen: kitchen ?? this.kitchen,
      odooMeta: odooMeta ?? this.odooMeta,
    );
  }

  factory ReceiptConfig.fromJson(Map<String, dynamic> json) {
    return ReceiptConfig(
      useOdooOriginalFormat: json['use_odoo_original_format'] as bool? ?? false,
      syncHeaderFooterFromOdoo: json['sync_header_footer_from_odoo'] as bool? ?? false,
      customerReceipt: json['customer_receipt'] is Map<String, dynamic>
          ? CustomerReceiptConfig.fromJson(json['customer_receipt'] as Map<String, dynamic>)
          : const CustomerReceiptConfig(),
      cashMove: json['cash_move'] is Map<String, dynamic>
          ? CashMoveReceiptConfig.fromJson(json['cash_move'] as Map<String, dynamic>)
          : const CashMoveReceiptConfig(),
      sessionClose: json['session_close'] is Map<String, dynamic>
          ? SessionCloseReceiptConfig.fromJson(json['session_close'] as Map<String, dynamic>)
          : const SessionCloseReceiptConfig(),
      kitchen: json['kitchen'] is Map<String, dynamic>
          ? KitchenReceiptConfig.fromJson(json['kitchen'] as Map<String, dynamic>)
          : const KitchenReceiptConfig(),
      odooMeta: json['odoo_meta'] is Map<String, dynamic>
          ? OdooReceiptMetadata.fromJson(json['odoo_meta'] as Map<String, dynamic>)
          : const OdooReceiptMetadata(),
    );
  }

  Map<String, dynamic> toJson() => {
        'use_odoo_original_format': useOdooOriginalFormat,
        'sync_header_footer_from_odoo': syncHeaderFooterFromOdoo,
        'customer_receipt': customerReceipt.toJson(),
        'cash_move': cashMove.toJson(),
        'session_close': sessionClose.toJson(),
        'kitchen': kitchen.toJson(),
        'odoo_meta': odooMeta.toJson(),
      };

  static const String _prefsKey = 'pos_receipt_config_json';

  /// Loads external `receipt_config.json` from local proxy/web server or saved preferences.
  static Future<ReceiptConfig> load({String? baseUrl}) async {
    try {
      final Uri uri = kIsWeb
          ? Uri.base.resolve('/receipt_config.json')
          : Uri.parse('${baseUrl ?? "http://127.0.0.1:8089"}/receipt_config.json');
      final response = await http.get(uri).timeout(const Duration(milliseconds: 800));
      if (response.statusCode == 200 && response.body.trim().startsWith('{')) {
        final map = jsonDecode(response.body) as Map<String, dynamic>;
        final cfg = ReceiptConfig.fromJson(map);
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefsKey, response.body);
        } catch (_) {}
        return cfg;
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null && saved.trim().startsWith('{')) {
        return ReceiptConfig.fromJson(jsonDecode(saved) as Map<String, dynamic>);
      }
    } catch (_) {}

    return const ReceiptConfig();
  }
}
