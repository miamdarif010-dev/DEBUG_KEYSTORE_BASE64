// functions/rewards.js
//
// Watch & Earn + Invite & Earn + admin tools.
//
// ALL numbers can be changed by the Admin in Firestore document
//   platformSettings/monetization   (or with the Reward Settings page)
//
//   pointsPerVideo           default 5     points for one rewarded video (0 = rewards paused)
//   dailyVideoLimit          default 20    rewarded videos per user per day
//   streakBonusEnabled       default true
//   streakBonusDays          default 7     bonus every N days in a row (2-60)
//   streakBonusPoints        default 50
//   referralEnabled          default true
//   referralBonusPoints      default 200   points for the INVITER
//   referralWelcomePoints    default 50    points for the NEW user
//   referralMaxPerUser       default 50    max rewarded invites per user (0 = no limit)
//   pointsPerTaka            default 100   (100 points = 1 Taka)
//   minPointsToConvert       default 500
//   pointsConversionEnabled  default true
//   maxConvertTakaPerDay     default 0     (0 = no daily limit)
//
// The client can only CREATE a claim (see firestore.rules). The trigger
// below is the only thing that changes pointsBalance.
//
// Add to functions/index.js:
//   Object.assign(exports, require("./rewards"));

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const crypto = require("crypto");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

const REGION = "asia-northeast3";
const ADMIN_EMAIL = "miamdarif010@gmail.com";

const MIN_WATCH_SECONDS = 10;
const DAY_MS = 24 * 60 * 60 * 1000;
const DAY_OFFSET_MS = 6 * 60 * 60 * 1000; // Bangladesh time (UTC+6)

// An invite code can only be entered within this many days after joining.
const REFERRAL_CODE_WINDOW_DAYS = 7;

// YYYY-MM-DD in Bangladesh time. daysAgo = 1 gives yesterday.
function dayKey(daysAgo = 0) {
  return new Date(Date.now() + DAY_OFFSET_MS - daysAgo * DAY_MS)
    .toISOString()
    .slice(0, 10);
}

function intOr(value, min, max, fallback) {
  const n = Math.floor(Number(value));

  if (!Number.isFinite(n)) return fallback;

  return Math.min(max, Math.max(min, n));
}

function roundMoney(value) {
  return Math.round((Number(value) || 0) * 100) / 100;
}

function requireUid(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "You must be logged in.");
  }

  return request.auth.uid;
}

function requireAdminCall(request) {
  const uid = requireUid(request);
  const token = request.auth.token || {};
  const email = String(token.email || "").toLowerCase();

  if (email !== ADMIN_EMAIL || token.email_verified !== true) {
    throw new HttpsError("permission-denied", "Admin access required.");
  }

  return { uid, email };
}

// ============================================================
// WATCH CLAIM -> POINTS (+ STREAK BONUS + REFERRAL REWARD)
// ============================================================

