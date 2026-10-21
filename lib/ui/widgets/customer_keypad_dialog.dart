import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/customer.dart';
import '../../data/repositories/juice_pos_repository.dart';
import '../../logic/pos_controller.dart';
import '../core/app_colors.dart';

class CustomerKeypadDialog extends StatefulWidget {
  final JuicePosRepository repository;
  final Function(Customer customer) onCustomerSelected;
  final Customer? currentCustomer;
  final VoidCallback? onClearCustomer;
  final PosController? posController;

  const CustomerKeypadDialog({
    super.key,
    required this.repository,
    required this.onCustomerSelected,
    this.currentCustomer,
    this.onClearCustomer,
    this.posController,
  });

  @override
  State<CustomerKeypadDialog> createState() => _CustomerKeypadDialogState();
}

class _CustomerKeypadDialogState extends State<CustomerKeypadDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  Timer? _debounceTimer;

  bool _isLoading = false;
  List<Customer> _results = [];
  bool _showNumpad = false;
  Customer? _activeCustomer;

  // Point exchange state
  final TextEditingController _pointsInputController = TextEditingController();
  String _rewardSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _activeCustomer = widget.currentCustomer;
    // If customer already attached with points, start on Tukar Poin tab if cart has items
    final hasPoints = _activeCustomer != null && _activeCustomer!.points > 0;
    _tabController = TabController(length: 2, vsync: this, initialIndex: (hasPoints && (widget.posController?.cartItems.isNotEmpty ?? false)) ? 1 : 0);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    _searchFocusNode.requestFocus();
    _performSearch('');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _pointsInputController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final q = query.trim();
    setState(() => _isLoading = true);
    final list = await widget.repository.searchCustomers(q);
    if (mounted) {
      setState(() {
        _results = list;
        _isLoading = false;
      });
    }
  }

  void _onNumpadPress(String val) {
    final text = _searchController.text;
    final newText = text + val;
    _searchController.text = newText;
    _searchController.selection = TextSelection.fromPosition(TextPosition(offset: newText.length));
    _onSearchChanged(newText);
  }

  void _onNumpadBackspace() {
    final text = _searchController.text;
    if (text.isNotEmpty) {
      final newText = text.substring(0, text.length - 1);
      _searchController.text = newText;
      _searchController.selection = TextSelection.fromPosition(TextPosition(offset: newText.length));
      _onSearchChanged(newText);
    }
  }

  void _onNumpadClear() {
    _searchController.clear();
    _onSearchChanged('');
  }

  void _selectCustomer(Customer cust) {
    setState(() {
      _activeCustomer = cust;
    });
    widget.onCustomerSelected(cust);
  }

  void _clearCustomer() {
    setState(() {
      _activeCustomer = null;
    });
    widget.onClearCustomer?.call();
    widget.posController?.clearRedeemedPoints();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header with Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.brandRed.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.card_membership_rounded, color: AppColors.brandRed, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MEMBER & LOYALTY POINT',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            _activeCustomer != null
                                ? 'Member: ${_activeCustomer!.name} (${_activeCustomer!.pointsDisplay} Pts)'
                                : 'Kelola pelanggan dan penukaran poin hadiah',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 2. Tab Navigation
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.deepSlate,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: [
                    const Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_search_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Cari Member'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.stars_rounded, size: 16, color: AppColors.sunYellow),
                          const SizedBox(width: 6),
                          Text(
                            _activeCustomer != null && _activeCustomer!.points > 0
                                ? 'Tukar Poin (${_activeCustomer!.pointsDisplay} pts)'
                                : 'Tukar Poin & Hadiah',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 3. Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSearchTab(),
                    _buildPointExchangeTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- TAB 1: Cari Member ---
  Widget _buildSearchTab() {
    return Column(
      children: [
        // Currently Attached Member Banner (if any)
        if (_activeCustomer != null)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade300, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.stars_rounded, color: Colors.amber, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Member Terpilih: ${_activeCustomer!.name}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        'Saldo: ${_activeCustomer!.pointsDisplay} Pts • ${_activeCustomer!.phone}',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.link_off_rounded, size: 16, color: AppColors.brandRed),
                  label: const Text('Lepas', style: TextStyle(color: AppColors.brandRed, fontWeight: FontWeight.bold)),
                  onPressed: _clearCustomer,
                ),
              ],
            ),
          ),

        // Search Input Bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderDark, width: 1.5),
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.0),
                child: Icon(Icons.search_rounded, color: AppColors.brandRed, size: 22),
              ),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    hintText: 'Ketik nama member atau nomor HP (cth: 0823 atau Budi)...',
                    hintStyle: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (val) {
                    _onSearchChanged(val);
                    setState(() {});
                  },
                ),
              ),
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                    setState(() {});
                  },
                ),
              IconButton(
                icon: Icon(
                  _showNumpad ? Icons.keyboard_rounded : Icons.dialpad_rounded,
                  color: _showNumpad ? AppColors.brandRed : Colors.grey.shade600,
                  size: 20,
                ),
                tooltip: _showNumpad ? 'Tutup Touch Numpad' : 'Buka Touch Numpad',
                onPressed: () => setState(() => _showNumpad = !_showNumpad),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Search Results List
        Expanded(
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2.5),
                      SizedBox(height: 10),
                      Text('Mencari data member & poin...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                )
              : _results.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_search_rounded, size: 44, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text(
                              _searchController.text.trim().isEmpty
                                  ? 'Ketik nama atau nomor HP member di atas.'
                                  : 'Member "${_searchController.text.trim()}" tidak ditemukan.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                            if (_searchController.text.trim().length >= 3) ...[
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                                label: Text('Gunakan Sebagai Tamu: "${_searchController.text.trim()}"'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.deepSlate,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  final guest = Customer(
                                    id: DateTime.now().millisecondsSinceEpoch,
                                    name: _searchController.text.trim(),
                                    phone: _searchController.text.trim(),
                                    points: 0.0,
                                  );
                                  _selectCustomer(guest);
                                  Navigator.pop(context);
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (ctx, idx) {
                        final cust = _results[idx];
                        final isSelected = _activeCustomer?.id == cust.id;
                        return ListTile(
                          dense: true,
                          selected: isSelected,
                          selectedTileColor: Colors.amber.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: isSelected ? AppColors.sunYellow : AppColors.deepSlate,
                            child: Text(
                              cust.name.isNotEmpty ? cust.name[0].toUpperCase() : 'M',
                              style: TextStyle(
                                color: isSelected ? AppColors.pitchBlack : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          title: Text(
                            cust.name,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                          ),
                          subtitle: Text(
                            cust.phone,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.amber.shade400, width: 1.2),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.stars_rounded, size: 14, color: Colors.amber),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${cust.pointsDisplay} Pts',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSelected ? Colors.green.shade700 : AppColors.deepSlate,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: const Size(60, 32),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  _selectCustomer(cust);
                                  Navigator.pop(context);
                                },
                                child: Text(isSelected ? 'Terpilih' : 'Pilih', style: const TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),

        // Collapsible Touch Numpad
        if (_showNumpad) ...[
          const SizedBox(height: 6),
          const Divider(height: 1),
          const SizedBox(height: 6),
          _buildCompactNumpad(),
        ],
      ],
    );
  }

  // --- TAB 2: Tukar Poin & Menu Hadiah ---
  Widget _buildPointExchangeTab() {
    if (_activeCustomer == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.stars_rounded, size: 56, color: Colors.amber.shade400),
              const SizedBox(height: 12),
              const Text(
                'Belum Ada Member Terpilih',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Silakan pilih member terlebih dahulu di tab "Cari Member" untuk melihat saldo poin loyalty dan katalog hadiah tukar poin.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_search_rounded, size: 16),
                label: const Text('Cari Member Sekarang'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepSlate,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  _tabController.animateTo(0);
                },
              ),
            ],
          ),
        ),
      );
    }

    final availablePoints = _activeCustomer!.points.toInt();
    final cartSubtotal = widget.posController?.subtotal ?? 0;
    final redeemedPoints = widget.posController?.redeemedPoints ?? 0;
    final maxRedeemable = availablePoints < cartSubtotal ? availablePoints : cartSubtotal;

    // Filter products for point trade catalogue
    final allProducts = widget.repository.getProducts();
    final rewardProducts = allProducts.where((p) {
      if (_rewardSearchQuery.isEmpty) return true;
      return p.name.toLowerCase().contains(_rewardSearchQuery.toLowerCase()) ||
          p.category.toLowerCase().contains(_rewardSearchQuery.toLowerCase());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Member Points Balance Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.deepSlate,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Member: ${_activeCustomer!.name}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '1 Poin Loyalty = Rp 1 Potongan',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.sunYellow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars_rounded, size: 16, color: AppColors.pitchBlack),
                    const SizedBox(width: 4),
                    Text(
                      '$availablePoints Pts',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.pitchBlack),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Section 1: Potongan Poin Belanja Langsung (1 pt = Rp 1)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEFCE8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.discount_rounded, size: 16, color: Colors.amber),
                      SizedBox(width: 6),
                      Text(
                        'Tukar Poin ke Potongan Belanja Langsung',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF78350F)),
                      ),
                    ],
                  ),
                  if (redeemedPoints > 0)
                    TextButton.icon(
                      icon: const Icon(Icons.cancel_rounded, size: 14, color: Colors.red),
                      label: const Text('Hapus Poin', style: TextStyle(color: Colors.red, fontSize: 11.5, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        widget.posController?.clearRedeemedPoints();
                        setState(() {});
                      },
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (redeemedPoints > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Text(
                    'Sedang Aktif: -${_currency.format(redeemedPoints)} ($redeemedPoints Poin)',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 12.5),
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final pts in [5000, 10000, 20000])
                    if (availablePoints >= pts)
                      OutlinedButton(
                        onPressed: cartSubtotal <= 0
                            ? null
                            : () {
                                final applyPts = pts <= maxRedeemable ? pts : maxRedeemable;
                                widget.posController?.setRedeemedPoints(applyPts);
                                setState(() {});
                              },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: Text('Tukar $pts Pts (-${_currency.format(pts)})', style: const TextStyle(fontSize: 11.5)),
                      ),
                  if (maxRedeemable > 0)
                    ElevatedButton.icon(
                      onPressed: () {
                        widget.posController?.setRedeemedPoints(maxRedeemable);
                        setState(() {});
                      },
                      icon: const Icon(Icons.flash_on_rounded, size: 14),
                      label: Text('Tukar Maksimal ($maxRedeemable Pts)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Section 2: Menu / Items Hadiah Tukar Poin (Katalog Hadiah)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.card_giftcard_rounded, size: 16, color: AppColors.brandRed),
                SizedBox(width: 6),
                Text(
                  'Menu & Produk yang Bisa Ditukar Poin',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary),
                ),
              ],
            ),
            SizedBox(
              width: 180,
              height: 32,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Cari menu hadiah...',
                  hintStyle: const TextStyle(fontSize: 11),
                  prefixIcon: const Icon(Icons.search_rounded, size: 14),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (val) {
                  setState(() => _rewardSearchQuery = val.trim());
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Rewards Catalog List
        Expanded(
          child: rewardProducts.isEmpty
              ? const Center(
                  child: Text('Tidak ada produk hadiah ditemukan', style: TextStyle(color: Colors.grey, fontSize: 12)),
                )
              : ListView.separated(
                  itemCount: rewardProducts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (ctx, idx) {
                    final prod = rewardProducts[idx];
                    final pointCost = prod.price; // 1 pt = Rp 1
                    final canAfford = availablePoints >= pointCost && pointCost > 0;

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: canAfford ? Colors.amber.shade100 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.local_cafe_rounded,
                          size: 18,
                          color: canAfford ? Colors.amber.shade900 : Colors.grey.shade500,
                        ),
                      ),
                      title: Text(
                        prod.name,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      subtitle: Text(
                        '${prod.category} • ${_currency.format(prod.price)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: canAfford ? Colors.amber.shade50 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: canAfford ? Colors.amber.shade400 : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.stars_rounded, size: 13, color: canAfford ? Colors.amber.shade800 : Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  '$pointCost Pts',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: canAfford ? Colors.amber.shade900 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canAfford ? AppColors.deepSlate : Colors.grey.shade300,
                              foregroundColor: canAfford ? Colors.white : Colors.grey.shade600,
                              elevation: canAfford ? 1 : 0,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: const Size(60, 32),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: canAfford
                                ? () {
                                    // 1. Add item to cart
                                    widget.posController?.addProductDirectly(prod, 1);
                                    // 2. Add points discount for this item
                                    final currentPts = widget.posController?.redeemedPoints ?? 0;
                                    widget.posController?.setRedeemedPoints(currentPts + pointCost);
                                    setState(() {});

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Berhasil menukarkan "${prod.name}" dengan $pointCost poin!'),
                                        duration: const Duration(seconds: 2),
                                        backgroundColor: Colors.green.shade800,
                                      ),
                                    );
                                  }
                                : null,
                            child: Text(
                              canAfford ? 'Tukar' : 'Kurang',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- Numpad Helper ---
  Widget _buildCompactNumpad() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildNumpadRow(['1', '2', '3']),
        const SizedBox(height: 4),
        _buildNumpadRow(['4', '5', '6']),
        const SizedBox(height: 4),
        _buildNumpadRow(['7', '8', '9']),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey('C', onPressed: _onNumpadClear, isAccent: true),
            _buildKey('0', onPressed: () => _onNumpadPress('0')),
            _buildKey('⌫', onPressed: _onNumpadBackspace, isAccent: true),
          ],
        ),
      ],
    );
  }

  Widget _buildNumpadRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) => _buildKey(key, onPressed: () => _onNumpadPress(key))).toList(),
    );
  }

  Widget _buildKey(String label, {required VoidCallback onPressed, bool isAccent = false}) {
    return SizedBox(
      width: 76,
      height: 38,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isAccent ? Colors.grey.shade200 : Colors.white,
          elevation: 0.5,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isAccent ? Colors.red.shade700 : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
