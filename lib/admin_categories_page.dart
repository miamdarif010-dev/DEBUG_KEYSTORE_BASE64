import 'package:flutter/material.dart';

import 'category_service.dart';

class AdminCategoriesPage extends StatefulWidget {
  const AdminCategoriesPage({super.key});

  @override
  State<AdminCategoriesPage> createState() =>
      _AdminCategoriesPageState();
}

class _AdminCategoriesPageState extends State<AdminCategoriesPage> {
  final TextEditingController _nameController = TextEditingController();

  String _iconKey = 'category';
  String _colorKey = 'red';
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  void _message(String text, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Colors.red.shade700 : null,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ============================================================
  // ADD
  // ============================================================

  Future<void> _addCategory(List<CategoryItem> current) async {
    if (_busy) return;

    final name = _nameController.text.trim();

    if (name.isEmpty) {
      _message('Enter a category name.', error: true);
      return;
    }

    if (name.toLowerCase() == CategoryService.allName.toLowerCase()) {
      _message('"All" is added automatically.', error: true);
      return;
    }

    final exists = current.any(
      (c) => c.name.toLowerCase() == name.toLowerCase(),
    );

    if (exists) {
      _message('This category already exists.', error: true);
      return;
    }

    setState(() => _busy = true);

    try {
      await CategoryService.add(
        name: name,
        iconKey: _iconKey,
        colorKey: _colorKey,
        order: current.length,
      );

      _nameController.clear();
      FocusManager.instance.primaryFocus?.unfocus();

      _message('Category added.');
    } catch (e) {
      _message('Failed to add category: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> _deleteCategory(CategoryItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete category?'),
          content: Text(
            '"${item.name}" will be removed from the category list.\n\n'
            'Products already saved in this category are not deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await CategoryService.delete(item.id);
      _message('Category deleted.');
    } catch (e) {
      _message('Failed to delete: $e', error: true);
    }
  }

  // ============================================================
  // REORDER
  // ============================================================

  Future<void> _reorder(
    List<CategoryItem> items,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) newIndex -= 1;

    final list = [...items];
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);

    try {
      await CategoryService.saveOrder(list);
    } catch (e) {
      _message('Failed to save order: $e', error: true);
    }
  }

  // ============================================================
  // SEED DEFAULTS
  // ============================================================

  Future<void> _seedDefaults() async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      await CategoryService.seedDefaults();
      _message('Default categories loaded.');
    } catch (e) {
      _message('Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Categories',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<CategoryItem>>(
        stream: CategoryService.adminStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Error:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data ?? [];

          return Column(
            children: [
              _addCard(items),
              Expanded(child: _list(items)),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // ADD CARD
  // ============================================================

  Widget _addCard(List<CategoryItem> items) {
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add new category',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              maxLength: 24,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Category name',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              onSubmitted: (_) => _addCategory(items),
            ),
            const SizedBox(height: 10),

            // ICON PICKER
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: CategoryService.icons.entries.map((entry) {
                  final selected = entry.key == _iconKey;

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _iconKey = entry.key),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: selected
                              ? primary.withValues(alpha: 0.15)
                              : Colors.grey.shade100,
                          border: Border.all(
                            color: selected ? primary : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          entry.value,
                          color: selected ? primary : Colors.black54,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),

            // COLOR PICKER
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: CategoryService.colors.entries.map((entry) {
                  final selected = entry.key == _colorKey;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _colorKey = entry.key),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: entry.value,
                          border: Border.all(
                            color: selected
                                ? Colors.black87
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: selected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              )
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _addCategory(items),
                icon: const Icon(Icons.add),
                label: const Text('Add Category'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LIST
  // ============================================================

  Widget _list(List<CategoryItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No categories yet.\n'
                'The app is showing the default list right now.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _busy ? null : _seedDefaults,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Load default categories'),
              ),
            ],
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
      itemCount: items.length,
      onReorder: (oldIndex, newIndex) =>
          _reorder(items, oldIndex, newIndex),
      itemBuilder: (context, index) {
        final item = items[index];

        return Card(
          key: ValueKey(item.id),
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: item.color.withValues(alpha: 0.15),
              child: Icon(item.icon, color: item.color),
            ),
            title: Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Hold and drag to change order'),
            trailing: IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
              ),
              onPressed: () => _deleteCategory(item),
            ),
          ),
        );
      },
    );
  }
}
