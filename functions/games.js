// functions/games.js
//
// Play & Earn: BIKE RIDER game.
// The app only plays the game. The SERVER decides how many points the
// user gets, so nobody can type their own reward:
//   1. startBikeGame  -> uses one play of the day, saves the start time
//   2. finishBikeGame -> checks the score against the real time played,
//                        then adds points to users/{uid}.pointsBalance
//
// Points land in the same place as Watch & Earn, so "Convert points to
// wallet" works for them too.
//
// Admin can change everything in platformSettings/monetization:
//   gameEnabled          default true
//   gamePlaysPerDay      default 5      (1 - 50)
//   gameScorePerPoint    default 100    score needed for 1 point
//   gameMaxPointsPerRun  default 10     most points from one run
//   gameMaxPointsPerDay  default 30     most game points per day
//
// Also: DAILY LUCKY SPIN (a wheel that opens when the Home page opens)
//   spinEnabled          default true
//   spinPlaysPerDay      default 1      (1 - 20)
//   spinSegments         default [1,2,3,5,8,10,15,20]   points on the wheel
//   spinWeights          default [30,25,20,10,7,4,3,1]  chance of each piece
//
// Add to functions/index.js (if not already there):
//   Object.assign(exports, require("./games"));

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const crypto = require("crypto");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

const REGION = "asia-northeast3";
const DAY_OFFSET_MS = 6 * 60 * 60 * 1000; // Bangladesh time (UTC+6)

const MIN_RUN_SECONDS = 5;
const MAX_RUN_SECONDS = 60 * 60;
// The games give about 10-45 score per second. Anything far above this
// cannot be a real run.
const MAX_SCORE_PER_SECOND = 60;

function dayKey() {
  return new Date(Date.now() + DAY_OFFSET_MS).toISOString().slice(0, 10);
}

function intOr(value, min, max, fallback) {
  const n = Math.floor(Number(value));

  if (!Number.isFinite(n)) return fallback;

  return Math.min(max, Math.max(min, n));
}

function requireUid(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "You must be logged in.");
  }

  return request.auth.uid;
}

function readRules(config) {
  return {
    enabled: config.gameEnabled !== false,
    playsPerDay: intOr(config.gamePlaysPerDay, 1, 50, 5),
    scorePerPoint: intOr(config.gameScorePerPoint, 1, 100000, 100),
    maxPointsPerRun: intOr(config.gameMaxPointsPerRun, 1, 1000, 10),
    maxPointsPerDay: intOr(config.gameMaxPointsPerDay, 1, 100000, 30),
  };
}

// ------------------------------------------------------------
// Status: rules + how much the user has left today
// ------------------------------------------------------------
exports.getGameStatus = onCall({ region: REGION }, async (request) => {
  const uid = requireUid(request);

  const configRef = db.collection("platformSettings").doc("monetization");
  const dailyRef = db
    .collection("users")
    .doc(uid)
    .collection("rewardDaily")
    .doc(dayKey());

  const [configSnap, dailySnap] = await Promise.all([
    configRef.get(),
    dailyRef.get(),
  ]);

  const rules = readRules(configSnap.exists ? configSnap.data() || {} : {});
  const daily = dailySnap.exists ? dailySnap.data() || {} : {};

  const played = Number(daily.gamePlays) || 0;

  return {
    enabled: rules.enabled,
    playsPerDay: rules.playsPerDay,
    playsLeft: rules.enabled ? Math.max(0, rules.playsPerDay - played) : 0,
    scorePerPoint: rules.scorePerPoint,
    maxPointsPerRun: rules.maxPointsPerRun,
    maxPointsPerDay: rules.maxPointsPerDay,
    pointsToday: Number(daily.gamePoints) || 0,
  };
});

