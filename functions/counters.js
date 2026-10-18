// functions/counters.js
//
// Server-side counters for BuyNova videos + safe public profiles.
//
// Add to functions/index.js:
//   Object.assign(exports, require('./counters'));
//
// Needs firebase-functions v2 and firebase-admin:
//   npm i firebase-functions firebase-admin
//
// REGION: Firestore triggers must run in a region that matches your
// Firestore database location. Your callables use asia-northeast3.
// If your database is NOT in Seoul, change REGION below to the
// database's region (Firebase console > Firestore > Settings).

const {
  onDocumentCreated,
  onDocumentDeleted,
  onDocumentWritten,
} = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

const REGION = 'asia-northeast3';
const ADMIN_EMAIL = 'miamdarif010@gmail.com';

// ---------------------------------------------------------
// helper: change video counter + owner total
// ---------------------------------------------------------
async function bump(videoId, videoField, userField, delta) {
  const videoRef = db.collection('sellerVideos').doc(videoId);
  const snap = await videoRef.get();
  if (!snap.exists) return;

  const data = snap.data() || {};
  const ownerId = data.userId || data.sellerId || '';

  const batch = db.batch();
  batch.update(videoRef, { [videoField]: FieldValue.increment(delta) });
  if (ownerId) {
    batch.set(
      db.collection('users').doc(ownerId),
      { [userField]: FieldValue.increment(delta) },
      { merge: true },
    );
  }
  await batch.commit();
}

// ---------------------------------------------------------
// LIKES
// ---------------------------------------------------------
exports.onLikeCreated = onDocumentCreated(
  { document: 'sellerVideos/{videoId}/likes/{uid}', region: REGION },
  (event) => bump(event.params.videoId, 'likeCount', 'totalLikes', 1),
);

exports.onLikeDeleted = onDocumentDeleted(
  { document: 'sellerVideos/{videoId}/likes/{uid}', region: REGION },
  (event) => bump(event.params.videoId, 'likeCount', 'totalLikes', -1),
);

// ---------------------------------------------------------
// VIEWS (one doc per user = one view per user)
// ---------------------------------------------------------
exports.onViewCreated = onDocumentCreated(
  { document: 'sellerVideos/{videoId}/views/{uid}', region: REGION },
  (event) => bump(event.params.videoId, 'viewCount', 'totalViews', 1),
);

// ---------------------------------------------------------
// COMMENTS
// ---------------------------------------------------------
exports.onCommentCreated = onDocumentCreated(
  { document: 'sellerVideos/{videoId}/comments/{commentId}', region: REGION },
  (event) => bump(event.params.videoId, 'commentCount', 'totalComments', 1),
);

exports.onCommentDeleted = onDocumentDeleted(
  { document: 'sellerVideos/{videoId}/comments/{commentId}', region: REGION },
  (event) => bump(event.params.videoId, 'commentCount', 'totalComments', -1),
);

// ---------------------------------------------------------
// SHARES (one doc per user per video)
// ---------------------------------------------------------
exports.onShareCreated = onDocumentCreated(
  { document: 'sellerVideos/{videoId}/shares/{uid}', region: REGION },
  (event) => bump(event.params.videoId, 'shareCount', 'totalShares', 1),
);

// ---------------------------------------------------------
// PUBLIC PROFILE MIRROR
// Copies only the safe fields of users/{uid} into publicProfiles/{uid}.
// ---------------------------------------------------------
function toPublic(d) {
  return {
    name: d.name || '',
    profileImageUrl: d.profileImageUrl || '',
    sellerStatus: d.sellerStatus || 'none',
    entrepreneurStatus: d.entrepreneurStatus || 'none',
    totalLikes: d.totalLikes || 0,
    totalViews: d.totalViews || 0,
    totalShares: d.totalShares || 0,
    totalComments: d.totalComments || 0,
  };
}

exports.mirrorPublicProfile = onDocumentWritten(
  { document: 'users/{uid}', region: REGION },
  async (event) => {
    const ref = db.collection('publicProfiles').doc(event.params.uid);
    const after = event.data && event.data.after;

    if (!after || !after.exists) {
      await ref.delete().catch(() => {});
      return;
    }
    const next = toPublic(after.data() || {});
    // Skip the write when no public field changed (wallet updates etc.).
    if (event.data.before && event.data.before.exists) {
      const prev = toPublic(event.data.before.data() || {});
      if (JSON.stringify(prev) === JSON.stringify(next)) return;
    }
    await ref.set(next, { merge: true });
  },
);

// ---------------------------------------------------------
// ONE-TIME BACKFILL (admin only): creates publicProfiles for
// users that already exist. Run once from the app / console.
// ---------------------------------------------------------
exports.backfillPublicProfiles = onCall({ region: REGION }, async (request) => {
  const token = request.auth && request.auth.token;
  if (!token || token.email !== ADMIN_EMAIL || token.email_verified !== true) {
    throw new HttpsError('permission-denied', 'Admin only.');
  }

  const users = await db.collection('users').get();
  let writer = db.batch();
  let pending = 0;
  let total = 0;

  for (const doc of users.docs) {
    writer.set(db.collection('publicProfiles').doc(doc.id), toPublic(doc.data()), {
      merge: true,
    });
    pending++;
    total++;
    if (pending === 400) {
      await writer.commit();
      writer = db.batch();
      pending = 0;
    }
  }
  if (pending > 0) await writer.commit();

  return { success: true, count: total };
});
