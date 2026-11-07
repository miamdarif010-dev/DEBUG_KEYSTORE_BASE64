import 'package:flutter/material.dart';

import 'fresh_info.dart';

/// Product type (Regular / Fresh) plus the Fresh-only fields:
/// category, unit, packing date and expiry date.
///
/// Used by the Edit Product page.
class FreshFormFields extends StatelessWidget {
  final bool isFresh;
  final String? category;
  final String unit;
  final DateTime? packedDate;
  final DateTime? expiryDate;
  final bool enabled;

  final ValueChanged<bool> onFreshChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onUnitChanged;
  final ValueChanged<DateTime> onPackedChanged;
  final ValueChanged<DateTime> onExpiryChanged;

  const FreshFormFields({
    super.key,
    required this.isFresh,
    required this.category,
    required this.unit,
    required this.packedDate,
    required this.expiryDate,
    required this.enabled,
    required this.onFreshChanged,
    required this.onCategoryChanged,
    required this.onUnitChanged,
    required this.onPackedChanged,
    required this.onExpiryChanged,
  });

  Future<void> _pickDate(BuildContext context, {required bool expiry}) async {
    final DateTime now = FreshInfo.today();

    final DateTime initial = expiry
        ? (expiryDate ?? now.add(const Duration(days: 3)))
        : (packedDate ?? now);

    final DateTime first = expiry ? now : now.subtract(const Duration(days: 30));
    final DateTime last = now.add(const Duration(days: 365));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first)
          ? first
          : (initial.isAfter(last) ? last : initial),
      firstDate: first,
      lastDate: last,
      helpText: expiry ? 'Select expiry date' : 'Select packing / harvest date',
    );

    if (picked == null) return;

    if (expiry) {
      onExpiryChanged(picked);
    } else {
      onPackedChanged(picked);
    }
  }

  Widget _typeOption({
    required bool fresh,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final bool selected = isFresh == fresh;
    final Color color = fresh ? Colors.green : Colors.redAccent;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? () => onFreshChanged(fresh) : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected ? color.withValues(alpha: 0.10) : Colors.white,
            border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: selected ? color : Colors.grey),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: selected ? color : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateField(
    BuildContext context, {
    required String label,
    required DateTime? value,
    required bool expiry,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? () => _pickDate(context, expiry: expiry) : null,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(
              expiry ? Icons.event_busy_outlined : Icons.inventory_outlined,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            value == null ? 'Select date' : FreshInfo.formatDate(value),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: value == null ? Colors.grey : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Product Type',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _typeOption(
              fresh: false,
              icon: Icons.inventory_2_outlined,
              title: 'Regular',
              subtitle: 'Normal product',
            ),
            const SizedBox(width: 10),
            _typeOption(
              fresh: true,
              icon: Icons.eco_outlined,
              title: 'Fresh',
              subtitle: 'Vegetables, fish, meat, eggs...',
            ),
          ],
        ),
        if (isFresh) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fresh Category *',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final c in FreshInfo.categories)
                      ChoiceChip(
                        avatar: Icon(
                          c.icon,
                          size: 18,
                          color: category == c.key ? Colors.white : Colors.green,
                        ),
                        label: Text(c.label),
                        selected: category == c.key,
                        showCheckmark: false,
                        selectedColor: Colors.green,
                        labelStyle: TextStyle(
                          color:
                              category == c.key ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected:
                            enabled ? (bool _) => onCategoryChanged(c.key) : null,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Price is per unit',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final u in FreshInfo.units)
                      ChoiceChip(
                        label: Text(u.label),
                        selected: unit == u.key,
                        selectedColor: Colors.green.withValues(alpha: 0.2),
                        onSelected:
                            enabled ? (bool _) => onUnitChanged(u.key) : null,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _dateField(
                      context,
                      label: 'Packing date *',
                      value: packedDate,
                      expiry: false,
                    ),
                    const SizedBox(width: 10),
                    _dateField(
                      context,
                      label: 'Expiry date *',
                      value: expiryDate,
                      expiry: true,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Both dates are required. Buyers see how many days are '
                  'left, and the product is hidden automatically after the '
                  'expiry date.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
