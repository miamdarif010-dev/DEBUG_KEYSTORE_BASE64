// functions/cloudinary_functions.js
//
// Cloudinary video functions:
//   getVideoUploadSignature : unique signed upload (never overwrites)
//   deleteCloudinaryVideo   : owner-only delete.
//     - If the Firestore video doc exists: deletes the URL stored there.
//     - If it does NOT exist (upload worked but saving failed): deletes the
//       client-sent videoUrl, but ONLY if its public_id starts with
//       buynova_videos/<caller uid>_ (set by getVideoUploadSignature).
//
// In functions/index.js this is loaded with:
//   Object.assign(exports, require("./cloudinary_functions"));

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const cloudinary = require("cloudinary").v2;
const crypto = require("crypto");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const REGION = "asia-northeast3";

const cloudinaryApiKey = defineSecret("CLOUDINARY_API_KEY");
const cloudinaryApiSecret = defineSecret("CLOUDINARY_API_SECRET");

// Must be the same cloud name that your videos live in.
const CLOUDINARY_CLOUD_NAME = "hut6g3w7";

function requireAuth(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "You must be logged in.");
  }

  return request.auth.uid;
}

// Extracts the Cloudinary public_id from a delivery URL.
function extractCloudinaryPublicId(url) {
  try {
    const uri = new URL(url);
    const path = uri.pathname;

    const uploadIndex = path.indexOf("/upload/");
    if (uploadIndex === -1) return null;

    let rest = path.substring(uploadIndex + "/upload/".length);

    const segments = rest.split("/");

    // Remove a transformation segment such as so_0
    if (segments.length > 1 && /^[a-z]{1,3}_/.test(segments[0])) {
      segments.shift();
    }

    rest = segments.join("/");

    // Remove version segment (v123456)
    rest = rest.replace(/^v\d+\//, "");

    // Remove file extension
    rest = rest.replace(/\.[^./]+$/, "");

    return rest || null;
  } catch (e) {
    return null;
  }
}

// ============================================================
// SIGNED UPLOAD (unique public_id, overwrite=false)
// ============================================================

exports.getVideoUploadSignature = onCall(
  { region: REGION, secrets: [cloudinaryApiKey, cloudinaryApiSecret] },
  async (request) => {
    const uid = requireAuth(request);

    const publicId =
      `buynova_videos/${uid}_${Date.now()}_` +
      crypto.randomBytes(6).toString("hex");

    const timestamp = Math.round(Date.now() / 1000);

    // These exact parameters are signed; the app must send the same
    // values for overwrite, public_id and timestamp.
    const signature = cloudinary.utils.api_sign_request(
      { overwrite: "false", public_id: publicId, timestamp: timestamp },
      cloudinaryApiSecret.value()
    );

    return {
      cloudName: CLOUDINARY_CLOUD_NAME,
      apiKey: cloudinaryApiKey.value(),
      timestamp: timestamp,
      signature: signature,
      publicId: publicId,
    };
  }
);

// ============================================================
// DELETE CLOUDINARY VIDEO (owner only)
// ============================================================

exports.deleteCloudinaryVideo = onCall(
  { region: REGION, secrets: [cloudinaryApiKey, cloudinaryApiSecret] },
  async (request) => {
    const uid = requireAuth(request);

    const { videoId, videoUrl } = request.data || {};

    if (!videoId || typeof videoId !== "string" || videoId.includes("/")) {
      throw new HttpsError("invalid-argument", "videoId is required.");
    }

    const snap = await db.collection("sellerVideos").doc(videoId).get();

    let publicId = null;

    if (snap.exists) {
      // Normal delete: only the URL stored in Firestore is used.
      const v = snap.data() || {};

      if (v.userId !== uid && v.sellerId !== uid) {
        throw new HttpsError("permission-denied", "Not your video.");
      }

      publicId = extractCloudinaryPublicId(String(v.videoUrl || ""));
    } else {
      // Orphan upload: the Firestore doc was never saved.
      // Allowed only for the caller's own signed upload.
      publicId = extractCloudinaryPublicId(String(videoUrl || ""));

      if (!publicId || !publicId.startsWith(`buynova_videos/${uid}_`)) {
        throw new HttpsError("permission-denied", "Not your upload.");
      }
    }

    if (!publicId) {
      return { video: null };
    }

    cloudinary.config({
      cloud_name: CLOUDINARY_CLOUD_NAME,
      api_key: cloudinaryApiKey.value(),
      api_secret: cloudinaryApiSecret.value(),
    });

    try {
      const video = await cloudinary.uploader.destroy(publicId, {
        resource_type: "video",
        invalidate: true,
      });

      return { video };
    } catch (e) {
      console.error("Failed to delete Cloudinary video:", e);

      return { video: { error: e.message } };
    }
  }
);
