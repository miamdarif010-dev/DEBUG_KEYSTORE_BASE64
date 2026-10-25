const admin = require("firebase-admin");
const crypto = require("crypto");
const nodemailer = require("nodemailer");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();
const Timestamp = admin.firestore.Timestamp;
const FieldValue = admin.firestore.FieldValue;

const REGION = "asia-northeast3";

// The Gmail address that sends the code, and its App Password.
// Set them once with:
//   firebase functions:secrets:set GMAIL_USER
//   firebase functions:secrets:set GMAIL_APP_PASSWORD
const GMAIL_USER = defineSecret("GMAIL_USER");
const GMAIL_APP_PASSWORD = defineSecret("GMAIL_APP_PASSWORD");

const CODE_TTL_MS = 10 * 60 * 1000; // a code works for 10 minutes
const RESEND_MS = 60 * 1000; // wait 1 minute before asking for a new code
const MAX_ATTEMPTS = 5; // wrong guesses allowed per code
const MAX_PER_HOUR = 5; // codes one account can ask for per hour

const hashCode = (uid, salt, code) =>
  crypto.createHash("sha256").update(`${uid}:${salt}:${code}`).digest("hex");

// ------------------------------------------------------------
// Sends the email. To use another service later (Resend, SendGrid),
// only this function has to change.
// ------------------------------------------------------------
async function sendMail(to, code) {
  const transporter = nodemailer.createTransport({
    service: "gmail",
    auth: { user: GMAIL_USER.value(), pass: GMAIL_APP_PASSWORD.value() },
  });

  await transporter.sendMail({
    from: `"BuyNova" <${GMAIL_USER.value()}>`,
    to,
    subject: `${code} is your BuyNova verification code`,
    text:
      `Your BuyNova verification code is ${code}\n` +
      `আপনার BuyNova যাচাইকরণ কোড: ${code}\n\n` +
      `This code works for 10 minutes. Do not share it with anyone.\n` +
      `কোডটি ১০ মিনিট পর্যন্ত চলবে। কাউকে কোডটি দেবেন না।\n\n` +
      `If you did not create a BuyNova account, ignore this email.`,
    html:
      `<div style="font-family:Arial,sans-serif;max-width:420px;margin:auto;padding:20px">` +
      `<h2 style="color:#ff5252;margin:0 0 12px">BuyNova</h2>` +
      `<p>Your verification code / আপনার যাচাইকরণ কোড:</p>` +
      `<p style="font-size:34px;font-weight:bold;letter-spacing:8px;margin:12px 0">${code}</p>` +
      `<p style="color:#555">This code works for 10 minutes. Do not share it with anyone.<br>` +
      `কোডটি ১০ মিনিট পর্যন্ত চলবে। কাউকে কোডটি দেবেন না।</p>` +
      `<p style="color:#888;font-size:12px">If you did not create a BuyNova account, ignore this email.</p>` +
      `</div>`,
  });
}

// ============================================================
// sendLoginCode
// Sends a new 6 digit code to the signed-in user's email.
// Only a hash of the code is stored (collection login_codes,
// which the app and website can never read).
// ============================================================
exports.sendLoginCode = onCall(
  { region: REGION, secrets: [GMAIL_USER, GMAIL_APP_PASSWORD] },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Please login again.");

    const email = request.auth.token.email;
    if (!email) {
      throw new HttpsError("failed-precondition", "This account has no email address.");
    }

    const userSnap = await db.doc(`users/${uid}`).get();
    if (userSnap.exists && userSnap.data().emailCodeVerified === true) {
      return { alreadyVerified: true };
    }

    const ref = db.doc(`login_codes/${uid}`);
    const now = Date.now();
    const code = String(crypto.randomInt(0, 1000000)).padStart(6, "0");
    const salt = crypto.randomBytes(8).toString("hex");

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const d = snap.exists ? snap.data() : {};

      const sentAt = d.sentAt ? d.sentAt.toMillis() : 0;
      if (now - sentAt < RESEND_MS) {
        const wait = Math.ceil((RESEND_MS - (now - sentAt)) / 1000);
        throw new HttpsError(
          "resource-exhausted",
          `Please wait ${wait} seconds before asking for a new code.`
        );
      }

      let windowStart = d.windowStart ? d.windowStart.toMillis() : 0;
      let count = Number(d.count) || 0;
      if (now - windowStart > 60 * 60 * 1000) {
        windowStart = now;
        count = 0;
      }
      if (count >= MAX_PER_HOUR) {
        throw new HttpsError(
          "resource-exhausted",
          "Too many codes were requested. Please try again after some time."
        );
      }

      tx.set(ref, {
        hash: hashCode(uid, salt, code),
        salt,
        email,
        attempts: 0,
        count: count + 1,
        windowStart: Timestamp.fromMillis(windowStart),
        sentAt: Timestamp.fromMillis(now),
        expiresAt: Timestamp.fromMillis(now + CODE_TTL_MS),
      });
    });

    try {
      await sendMail(email, code);
    } catch (e) {
      console.error("sendLoginCode mail error", e);
      await ref.delete().catch(() => {});
      throw new HttpsError("internal", "Could not send the email. Please try again.");
    }

    return {
      sent: true,
      email,
      resendAfterSeconds: RESEND_MS / 1000,
      expiresInSeconds: CODE_TTL_MS / 1000,
    };
  }
);

// ============================================================
// verifyLoginCode
// Checks the code. On success the server marks the user as
// verified (users/{uid}.emailCodeVerified = true). Nobody else
// can set this field, because the security rules do not allow it.
// ============================================================
exports.verifyLoginCode = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Please login again.");

  const code = String(request.data?.code ?? "").trim();
  if (!/^\d{6}$/.test(code)) {
    throw new HttpsError("invalid-argument", "Please enter the 6 digit code.");
  }

  const ref = db.doc(`login_codes/${uid}`);
  const userRef = db.doc(`users/${uid}`);

  let status = "ok";
  let left = 0;

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);

    if (!snap.exists) {
      status = "nocode";
      return;
    }

    const d = snap.data();

    if (d.expiresAt.toMillis() < Date.now()) {
      tx.delete(ref);
      status = "expired";
      return;
    }

    if ((Number(d.attempts) || 0) >= MAX_ATTEMPTS) {
      status = "locked";
      return;
    }

    const given = Buffer.from(hashCode(uid, d.salt, code), "hex");
    const saved = Buffer.from(String(d.hash), "hex");
    const same = given.length === saved.length && crypto.timingSafeEqual(given, saved);

    if (!same) {
      const attempts = (Number(d.attempts) || 0) + 1;
      tx.update(ref, { attempts });
      left = MAX_ATTEMPTS - attempts;
      status = "wrong";
      return;
    }

    tx.delete(ref);
    tx.set(
      userRef,
      {
        emailCodeVerified: true,
        emailCodeVerifiedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });

  if (status === "nocode") {
    throw new HttpsError("failed-precondition", "No code was found. Please ask for a new code.");
  }
  if (status === "expired") {
    throw new HttpsError("failed-precondition", "This code has expired. Please ask for a new code.");
  }
  if (status === "locked") {
    throw new HttpsError(
      "resource-exhausted",
      "Too many wrong attempts. Please ask for a new code."
    );
  }
  if (status === "wrong") {
    throw new HttpsError(
      "invalid-argument",
      left > 0
        ? `The code is wrong. ${left} attempts left.`
        : "The code is wrong. Please ask for a new code."
    );
  }

  return { verified: true };
});
