import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../logic/pos_controller.dart';
import '../core/app_colors.dart';
import 'scrollable_category_bar.dart';
import 'compact_juice_tile.dart';
import 'cart_item_quantity_dialog.dart';

class CatalogPanel extends ConsumerStatefulWidget {
  const CatalogPanel({super.key});

  @override
  ConsumerState<CatalogPanel> createState() => _CatalogPanelState();
}

class _CatalogPanelState extends ConsumerState<CatalogPanel> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  bool _isClearingSearch = false;
  bool _wasSearchEmpty = true;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    if (_isClearingSearch) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        ref.read(posControllerProvider).setSearchQuery(val);
      }
    });
  }

  void _onSearchSubmitted(String val) {
    final query = val.trim();
    if (query.isEmpty) return;

    _debounceTimer?.cancel();
    final controller = ref.read(posControllerProvider);
    final matched = controller.handleBarcodeScan(query);

    if (matched != null) {
      _isClearingSearch = true;
      _searchController.clear();
      _wasSearchEmpty = true;
      controller.setSearchQuery('');
      _isClearingSearch = false;

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ditambahkan: ${matched.name}'),
            duration: const Duration(seconds: 1),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    } else {
      controller.setSearchQuery(query);
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produk barcode "$query" tidak ditemukan'),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.brandDarkRed,
          ),
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_searchFocusNode.hasFocus) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(posControllerProvider);
    final products = controller.filteredProducts;

    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // 1. Search & Barcode Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.topbarBg,
              border: Border(bottom: BorderSide(color: AppColors.borderDark, width: 2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderDark, width: 1.5),
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      autofocus: true,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Scan barcode atau ketik nama produk / kode SKU...',
                        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        prefixIcon: const Icon(Icons.qr_code_scanner_rounded, size: 22, color: AppColors.brandRed),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _debounceTimer?.cancel();
                                  _isClearingSearch = true;
                                  _searchController.clear();
                                  _wasSearchEmpty = true;
                                  controller.setSearchQuery('');
                                  _isClearingSearch = false;
                                  setState(() {});
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (val) {
                        _onSearchChanged(val);
                        final isNowEmpty = val.isEmpty;
                        if (_wasSearchEmpty != isNowEmpty) {
                          _wasSearchEmpty = isNowEmpty;
                          setState(() {});
                        }
                      },
                      onSubmitted: _onSearchSubmitted,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.deepSlate,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderDark, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 18, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        '${products.length} Item',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Horizontally Scrollable Category Bar (if more than 1 category)
          if (controller.categories.length > 1)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: const BoxDecoration(
                color: AppColors.topbarBg,
                border: Border(bottom: BorderSide(color: AppColors.borderDark, width: 1.5)),
              ),
              child: ScrollableCategoryBar(
                categories: controller.categories,
                selectedCategory: controller.selectedCategory,
                onSelected: (cat) => controller.selectCategory(cat),
              ),
            ),

          // 3. Retail Product Grid (Direct tap adds to cart)
          Expanded(
            child: products.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 8),
                        Text(
                          'Tidak ada produk ditemukan (${controller.selectedCategory})',
                          style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      childAspectRatio: controller.showProductImages ? 0.70 : 0.95,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return CompactJuiceTile(
                        product: product,
                        showImage: controller.showProductImages,
                        imageBaseUrl: controller.imageBaseUrl,
                        onTap: () {
                          controller.addProductDirectly(product);
                        },
                        onLongPress: () async {
                          final qty = await CartItemQuantityDialog.show(
                            context,
                            productName: product.name,
                            initialQuantity: 1,
                            unitPrice: product.price,
                            sku: product.defaultCode ?? product.barcode,
                          );
                          if (qty != null && qty > 0) {
                            controller.addProductDirectly(product, qty);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
