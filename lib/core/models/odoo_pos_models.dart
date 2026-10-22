import '../config/app_mode.dart';

class OdooCompanyProfile {
  final String displayName;
  final String login;
  final String password;
  final int companyId;
  final int posConfigId;
  final PosBusinessMode mode;
  final WorkerUiGuardrails guardrails;

  const OdooCompanyProfile({
    required this.displayName,
    required this.login,
    required this.password,
    required this.companyId,
    required this.posConfigId,
    this.mode = PosBusinessMode.retail,
    WorkerUiGuardrails? guardrails,
  }) : guardrails = guardrails ??
            (mode == PosBusinessMode.fnb
                ? const WorkerUiGuardrails(
                    allowManualDiscount: true,
                    allowPriceOverride: false,
                    allowRefund: true,
                    allowCashInOut: true,
                    requireAdminPinForSettings: true,
                    enableFnbModifiers: true,
                    enableOrderChannels: true,
                    enableKitchenSlip: true,
                    showStockBadges: false,
                  )
                : const WorkerUiGuardrails());

  bool get isRetail => mode.isRetail;
  bool get isFnb => mode.isFnb;

  factory OdooCompanyProfile.fromJson(Map<String, dynamic> json) {
    final compId = (json['company_id'] as num?)?.toInt() ?? 1;
    final parsedMode = PosBusinessMode.fromString(
      json['mode']?.toString(),
      companyId: compId,
    );
    return OdooCompanyProfile(
      displayName: json['display_name']?.toString() ?? 'Store POS',
      login: json['login']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      companyId: compId,
      posConfigId: (json['pos_config_id'] as num?)?.toInt() ?? 1,
      mode: parsedMode,
      guardrails: json['guardrails'] is Map<String, dynamic>
          ? WorkerUiGuardrails.fromJson(json['guardrails'] as Map<String, dynamic>, mode: parsedMode)
          : WorkerUiGuardrails.forMode(parsedMode),
    );
  }

  Map<String, dynamic> toJson() => {
        'display_name': displayName,
        'login': login,
        'password': password,
        'company_id': companyId,
        'pos_config_id': posConfigId,
        'mode': mode.code,
        'guardrails': guardrails.toJson(),
      };

  static const List<OdooCompanyProfile> availableProfiles = [
    OdooCompanyProfile(
      displayName: '🏪 Arawali Kasir 1',
      login: 'agent.arawali',
      password: 'nDutPPnZ1w3sU-SeaGs',
      companyId: 1,
      posConfigId: 2,
      mode: PosBusinessMode.retail,
    ),
    OdooCompanyProfile(
      displayName: '🏪 Arawali Kasir 2',
      login: 'agent.arawali',
      password: 'nDutPPnZ1w3sU-SeaGs',
      companyId: 1,
      posConfigId: 1,
      mode: PosBusinessMode.retail,
    ),
    OdooCompanyProfile(
      displayName: '🥤 PAJ Kartini POS',
      login: 'agent.kartini',
      password: 'xABS_sdTDEAFAVydT48',
      companyId: 6,
      posConfigId: 14,
      mode: PosBusinessMode.fnb,
    ),
    OdooCompanyProfile(
      displayName: '🥤 PAJ Santi POS',
      login: 'agent.santi',
      password: 'TKb-v6UPr9ru22sXBFk',
      companyId: 2,
      posConfigId: 13,
      mode: PosBusinessMode.fnb,
    ),
    OdooCompanyProfile(
      displayName: '🥤 PAJ SKW POS',
      login: 'agent.skw',
      password: 'pcteGagVrB4xi49v7iE',
      companyId: 7,
      posConfigId: 15,
      mode: PosBusinessMode.fnb,
    ),
    OdooCompanyProfile(
      displayName: '🍞 Bakery POS',
      login: 'agent.bakery',
      password: 'J3f5XZNLHNBL5Fh4UfI',
      companyId: 3,
      posConfigId: 6,
      mode: PosBusinessMode.fnb,
    ),
  ];
}

