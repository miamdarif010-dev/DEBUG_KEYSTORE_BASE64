import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color _kPriceRed = Color(0xFFE5233F);

String formatTaka(double value) => '৳${value.toStringAsFixed(2)}';

String formatPercent(double percent) {
  if (percent <= 0) return '0%';

  final rounded = percent.roundToDouble();

  if ((percent - rounded).abs() < 0.05) return '${rounded.toInt()}%';

  return '${percent.toStringAsFixed(1)}%';
}

double _round2(double v) => (v * 100).roundToDouble() / 100;

double _parse(String text) =>
    double.tryParse(text.replaceAll(',', '').trim()) ?? 0;

String _plain(double v) {
  final r = _round2(v);

  if (r == r.roundToDouble()) return r.toInt().toString();

  return r.toStringAsFixed(2);
}

// ===================================================================
// RESULT
// ===================================================================

class DiscountResult {
  final double original; // total price before discount
  final double finalPrice; // price the buyer pays

  const DiscountResult({required this.original, required this.finalPrice});

  double get amount => original - finalPrice;

  double get percent => original > 0 ? amount / original * 100 : 0;

  bool get isValid => original > 0 && finalPrice > 0;

  bool get hasDiscount => isValid && amount > 0.004;
}

// ===================================================================
// PRICE TAG  (final price, red struck original price, % badge)
// ===================================================================

class PriceTag extends StatelessWidget {
  final double price;
  final double? originalPrice;
  final double fontSize;
  final Color color;
  final WrapAlignment align;
  final bool showBadge;

  const PriceTag({
    super.key,
    required this.price,
    this.originalPrice,
    this.fontSize = 16,
    this.color = _kPriceRed,
    this.align = WrapAlignment.start,
    this.showBadge = true,
  });

  bool get _hasDiscount =>
      originalPrice != null && price > 0 && originalPrice! > price + 0.004;

  @override
  Widget build(BuildContext context) {
    final double smallSize = (fontSize * 0.72).clamp(11.0, 18.0).toDouble();
    final double badgeSize = (fontSize * 0.62).clamp(10.0, 14.0).toDouble();

    final double percent =
        _hasDiscount ? (originalPrice! - price) / originalPrice! * 100 : 0;

    return Wrap(
      alignment: align,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 2,
      children: [
        Text(
          formatTaka(price),
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (_hasDiscount)
          Text(
            formatTaka(originalPrice!),
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: smallSize,
              decoration: TextDecoration.lineThrough,
              decorationColor: Colors.red,
              decorationThickness: 2,
            ),
          ),
        if (_hasDiscount && showBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '-${formatPercent(percent)}',
              style: TextStyle(
                color: Colors.white,
                fontSize: badgeSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

// ===================================================================
// INPUT: total price + discount % + discount amount
// Edit % and the amount follows, edit the amount and % follows.
// ===================================================================

class DiscountPriceInput extends StatefulWidget {
  final ValueChanged<DiscountResult> onChanged;
  final String originalLabel;
  final String? helperText;
  final double? initialOriginal;
  final double? initialDiscountAmount; // existing discount (edit pages)
  final bool enabled;

  const DiscountPriceInput({
    super.key,
    required this.onChanged,
    this.originalLabel = 'Total Price (BDT)',
    this.helperText,
    this.initialOriginal,
    this.initialDiscountAmount,
    this.enabled = true,
  });

  @override
  State<DiscountPriceInput> createState() => _DiscountPriceInputState();
}

class _DiscountPriceInputState extends State<DiscountPriceInput> {
  late final TextEditingController _original;
  final TextEditingController _percent = TextEditingController();
  final TextEditingController _amount = TextEditingController();

  late DiscountResult _result;

  @override
  void initState() {
    super.initState();

    final initial = widget.initialOriginal;

    _original = TextEditingController(
      text: initial == null || initial <= 0 ? '' : _plain(initial),
    );

    final double base = initial ?? 0;
    final double disc = widget.initialDiscountAmount ?? 0;

    if (base > 0 && disc > 0.004 && disc < base) {
      _amount.text = _plain(disc);
      _percent.text = _plain(disc / base * 100);

      _result = DiscountResult(
        original: base,
        finalPrice: _round2(base - disc),
      );
    } else {
      _result = DiscountResult(original: base, finalPrice: base);
    }
  }

  @override
  void dispose() {
    _original.dispose();
    _percent.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _emit() {
    final double original = _parse(_original.text);

    double amount = _parse(_amount.text);

    if (amount < 0) amount = 0;
    if (amount > original) amount = original;

    final result = DiscountResult(
      original: original,
      finalPrice: _round2(original - amount),
    );

    setState(() {
      _result = result;
    });

    widget.onChanged(result);
  }

  void _onOriginalChanged() {
    final double original = _parse(_original.text);

    if (_percent.text.trim().isNotEmpty) {
      final double pct = _parse(_percent.text).clamp(0.0, 99.99).toDouble();

      _amount.text = _plain(original * pct / 100);
    }

    _emit();
  }

  void _onPercentChanged() {
    final double original = _parse(_original.text);

    if (_percent.text.trim().isEmpty) {
      _amount.clear();
      _emit();
      return;
    }

    double pct = _parse(_percent.text);

    if (pct > 99.99) {
      pct = 99.99;
      _percent.text = '99.99';
    }

    _amount.text = _plain(original * pct / 100);

    _emit();
  }

  void _onAmountChanged() {
    final double original = _parse(_original.text);

    if (_amount.text.trim().isEmpty) {
      _percent.clear();
      _emit();
      return;
    }

    double amount = _parse(_amount.text);

    // The buyer price must stay above zero.
    if (original > 0 && amount >= original) {
      amount = original - 0.01;
      if (amount < 0) amount = 0;
      _amount.text = _plain(amount);
    }

    _percent.text = original > 0 ? _plain(amount / original * 100) : '';

    _emit();
  }

  InputDecoration _decoration(
    String label, {
    String? prefix,
    String? suffix,
    String? helper,
  }) {
    return InputDecoration(
      labelText: label,
      prefixText: prefix,
      suffixText: suffix,
      helperText: helper,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _preview() {
    if (!_result.isValid) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _result.hasDiscount ? 'Buyers will see' : 'Price (no discount)',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
          const SizedBox(height: 4),
          PriceTag(
            price: _result.finalPrice,
            originalPrice: _result.hasDiscount ? _result.original : null,
            fontSize: 22,
          ),
          if (_result.hasDiscount) ...[
            const SizedBox(height: 4),
            Text(
              'You save ${formatTaka(_result.amount)}',
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatter = FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'));

    const keyboard = TextInputType.numberWithOptions(decimal: true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _original,
          enabled: widget.enabled,
          keyboardType: keyboard,
          inputFormatters: [formatter],
          decoration: _decoration(
            widget.originalLabel,
            prefix: '৳ ',
            helper: widget.helperText,
          ),
          onChanged: (_) => _onOriginalChanged(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _percent,
                enabled: widget.enabled,
                keyboardType: keyboard,
                inputFormatters: [formatter],
                decoration: _decoration('Discount (%)', suffix: '%'),
                onChanged: (_) => _onPercentChanged(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _amount,
                enabled: widget.enabled,
                keyboardType: keyboard,
                inputFormatters: [formatter],
                decoration: _decoration('Discount (৳)', prefix: '৳ '),
                onChanged: (_) => _onAmountChanged(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Discount is optional. Fill % or the amount, the other one is calculated.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5),
        ),
        const SizedBox(height: 10),
        _preview(),
      ],
    );
  }
}
