class Customer {
  final int id;
  final String name;
  final String phone;
  final String tier;
  final double points;

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.tier = 'Regular',
    this.points = 0.0,
  });

  String get pointsDisplay {
    if (points == points.roundToDouble()) {
      return points.toInt().toString();
    }
    return points.toStringAsFixed(1);
  }

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    String? tier,
    double? points,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      tier: tier ?? this.tier,
      points: points ?? this.points,
    );
  }
}
