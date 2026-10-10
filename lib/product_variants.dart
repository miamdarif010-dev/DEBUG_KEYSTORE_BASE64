import 'package:flutter/material.dart';

const Color kAccent = Color(0xFFE2703A);

// ===================================================================
// MODEL
// ===================================================================

class ColorVariant {
  final String name;
  final Color color;
  final List<String> images;

  const ColorVariant({
    required this.name,
    required this.color,
    required this.images,
  });
}

Color colorFromHex(String hex) {
  var h = hex.replaceAll('#', '').trim();

  if (h.length == 6) {
    h = 'FF$h';
  }

  final value = int.tryParse(h, radix: 16);

  return Color(value ?? 0xFF9E9E9E);
}

String colorToHex(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;

  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Reads the product's `colors` field:
/// [{name: "Brown", hex: "#6B4226", images: ["url1", "url2"]}, ...]
List<ColorVariant> parseColorVariants(dynamic raw) {
  if (raw is! List) return const <ColorVariant>[];

  final result = <ColorVariant>[];

  for (final item in raw) {
    if (item is! Map) continue;

    final name = item['name']?.toString().trim() ?? '';
    final hex = item['hex']?.toString().trim() ?? '';

    if (name.isEmpty && hex.isEmpty) continue;

    final images = <String>[];
    final rawImages = item['images'];

    if (rawImages is List) {
      for (final img in rawImages) {
        final url = img?.toString().trim() ?? '';
        if (url.isNotEmpty && !images.contains(url)) {
          images.add(url);
        }
      }
    } else if (rawImages is String && rawImages.trim().isNotEmpty) {
      images.add(rawImages.trim());
    }

    result.add(
      ColorVariant(
        name: name.isEmpty ? hex : name,
        color: colorFromHex(hex),
        images: images,
      ),
    );
  }

  return result;
}

// ===================================================================
// COLOR SELECTOR (round color circles)
// ===================================================================

class ColorSelector extends StatelessWidget {
  final List<ColorVariant> colors;
  final int? selectedIndex;
  final ValueChanged<int?> onSelected;

  const ColorSelector({
    super.key,
    required this.colors,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (colors.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Row(
          children: [
            const Text(
              'Color',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 10),
            if (selectedIndex != null && selectedIndex! < colors.length)
              Text(
                colors[selectedIndex!].name,
                style: const TextStyle(
                  fontSize: 15,
                  color: kAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 12,
          children: List.generate(colors.length, (index) {
            final variant = colors[index];
            final selected = index == selectedIndex;

            return GestureDetector(
              onTap: () => onSelected(selected ? null : index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 46,
                height: 46,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? kAccent : Colors.grey.shade300,
                    width: selected ? 2.5 : 1.5,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: variant.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black12,
                    ),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check,
                          size: 18,
                          color: variant.color.computeLuminance() > 0.6
                              ? Colors.black
                              : Colors.white,
                        )
                      : null,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ===================================================================
// SIZE SELECTOR (rounded boxes, orange when selected)
// ===================================================================

class SizeSelector extends StatelessWidget {
  final List<String> sizes;
  final String? selected;
  final ValueChanged<String> onSelected;

  const SizeSelector({
    super.key,
    required this.sizes,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (sizes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        const Text(
          'Size',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: sizes.map((size) {
            final isSelected = size == selected;

            return GestureDetector(
              onTap: () => onSelected(size),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                constraints: const BoxConstraints(minWidth: 52),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? kAccent : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? kAccent : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  size,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