// ------------------------------------------------------------
// Start one run (uses one play)
// ------------------------------------------------------------
exports.startBikeGame = onCall({ region: REGION }, async (request) => {
  const uid = requireUid(request);
  const today = dayKey();

  const userRef = db.collection("users").doc(uid);
  const dailyRef = userRef.collection("rewardDaily").doc(today);
  const configRef = db.collection("platformSettings").doc("monetization");
  const sessionRef = userRef.collection("gameSessions").doc();

  const result = await db.runTransaction(async (tx) => {
    const [userSnap, dailySnap, configSnap] = await Promise.all([
      tx.get(userRef),
      tx.get(dailyRef),
      tx.get(configRef),
    ]);

    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User account not found.");
    }

    const rules = readRules(configSnap.exists ? configSnap.data() || {} : {});

    if (!rules.enabled) {
      throw new HttpsError("failed-precondition", "The game is paused.");
    }

    const played = Number((dailySnap.data() || {}).gamePlays) || 0;

    if (played >= rules.playsPerDay) {
      throw new HttpsError(
        "resource-exhausted",
        "No plays left today. Come back tomorrow!"
      );
    }

    tx.set(
      dailyRef,
      {
        gamePlays: played + 1,
        day: today,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    tx.set(sessionRef, {
      userId: uid,
      status: "started",
      day: today,
      startedAt: FieldValue.serverTimestamp(),
    });

    return {
      sessionId: sessionRef.id,
      playsLeft: Math.max(0, rules.playsPerDay - (played + 1)),
    };
  });

  return { success: true, ...result };
});

// ------------------------------------------------------------
// Finish the run: check the score, give points
// ------------------------------------------------------------
exports.finishBikeGame = onCall({ region: REGION }, async (request) => {
  const uid = requireUid(request);
  const data = request.data || {};

  const sessionId =
    typeof data.sessionId === "string" ? data.sessionId.trim() : "";
  const score = Number(data.score);

  if (!sessionId || sessionId.includes("/")) {
    throw new HttpsError("invalid-argument", "Invalid game session.");
  }

  if (!Number.isInteger(score) || score < 0 || score > 1000000) {
    throw new HttpsError("invalid-argument", "Invalid score.");
  }

  const today = dayKey();

  const userRef = db.collection("users").doc(uid);
  const sessionRef = userRef.collection("gameSessions").doc(sessionId);
  const dailyRef = userRef.collection("rewardDaily").doc(today);
  const configRef = db.collection("platformSettings").doc("monetization");

  const result = await db.runTransaction(async (tx) => {
    const [sessionSnap, dailySnap, configSnap] = await Promise.all([
      tx.get(sessionRef),
      tx.get(dailyRef),
      tx.get(configRef),
    ]);

    if (!sessionSnap.exists) {
      throw new HttpsError("not-found", "Game session not found.");
    }

    const session = sessionSnap.data() || {};

    if (session.status !== "started") {
      throw new HttpsError(
        "failed-precondition",
        "This game was already finished."
      );
    }

    const rules = readRules(configSnap.exists ? configSnap.data() || {} : {});
    const daily = dailySnap.exists ? dailySnap.data() || {} : {};

    const played = Number(daily.gamePlays) || 0;
    const pointsToday = Number(daily.gamePoints) || 0;

    const startedMs =
      session.startedAt && typeof session.startedAt.toMillis === "function"
        ? session.startedAt.toMillis()
        : 0;

    const elapsed = startedMs ? (Date.now() - startedMs) / 1000 : 0;

    let points = 0;
    let note = "ok";

    if (!startedMs || elapsed > MAX_RUN_SECONDS) {
      note = "expired";
    } else if (elapsed < MIN_RUN_SECONDS) {
      note = "too_fast";
    } else if (score > elapsed * MAX_SCORE_PER_SECOND + 30) {
      note = "rejected";
    } else {
      points = Math.min(
        Math.floor(score / rules.scorePerPoint),
        rules.maxPointsPerRun
      );

      const remaining = Math.max(0, rules.maxPointsPerDay - pointsToday);

      if (points > remaining) {
        points = remaining;
        note = "daily_cap";
      }
    }

    tx.update(sessionRef, {
      status: note === "ok" || note === "daily_cap" ? "finished" : note,
      score: score,
      points: points,
      note: note,
      elapsedSeconds: Math.round(elapsed),
      finishedAt: FieldValue.serverTimestamp(),
    });

    if (points > 0) {
      tx.set(
        dailyRef,
        {
          gamePoints: pointsToday + points,
          day: today,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      tx.set(
        userRef,
        {
          pointsBalance: FieldValue.increment(points),
          lifetimePoints: FieldValue.increment(points),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      tx.set(userRef.collection("pointsTransactions").doc(), {
        userId: uid,
        type: "Bike Rider game",
        source: "game_bike",
        points: points,
        score: score,
        day: today,
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    return {
      points,
      note,
      playsLeft: Math.max(0, rules.playsPerDay - played),
      pointsToday: pointsToday + points,
      maxPointsPerDay: rules.maxPointsPerDay,
    };
  });

  return { success: true, ...result };
});


// ============================================================
// DAILY LUCKY SPIN
// ============================================================
//
// The server picks the winning piece, so the app cannot cheat.
// Spins are counted in users/{uid}/rewardDaily/{day}.spinPlays
// (separate from the bike game).

const DEFAULT_SEGMENTS = [1, 2, 3, 5, 8, 10, 15, 20];
const DEFAULT_WEIGHTS = [30, 25, 20, 10, 7, 4, 3, 1];

function readSpinRules(config) {
  let segments = Array.isArray(config.spinSegments)
    ? config.spinSegments.map((v) => Math.floor(Number(v)))
    : [];

  let weights = Array.isArray(config.spinWeights)
    ? config.spinWeights.map((v) => Number(v))
    : [];

  const ok =
    segments.length >= 2 &&
    segments.length <= 12 &&
    segments.length === weights.length &&
    segments.every((v) => Number.isFinite(v) && v >= 0 && v <= 1000) &&
    weights.every((v) => Number.isFinite(v) && v >= 0) &&
    weights.some((v) => v > 0);

  if (!ok) {
    segments = DEFAULT_SEGMENTS;
    weights = DEFAULT_WEIGHTS;
  }

  return {
    enabled: config.spinEnabled !== false,
    playsPerDay: intOr(config.spinPlaysPerDay, 1, 20, 1),
    segments,
    weights,
  };
}

function pickIndex(weights) {
  const total = weights.reduce((a, b) => a + b, 0);
  const r = (crypto.randomInt(1000000) / 1000000) * total;

  let acc = 0;

  for (let i = 0; i < weights.length; i++) {
    acc += weights[i];
    if (r < acc) return i;
  }

  return weights.length - 1;
}

exports.getSpinStatus = onCall({ region: REGION }, async (request) => {
  const uid = requireUid(request);

  const configRef = db.collection("platformSettings").doc("monetization");
  const dailyRef = db
    .collection("users")
    .doc(uid)
    .collection("rewardDaily")
    .doc(dayKey());

  const [configSnap, dailySnap] = await Promise.all([
    configRef.get(),
    dailyRef.get(),
  ]);

  const rules = readSpinRules(configSnap.exists ? configSnap.data() || {} : {});
  const played = Number((dailySnap.data() || {}).spinPlays) || 0;

  return {
    enabled: rules.enabled,
    segments: rules.segments,
    playsPerDay: rules.playsPerDay,
    playsLeft: rules.enabled ? Math.max(0, rules.playsPerDay - played) : 0,
  };
});

exports.playSpinGame = onCall({ region: REGION }, async (request) => {
  const uid = requireUid(request);
  const today = dayKey();

  const userRef = db.collection("users").doc(uid);
  const dailyRef = userRef.collection("rewardDaily").doc(today);
  const configRef = db.collection("platformSettings").doc("monetization");

  const result = await db.runTransaction(async (tx) => {
    const [userSnap, dailySnap, configSnap] = await Promise.all([
      tx.get(userRef),
      tx.get(dailyRef),
      tx.get(configRef),
    ]);

    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User account not found.");
    }

    const rules = readSpinRules(
      configSnap.exists ? configSnap.data() || {} : {}
    );

    if (!rules.enabled) {
      throw new HttpsError("failed-precondition", "The spin is paused.");
    }

    const played = Number((dailySnap.data() || {}).spinPlays) || 0;

    if (played >= rules.playsPerDay) {
      throw new HttpsError(
        "resource-exhausted",
        "No spins left today. Come back tomorrow!"
      );
    }

    const index = pickIndex(rules.weights);
    const points = rules.segments[index];

    tx.set(
      dailyRef,
      {
        spinPlays: played + 1,
        day: today,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    if (points > 0) {
      tx.set(
        userRef,
        {
          pointsBalance: FieldValue.increment(points),
          lifetimePoints: FieldValue.increment(points),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      tx.set(userRef.collection("pointsTransactions").doc(), {
        userId: uid,
        type: "Lucky Spin",
        source: "game_spin",
        points: points,
        day: today,
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    return {
      index,
      points,
      playsLeft: Math.max(0, rules.playsPerDay - (played + 1)),
    };
  });

  return { success: true, ...result };
});