exports.onWatchRewardClaimCreated = onDocumentCreated(
  { document: "watchRewardClaims/{claimId}", region: REGION },
  async (event) => {
    const snap = event.data;
    if (!snap) return null;

    const claimRef = snap.ref;
    const claimId = event.params.claimId;
    const today = dayKey(0);
    const yesterday = dayKey(1);

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
        const yesterdayRef = userRef.collection("rewardDaily").doc(yesterday);
        const pointsRef = userRef.collection("pointsTransactions").doc(claimId);
        const bonusRef = userRef
          .collection("pointsTransactions")
          .doc(`streak_${today}`);
        const configRef = db.collection("platformSettings").doc("monetization");

        // All reads first (Firestore transactions need reads before writes).
        const [
          userSnap,
          videoSnap,
          dailySnap,
          pointsSnap,
          yesterdaySnap,
          bonusSnap,
          configSnap,
        ] = await Promise.all([
          tx.get(userRef),
          tx.get(videoRef),
          tx.get(dailyRef),
          tx.get(pointsRef),
          tx.get(yesterdayRef),
          tx.get(bonusRef),
          tx.get(configRef),
        ]);

        if (!userSnap.exists) return reject("user_not_found");
        if (!videoSnap.exists) return reject("video_not_found");
        if (pointsSnap.exists) return reject("already_rewarded");

        const config = configSnap.exists ? configSnap.data() || {} : {};

        const pointsPerVideo = intOr(config.pointsPerVideo, 0, 1000, 5);
        const dailyLimit = intOr(config.dailyVideoLimit, 1, 1000, 20);

        if (pointsPerVideo <= 0) return reject("rewards_paused");

        const video = videoSnap.data() || {};
        const ownerId = video.userId || video.sellerId || "";

        if (video.rewardEligible === false) return reject("not_eligible");
        if (ownerId === uid) return reject("own_video");

        const daily = dailySnap.exists ? dailySnap.data() || {} : {};
        const watchedToday = Number(daily.count) || 0;

        if (watchedToday >= dailyLimit) return reject("daily_limit");

        // ---------- streak ----------
        const streakEnabled = config.streakBonusEnabled !== false;
        const streakDays = intOr(config.streakBonusDays, 2, 60, 7);
        const streakPoints = intOr(config.streakBonusPoints, 0, 100000, 50);

        let streak = Number(daily.streak) || 0;
        let bonus = 0;

        // The first rewarded video of the day moves the streak forward.
        if (watchedToday === 0) {
          const y = yesterdaySnap.exists ? yesterdaySnap.data() || {} : {};

          streak = Number(y.count) > 0 ? (Number(y.streak) || 1) + 1 : 1;

          if (
            streakEnabled &&
            streakPoints > 0 &&
            streak % streakDays === 0 &&
            !bonusSnap.exists
          ) {
            bonus = streakPoints;
          }
        } else if (streak < 1) {
          streak = 1;
        }

        // ---------- referral (first rewarded video of an invited user) ----------
        const user = userSnap.data() || {};
        const referredBy =
          typeof user.referredBy === "string" ? user.referredBy : "";
        const referralEnabled = config.referralEnabled !== false;
        const referralPending =
          referralEnabled && referredBy && user.referralStatus === "pending";

        const inviterRef = referredBy ? db.collection("users").doc(referredBy) : null;
        const referralDocRef = db.collection("referrals").doc(uid);
        const inviterTxRef = inviterRef
          ? inviterRef.collection("pointsTransactions").doc(`referral_${uid}`)
          : null;

        let inviterBonus = 0;
        let welcomeBonus = 0;
        let referralResult = "";

        if (referralPending && inviterRef) {
          const [inviterSnap, referralSnap, inviterTxSnap] = await Promise.all([
            tx.get(inviterRef),
            tx.get(referralDocRef),
            tx.get(inviterTxRef),
          ]);

          const valid =
            inviterSnap.exists && referralSnap.exists && !inviterTxSnap.exists;

          if (!valid) {
            referralResult = "invalid";
          } else {
            const maxReferrals = intOr(config.referralMaxPerUser, 0, 100000, 50);
            const inviterCount =
              Number((inviterSnap.data() || {}).referralCount) || 0;

            if (maxReferrals > 0 && inviterCount >= maxReferrals) {
              referralResult = "capped";
            } else {
              referralResult = "rewarded";
              inviterBonus = intOr(config.referralBonusPoints, 0, 1000000, 200);
              welcomeBonus = intOr(config.referralWelcomePoints, 0, 1000000, 50);
            }
          }
        }

        const totalPoints = pointsPerVideo + bonus + welcomeBonus;

        // ---------- writes ----------
        const userUpdate = {
          pointsBalance: FieldValue.increment(totalPoints),
          lifetimePoints: FieldValue.increment(totalPoints),
          updatedAt: FieldValue.serverTimestamp(),
        };

        if (referralResult) {
          userUpdate.referralStatus = referralResult;
        }

        tx.set(userRef, userUpdate, { merge: true });

        tx.set(
          dailyRef,
          {
            count: watchedToday + 1,
            streak: streak,
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
          points: pointsPerVideo,
          day: today,
          createdAt: FieldValue.serverTimestamp(),
        });

        if (bonus > 0) {
          tx.set(bonusRef, {
            userId: uid,
            type: `${streak}-day streak bonus`,
            source: "streak_bonus",
            points: bonus,
            streak: streak,
            day: today,
            createdAt: FieldValue.serverTimestamp(),
          });

          tx.set(userRef.collection("notifications").doc(), {
            title: "Streak Bonus!",
            message: `You watched videos ${streak} days in a row and earned ${bonus} bonus points.`,
            type: "streak_bonus",
            amount: bonus,
            read: false,
            isRead: false,
            createdAt: FieldValue.serverTimestamp(),
          });
        }

        if (referralResult) {
          tx.set(
            referralDocRef,
            {
              status: referralResult,
              inviterPoints: inviterBonus,
              welcomePoints: welcomeBonus,
              rewardedAt: FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        }

        if (welcomeBonus > 0) {
          tx.set(userRef.collection("pointsTransactions").doc("referral_welcome"), {
            userId: uid,
            type: "Invite welcome bonus",
            source: "referral_welcome",
            points: welcomeBonus,
            createdAt: FieldValue.serverTimestamp(),
          });
        }

        if (inviterBonus > 0 && inviterRef) {
          tx.set(
            inviterRef,
            {
              pointsBalance: FieldValue.increment(inviterBonus),
              lifetimePoints: FieldValue.increment(inviterBonus),
              referralCount: FieldValue.increment(1),
              referralEarnings: FieldValue.increment(inviterBonus),
              updatedAt: FieldValue.serverTimestamp(),
            },
            { merge: true }
          );

          tx.set(inviterTxRef, {
            userId: referredBy,
            type: "Invite bonus",
            source: "referral",
            points: inviterBonus,
            invitedUserId: uid,
            createdAt: FieldValue.serverTimestamp(),
          });

          tx.set(inviterRef.collection("notifications").doc(), {
            title: "Invite Bonus!",
            message: `Your friend joined and earned their first reward. You got ${inviterBonus} points.`,
            type: "referral",
            amount: inviterBonus,
            read: false,
            isRead: false,
            createdAt: FieldValue.serverTimestamp(),
          });
        }

        tx.update(claimRef, {
          status: "approved",
          rewardPoints: pointsPerVideo,
          bonusPoints: bonus,
          welcomePoints: welcomeBonus,
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
// INVITE & EARN
// ============================================================
//
// 1. Every user has a personal invite code (getMyReferralCode).
// 2. A NEW user (joined in the last 7 days, no points yet) enters the code
//    once (applyReferralCode). The link is saved as "pending".
// 3. When the invited user gets their first approved video reward, the
//    inviter receives referralBonusPoints and the new user receives
//    referralWelcomePoints (see the claim trigger above).
//
// Rewarding only after real activity makes fake sign-ups pointless.

const CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no 0/O/1/I

function randomCode(length = 7) {
  let code = "";

  for (let i = 0; i < length; i++) {
    code += CODE_CHARS[crypto.randomInt(CODE_CHARS.length)];
  }

  return code;
}

exports.getMyReferralCode = onCall({ region: REGION }, async (request) => {
  const uid = requireUid(request);

  const userRef = db.collection("users").doc(uid);
  const userSnap = await userRef.get();

  if (!userSnap.exists) {
    throw new HttpsError("not-found", "User account not found.");
  }

  const existing = (userSnap.data() || {}).referralCode;

  if (typeof existing === "string" && existing) {
    return { success: true, code: existing };
  }

  for (let attempt = 0; attempt < 8; attempt++) {
    const code = randomCode(7);
    const codeRef = db.collection("referralCodes").doc(code);

    const result = await db.runTransaction(async (tx) => {
      const [codeSnap, freshUser] = await Promise.all([
        tx.get(codeRef),
        tx.get(userRef),
      ]);

      if (codeSnap.exists) return null;

      const already = (freshUser.data() || {}).referralCode;

      if (typeof already === "string" && already) return already;

      tx.set(codeRef, { uid, createdAt: FieldValue.serverTimestamp() });
      tx.set(userRef, { referralCode: code }, { merge: true });

      return code;
    });

    if (result) return { success: true, code: result };
  }

  throw new HttpsError("internal", "Could not create a code. Try again.");
});

exports.applyReferralCode = onCall({ region: REGION }, async (request) => {
  const uid = requireUid(request);

  const code = String((request.data || {}).code || "")
    .trim()
    .toUpperCase();

  if (!/^[A-Z0-9]{6,10}$/.test(code)) {
    throw new HttpsError("invalid-argument", "Enter a valid invite code.");
  }

  // Only new accounts can use an invite code.
  let createdAt = 0;

  try {
    const authUser = await admin.auth().getUser(uid);
    createdAt = Date.parse(authUser.metadata.creationTime) || 0;
  } catch (e) {
    throw new HttpsError("internal", "Could not check your account.");
  }

  if (!createdAt || Date.now() - createdAt > REFERRAL_CODE_WINDOW_DAYS * DAY_MS) {
    throw new HttpsError(
      "failed-precondition",
      `Invite codes can only be used within ${REFERRAL_CODE_WINDOW_DAYS} days of joining.`
    );
  }

  const userRef = db.collection("users").doc(uid);
  const codeRef = db.collection("referralCodes").doc(code);
  const referralRef = db.collection("referrals").doc(uid);
  const configRef = db.collection("platformSettings").doc("monetization");

  const result = await db.runTransaction(async (tx) => {
    const [userSnap, codeSnap, referralSnap, configSnap] = await Promise.all([
      tx.get(userRef),
      tx.get(codeRef),
      tx.get(referralRef),
      tx.get(configRef),
    ]);

    const config = configSnap.exists ? configSnap.data() || {} : {};

    if (config.referralEnabled === false) {
      throw new HttpsError("failed-precondition", "Invites are currently paused.");
    }

    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User account not found.");
    }

    const user = userSnap.data() || {};

    if (user.referredBy || referralSnap.exists) {
      throw new HttpsError("already-exists", "You already used an invite code.");
    }

    if ((Number(user.lifetimePoints) || 0) > 0) {
      throw new HttpsError(
        "failed-precondition",
        "Invite codes are only for new users who have not earned points yet."
      );
    }

    if (!codeSnap.exists) {
      throw new HttpsError("not-found", "This invite code was not found.");
    }

    const inviterUid = String((codeSnap.data() || {}).uid || "");

    if (!inviterUid || inviterUid === uid) {
      throw new HttpsError("failed-precondition", "You cannot use your own code.");
    }

    const inviterRef = db.collection("users").doc(inviterUid);
    const inviterSnap = await tx.get(inviterRef);

    if (!inviterSnap.exists) {
      throw new HttpsError("not-found", "This invite code is no longer valid.");
    }

    tx.set(
      userRef,
      {
        referredBy: inviterUid,
        referralStatus: "pending",
        referredAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    tx.set(referralRef, {
      inviterUid: inviterUid,
      inviteeUid: uid,
      code: code,
      status: "pending",
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      inviterName: String((inviterSnap.data() || {}).name || "your friend"),
    };
  });

  return { success: true, ...result };
});

// ============================================================
// CONVERT POINTS -> BUYNOVA WALLET (BDT)
// ============================================================
//
// Client sends { points }. Server converts only whole Taka:
// taka = floor(points / pointsPerTaka); points used = taka * pointsPerTaka.
// If maxConvertTakaPerDay > 0, a user can convert at most that many Taka
// per day (Bangladesh time), kept in
// users/{uid}/rewardDaily/{day}.convertedTaka.

exports.convertPointsToWallet = onCall({ region: REGION }, async (request) => {
  const uid = requireUid(request);
  const requested = Number((request.data || {}).points);

  if (!Number.isInteger(requested) || requested <= 0) {
    throw new HttpsError("invalid-argument", "Enter a valid number of points.");
  }

  const today = dayKey(0);

  const userRef = db.collection("users").doc(uid);
  const configRef = db.collection("platformSettings").doc("monetization");
  const dailyRef = userRef.collection("rewardDaily").doc(today);

  const result = await db.runTransaction(async (tx) => {
    const [userSnap, configSnap, dailySnap] = await Promise.all([
      tx.get(userRef),
      tx.get(configRef),
      tx.get(dailyRef),
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

    // ---------- daily conversion limit ----------
    const dailyLimit = intOr(config.maxConvertTakaPerDay, 0, 100000000, 0);
    const convertedToday =
      Number((dailySnap.exists ? dailySnap.data() || {} : {}).convertedTaka) ||
      0;

    if (dailyLimit > 0 && convertedToday + taka > dailyLimit) {
      const left = Math.max(0, dailyLimit - convertedToday);

      throw new HttpsError(
        "failed-precondition",
        left > 0
          ? `Daily conversion limit is ৳${dailyLimit}. You can convert ৳${left} more today.`
          : `Daily conversion limit of ৳${dailyLimit} reached. Try again tomorrow.`
      );
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

    tx.set(
      dailyRef,
      {
        convertedTaka: FieldValue.increment(taka),
        day: today,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

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

// ============================================================
// ADMIN: ADD / DEDUCT POINTS
// ============================================================
//
// Client sends { uid, points, action: "add" | "deduct", reason }.
// Saved in users/{uid}/pointsTransactions (source: "admin_adjust").

exports.adminAdjustPoints = onCall({ region: REGION }, async (request) => {
  const adminInfo = requireAdminCall(request);

  const data = request.data || {};
  const targetUid = typeof data.uid === "string" ? data.uid.trim() : "";
  const points = Number(data.points);
  const action = data.action;
  const reason = typeof data.reason === "string" ? data.reason.trim() : "";

  if (!targetUid || targetUid.includes("/")) {
    throw new HttpsError("invalid-argument", "User uid is required.");
  }

  if (!Number.isInteger(points) || points <= 0 || points > 10000000) {
    throw new HttpsError("invalid-argument", "Enter a valid number of points.");
  }

  if (action !== "add" && action !== "deduct") {
    throw new HttpsError("invalid-argument", "Action must be add or deduct.");
  }

  if (reason.length < 3 || reason.length > 200) {
    throw new HttpsError(
      "invalid-argument",
      "Please write a reason (3 to 200 characters)."
    );
  }

  const userRef = db.collection("users").doc(targetUid);
  const txRef = userRef.collection("pointsTransactions").doc();

  const result = await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);

    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User account not found.");
    }

    const user = userSnap.data() || {};
    const balance = Math.floor(Number(user.pointsBalance) || 0);

    const isAdd = action === "add";

    if (!isAdd && points > balance) {
      throw new HttpsError(
        "failed-precondition",
        `User has only ${balance} points. You cannot deduct ${points}.`
      );
    }

    const newBalance = isAdd ? balance + points : balance - points;

    const update = {
      pointsBalance: newBalance,
      updatedAt: FieldValue.serverTimestamp(),
    };

    // Lifetime = total ever earned. Only additions count.
    if (isAdd) {
      update.lifetimePoints = FieldValue.increment(points);
    }

    tx.set(userRef, update, { merge: true });

    tx.set(txRef, {
      userId: targetUid,
      type: isAdd ? "Added by admin" : "Deducted by admin",
      source: "admin_adjust",
      points: isAdd ? points : -points,
      reason: reason,
      adminUid: adminInfo.uid,
      adminEmail: adminInfo.email,
      createdAt: FieldValue.serverTimestamp(),
    });

    tx.set(userRef.collection("notifications").doc(), {
      title: isAdd ? "Points Added" : "Points Deducted",
      message: isAdd
        ? `${points} reward points were added to your account. Reason: ${reason}`
        : `${points} reward points were deducted from your account. Reason: ${reason}`,
      type: "admin_points",
      amount: points,
      read: false,
      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });

    return { newBalance };
  });

  return { success: true, ...result };
});
