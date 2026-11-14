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
// setPushEnabled  (Settings -> Notifications switch)
// pushEnabled === false  => no phone pushes for this user at all.
// ============================================================
exports.setPushEnabled = onCall({ region: REGION }, async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError('unauthenticated', 'You must be logged in.');
  }
  const enabled = !!(request.data && request.data.enabled === true);
  const token = text(request.data && request.data.token, 4096).trim();

  const ref = db.collection('users').doc(request.auth.uid);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'User account not found.');
  }

  const update = {
    pushEnabled: enabled,
    fcmUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (!enabled && token) {
    update.fcmTokens = admin.firestore.FieldValue.arrayRemove(token);
  }
  await ref.update(update);
  return { success: true };
});

// ============================================================
// deleteMyAccount  (Settings -> Delete Account)
// Runs with admin rights, so it can remove what the Firestore rules
// do not let the app delete. The app re-checks the password first.
//
// KEPT on purpose (money / legal records): orders, seller_orders,
// reseller_orders, return_refund_requests, conversations.
// NOT touched: the user's products (see note below).
// ============================================================
exports.deleteMyAccount = onCall(
  { region: REGION, timeoutSeconds: 300, memory: '512MiB' },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError('unauthenticated', 'You must be logged in.');
    }
    const uid = request.auth.uid;
    const userRef = db.collection('users').doc(uid);
    const userSnap = await userRef.get();
    const u = userSnap.exists ? userSnap.data() || {} : {};

    // ---- Safety checks: never delete someone who still has money / open orders
    const money = Math.max(Number(u.walletBalance || 0), Number(u.balance || 0));
    if (money > 0) {
      throw new HttpsError(
        'failed-precondition',
        'Please withdraw your wallet balance before deleting your account.'
      );
    }

    const pendingWallet = await userRef
      .collection('walletTransactions')
      .where('status', '==', 'pending')
      .limit(1)
      .get();
    if (!pendingWallet.empty) {
      throw new HttpsError(
        'failed-precondition',
        'You have a pending wallet request. Please wait until it is finished.'
      );
    }

    const OPEN = ['placed', 'confirmed', 'processing', 'shipped'];
    const hasOpen = async (field) => {
      const snap = await db
        .collection('seller_orders')
        .where(field, '==', uid)
        .limit(100)
        .get();
      return snap.docs.some((d) => OPEN.includes((d.data() || {}).orderStatus));
    };
    if ((await hasOpen('customerId')) || (await hasOpen('sellerId'))) {
      throw new HttpsError(
        'failed-precondition',
        'You still have open orders. Please finish or cancel them first.'
      );
    }

    // ---- Delete user-owned documents (with all their sub-collections)
    const removeWhere = async (collection, field) => {
      const snap = await db.collection(collection).where(field, '==', uid).get();
      for (const d of snap.docs) {
        await db.recursiveDelete(d.ref);
      }
    };

    // Edit this list to match your data.
    await removeWhere('sellerVideos', 'userId');
    await removeWhere('product_reviews', 'userId');
    await removeWhere('reseller_products', 'entrepreneurUid');
    await removeWhere('watchRewardClaims', 'userId');

    // NOTE: products where sellerId == uid are left as they are. Add
    //   await removeWhere('products', 'sellerId');
    // above if sellers' products should disappear with the account.

    await db.collection('publicProfiles').doc(uid).delete().catch(() => {});

    // users/{uid} + cart, addresses, favorites, notifications,
    // walletTransactions, paymentMethods, ... (all sub-collections)
    await db.recursiveDelete(userRef);

    // Finally the login account itself
    try {
      await admin.auth().deleteUser(uid);
    } catch (e) {
      if (!e || e.code !== 'auth/user-not-found') {
        console.error('deleteUser failed', uid, e);
        throw new HttpsError('internal', 'Could not delete the login account.');
      }
    }
    return { success: true };
  }
);

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

    // User turned notifications off in Settings.
    if ((userSnap.data() || {}).pushEnabled === false) return null;

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

// ============================================================
// ADMIN ONLY helper (same admin e-mail as the rest of the backend)
// ============================================================
const ADMIN_EMAIL = 'miamdarif010@gmail.com';

function requireAdmin(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError('unauthenticated', 'You must be logged in.');
  }
  const email = String(request.auth.token.email || '').toLowerCase();
  if (email !== ADMIN_EMAIL || request.auth.token.email_verified !== true) {
    throw new HttpsError('permission-denied', 'Admin access required.');
  }
}

const isHttps = (v) => typeof v === 'string' && v.indexOf('https://') === 0;

