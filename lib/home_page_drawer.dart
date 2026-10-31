part of 'home_page.dart';

// ===================================================================
// HOME PAGE SIDE MENU (Drawer) - separate file
// Categories are small chips (like the Home page). Tapping one closes
// the menu and shows that category's products on the Home page.
// ===================================================================

class _HomeDrawer extends StatelessWidget {
  final bool isLoggedIn;
  final VoidCallback onAccount;
  final VoidCallback onHome;
  final VoidCallback onVideos;
  final ValueChanged<String> onCategorySelected;

  const _HomeDrawer({
    required this.isLoggedIn,
    required this.onAccount,
    required this.onHome,
    required this.onVideos,
    required this.onCategorySelected,
  });

  // One small category chip.
  Widget _chip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.redAccent),
            const SizedBox(width: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // All categories (Admin list), shown as small chips.
  Widget _buildCategoryChips(NavigatorState nav) {
    return StreamBuilder<List<CategoryItem>>(
      stream: CategoryService.stream(),
      builder: (context, snapshot) {
        // (name, icon) pairs. "All" is always first.
        final entries = <MapEntry<String, IconData>>[
          const MapEntry(CategoryService.allName, Icons.apps_rounded),
        ];

        final items = snapshot.data;

        if (items != null) {
          for (final item in items) {
            entries.add(MapEntry(item.name, item.icon));
          }
        } else {
          // Until the Admin list arrives, show the default names.
          for (final d in CategoryService.defaults) {
            entries.add(MapEntry(d['name']!, Icons.category));
          }
        }

        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in entries)
              _chip(
                icon: e.value,
                label: e.key,
                onTap: () {
                  nav.pop();
                  onCategorySelected(e.key);
                },
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final nav = Navigator.of(context);

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                gradient: _HomePageState._headerGradient,
              ),
              child: Row(
                children: [
                  Icon(Icons.shopping_bag, color: Colors.white, size: 32),
                  SizedBox(width: 12),
                  Text(
                    'BuyNova',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Account'),
              onTap: () {
                nav.pop();
                onAccount();
              },
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Home'),
              onTap: () {
                nav.pop();
                onHome();
              },
            ),

            // CATEGORIES (small chips, open the list on the Home page)
            Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
              ),
              child: ExpansionTile(
                leading: const Icon(Icons.category_outlined),
                title: const Text('Categories'),
                initiallyExpanded: true,
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [
                  _buildCategoryChips(nav),
                ],
              ),
            ),

            if (isLoggedIn)
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Add Product'),
                onTap: () {
                  nav.pop();
                  nav.push(
                    MaterialPageRoute(
                      builder: (context) => const AddProductPage(),
                    ),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('Videos'),
              subtitle: const Text('Watch Reels & Videos'),
              onTap: () {
                nav.pop();
                onVideos();
              },
            ),

            // INVITE (replaces Cart)
            ListTile(
              leading: const Icon(Icons.group_add_outlined),
              title: const Text('Invite'),
              subtitle: const Text('Invite friends & earn points'),
              onTap: () {
                nav.pop();
                nav.push(
                  MaterialPageRoute(
                    builder: (context) =>
                        isLoggedIn ? const InvitePage() : const LoginPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                nav.pop();
                nav.push(
                  MaterialPageRoute(
                    builder: (context) => const SettingsPage(),
                  ),
                );
              },
            ),
            if (isLoggedIn)
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () async {
                  nav.pop();
                  await FirebaseAuth.instance.signOut();
                },
              ),
          ],
        ),
      ),
    );
  }
}
