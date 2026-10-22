import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/services/odoo_client.dart';
import '../../logic/pos_controller.dart';
import '../core/app_colors.dart';

class OdooConnectionDialog extends StatefulWidget {
  final OdooClient odooClient;
  final PosController controller;

  const OdooConnectionDialog({
    super.key,
    required this.odooClient,
    required this.controller,
  });

  @override
  State<OdooConnectionDialog> createState() => _OdooConnectionDialogState();
}

class _OdooConnectionDialogState extends State<OdooConnectionDialog> {
  late TextEditingController _dbController;
  late TextEditingController _urlController;
  final TextEditingController _pinController = TextEditingController();
  late OdooCompanyProfile _selectedProfile;
  bool _isLoading = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _dbController = TextEditingController(text: widget.odooClient.database);
    _urlController = TextEditingController(text: widget.odooClient.baseUrl);
    _selectedProfile = widget.odooClient.profile;
  }

  Future<void> _testAndConnect() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      widget.odooClient.baseUrl = _urlController.text.trim();
      widget.odooClient.switchDatabase(_dbController.text.trim());
      widget.odooClient.switchProfile(_selectedProfile);

      final uid = await widget.odooClient.authenticate();
      final sessionId = await widget.odooClient.fetchActiveSession();
      await widget.controller.syncOdooCatalog();
      await widget.odooClient.saveSettings();

      setState(() {
        _isLoading = false;
        _isSuccess = true;
        _statusMessage = 'Terhubung! UID: $uid • ${sessionId != null ? "Sesi Kasir: ${widget.odooClient.activeSessionName ?? '#$sessionId'} AKTIF" : "⚠️ Tidak ada sesi kasir yang terbuka untuk toko ini."}';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _statusMessage = 'Gagal terhubung: $e';
      });
    }
  }

  Future<void> _saveNewPin() async {
    final pin = _pinController.text.trim();
    if (pin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN harus minimal 4 digit.'), backgroundColor: Colors.red),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_pin', pin);
    _pinController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PIN Admin berhasil diperbarui menjadi: $pin'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.settings_suggest_rounded, color: AppColors.primaryGreen),
                      SizedBox(width: 8),
                      Text(
                        'PENGATURAN ODOO & DATABASE',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: AppColors.divider),
              const SizedBox(height: 10),

              // Server URL Field
              const Text('Odoo Server URL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.dns_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),

              // Database Field
              const Text('Database Odoo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              TextField(
                controller: _dbController,
                decoration: InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.storage_rounded, size: 20),
                  hintText: 'arawali',
                ),
              ),
              const SizedBox(height: 12),

              // Company Profile Dropdown
              const Text('Pilih Toko / Company Profil', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<OdooCompanyProfile>(
                    value: _selectedProfile,
                    isExpanded: true,
                    items: OdooCompanyProfile.availableProfiles.map((p) {
                      return DropdownMenuItem<OdooCompanyProfile>(
                        value: p,
                        child: Text(p.displayName, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedProfile = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Ubah PIN Admin Section
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_reset_rounded, size: 20, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        obscureText: true,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Ubah PIN Admin (min 4 digit)',
                          isDense: true,
                          counterText: '',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _saveNewPin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey.shade800,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        elevation: 0,
                      ),
                      child: const Text('Simpan PIN', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Live Status Box
              if (_statusMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _isSuccess ? Colors.green.shade300 : Colors.red.shade300),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _isSuccess ? Colors.green.shade900 : Colors.red.shade900,
                    ),
                  ),
                ),

              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Tutup'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _testAndConnect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text(
                              'Hubungkan & Sinkronisasi',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
