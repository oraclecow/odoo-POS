import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class OrderNoteDialog extends StatefulWidget {
  final String? initialNote;
  final ValueChanged<String?> onSave;

  const OrderNoteDialog({
    super.key,
    this.initialNote,
    required this.onSave,
  });

  @override
  State<OrderNoteDialog> createState() => _OrderNoteDialogState();
}

class _OrderNoteDialogState extends State<OrderNoteDialog> {
  late TextEditingController _controller;
  final _presets = const ['Tanpa Sedotan', 'Pisah Kantong', 'Es Dipisah', 'Extra Tisu'];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Catatan Pesanan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _presets.map((preset) {
                return ActionChip(
                  label: Text(preset, style: const TextStyle(fontSize: 11.5)),
                  backgroundColor: Colors.grey.shade100,
                  onPressed: () {
                    final current = _controller.text.trim();
                    if (current.isEmpty) {
                      _controller.text = preset;
                    } else {
                      _controller.text = '$current, $preset';
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Tulis catatan untuk barista / dapur...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_controller.text.isNotEmpty)
          TextButton(
            onPressed: () {
              widget.onSave(null);
              Navigator.pop(context);
            },
            child: const Text('Hapus Catatan', style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () {
            final text = _controller.text.trim();
            widget.onSave(text.isEmpty ? null : text);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
          child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