class OdooOrderRecord {
  final int id;
  final String name;
  final String posReference;
  final String dateOrder;
  final double amountTotal;
  final String partnerName;
  final String state;

  const OdooOrderRecord({
    required this.id,
    required this.name,
    required this.posReference,
    required this.dateOrder,
    required this.amountTotal,
    required this.partnerName,
    required this.state,
  });

  String get localDateOrder {
    if (dateOrder.isEmpty) return '';
    try {
      final normalized = dateOrder.contains('T') ? dateOrder : dateOrder.replaceFirst(' ', 'T');
      final utcDate = DateTime.parse(normalized.endsWith('Z') ? normalized : '${normalized}Z');
      final local = utcDate.toLocal();
      final y = local.year.toString().padLeft(4, '0');
      final m = local.month.toString().padLeft(2, '0');
      final d = local.day.toString().padLeft(2, '0');
      final hh = local.hour.toString().padLeft(2, '0');
      final mm = local.minute.toString().padLeft(2, '0');
      final ss = local.second.toString().padLeft(2, '0');
      return '$y-$m-$d $hh:$mm:$ss';
    } catch (_) {
      return dateOrder;
    }
  }
}

class PosCashier {
  final int id;
  final String name;
  final int? userId;
  final bool hasPin;
  final String? pin;

