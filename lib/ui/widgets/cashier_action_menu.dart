import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../data/services/odoo_client.dart';
import '../../data/services/printer/printer_service.dart';
import '../../logic/pos_controller.dart';
import '../core/app_colors.dart';
import 'odoo_connection_dialog.dart';
import 'admin_pin_dialog.dart';
import 'printer_config_dialog.dart';
import 'cashier_select_dialog.dart';
import 'open_session_dialog.dart';
import 'app_update_dialog.dart';
import 'cash_in_out_dialog.dart';
import '../../data/services/app_update_service.dart';

class CashierActionMenu {
  static void show(
    BuildContext context,
    OdooClient odooClient,
    PosController controller,
    PrinterService printerService,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header: Logo, Title, and Close Button
                Row(
                  children: [
                    Image.asset('assets/images/arawali_logo.png', height: 28, fit: BoxFit.contain),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cashier Actions',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'ARAWALI STORE POS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 1. CASHIER (Switch Cashier)
                _buildActionCard(
                  number: '1',
                  icon: Icons.badge_rounded,
                  iconColor: Colors.teal,
                  title: 'Cashier (Ganti Kasir)',
                  subtitle: 'Active: ${controller.activeCashier?.name ?? "Ainun"} (Tap to switch)',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Text(
                      controller.activeCashier?.name ?? 'Switch',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    CashierSelectDialog.show(context, controller);
                  },
                ),
                const SizedBox(height: 10),

                // 2. REGISTER / POS CONFIG (Switch Kasir 1 vs Kasir 2)
                _buildActionCard(
                  number: '2',
                  icon: Icons.point_of_sale_rounded,
                  iconColor: Colors.purple.shade700,
                  title: 'Register (Kasir 1 / Kasir 2)',
                  subtitle: 'Active: ${odooClient.profile.displayName}',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Text(
                      odooClient.profile.posConfigId == 1 ? 'Kasir 2' : 'Kasir 1',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple.shade800),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showRegisterSwitchDialog(context, odooClient, controller);
                  },
                ),
                const SizedBox(height: 10),

                // 3. CASH OUT (Cash In / Cash Out)
                _buildActionCard(
                  number: '3',
                  icon: Icons.payments_outlined,
                  iconColor: Colors.amber.shade800,
                  title: 'Cash Out / In (Tarik & Setor Kas)',
                  subtitle: 'Petty cash drawer adjustment & expense slip',
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(ctx);
                    CashInOutDialog.show(context, odooClient, controller, printerService);
                  },
                ),
                const SizedBox(height: 10),

                // 4. REPRINT (Reprint Last Receipt / Test Print)
                _buildActionCard(
                  number: '4',
                  icon: Icons.receipt_long_rounded,
                  iconColor: Colors.indigo,
                  title: 'Reprint (Cetak Ulang Struk)',
                  subtitle: 'Reprint nota terakhir atau kirim test print (${printerService.settings.activeBadgeName})',
                  trailing: const Icon(Icons.print_outlined, color: Colors.indigo),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showReprintDialog(context, odooClient, controller, printerService);
                  },
                ),
                const SizedBox(height: 10),

