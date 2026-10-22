import 'package:flutter/material.dart';
import '../../data/models/customer.dart';
import '../../data/repositories/juice_pos_repository.dart';
import '../../ui/core/app_colors.dart';
import 'member_service.dart';

/// Modal dialog for quickly registering a new customer / member at the POS checkout.
class MemberRegistrationDialog extends StatefulWidget {
  final JuicePosRepository repository;
  final String? initialQuery;
  final Function(Customer customer) onMemberRegistered;

  const MemberRegistrationDialog({
    super.key,
    required this.repository,
    this.initialQuery,
    required this.onMemberRegistered,
  });

  static Future<Customer?> show(
    BuildContext context, {
    required JuicePosRepository repository,
    String? initialQuery,
    required Function(Customer customer) onMemberRegistered,
  }) {
    return showDialog<Customer>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MemberRegistrationDialog(
        repository: repository,
        initialQuery: initialQuery,
        onMemberRegistered: onMemberRegistered,
      ),
    );
  }

  @override
  State<MemberRegistrationDialog> createState() => _MemberRegistrationDialogState();
}

class _MemberRegistrationDialogState extends State<MemberRegistrationDialog> {
  late final MemberService _memberService;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();

  bool _isSaving = false;
  String? _errorMessage;
  bool _showAddressField = false;

  @override
  void initState() {
    super.initState();
    _memberService = MemberService(repository: widget.repository);

    final query = widget.initialQuery?.trim() ?? '';
    final isPhoneLike = RegExp(r'^[0-9+]+$').hasMatch(query);

    if (isPhoneLike && query.isNotEmpty) {
      _phoneController.text = query;
      WidgetsBinding.instance.addPostFrameCallback((_) => _nameFocus.requestFocus());
    } else if (query.isNotEmpty) {
      _nameController.text = query;
      WidgetsBinding.instance.addPostFrameCallback((_) => _phoneFocus.requestFocus());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _phoneFocus.requestFocus());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final street = _streetController.text.trim();

    setState(() => _isSaving = true);

    try {
      final newCustomer = await _memberService.registerMember(
        name: name,
        phone: phone,
        street: street.isNotEmpty ? street : null,
      );

      widget.onMemberRegistered(newCustomer);
      if (mounted) {
        Navigator.of(context).pop(newCustomer);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppColors.background,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderDark, width: 1.5),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.sunYellow.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: AppColors.sunYellow,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daftarkan Member Baru',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Data otomatis tersimpan ke Odoo ERP & kartu loyalty',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    tooltip: 'Tutup',
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24, color: AppColors.divider),

              // Error banner if any
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade400),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Nomor HP / WhatsApp
              const Text(
                'Nomor WhatsApp / HP *',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneController,
                focusNode: _phoneFocus,
                enabled: !_isSaving,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Cth: 081234567890',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  prefixIcon: const Icon(Icons.phone_android_rounded, size: 20, color: AppColors.sunYellow),
                  filled: true,
                  fillColor: AppColors.deepSlate,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderDark),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderDark),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.sunYellow, width: 1.5),
                  ),
                ),
                validator: (val) {
                  final text = val?.trim() ?? '';
                  if (text.isEmpty) return 'Nomor HP wajib diisi';
                  if (text.replaceAll(RegExp(r'\D'), '').length < 8) {
                    return 'Nomor HP minimal 8 digit';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Nama Lengkap
              const Text(
                'Nama Lengkap Member *',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                focusNode: _nameFocus,
                enabled: !_isSaving,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Cth: Budi Pratama',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  prefixIcon: const Icon(Icons.badge_rounded, size: 20, color: AppColors.sunYellow),
                  filled: true,
                  fillColor: AppColors.deepSlate,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderDark),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderDark),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.sunYellow, width: 1.5),
                  ),
                ),
                validator: (val) {
                  if ((val?.trim() ?? '').isEmpty) {
                    return 'Nama member wajib diisi';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submitRegistration(),
              ),
              const SizedBox(height: 12),

              // Toggle Alamat / Detail Tambahan
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _showAddressField = !_showAddressField),
                  icon: Icon(
                    _showAddressField ? Icons.arrow_drop_up_rounded : Icons.add_rounded,
                    size: 18,
                    color: AppColors.sunYellow,
                  ),
                  label: Text(
                    _showAddressField ? 'Sembunyikan Alamat' : '+ Tambah Alamat / Catatan',
                    style: const TextStyle(fontSize: 12, color: AppColors.sunYellow),
                  ),
                ),
              ),

              if (_showAddressField) ...[
                const SizedBox(height: 4),
                TextFormField(
                  controller: _streetController,
                  enabled: !_isSaving,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Alamat lengkap / kelurahan / catatan...',
                    hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    prefixIcon: const Icon(Icons.location_on_rounded, size: 18, color: Colors.grey),
                    filled: true,
                    fillColor: AppColors.deepSlate,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              const SizedBox(height: 16),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.borderDark),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Batal', style: TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _submitRegistration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      _isSaving ? 'Menyimpan ke Odoo...' : 'Simpan & Pilih Member',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
