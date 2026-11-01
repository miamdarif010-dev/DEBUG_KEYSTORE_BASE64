import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'bike_game_page.dart';
import 'login_page.dart';
import 'spin_game_page.dart';

// ===================================================================
// EARNING HUB
// The "Play & Earn" button on the Home page opens this page. Every game
// that gives points is listed here.
//
// HOW TO ADD A NEW GAME (3 steps):
//   1. Make the game page, for example  MyNewGamePage  (its own file).
//   2. Import it at the top of this file.
//   3. Add ONE entry to kEarnGames below. Nothing else changes.
//
// HOW TO HIDE A GAME WITHOUT A NEW APP VERSION:
//   Firestore document  platformSettings/earnGames
//     hidden: ["bike"]        <- list of game ids to hide
// ===================================================================

class EarnGame {
  final String id;
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final List<Color> colors;
  final Widget Function(BuildContext context) pageBuilder;

  const EarnGame({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.pageBuilder,
    this.badge = '',
  });
}

// ---- ALL GAMES LIVE HERE (add new ones at the end) ----------------

final List<EarnGame> kEarnGames = [
  EarnGame(
    id: 'spin',
    title: 'Daily Lucky Spin',
    subtitle: 'Spin the wheel and win points',
    badge: 'FREE DAILY',
    icon: Icons.casino,
    colors: const [Color(0xFFFF7043), Color(0xFFFF5252)],
    pageBuilder: (context) => const SpinGamePage(),
  ),
  EarnGame(
    id: 'bike',
    title: 'Bike Rider',
    subtitle: 'Ride, dodge the cars, collect coins',
    badge: 'NEW',
    icon: Icons.two_wheeler,
    colors: const [Color(0xFF26A69A), Color(0xFF00897B)],
    pageBuilder: (context) => const BikeGamePage(),
  ),
];

// -------------------------------------------------------------------

class EarnPage extends StatelessWidget {
  const EarnPage({super.key});

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userStream() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return null;

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots();
  }

  Future<Set<String>> _loadHidden() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('platformSettings')
          .doc('earnGames')
          .get();

      final hidden = doc.data()?['hidden'];

      if (hidden is List) {
        return hidden.map((e) => e.toString()).toSet();
      }
    } catch (_) {
      // Optional setting. Show every game if it cannot be read.
    }

    return <String>{};
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      appBar: AppBar(
        title: const Text('Play & Earn'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _PointsCard(stream: _userStream(), loggedIn: loggedIn),

          const SizedBox(height: 20),

          const Text(
            'Games',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Play games every day and collect reward points.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 14),

          FutureBuilder<Set<String>>(
            future: _loadHidden(),
            builder: (context, snapshot) {
              final hidden = snapshot.data ?? <String>{};

              final games =
                  kEarnGames.where((g) => !hidden.contains(g.id)).toList();

              return Column(
                children: [
                  for (final g in games) _GameCard(game: g),
                  const _ComingSoonCard(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// POINTS HEADER
// ===================================================================

class _PointsCard extends StatelessWidget {
  final Stream<DocumentSnapshot<Map<String, dynamic>>>? stream;
  final bool loggedIn;

  const _PointsCard({required this.stream, required this.loggedIn});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.monetization_on_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: loggedIn
                ? StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: stream,
                    builder: (context, snapshot) {
                      final d = snapshot.data?.data() ?? {};

                      final points =
                          (d['pointsBalance'] as num?)?.toInt() ?? 0;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'My points',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '$points',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      );
                    },
                  )
                : const Text(
                    'Sign in to earn points',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          if (!loggedIn)
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.deepOrange,
              ),
              child: const Text('Sign In'),
            ),
        ],
      ),
    );
  }
}

// ===================================================================
// ONE GAME CARD
// ===================================================================

class _GameCard extends StatelessWidget {
  final EarnGame game;

  const _GameCard({required this.game});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: game.pageBuilder),
            );
          },
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(colors: game.colors),
              boxShadow: [
                BoxShadow(
                  color: game.colors.last.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(game.icon, color: Colors.white, size: 34),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              game.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (game.badge.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                game.badge,
                                style: TextStyle(
                                  color: game.colors.last,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        game.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===================================================================
// "MORE GAMES SOON" CARD
// ===================================================================

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.extension_outlined, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'More games are coming soon!',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
