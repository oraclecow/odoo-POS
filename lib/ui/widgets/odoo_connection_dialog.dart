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
  late TextEditingController _urlController;
  late TextEditingController _dbController;
  late TextEditingController _loginController;
  late TextEditingController _passwordController;
  late TextEditingController _companyIdController;
  late TextEditingController _posConfigIdController;
  late TextEditingController _displayNameController;
  late TextEditingController _receiptHeaderController;
  late TextEditingController _receiptFooterController;
  final TextEditingController _pinController = TextEditingController();

  late PosBusinessMode _mode;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.odooClient.profile;
    _mode = profile.mode;
    _urlController = TextEditingController(text: widget.odooClient.baseUrl);
    _dbController = TextEditingController(text: widget.odooClient.database);
    _loginController = TextEditingController(text: profile.login);
    _passwordController = TextEditingController(text: profile.password);
    _companyIdController = TextEditingController(text: profile.companyId.toString());
    _posConfigIdController = TextEditingController(text: profile.posConfigId.toString());
    _displayNameController = TextEditingController(text: profile.displayName);
    _receiptHeaderController = TextEditingController(text: profile.receiptHeader);
    _receiptFooterController = TextEditingController(text: profile.receiptFooter);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _dbController.dispose();
    _loginController.dispose();
    _passwordController.dispose();
    _companyIdController.dispose();
    _posConfigIdController.dispose();
    _displayNameController.dispose();
    _receiptHeaderController.dispose();
    _receiptFooterController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _testAndConnect() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final url = _urlController.text.trim();
      final db = _dbController.text.trim();
      final login = _loginController.text.trim();
      final password = _passwordController.text;
      final companyId = int.tryParse(_companyIdController.text.trim()) ?? 1;
      final posConfigId = int.tryParse(_posConfigIdController.text.trim()) ?? 1;
      final displayName = _displayNameController.text.trim().isEmpty
          ? 'Store POS #$posConfigId'
          : _displayNameController.text.trim();
      final receiptHeader = _receiptHeaderController.text.trim().isEmpty
          ? 'Point of Sale Receipt'
          : _receiptHeaderController.text.trim();
      final receiptFooter = _receiptFooterController.text.trim().isEmpty
          ? 'Thank you for your business!'
          : _receiptFooterController.text.trim();

      if (url.isEmpty || db.isEmpty || login.isEmpty) {
        throw Exception('Server URL, Database, and Login cannot be empty.');
      }

      widget.odooClient.baseUrl = url;
      widget.odooClient.database = db;
      final newProfile = OdooCompanyProfile(
        displayName: displayName,
        login: login,
        password: password,
        companyId: companyId,
        posConfigId: posConfigId,
        receiptHeader: receiptHeader,
        receiptFooter: receiptFooter,
        mode: _mode,
      );
      widget.odooClient.switchProfile(newProfile);

      final uid = await widget.odooClient.authenticate();
      final sessionId = await widget.odooClient.fetchActiveSession();
      await widget.controller.syncOdooCatalog();
      await widget.odooClient.saveSettings();

      setState(() {
        _isLoading = false;
        _isSuccess = true;
        _statusMessage = 'Connected! UID: $uid • ${sessionId != null ? "Active Session: ${widget.odooClient.activeSessionName ?? "#$sessionId"}" : "Note: No active POS session open for Config #$posConfigId."}';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _statusMessage = 'Connection failed: $e';
      });
    }
  }

  Future<void> _saveNewPin() async {
    final pin = _pinController.text.trim();
    if (pin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN must be at least 4 digits.'), backgroundColor: Colors.red),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_pin', pin);
    _pinController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Admin PIN updated to: '), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.settings_suggest_rounded, color: AppColors.primaryGreen, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'ODOO SERVER & REGISTER SETUP',
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
              const SizedBox(height: 12),

              const Text('Odoo Server URL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  hintText: 'http://192.168.1.100:8069 or https://erp.yourdomain.com',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.dns_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),

              const Text('Database Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              TextField(
                controller: _dbController,
                decoration: InputDecoration(
                  hintText: 'e.g. odoo, production, main_store',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.storage_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Login / Username', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _loginController,
                          decoration: InputDecoration(
                            hintText: 'e.g. admin or pos_agent',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.person_outline, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.lock_outline, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('POS Config ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _posConfigIdController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '1',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.point_of_sale_rounded, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Company ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _companyIdController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '1',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.business_rounded, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              const Text('Business Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              SegmentedButton<PosBusinessMode>(
                segments: const [
                  ButtonSegment(value: PosBusinessMode.retail, label: Text('Retail / Shop'), icon: Icon(Icons.shopping_basket_outlined)),
                  ButtonSegment(value: PosBusinessMode.fnb, label: Text('F&B / Restaurant'), icon: Icon(Icons.restaurant_rounded)),
                ],
                selected: {_mode},
                onSelectionChanged: (v) => setState(() => _mode = v.first),
              ),
              const SizedBox(height: 12),

              const Text('Register Display Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              TextField(
                controller: _displayNameController,
                decoration: InputDecoration(
                  hintText: 'e.g. Counter 1 / Retail Register',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.storefront_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Receipt Header (Address / Phone)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _receiptHeaderController,
                          decoration: InputDecoration(
                            hintText: 'e.g. 123 Main St • 0812-3456-7890',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.receipt_long_rounded, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Receipt Footer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _receiptFooterController,
                          decoration: InputDecoration(
                            hintText: 'e.g. Thank you for shopping with us!',
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.short_text_rounded, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

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
                          hintText: 'Admin PIN (min 4 digits, default 1234)',
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
                      child: const Text('Save PIN', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

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
                    child: const Text('Close'),
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
                              'Test Connection & Sync Catalog',
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