                // 5. SYNC (Sync Catalog with Odoo & check OTA updates)
                _buildActionCard(
                  number: '5',
                  icon: Icons.sync_rounded,
                  iconColor: Colors.blue.shade700,
                  title: 'Sync with Odoo (Sinkronisasi)',
                  subtitle: 'Refresh catalog, prices & check for app updates',
                  trailing: const Icon(Icons.cloud_download_outlined, color: Colors.blue),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await controller.syncOdooCatalog();
                      if (!context.mounted) return;

                      final updateRes = await AppUpdateService.checkForUpdates(serverBaseUrl: odooClient.baseUrl);
                      if (!context.mounted) return;

                      if (updateRes.hasUpdate && updateRes.versionInfo != null) {
                        AppUpdateDialog.show(
                          context,
                          versionInfo: updateRes.versionInfo!,
                          serverBaseUrl: odooClient.baseUrl,
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✅ Catalog synchronized (${controller.filteredProducts.length} products). App is up to date.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 10),

                // 6. TOGGLE PRODUCT IMAGES
                _buildActionCard(
                  number: '6',
                  icon: controller.showProductImages ? Icons.photo_library_rounded : Icons.photo_library_outlined,
                  iconColor: Colors.deepOrange,
                  title: 'Foto Produk (${controller.showProductImages ? "ON" : "OFF"})',
                  subtitle: controller.showProductImages
                      ? 'Menampilkan foto produk dari Odoo (Mode Gambar)'
                      : 'Hanya teks nama produk (Mode Teks Ringkas)',
                  trailing: Switch(
                    value: controller.showProductImages,
                    activeThumbColor: AppColors.arawaliOrange,
                    onChanged: (val) {
                      controller.toggleShowProductImages(val);
                      Navigator.pop(ctx);
                    },
                  ),
                  onTap: () {
                    controller.toggleShowProductImages(!controller.showProductImages);
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 18),

                // Subtle Divider for Secondary Tools
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 14),

                // Secondary Row: Printer, Session, APK / Update, Admin
                Row(
                  children: [
                    Expanded(
                      child: _buildSecondaryToolButton(
                        icon: Icons.print_rounded,
                        label: 'Printer',
                        color: Colors.indigo,
                        onTap: () {
                          Navigator.pop(ctx);
                          PrinterConfigDialog.show(context, printerService);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSecondaryToolButton(
                        icon: controller.isSessionOpen ? Icons.point_of_sale_rounded : Icons.lock_open_rounded,
                        label: controller.isSessionOpen ? 'Tutup Reg' : 'Buka Reg',
                        color: controller.isSessionOpen ? Colors.purple.shade700 : Colors.amber.shade800,
                        onTap: () {
                          Navigator.pop(ctx);
                          OpenSessionDialog.show(context, controller, printerService: printerService);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSecondaryToolButton(
                        icon: Icons.system_update_rounded,
                        label: 'APK/Update',
                        color: Colors.teal,
                        onTap: () {
                          Navigator.pop(ctx);
                          if (kIsWeb) {
                            AppUpdateService.downloadApkWeb();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Downloading PAJ POS Android APK installer...'),
                                backgroundColor: Colors.teal,
                              ),
                            );
                          } else {
                            AppUpdateDialog.show(
                              context,
                              versionInfo: const AppVersionInfo(
                                versionCode: AppUpdateService.currentVersionCode,
                                versionName: AppUpdateService.currentVersionName,
                                webVersion: AppUpdateService.currentVersionName,
                                apkUrl: '/app-release.apk',
                                releaseDate: '2026-10-12',
                                releaseNotes: ['Official PAJ POS Android APK Installer'],
                              ),
                              serverBaseUrl: odooClient.baseUrl,
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSecondaryToolButton(
                        icon: Icons.lock_outline_rounded,
                        label: 'Admin',
                        color: Colors.grey.shade700,
                        onTap: () async {
                          Navigator.pop(ctx);
                          final isAuthorized = await AdminPinDialog.verify(context);
                          if (isAuthorized && context.mounted) {
                            showDialog(
                              context: context,
                              builder: (_) => OdooConnectionDialog(odooClient: odooClient, controller: controller),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildActionCard({
    required String number,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200, width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            // Priority Number Badge + Icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            // Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }

  static Widget _buildSecondaryToolButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showRegisterSwitchDialog(
    BuildContext context,
    OdooClient odooClient,
    PosController controller,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.point_of_sale_rounded, color: Colors.purple.shade700, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pilih Register Kasir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('Pilih POS register yang aktif di kasir ini', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildRegisterOption(
                  ctx: ctx,
                  context: context,
                  title: '🏪 Arawali Kasir 1',
                  subtitle: 'Register Utama (Config #2 - arawali)',
                  isSelected: odooClient.profile.posConfigId == 2,
                  onSelect: () async {
                    Navigator.pop(ctx);
                    final target = OdooCompanyProfile.availableProfiles.firstWhere(
                      (p) => p.posConfigId == 2,
                      orElse: () => OdooCompanyProfile.availableProfiles.first,
                    );
                    await controller.switchRegisterProfile(target);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Berpindah ke ${target.displayName}. Sesi: ${odooClient.activeSessionName ?? "Belum Buka Sesi"}'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 10),
                _buildRegisterOption(
                  ctx: ctx,
                  context: context,
                  title: '🏪 Arawali Kasir 2',
                  subtitle: 'Register Sekunder (Config #1 - Kasir2)',
                  isSelected: odooClient.profile.posConfigId == 1,
                  onSelect: () async {
                    Navigator.pop(ctx);
                    final target = OdooCompanyProfile.availableProfiles.firstWhere(
                      (p) => p.posConfigId == 1,
                      orElse: () => OdooCompanyProfile.availableProfiles[1],
                    );
                    await controller.switchRegisterProfile(target);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Berpindah ke ${target.displayName}. Sesi: ${odooClient.activeSessionName ?? "Belum Buka Sesi"}'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildRegisterOption({
    required BuildContext ctx,
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onSelect,
  }) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple.shade50 : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.purple.shade700 : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: isSelected ? Colors.purple.shade700 : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.purple.shade900 : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showReprintDialog(
    BuildContext context,
    OdooClient odooClient,
    PosController controller,
    PrinterService printerService,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.print_rounded, color: Colors.indigo),
            ),
            const SizedBox(width: 12),
            const Text('Opsi Cetak Ulang (Reprint)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.receipt_rounded, color: Colors.indigo),
              title: const Text('Cetak Ulang Nota Terakhir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              subtitle: const Text('Ambil transaksi terakhir dari Odoo dan cetak ulang struknya', style: TextStyle(fontSize: 11)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300)),
              onTap: () async {
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mengambil nota terakhir dari Odoo...'), duration: Duration(seconds: 1)),
                );
                try {
                  final orders = await odooClient.fetchRecentOrders(1);
                  if (orders.isEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Belum ada nota transaksi yang tercatat.'), backgroundColor: Colors.orange),
                      );
                    }
                    return;
                  }
                  final lastOrder = orders.first;
                  final lines = await odooClient.fetchOrderLines(lastOrder.id);
                  final res = await printerService.printHistoryReceipt(
                    order: lastOrder,
                    lines: lines,
                    storeName: odooClient.profile.displayName.replaceAll(RegExp(r'\(.*?\)'), '').trim(),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res['message'] ?? 'Perintah cetak terkirim.'),
                        backgroundColor: res['success'] == true ? Colors.green : Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal reprint: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.check_circle_outline_rounded, color: Colors.teal),
              title: const Text('Test Print Diagnostic Slip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              subtitle: Text('Kirim slip tes koneksi ke printer (${printerService.settings.activeBadgeName})', style: const TextStyle(fontSize: 11)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300)),
              onTap: () async {
                Navigator.pop(dialogCtx);
                final res = await printerService.testPrint();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message'] ?? 'Print command sent.'),
                      backgroundColor: res['success'] == true ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: Icon(Icons.history_rounded, color: Colors.amber.shade900),
              title: const Text('Pilih dari Riwayat Nota', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              subtitle: const Text('Buka halaman Orders untuk mencari dan mencetak nota lama', style: TextStyle(fontSize: 11)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300)),
              onTap: () {
                Navigator.pop(dialogCtx);
                controller.setActiveTab('Orders');
              },
            ),
          ],
        ),
      ),
    );
  }
}

