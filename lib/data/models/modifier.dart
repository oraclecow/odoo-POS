class AddOnOption {
  final String id;
  final String name;
  final int extraPrice;

  const AddOnOption({
    required this.id,
    required this.name,
    required this.extraPrice,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddOnOption && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class SelectedModifiers {
  final String sugar;
  final String ice;
  final String skm;
  final List<AddOnOption> addOns;

  const SelectedModifiers({
    this.sugar = 'Normal',
    this.ice = 'Normal',
    this.skm = 'Normal',
    this.addOns = const [],
  });

  List<AddOnOption> get selectedAddOns => addOns;

  int get extraPriceTotal {
    return addOns.fold(0, (sum, item) => sum + item.extraPrice);
  }

  String get summaryDescription {
    final parts = <String>[];
    if (sugar != 'Normal') parts.add(sugar);
    if (ice != 'Normal') parts.add(ice);
    if (skm != 'Normal') parts.add(skm);
    for (final addon in addOns) {
      parts.add('+${addon.name}');
    }
    return parts.isEmpty ? 'Normal (Default)' : parts.join(', ');
  }

  SelectedModifiers copyWith({
    String? sugar,
    String? ice,
    String? skm,
    List<AddOnOption>? addOns,
  }) {
    return SelectedModifiers(
      sugar: sugar ?? this.sugar,
      ice: ice ?? this.ice,
      skm: skm ?? this.skm,
      addOns: addOns ?? this.addOns,
    );
  }
}
