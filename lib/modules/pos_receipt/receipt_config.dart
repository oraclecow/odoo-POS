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
    this.storeName = 'MAIN STORE POS',
    this.subtitle = 'Point of Sale Receipt',
    this.footer = 'Thank you for your business!',
    this.fnbStoreName = 'CAFE & RESTAURANT POS',
    this.fnbSubtitle = 'Point of Sale Receipt',
    this.fnbFooter = 'Thank you for your business!',
    this.showSubtitle = true,
    this.showCashier = true,
    this.showCustomer = true,
    this.showLoyaltyPoints = true,
    this.showFooter = true,
  });

  factory CustomerReceiptConfig.fromJson(Map<String, dynamic> json) {
    return CustomerReceiptConfig(
      storeName: json['store_name']?.toString() ?? 'MAIN STORE POS',
      subtitle: json['subtitle']?.toString() ?? 'Point of Sale Receipt',
      footer: json['footer']?.toString() ?? 'Thank you for your business!',
      fnbStoreName: json['fnb_store_name']?.toString() ?? 'CAFE & RESTAURANT POS',
      fnbSubtitle: json['fnb_subtitle']?.toString() ?? 'Point of Sale Receipt',
      fnbFooter: json['fnb_footer']?.toString() ?? 'Thank you for your business!',
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
  final String headerTitle;
  final String subtitle;
  final bool showVoucherBanner;
  final bool showSignature;
  final String footerNote;

  const CashMoveReceiptConfig({
    this.headerTitle = 'MAIN STORE POS',
    this.subtitle = '',
    this.showVoucherBanner = false,
    this.showSignature = false,
    this.footerNote = '',
  });

  factory CashMoveReceiptConfig.fromJson(Map<String, dynamic> json) {
    return CashMoveReceiptConfig(
      headerTitle: json['header_title']?.toString() ?? 'MAIN STORE POS',
      subtitle: json['subtitle']?.toString() ?? '',
      showVoucherBanner: json['show_voucher_banner'] as bool? ?? false,
      showSignature: json['show_signature'] as bool? ?? false,
      footerNote: json['footer_note']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'header_title': headerTitle,
        'subtitle': subtitle,
        'show_voucher_banner': showVoucherBanner,
        'show_signature': showSignature,
        'footer_note': footerNote,
      };
}

class SessionCloseReceiptConfig {
  final String headerTitle;
  final String reportTitle;
  final String subtitle;
  final String headerDividerChar;
  final bool showCashMovesDetail;
  final bool showNonCashBreakdown;
  final bool showSignature;
  final String footerNote;

  const SessionCloseReceiptConfig({
    this.headerTitle = 'MAIN STORE POS',
    this.reportTitle = 'LAPORAN PENUTUPAN KASIR',
    this.subtitle = '',
    this.headerDividerChar = '=',
    this.showCashMovesDetail = true,
    this.showNonCashBreakdown = true,
    this.showSignature = false,
    this.footerNote = '',
  });

  factory SessionCloseReceiptConfig.fromJson(Map<String, dynamic> json) {
    return SessionCloseReceiptConfig(
      headerTitle: json['header_title']?.toString() ?? 'MAIN STORE POS',
      reportTitle: json['report_title']?.toString() ?? 'LAPORAN PENUTUPAN KASIR',
      subtitle: json['subtitle']?.toString() ?? '',
      headerDividerChar: json['header_divider_char']?.toString() ?? '=',
      showCashMovesDetail: json['show_cash_moves_detail'] as bool? ?? true,
      showNonCashBreakdown: json['show_non_cash_breakdown'] as bool? ?? true,
      showSignature: json['show_signature'] as bool? ?? false,
      footerNote: json['footer_note']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'header_title': headerTitle,
        'report_title': reportTitle,
        'subtitle': subtitle,
        'header_divider_char': headerDividerChar,
        'show_cash_moves_detail': showCashMovesDetail,
        'show_non_cash_breakdown': showNonCashBreakdown,
        'show_signature': showSignature,
        'footer_note': footerNote,
      };
}

class KitchenReceiptConfig {
  final String headerTitle;
  final bool showModifiers;
  final bool showNotes;

  const KitchenReceiptConfig({
    this.headerTitle = '*** KITCHEN / BARISTA ORDER ***',
    this.showModifiers = true,
    this.showNotes = true,
  });

  factory KitchenReceiptConfig.fromJson(Map<String, dynamic> json) {
    return KitchenReceiptConfig(
      headerTitle: json['header_title']?.toString() ?? '*** KITCHEN / BARISTA ORDER ***',
      showModifiers: json['show_modifiers'] as bool? ?? true,
      showNotes: json['show_notes'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'header_title': headerTitle,
        'show_modifiers': showModifiers,
        'show_notes': showNotes,
      };
}

/// Top-level Receipt Configuration loaded from `/receipt_config.json` or SharedPreferences.
/// Allows editing headers, footers, blocks, or toggling standard Odoo 19 receipt layout
/// without recompiling the application.
class ReceiptConfig {
  /// If true, uses the standard Odoo 19 `OrderReceipt` layout (Company info,
  /// "Served by", `pos.config.receipt_header`, itemized lines, `pos.config.receipt_footer`).
  final bool useOdooOriginalFormat;

  /// If true, overrides custom header/footer text with live `pos.config.receipt_header`
  /// and `pos.config.receipt_footer` fetched from Odoo 19.
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

  static const String _prefsKey = 'pos_receipt_config_v1';

  /// Loads `receipt_config.json` at runtime (via HTTP from local web server or SharedPreferences override).
  static Future<ReceiptConfig> load({String? baseUrl}) async {
    ReceiptConfig baseConfig = const ReceiptConfig();

    // 1. Try loading external `receipt_config.json` from local static server (web or 127.0.0.1:8089)
    try {
      final Uri configUri = kIsWeb
          ? Uri.base.resolve('/receipt_config.json')
          : Uri.parse('${baseUrl ?? "http://127.0.0.1:8089"}/receipt_config.json');
      final response = await http.get(configUri).timeout(const Duration(milliseconds: 800));
      if (response.statusCode == 200 && response.body.trim().startsWith('{')) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        baseConfig = ReceiptConfig.fromJson(decoded);
      }
    } catch (_) {}

    // 2. Check SharedPreferences for local overrides or cached Odoo metadata
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_prefsKey);
      if (savedJson != null && savedJson.trim().startsWith('{')) {
        final savedMap = jsonDecode(savedJson) as Map<String, dynamic>;
        final savedCfg = ReceiptConfig.fromJson(savedMap);
        return baseConfig.copyWith(
          useOdooOriginalFormat: savedMap.containsKey('use_odoo_original_format')
              ? savedCfg.useOdooOriginalFormat
              : baseConfig.useOdooOriginalFormat,
          syncHeaderFooterFromOdoo: savedMap.containsKey('sync_header_footer_from_odoo')
              ? savedCfg.syncHeaderFooterFromOdoo
              : baseConfig.syncHeaderFooterFromOdoo,
          odooMeta: savedCfg.odooMeta,
        );
      }
    } catch (_) {}

    return baseConfig;
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(toJson()));
    } catch (_) {}
  }
}
