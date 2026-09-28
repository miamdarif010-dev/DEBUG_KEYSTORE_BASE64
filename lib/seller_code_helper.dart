import 'package:cloud_firestore/cloud_firestore.dart';

/// Makes sure an approved seller has a sellerCode.
///
/// Uses the same format as admin_panel_page.dart:
/// SELL- + first 6 characters of the user's UID (uppercase).
///
/// - If the user already has a code, nothing changes.
/// - If the user is not approved, nothing changes.
Future<void> ensureSellerCode(String uid) async {
  final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

  try {
    final snap = await userRef.get();
    final data = snap.data() ?? {};

    final existing = (data['sellerCode'] ?? '').toString();
    if (existing.isNotEmpty) return;

    if ((data['sellerStatus'] ?? '').toString() != 'approved') return;

    final short = uid.length >= 6 ? uid.substring(0, 6) : uid;

    await userRef.set(
      {'sellerCode': 'SELL-${short.toUpperCase()}'},
      SetOptions(merge: true),
    );
  } catch (_) {
    // Ignore: the dashboard will simply try again next time it opens.
  }
}
