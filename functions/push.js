const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();
const REGION = 'asia-northeast3';
const MAX_TOKENS = 10;

const text = (v, max) => String(v == null ? '' : v).slice(0, max);

// ============================================================
// savePushToken  (called by the app after login)
// Saves this phone's FCM token on users/{uid}.fcmTokens
// ============================================================
exports.savePushToken = onCall({ region: REGION }, async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError('unauthenticated', 'You must be logged in.');
  }
  const token = text(request.data && request.data.token, 4096).trim();
  if (!token) {
    throw new HttpsError('invalid-argument', 'token is required.');
  }

  const ref = db.collection('users').doc(request.auth.uid);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'User account not found.');
  }

  const current = Array.isArray((snap.data() || {}).fcmTokens)
    ? snap.data().fcmTokens
    : [];
  const next = [token, ...current.filter((t) => t !== token)].slice(0, MAX_TOKENS);

  await ref.update({
    fcmTokens: next,
    fcmUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { success: true };
});

// ============================================================
// removePushToken  (called by the app on logout)
// ============================================================
exports.removePushToken = onCall({ region: REGION }, async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError('unauthenticated', 'You must be logged in.');
  }
  const token = text(request.data && request.data.token, 4096).trim();
  if (!token) return { success: true };

  await db
    .collection('users')
    .doc(request.auth.uid)
    .update({ fcmTokens: admin.firestore.FieldValue.arrayRemove(token) });
  return { success: true };
});

// ============================================================
// Every in-app notification also becomes a phone push.
// Trigger: a new document in users/{uid}/notifications
// (wallet, order refund, earning, membership ... all already
// write there, so no other code has to change).
//
// Optional fields on the notification document:
//   imageUrl  (https)  -> picture inside the push
//   productId + kind   -> opens that product (kind: "p" or "r")
// ============================================================
exports.onNotificationCreatedPush = onDocumentCreated(
  { document: 'users/{userId}/notifications/{notificationId}', region: REGION },
  async (event) => {
    const snap = event.data;
    if (!snap) return null;

    const n = snap.data() || {};
    const userId = event.params.userId;

    const userRef = db.collection('users').doc(userId);
    const userSnap = await userRef.get();
    if (!userSnap.exists) return null;

    const tokens = (Array.isArray((userSnap.data() || {}).fcmTokens)
      ? userSnap.data().fcmTokens
      : []
    ).filter((t) => typeof t === 'string' && t);
    if (!tokens.length) return null;

    const kind = n.kind === 'r' ? 'r' : 'p';
    const link = n.productId
      ? `buynova://${kind}/${encodeURIComponent(String(n.productId))}`
      : '';

    const notification = {
      title: text(n.title || 'BuyNova', 100),
      body: text(n.message || n.body || '', 300),
    };
    if (typeof n.imageUrl === 'string' && n.imageUrl.indexOf('https://') === 0) {
      notification.imageUrl = n.imageUrl;
    }

    const message = {
      tokens,
      notification,
      data: {
        type: text(n.type, 50),
        orderId: text(n.orderId, 100),
        productId: text(n.productId, 100),
        link,
      },
      android: { priority: 'high' },
    };

    let response;
    try {
      response = await admin.messaging().sendEachForMulticast(message);
    } catch (e) {
      console.error('Push send failed for', userId, e);
      return null;
    }

    // Remove tokens that are no longer valid (app uninstalled etc.)
    const dead = [];
    response.responses.forEach((r, i) => {
      const code = r.error && r.error.code;
      if (
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token'
      ) {
        dead.push(tokens[i]);
      }
    });
    if (dead.length) {
      await userRef.update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...dead),
      });
    }
    return null;
  }
);
