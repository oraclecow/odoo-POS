import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/juice_product.dart';
import '../core/app_colors.dart';

class CompactJuiceTile extends StatelessWidget {
  final JuiceProduct product;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool showImage;
  final String imageBaseUrl;
  final dynamic channelType;
  final bool showStockBadge;

  const CompactJuiceTile({
    super.key,
    required this.product,
    required this.onTap,
    this.onLongPress,
    this.showImage = true,
    this.imageBaseUrl = '',
    this.channelType,
    this.showStockBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderDark,
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 7.0),
            child: showImage
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Maximized Picture Container filling available height with floating badges
                      _buildImageStack(),
                      const SizedBox(height: 5),

                      // 2. Product Name at bottom, right above the price
                      SizedBox(
                        height: 30,
                        child: Center(
                          child: Text(
                            product.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.pitchBlack,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // 3. Price Tag Pill at the very bottom
                      _buildPricePill(currency),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Compact Text Mode: Top Row with SKU and Stock
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                              ),
                              child: Text(
                                product.defaultCode ?? (product.barcode != null && product.barcode!.length > 6
                                    ? '...${product.barcode!.substring(product.barcode!.length - 5)}'
                                    : '#${product.id}'),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          _buildStockBadge(product),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Product Name in middle
                      Expanded(
                        child: Center(
                          child: Text(
                            product.name,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.pitchBlack,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Price Tag Pill at bottom
                      _buildPricePill(currency),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildPricePill(NumberFormat currency) {
    final effectivePrice = channelType != null ? product.getPriceForChannel(channelType) : product.price;
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
      decoration: BoxDecoration(
        color: AppColors.brandOrangeLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.brandOrange, width: 1.2),
      ),
      child: Text(
        currency.format(effectivePrice),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: AppColors.brandDarkRed,
        ),
      ),
    );
  }

  Widget _buildImageStack() {
    final imgUrl = product.getImageUrl(imageBaseUrl);

    return Expanded(
      child: Stack(
        children: [
          // Full-area Picture Container
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: (product.hasImage && imgUrl != null)
                    ? Image.network(
                        imgUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.brandOrange,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.inventory_2_outlined,
                              size: 32,
                              color: Color(0xFF94A3B8),
                            ),
                          );
                        },
                      )
                    : const Center(
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 36,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
              ),
            ),
          ),

          // Top-Left Floating SKU Badge
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                product.defaultCode ?? (product.barcode != null && product.barcode!.length > 6
                    ? '...${product.barcode!.substring(product.barcode!.length - 5)}'
                    : '#${product.id}'),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9.0,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ),

          // Top-Right Floating Stock Badge
          Positioned(
            top: 4,
            right: 4,
            child: _buildStockBadge(product),
          ),
        ],
      ),
    );
  }

  Widget _buildStockBadge(JuiceProduct product) {
    // Rule: BOM kit products or F&B guardrail should not show stock
    if (!showStockBadge || product.isKit) {
      return const SizedBox.shrink();
    }

    final stock = product.qtyAvailable;
    if (stock == null) {
      return const Icon(
        Icons.add_shopping_cart_rounded,
        size: 14,
        color: AppColors.brandRed,
      );
    }
    final isOut = stock <= 0;
    final isLow = stock > 0 && stock <= 5;
    final color = isOut
        ? const Color(0xFFDC2626) // red
        : isLow
            ? const Color(0xFFD97706) // amber
            : const Color(0xFF16A34A); // green
    final bgColor = isOut
        ? const Color(0xFFFEF2F2)
        : isLow
            ? const Color(0xFFFFFBEB)
            : const Color(0xFFF0FDF4);
    final text = isOut ? 'Habis' : '${stock.toInt()} pcs';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
