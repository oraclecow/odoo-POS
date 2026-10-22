enum PosBusinessMode {
  retail('retail', 'Retail / Supermarket (point_of_sale)'),
  fnb('fnb', 'F&B / Cafe / Bakery (pos_restaurant)');

  final String code;
  final String label;
  const PosBusinessMode(this.code, this.label);

  bool get isRetail => this == PosBusinessMode.retail;
  bool get isFnb => this == PosBusinessMode.fnb;

  static PosBusinessMode fromString(String? value, {int? companyId}) {
    if (value != null) {
      final clean = value.trim().toLowerCase();
      if (clean == 'fnb' || clean == 'restaurant' || clean == 'cafe' || clean == 'bakery') {
        return PosBusinessMode.fnb;
      }
      if (clean == 'retail' || clean == 'shop' || clean == 'supermarket') {
        return PosBusinessMode.retail;
      }
    }
    // Auto-detect fallback based on known company IDs (1 = Arawali Retail, others = PAJ / Bakery F&B)
    if (companyId != null && companyId != 1) {
      return PosBusinessMode.fnb;
    }
    return PosBusinessMode.retail;
  }
}

/// Mistake-proofing guardrails for cashier operations.
/// Hides complicated controls that workers do not need in daily operation.
class WorkerUiGuardrails {
  final bool allowManualDiscount;
  final bool allowPriceOverride;
  final bool allowRefund;
  final bool allowCashInOut;
  final bool requireAdminPinForSettings;
  final bool enableFnbModifiers;
  final bool enableOrderChannels;
  final bool enableKitchenSlip;
  final bool showStockBadges;

  const WorkerUiGuardrails({
    this.allowManualDiscount = true,
    this.allowPriceOverride = true,
    this.allowRefund = true,
    this.allowCashInOut = true,
    this.requireAdminPinForSettings = true,
    this.enableFnbModifiers = false,
    this.enableOrderChannels = false,
    this.enableKitchenSlip = false,
    this.showStockBadges = true,
  });

  /// Standard preset for Retail Supermarket (fast barcode scanning, zero F&B clutter)
  factory WorkerUiGuardrails.forMode(PosBusinessMode mode) {
    if (mode.isFnb) {
      return const WorkerUiGuardrails(
        allowManualDiscount: true,
        allowPriceOverride: false,
        allowRefund: true,
        allowCashInOut: true,
        requireAdminPinForSettings: true,
        enableFnbModifiers: true,
        enableOrderChannels: true,
        enableKitchenSlip: true,
        showStockBadges: false,
      );
    }
    return const WorkerUiGuardrails(
      allowManualDiscount: true,
      allowPriceOverride: true,
      allowRefund: true,
      allowCashInOut: true,
      requireAdminPinForSettings: true,
      enableFnbModifiers: false,
      enableOrderChannels: false,
      enableKitchenSlip: false,
      showStockBadges: true,
    );
  }

  factory WorkerUiGuardrails.fromJson(Map<String, dynamic> json, {PosBusinessMode mode = PosBusinessMode.retail}) {
    final defaults = WorkerUiGuardrails.forMode(mode);
    return WorkerUiGuardrails(
      allowManualDiscount: json['allow_manual_discount'] as bool? ?? defaults.allowManualDiscount,
      allowPriceOverride: json['allow_price_override'] as bool? ?? defaults.allowPriceOverride,
      allowRefund: json['allow_refund'] as bool? ?? defaults.allowRefund,
      allowCashInOut: json['allow_cash_in_out'] as bool? ?? defaults.allowCashInOut,
      requireAdminPinForSettings: json['require_admin_pin_for_settings'] as bool? ?? defaults.requireAdminPinForSettings,
      enableFnbModifiers: json['enable_fnb_modifiers'] as bool? ?? defaults.enableFnbModifiers,
      enableOrderChannels: json['enable_order_channels'] as bool? ?? defaults.enableOrderChannels,
      enableKitchenSlip: json['enable_kitchen_slip'] as bool? ?? defaults.enableKitchenSlip,
      showStockBadges: json['show_stock_badges'] as bool? ?? defaults.showStockBadges,
    );
  }

  Map<String, dynamic> toJson() => {
        'allow_manual_discount': allowManualDiscount,
        'allow_price_override': allowPriceOverride,
        'allow_refund': allowRefund,
        'allow_cash_in_out': allowCashInOut,
        'require_admin_pin_for_settings': requireAdminPinForSettings,
        'enable_fnb_modifiers': enableFnbModifiers,
        'enable_order_channels': enableOrderChannels,
        'enable_kitchen_slip': enableKitchenSlip,
        'show_stock_badges': showStockBadges,
      };
}