  const PosCashier({
    required this.id,
    required this.name,
    this.userId,
    this.hasPin = false,
    this.pin,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'user_id': userId,
        'has_pin': hasPin,
      };

  factory PosCashier.fromJson(Map<String, dynamic> json) => PosCashier(
        id: json['id'] as int,
        name: json['name'] as String,
        userId: json['user_id'] as int?,
        hasPin: json['has_pin'] as bool? ?? false,
        pin: json['pin'] as String?,
      );

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class PosNonCashPaymentMethod {
  final int id;
  final String name;
  final double amount;
  final int number;
  final String type;

  const PosNonCashPaymentMethod({
    required this.id,
    required this.name,
    required this.amount,
    required this.number,
    required this.type,
  });

  factory PosNonCashPaymentMethod.fromJson(Map<String, dynamic> json) => PosNonCashPaymentMethod(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        number: (json['number'] as num?)?.toInt() ?? 0,
        type: json['type'] as String? ?? 'bank',
      );
}

class PosClosingControlData {
  final int orderCount;
  final double totalSales;
  final String openingNotes;
  final double openingCash;
  final double cashPayments;
  final double cashMovesTotal;
  final List<Map<String, dynamic>> cashMoves;
  final double expectedCash;
  final List<PosNonCashPaymentMethod> nonCashMethods;
  final bool isManager;

  const PosClosingControlData({
    required this.orderCount,
    required this.totalSales,
    required this.openingNotes,
    required this.openingCash,
    required this.cashPayments,
    required this.cashMovesTotal,
    required this.cashMoves,
    required this.expectedCash,
    required this.nonCashMethods,
    this.isManager = false,
  });

  factory PosClosingControlData.fromJson(Map<String, dynamic> json) {
    final orders = json['orders_details'] as Map<String, dynamic>? ?? {};
    final cash = json['default_cash_details'] as Map<String, dynamic>? ?? {};
    final movesList = (cash['moves'] as List<dynamic>? ?? [])
        .map((m) => m as Map<String, dynamic>)
        .toList();

    double movesSum = 0.0;
    for (final m in movesList) {
      movesSum += (m['amount'] as num?)?.toDouble() ?? 0.0;
    }

    final nonCashList = (json['non_cash_payment_methods'] as List<dynamic>? ?? [])
        .map((nc) => PosNonCashPaymentMethod.fromJson(nc as Map<String, dynamic>))
        .toList();

    return PosClosingControlData(
      orderCount: (orders['quantity'] as num?)?.toInt() ?? 0,
      totalSales: (orders['amount'] as num?)?.toDouble() ?? 0.0,
      openingNotes: json['opening_notes'] is String ? (json['opening_notes'] as String) : '',
      openingCash: (cash['opening'] as num?)?.toDouble() ?? 0.0,
      cashPayments: (cash['payment_amount'] as num?)?.toDouble() ?? 0.0,
      cashMovesTotal: movesSum,
      cashMoves: movesList,
      expectedCash: (cash['amount'] as num?)?.toDouble() ?? 0.0,
      nonCashMethods: nonCashList,
      isManager: json['is_manager'] as bool? ?? false,
    );
  }
}

class PosPaymentMethodInfo {
  final int id;
  final String name;
  final bool isCashCount;
  final String? type;

  const PosPaymentMethodInfo({
    required this.id,
    required this.name,
    required this.isCashCount,
    this.type,
  });

  factory PosPaymentMethodInfo.fromMap(Map<String, dynamic> map) {
    return PosPaymentMethodInfo(
      id: (map['id'] as num).toInt(),
      name: (map['name'] ?? '').toString(),
      isCashCount: map['is_cash_count'] == true,
      type: map['type']?.toString(),
    );
  }
}

class StorePaymentRegistry {
  final int posConfigId;
  final List<PosPaymentMethodInfo> methods;

  const StorePaymentRegistry({
    required this.posConfigId,
    required this.methods,
  });

  PosPaymentMethodInfo? get cashMethod {
    for (final m in methods) {
      if (m.isCashCount || m.type == 'cash') return m;
    }
    return methods.isNotEmpty ? methods.first : null;
  }

  PosPaymentMethodInfo? get qrisOrBankMethod {
    for (final m in methods) {
      final lower = m.name.toLowerCase();
      if ((m.type == 'bank' || lower.contains('qris') || lower.contains('transfer')) &&
          !lower.contains('grab') &&
          !lower.contains('shopee')) {
        return m;
      }
    }
    return null;
  }

  PosPaymentMethodInfo? get grabMethod {
    for (final m in methods) {
      if (m.name.toLowerCase().contains('grab')) return m;
    }
    return null;
  }

  PosPaymentMethodInfo? get shopeeMethod {
    for (final m in methods) {
      if (m.name.toLowerCase().contains('shopee')) return m;
    }
    return null;
  }

  PosPaymentMethodInfo? resolveMethod(String requestedChannelOrName) {
    final lower = requestedChannelOrName.toLowerCase();
    if (lower.contains('grab')) {
      return grabMethod;
    } else if (lower.contains('shopee')) {
      return shopeeMethod;
    } else if (lower.contains('transfer') || lower.contains('qris') || lower.contains('bank')) {
      return qrisOrBankMethod ?? cashMethod;
    } else {
      return cashMethod;
    }
  }
}

class PosOrderSubmissionResult {
  final int? id;
  final String? name;
  final String? posReference;
  final String? trackingNumber;
  final Map<String, dynamic> raw;

  const PosOrderSubmissionResult({
    this.id,
    this.name,
    this.posReference,
    this.trackingNumber,
    required this.raw,
  });

  factory PosOrderSubmissionResult.fromSyncResult(dynamic result) {
    if (result is Map<String, dynamic>) {
      final orders = result['pos.order'];
      if (orders is List && orders.isNotEmpty) {
        final first = orders.first;
        if (first is Map<String, dynamic>) {
          return PosOrderSubmissionResult(
            id: (first['id'] as num?)?.toInt(),
            name: first['name']?.toString(),
            posReference: first['pos_reference']?.toString(),
            trackingNumber: first['tracking_number']?.toString(),
            raw: result,
          );
        }
      }
      return PosOrderSubmissionResult(raw: result);
    }
    return PosOrderSubmissionResult(raw: {'result': result});
  }
}
