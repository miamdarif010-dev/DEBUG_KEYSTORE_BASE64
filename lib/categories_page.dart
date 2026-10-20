import 'package:flutter/material.dart';

import 'category_service.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  int _selectedIndex = 0;

  // "All" is always first, then the categories the admin created.
  static const CategoryItem _allItem = CategoryItem(
    id: 'all',
    name: CategoryService.allName,
    iconKey: '',
    colorKey: '',
  );

  void _selectCategory(String name) {
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<CategoryItem>>(
        stream: CategoryService.stream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load categories.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final categories = <CategoryItem>[
            _allItem,
            ...snapshot.data!,
          ];

          final index = _selectedIndex < categories.length
              ? _selectedIndex
              : 0;

          final selected = categories[index];

          final selectedIcon =
              selected.id == 'all' ? Icons.apps : selected.icon;

          final selectedColor =
              selected.id == 'all' ? Colors.redAccent : selected.color;

          return Column(
            children: [
              // Search bar
              Container(
                color: Colors.redAccent,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(21),
                  ),
                  child: const TextField(
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),

              const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Shop by category',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              Expanded(
                child: Row(
                  children: [
                    // LEFT SIDEBAR
                    Container(
                      width: 110,
                      color: Colors.grey.shade100,
                      child: ListView.builder(
                        itemCount: categories.length,
                        itemBuilder: (context, i) {
                          final isSelected = i == index;
                          final name = categories[i].name;

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedIndex = i;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                                border: Border(
                                  left: BorderSide(
                                    color: isSelected
                                        ? Colors.redAccent
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Text(
                                name,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Colors.redAccent
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // RIGHT SIDE: selected category tile
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: GridView.count(
                          crossAxisCount: 3,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.8,
                          children: [
                            InkWell(
                              onTap: () => _selectCategory(selected.name),
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 36,
                                    backgroundColor: selectedColor
                                        .withValues(alpha: 0.15),
                                    child: Icon(
                                      selectedIcon,
                                      color: selectedColor,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    selected.name,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