// ============================================================
// sendAdminNotice  (Admin Panel -> "Send Notice")
// Creates one public notice in global_notifications.
// onGlobalNotificationCreatedPush (below) then pushes it to every phone.
//   kind: "announcement" | "app_update"
// ============================================================
exports.sendAdminNotice = onCall({ region: REGION }, async (request) => {
  requireAdmin(request);
  const d = request.data || {};

  const title = text(d.title, 100).trim();
  const message = text(d.message, 500).trim();
  if (!title) throw new HttpsError('invalid-argument', 'Title is required.');
  if (!message) throw new HttpsError('invalid-argument', 'Message is required.');

  const kind = d.kind === 'app_update' ? 'app_update' : 'announcement';
  const imageUrl = isHttps(d.imageUrl) ? String(d.imageUrl).trim() : '';
  const link = isHttps(d.link) ? String(d.link).trim() : '';

  const ref = await db.collection('global_notifications').add({
    type: kind,
    title,
    message,
    active: true,
    isActive: true,
    productImageUrl: imageUrl,
    imageUrl,
    link,
    sellerId: request.auth.uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { success: true, id: ref.id };
});

// ============================================================
// onGlobalNotificationCreatedPush
// A new document in global_notifications (new product from a seller or
// reseller, or an Admin notice) becomes a phone push for ALL users.
//  - users who turned notifications off (pushEnabled === false) are skipped
//  - the person who created it does not get a push for their own product
//  - dead tokens are removed
// ============================================================
exports.onGlobalNotificationCreatedPush = onDocumentCreated(
  {
    document: 'global_notifications/{notificationId}',
    region: REGION,
    timeoutSeconds: 540,
    memory: '512MiB',
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return null;
    const n = snap.data() || {};
    if (n.active === false || n.isActive === false) return null;

    const type = text(n.type, 50);
    const isProduct = !!n.productId;
    const kind = n.kind === 'r' || type.indexOf('reseller') === 0 ? 'r' : 'p';

    let link = '';
    if (isProduct) {
      link = `buynova://${kind}/${encodeURIComponent(String(n.productId))}`;
    }

    // Never put profit / earning words in a public push.
    const clean = (s) =>
      /profit|earning|commission|লাভ|প্রফিট/i.test(String(s || '')) ? '' : s;

    const title = text(clean(n.title) || 'BuyNova', 100);
    let body = text(clean(n.message), 300);
    if (!body && n.productName) {
      body = text(`${n.productName} is now available on BuyNova.`, 300);
    }

    const notification = { title, body };
    const img = n.productImageUrl || n.imageUrl || n.productImage;
    if (isHttps(img)) notification.imageUrl = img;

    const data = {
      type,
      productId: text(n.productId, 100),
      link,
      url: isHttps(n.link) ? String(n.link) : '',
      notificationId: event.params.notificationId,
    };

    const skipUid = isProduct ? String(n.sellerId || '') : '';

    let sent = 0;
    let last = null;
    for (;;) {
      let q = db
        .collection('users')
        .orderBy(admin.firestore.FieldPath.documentId())
        .select('fcmTokens', 'pushEnabled')
        .limit(300);
      if (last) q = q.startAfter(last);
      const page = await q.get();
      if (page.empty) break;
      last = page.docs[page.docs.length - 1];

      const owner = new Map(); // token -> uid
      for (const doc of page.docs) {
        if (doc.id === skipUid) continue;
        const u = doc.data() || {};
        if (u.pushEnabled === false) continue;
        const toks = Array.isArray(u.fcmTokens) ? u.fcmTokens : [];
        for (const t of toks) {
          if (typeof t === 'string' && t && !owner.has(t)) owner.set(t, doc.id);
        }
      }

      const tokens = [...owner.keys()];
      for (let i = 0; i < tokens.length; i += 500) {
        const chunk = tokens.slice(i, i + 500);
        let res;
        try {
          res = await admin.messaging().sendEachForMulticast({
            tokens: chunk,
            notification,
            data,
            android: { priority: 'high' },
          });
        } catch (e) {
          console.error('Global push chunk failed', e);
          continue;
        }
        sent += res.successCount;

        const dead = new Map(); // uid -> [tokens]
        res.responses.forEach((r, idx) => {
          const code = r.error && r.error.code;
          if (
            code === 'messaging/registration-token-not-registered' ||
            code === 'messaging/invalid-registration-token'
          ) {
            const uid = owner.get(chunk[idx]);
            if (!dead.has(uid)) dead.set(uid, []);
            dead.get(uid).push(chunk[idx]);
          }
        });
        for (const [uid, list] of dead) {
          await db
            .collection('users')
            .doc(uid)
            .update({ fcmTokens: admin.firestore.FieldValue.arrayRemove(...list) })
            .catch(() => {});
        }
      }
      if (page.size < 300) break;
    }
    console.log('Global push sent:', event.params.notificationId, sent);
    return null;
  }
);
