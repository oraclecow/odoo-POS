import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_odoo_pos/main.dart';

void main() {
  testWidgets('Renders OdooJuicePosApp in 1340x800 landscape tablet resolution', (WidgetTester tester) async {
    // Set viewport to Samsung Galaxy Tab A9 resolution: 1340 x 800
    tester.view.physicalSize = const Size(1340, 800);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: OdooJuicePosApp()));
    await tester.pumpAndSettle();

    // Verify consolidated header tabs
    expect(find.text('Register'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);

    // Verify loyalty / member indicator
    expect(find.text('+ Member'), findsOneWidget);

    // Verify retail base buttons
    expect(find.text('[Member / Pelanggan]'), findsOneWidget);
    expect(find.text('[Note]'), findsOneWidget);

    // Verify barcode scanner / quick search input exists
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Scan barcode atau ketik nama produk / kode SKU...'), findsOneWidget);

    // Verify 'Semua' and 'Archived' categories are not shown for retail POS
    expect(find.text('Semua'), findsNothing);
    expect(find.text('Archived'), findsNothing);
  });
}
