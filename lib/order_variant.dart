import 'package:flutter/material.dart';

/// "Color: Brown  •  Size: M" (empty text when the item has neither).
String variantText(Map<String, dynamic> item) {
  final parts = <String>[];

  final color = (item['color'] ?? '').toString().trim();
  final size = (item['size'] ?? '').toString().trim();

  if (color.isNotEmpty) parts.add('Color: $color');
  if (size.isNotEmpty) parts.add('Size: $size');

  return parts.join('  •  ');
}

/// Small line that shows the chosen color and size of an ordered product.
/// Shows nothing for old orders or products without options.
class VariantLine extends StatelessWidget {
  final Map<String, dynamic> item;

  const VariantLine(this.item, {super.key});

  @override
  Widget build(BuildContext context) {
    final text = variantText(item);

    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.deepOrange.shade700,
        ),
      ),
    );
  }
}
