import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'confirmed':
        bg = Colors.blue.withValues(alpha: 0.15);
        fg = Colors.blue.shade700;
        label = 'CONFIRMED';
        break;
      case 'active':
        bg = Colors.green.withValues(alpha: 0.15);
        fg = Colors.green.shade700;
        label = 'CHARGING NOW';
        break;
      case 'completed':
        bg = Colors.teal.withValues(alpha: 0.15);
        fg = Colors.teal.shade700;
        label = 'COMPLETED';
        break;
      case 'pending_payment':
        bg = Colors.amber.withValues(alpha: 0.15);
        fg = Colors.amber.shade800;
        label = 'PENDING PAYMENT';
        break;
      case 'cancelled_by_driver':
      case 'cancelled_by_host':
        bg = Colors.red.withValues(alpha: 0.15);
        fg = Colors.red.shade700;
        label = 'CANCELLED';
        break;
      case 'disputed':
        bg = Colors.purple.withValues(alpha: 0.15);
        fg = Colors.purple.shade700;
        label = 'DISPUTED';
        break;
      case 'expired':
        bg = Colors.grey.withValues(alpha: 0.15);
        fg = Colors.grey.shade700;
        label = 'EXPIRED';
        break;
      default:
        bg = Colors.grey.withValues(alpha: 0.15);
        fg = Colors.grey.shade700;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
