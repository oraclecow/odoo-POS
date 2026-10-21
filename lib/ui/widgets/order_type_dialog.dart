import 'package:flutter/material.dart';
import '../../data/models/order.dart';
import '../core/app_colors.dart';

class OrderTypeDialog extends StatelessWidget {
  final OrderChannel currentChannel;
  final Function(OrderChannelType type, String? pin) onChannelSelected;

  const OrderTypeDialog({
    super.key,
    required this.currentChannel,
    required this.onChannelSelected,
  });

  void _promptPin(BuildContext context, OrderChannelType type, String title) {
    final controller = TextEditingController(text: currentChannel.deliveryPin ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 4,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Masukkan 4 digit (misal: 4821)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final pin = controller.text.trim();
              Navigator.pop(ctx);
              Navigator.pop(context); // close parent dialog
              onChannelSelected(type, pin.isEmpty ? '0000' : pin);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
            child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Pilih Jenis Pesanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      children: [
        SimpleDialogOption(
          onPressed: () {
            Navigator.pop(context);
            onChannelSelected(OrderChannelType.dineIn, null);
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0),
            child: Text('🍽️ Dine In (Makan di Tempat)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
        SimpleDialogOption(
          onPressed: () {
            Navigator.pop(context);
            onChannelSelected(OrderChannelType.takeAway, null);
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0),
            child: Text('🥡 Take Away (Bungkus)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => _promptPin(context, OrderChannelType.grabFood, 'GrabFood Order ID'),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0),
            child: Text('🟢 GrabFood (4 Digit ID)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => _promptPin(context, OrderChannelType.shopeeFood, 'ShopeeFood Order ID'),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0),
            child: Text('🟠 ShopeeFood (4 Digit ID)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
