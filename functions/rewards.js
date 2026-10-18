// functions/rewards.js
//
// Watch & Earn: turns a pending watchRewardClaims doc into points.
// The client can only CREATE a claim (see firestore.rules). This
// trigger is the only thing that changes pointsBalance.
//
// Add to functions/index.js:
//   Object.assign(exports, require("./rewards"));

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

const REGION = "asia-northeast3";
const POINTS_PER_VIDEO = 5;
const MIN_WATCH_SECONDS = 10;
const DAILY_LIMIT = 20;
const DAY_OFFSET_MS = 6 * 60 * 60 * 1000; // Bangladesh time (UTC+6)

// Same format the app uses: YYYY-MM-DD in Bangladesh time.
function dayKey() {
  return new Date(Date.now() + DAY_OFFSET_MS).toISOString().slice(0, 10);
}

exports.onWatchRewardClaimCreated = onDocumentCreated(
  { document: "watchRewardClaims/{claimId}", region: REGION },
  async (event) => {
    const snap = event.data;
    if (!snap) return null;

    const claimRef = snap.ref;
    const claimId = event.params.claimId;
    const today = dayKey();

    try {
      await db.runTransaction(async (tx) => {
        const claimSnap = await tx.get(claimRef);
        if (!claimSnap.exists) return;

        const claim = claimSnap.data() || {};

        // Already handled (function retry) -> do nothing.
        if (claim.status !== "pending") return;

        const reject = (reason) => {
          tx.update(claimRef, {
            status: "rejected",
            rejectReason: reason,
            processedAt: FieldValue.serverTimestamp(),
          });
        };

        const uid = typeof claim.userId === "string" ? claim.userId : "";
        const videoId = typeof claim.videoId === "string" ? claim.videoId : "";

        if (!uid || !videoId || claimId !== `${uid}_${videoId}`) {
          return reject("invalid_claim");
        }

        if (!(Number(claim.watchSeconds) >= MIN_WATCH_SECONDS)) {
          return reject("not_watched_enough");
        }

        const userRef = db.collection("users").doc(uid);
        const videoRef = db.collection("sellerVideos").doc(videoId);
        const dailyRef = userRef.collection("rewardDaily").doc(today);
        const pointsRef = userRef.collection("pointsTransactions").doc(claimId);

        const [userSnap, videoSnap, dailySnap, pointsSnap] = await Promise.all([
          tx.get(userRef),
          tx.get(videoRef),
          tx.get(dailyRef),
          tx.get(pointsRef),
        ]);

        if (!userSnap.exists) return reject("user_not_found");
        if (!videoSnap.exists) return reject("video_not_found");
        if (pointsSnap.exists) return reject("already_rewarded");

        const video = videoSnap.data() || {};
        const ownerId = video.userId || video.sellerId || "";

        if (video.rewardEligible === false) return reject("not_eligible");
        if (ownerId === uid) return reject("own_video");

        const watchedToday = dailySnap.exists
          ? Number((dailySnap.data() || {}).count) || 0
          : 0;

        if (watchedToday >= DAILY_LIMIT) return reject("daily_limit");

        tx.set(
          userRef,
          {
            pointsBalance: FieldValue.increment(POINTS_PER_VIDEO),
            lifetimePoints: FieldValue.increment(POINTS_PER_VIDEO),
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        tx.set(
          dailyRef,
          {
            count: watchedToday + 1,
            day: today,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        tx.set(pointsRef, {
          userId: uid,
          type: "Watched video",
          source: "watch_video",
          videoId: videoId,
          points: POINTS_PER_VIDEO,
          day: today,
          createdAt: FieldValue.serverTimestamp(),
        });

        tx.update(claimRef, {
          status: "approved",
          rewardPoints: POINTS_PER_VIDEO,
          processedAt: FieldValue.serverTimestamp(),
        });
      });
    } catch (error) {
      console.error("Reward claim failed:", claimId, error);
    }

    return null;
  }
);

// ============================================================
// CONVERT POINTS -> BUYNOVA WALLET (BDT)
// ============================================================
//
// Rate is controlled by Admin in platformSettings/monetization:
//   pointsPerTaka              default 100   (100 points = 1 Taka)
//   minPointsToConvert         default 500
//   pointsConversionEnabled    default true  (set false to pause)
//
// Client sends { points }. Server converts only whole Taka:
// taka = floor(points / pointsPerTaka); points used = taka * pointsPerTaka.

function roundMoney(value) {
  return Math.round((Number(value) || 0) * 100) / 100;
}

exports.convertPointsToWallet = onCall({ region: REGION }, async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "You must be logged in.");
  }

  const uid = request.auth.uid;
  const requested = Number((request.data || {}).points);

  if (!Number.isInteger(requested) || requested <= 0) {
    throw new HttpsError("invalid-argument", "Enter a valid number of points.");
  }

  const userRef = db.collection("users").doc(uid);
  const configRef = db.collection("platformSettings").doc("monetization");

  const result = await db.runTransaction(async (tx) => {
    const [userSnap, configSnap] = await Promise.all([
      tx.get(userRef),
      tx.get(configRef),
    ]);

    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User account not found.");
    }

    const config = configSnap.exists ? configSnap.data() || {} : {};

    if (config.pointsConversionEnabled === false) {
      throw new HttpsError(
        "failed-precondition",
        "Points conversion is currently paused."
      );
    }

    const pointsPerTaka = Math.max(
      1,
      Math.floor(Number(config.pointsPerTaka) || 100)
    );
    const minPoints = Math.max(
      pointsPerTaka,
      Math.floor(Number(config.minPointsToConvert) || 500)
    );

    if (requested < minPoints) {
      throw new HttpsError(
        "failed-precondition",
        `Minimum ${minPoints} points required to convert.`
      );
    }

    const user = userSnap.data() || {};
    const pointsBalance = Math.floor(Number(user.pointsBalance) || 0);

    if (requested > pointsBalance) {
      throw new HttpsError("failed-precondition", "Not enough points.");
    }

    const taka = Math.floor(requested / pointsPerTaka);

    if (taka < 1) {
      throw new HttpsError("failed-precondition", "Not enough points for ৳1.");
    }

    const pointsUsed = taka * pointsPerTaka;

    const balanceBefore = Number(user.cashBalance ?? user.walletBalance ?? 0);

    if (!Number.isFinite(balanceBefore)) {
      throw new HttpsError("failed-precondition", "Invalid wallet balance.");
    }

    const balanceAfter = roundMoney(balanceBefore + taka);

    const walletTxRef = userRef.collection("walletTransactions").doc();
    const pointsTxRef = userRef.collection("pointsTransactions").doc();

    tx.update(userRef, {
      pointsBalance: pointsBalance - pointsUsed,
      cashBalance: balanceAfter,
      walletBalance: balanceAfter,
      updatedAt: FieldValue.serverTimestamp(),
    });

    tx.set(walletTxRef, {
      type: "credit",
      source: "points_conversion",
      status: "approved",
      amount: taka,
      currency: "BDT",
      currencySymbol: "৳",
      userId: uid,
      pointsUsed: pointsUsed,
      pointsPerTaka: pointsPerTaka,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      description: `Converted ${pointsUsed} reward points`,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    tx.set(pointsTxRef, {
      userId: uid,
      type: "Converted to wallet",
      source: "points_conversion",
      points: -pointsUsed,
      amount: taka,
      walletTransactionId: walletTxRef.id,
      createdAt: FieldValue.serverTimestamp(),
    });

    tx.set(userRef.collection("notifications").doc(), {
      title: "Points Converted",
      message: `${pointsUsed} points were converted to ৳${taka} in your BuyNova Wallet.`,
      type: "points_conversion",
      amount: taka,
      currency: "BDT",
      read: false,
      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      pointsUsed,
      taka,
      pointsLeft: pointsBalance - pointsUsed,
      newWalletBalance: balanceAfter,
    };
  });

  return { success: true, ...result };
});
