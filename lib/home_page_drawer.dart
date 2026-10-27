part of 'home_page.dart';

// ===================================================================
// HOME PAGE SIDE MENU (Drawer) - separate file
// Cart is replaced by Invite. Invite reads the numbers the Admin sets
// in Admin Panel > Reward Settings.
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
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Categories'),
              onTap: () async {
                nav.pop();

                final result = await nav.push<String>(
                  MaterialPageRoute(
                    builder: (context) => const CategoriesPage(),
                  ),
                );

                if (result != null) onCategorySelected(result);
              },
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
