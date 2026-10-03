const { onCall, HttpsError } = require("firebase-functions/v2/https");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const cloudinary = require("cloudinary").v2;

admin.initializeApp();

const db = admin.firestore();
const serverTimestamp = () => admin.firestore.FieldValue.serverTimestamp();

setGlobalOptions({
  region: "asia-northeast3",
  maxInstances: 10,
});

// ============================================================
// ORDER CREATION (server-side pricing, coupon and delivery fee)
// ============================================================

const orders = require("./orders");

exports.createOrder = orders.createOrder;
exports.cancelUnpaidOrder = orders.cancelUnpaidOrder;

// ============================================================
// CLOUDINARY SECRETS
// ============================================================

const cloudinaryApiKey = defineSecret("CLOUDINARY_API_KEY");
const cloudinaryApiSecret = defineSecret("CLOUDINARY_API_SECRET");

const CLOUDINARY_CLOUD_NAME = "riassg6d";

// ============================================================
// HELPERS
// ============================================================

function requireAuth(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "You must be logged in.");
  }

  return request.auth.uid;
}

function requireAdmin(request) {
  const uid = requireAuth(request);

  const email = request.auth.token.email || "";

  if (email.toLowerCase() !== "miamdarif010@gmail.com") {
    throw new HttpsError("permission-denied", "Admin access required.");
  }

  return uid;
}

// Extracts Cloudinary public_id from a delivery URL.
function extractCloudinaryPublicId(url) {
  try {
    const uri = new URL(url);
    const path = uri.pathname;

    const uploadIndex = path.indexOf("/upload/");
    if (uploadIndex === -1) return null;

    let rest = path.substring(uploadIndex + "/upload/".length);

    const segments = rest.split("/");

    if (segments.length > 1 && /^[a-z]{1,3}_/.test(segments[0])) {
      segments.shift();
    }

    rest = segments.join("/");

    rest = rest.replace(/^v\d+\//, "");

    rest = rest.replace(/\.[^./]+$/, "");

    return rest || null;
  } catch (e) {
    return null;
  }
}

// ============================================================
// HEALTH CHECK
// ============================================================

exports.healthCheck = onCall(async () => {
  return {
    success: true,
    message: "BuyNova Functions are working.",
    region: "asia-northeast3",
    timestamp: new Date().toISOString(),
  };
});

// ============================================================
// DELETE CLOUDINARY VIDEO (+ thumbnail)
// ============================================================

exports.deleteCloudinaryVideo = onCall(
  {
    secrets: [cloudinaryApiKey, cloudinaryApiSecret],
  },
  async (request) => {
    requireAuth(request);

    const { videoUrl, thumbnailUrl } = request.data || {};

    if (!videoUrl || typeof videoUrl !== "string") {
      throw new HttpsError("invalid-argument", "videoUrl is required.");
    }

    cloudinary.config({
      cloud_name: CLOUDINARY_CLOUD_NAME,
      api_key: cloudinaryApiKey.value(),
      api_secret: cloudinaryApiSecret.value(),
    });

    const results = {
      video: null,
      thumbnail: null,
    };

    const videoPublicId = extractCloudinaryPublicId(videoUrl);

    if (videoPublicId) {
      try {
        results.video = await cloudinary.uploader.destroy(videoPublicId, {
          resource_type: "video",
          invalidate: true,
        });
      } catch (e) {
        console.error("Failed to delete Cloudinary video:", e);

        results.video = {
          error: e.message,
        };
      }
    }

    if (thumbnailUrl && typeof thumbnailUrl === "string") {
      const thumbPublicId = extractCloudinaryPublicId(thumbnailUrl);

      if (thumbPublicId) {
        try {
          results.thumbnail = await cloudinary.uploader.destroy(
            thumbPublicId,
            {
              resource_type: "image",
              invalidate: true,
            }
          );
        } catch (e) {
          console.error("Failed to delete Cloudinary thumbnail:", e);

          results.thumbnail = {
            error: e.message,
          };
        }
      }
    }

    return results;
  }
);

// ============================================================
// WALLET TRANSACTION LISTENER
// ============================================================

exports.onWalletTransactionCreated = onDocumentCreated(
  "users/{userId}/walletTransactions/{transactionId}",
  async (event) => {
    const snapshot = event.data;

    if (!snapshot) {
      return;
    }

    const data = snapshot.data();

    console.log(
      "Wallet transaction created:",
      event.params.userId,
      event.params.transactionId,
      data
    );

    return null;
  }
);

// ============================================================
// GET WALLET BALANCE
// ============================================================

exports.getWalletBalance = onCall(async (request) => {
  const uid = requireAuth(request);

  const userSnapshot = await db.collection("users").doc(uid).get();

  if (!userSnapshot.exists) {
    throw new HttpsError("not-found", "User account not found.");
  }

  const userData = userSnapshot.data() || {};

  const rawBalance = userData.cashBalance ?? userData.walletBalance ?? 0;

  const balance = Number(rawBalance) || 0;

  return {
    success: true,
    balance: balance,
    cashBalance: balance,
    currency: "BDT",
  };
});

// ============================================================
// APPROVE WALLET TRANSACTION
// ============================================================

exports.approveWalletTransaction = onCall(async (request) => {
  requireAdmin(request);

  const { userId, transactionId } = request.data || {};

  if (!userId || !transactionId) {
    throw new HttpsError(
      "invalid-argument",
      "userId and transactionId are required."
    );
  }

  const transactionRef = db
    .collection("users")
    .doc(userId)
    .collection("walletTransactions")
    .doc(transactionId);

  const result = await db.runTransaction(async (transaction) => {
    const transactionSnapshot = await transaction.get(transactionRef);

    if (!transactionSnapshot.exists) {
      throw new HttpsError("not-found", "Wallet transaction not found.");
    }

    const transactionData = transactionSnapshot.data() || {};

    if (transactionData.status === "approved") {
      return {
        alreadyApproved: true,
      };
    }

    if (transactionData.status === "rejected") {
      throw new HttpsError(
        "failed-precondition",
        "This transaction has already been rejected."
      );
    }

    const userRef = db.collection("users").doc(userId);

    const userSnapshot = await transaction.get(userRef);

    if (!userSnapshot.exists) {
      throw new HttpsError("not-found", "User account not found.");
    }

    const userData = userSnapshot.data() || {};

    const currentBalance = Number(
      userData.cashBalance ?? userData.walletBalance ?? 0
    );

    const amount = Number(transactionData.amount ?? 0);

    if (amount <= 0) {
      throw new HttpsError(
        "invalid-argument",
        "Invalid wallet transaction amount."
      );
    }

    const newBalance = currentBalance + amount;

    transaction.update(userRef, {
      cashBalance: newBalance,
      walletBalance: newBalance,
      updatedAt: serverTimestamp(),
    });

    transaction.update(transactionRef, {
      status: "approved",
      balanceBefore: currentBalance,
      balanceAfter: newBalance,
      approvedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });

    return {
      alreadyApproved: false,
      newBalance,
    };
  });

  await db
    .collection("users")
    .doc(userId)
    .collection("notifications")
    .add({
      title: "Wallet Updated",
      message: "Your BuyNova Wallet transaction has been approved.",
      type: "wallet",
      read: false,
      createdAt: serverTimestamp(),
    });

  return {
    success: true,
    ...result,
  };
});

// ============================================================
// REJECT WALLET TRANSACTION
// ============================================================

exports.rejectWalletTransaction = onCall(async (request) => {
  requireAdmin(request);

  const { userId, transactionId, reason } = request.data || {};

  if (!userId || !transactionId) {
    throw new HttpsError(
      "invalid-argument",
      "userId and transactionId are required."
    );
  }

  const transactionRef = db
    .collection("users")
    .doc(userId)
    .collection("walletTransactions")
    .doc(transactionId);

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(transactionRef);

    if (!snapshot.exists) {
      throw new HttpsError("not-found", "Wallet transaction not found.");
    }

    const data = snapshot.data() || {};

    if (data.status === "rejected") {
      return;
    }

    if (data.status === "approved") {
      throw new HttpsError(
        "failed-precondition",
        "An approved transaction cannot be rejected."
      );
    }

    transaction.update(transactionRef, {
      status: "rejected",
      rejectionReason: reason || "Rejected by admin.",
      rejectedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
  });

  await db
    .collection("users")
    .doc(userId)
    .collection("notifications")
    .add({
      title: "Wallet Transaction Rejected",
      message: reason || "Your BuyNova Wallet transaction was rejected.",
      type: "wallet",
      read: false,
      createdAt: serverTimestamp(),
    });

  return {
    success: true,
    message: "Wallet transaction rejected.",
  };
});

// ============================================================
// PLACE WALLET ORDER
// ============================================================

exports.placeWalletOrder = onCall(async (request) => {
  const uid = requireAuth(request);

  const { orderId } = request.data || {};

  if (!orderId) {
    throw new HttpsError("invalid-argument", "orderId is required.");
  }

  const userRef = db.collection("users").doc(uid);

  const orderRef = db.collection("orders").doc(orderId);

  const result = await db.runTransaction(async (transaction) => {
    const userSnapshot = await transaction.get(userRef);

    if (!userSnapshot.exists) {
      throw new HttpsError("not-found", "User account not found.");
    }

    const orderSnapshot = await transaction.get(orderRef);

    if (!orderSnapshot.exists) {
      throw new HttpsError("not-found", "Order not found.");
    }

    const sellerOrdersSnapshot = await transaction.get(
      db.collection("seller_orders").where("orderId", "==", orderId)
    );

    const resellerOrdersSnapshot = await transaction.get(
      db.collection("reseller_orders").where("orderId", "==", orderId)
    );

    const orderData = orderSnapshot.data() || {};

    const orderUserId = orderData.userId ?? orderData.customerId;

    if (orderUserId !== uid) {
      throw new HttpsError(
        "permission-denied",
        "You cannot pay for this order."
      );
    }

    if (orderData.paymentMethod !== "BuyNova Wallet") {
      throw new HttpsError(
        "failed-precondition",
        "This order is not using BuyNova Wallet."
      );
    }

    if (orderData.paymentStatus === "paid") {
      return {
        alreadyPaid: true,
        transactionId: orderData.walletTransactionId || null,
        newBalance: null,
      };
    }

    const totalAmount = Number(
      orderData.grandTotal ?? orderData.total ?? orderData.totalAmount ?? 0
    );

    if (!Number.isFinite(totalAmount) || totalAmount <= 0) {
      throw new HttpsError("failed-precondition", "Invalid order amount.");
    }

    const userData = userSnapshot.data() || {};

    const balanceBefore = Number(
      userData.cashBalance ?? userData.walletBalance ?? 0
    );

    if (!Number.isFinite(balanceBefore)) {
      throw new HttpsError("failed-precondition", "Invalid wallet balance.");
    }

    if (balanceBefore < totalAmount) {
      throw new HttpsError(
        "failed-precondition",
        "Insufficient wallet balance."
      );
    }

    const balanceAfter = balanceBefore - totalAmount;

    const walletTransactionRef = userRef.collection("walletTransactions").doc();

    transaction.set(walletTransactionRef, {
      type: "debit",
      source: "order_payment",
      status: "approved",
      amount: totalAmount,
      currency: "BDT",
      orderId: orderId,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      description: `Payment for BuyNova order ${orderId}`,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });

    transaction.update(userRef, {
      cashBalance: balanceAfter,
      walletBalance: balanceAfter,
      updatedAt: serverTimestamp(),
    });

    transaction.update(orderRef, {
      paymentStatus: "paid",
      paymentMethod: "BuyNova Wallet",
      walletPaid: true,
      walletTransactionId: walletTransactionRef.id,
      walletPaidAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });

    for (const sellerDoc of sellerOrdersSnapshot.docs) {
      transaction.update(sellerDoc.ref, {
        paymentStatus: "paid",
        paymentMethod: "BuyNova Wallet",
        walletTransactionId: walletTransactionRef.id,
        updatedAt: serverTimestamp(),
      });
    }

    for (const resellerDoc of resellerOrdersSnapshot.docs) {
      transaction.update(resellerDoc.ref, {
        paymentStatus: "paid",
        paymentMethod: "BuyNova Wallet",
        walletTransactionId: walletTransactionRef.id,
        updatedAt: serverTimestamp(),
      });
    }

    const notificationRef = userRef.collection("notifications").doc();

    transaction.set(notificationRef, {
      title: "Payment Successful",
      message: `৳${totalAmount.toFixed(
        2
      )} was paid from your BuyNova Wallet for order ${orderId}.`,
      type: "order_payment",
      orderId: orderId,
      amount: totalAmount,
      currency: "BDT",
      read: false,
      createdAt: serverTimestamp(),
    });

    return {
      alreadyPaid: false,
      transactionId: walletTransactionRef.id,
      newBalance: balanceAfter,
      amountPaid: totalAmount,
    };
  });

  return {
    success: true,
    ...result,
  };
});

// ============================================================
// ORDER STATUS SYNC + WALLET REFUND ON CANCEL
// ============================================================

const STATUS_RANK = {
  placed: 0,
  confirmed: 1,
  processing: 2,
  shipped: 3,
  delivered: 4,
  returned: 5,
  refunded: 6,
};

function roundMoney(value) {
  return Math.round((Number(value) || 0) * 100) / 100;
}

function statusRank(status) {
  const rank = STATUS_RANK[status];

  return rank === undefined ? 0 : rank;
}

async function refundCancelledSubOrder(orderId, collectionName, subOrderId) {
  const orderRef = db.collection("orders").doc(orderId);

  const subRef = db.collection(collectionName).doc(subOrderId);

  await db.runTransaction(async (transaction) => {
    const orderSnap = await transaction.get(orderRef);

    if (!orderSnap.exists) return;

    const subSnap = await transaction.get(subRef);

    if (!subSnap.exists) return;

    const sellerOrdersSnap = await transaction.get(
      db.collection("seller_orders").where("orderId", "==", orderId)
    );

    const resellerOrdersSnap = await transaction.get(
      db.collection("reseller_orders").where("orderId", "==", orderId)
    );

    const order = orderSnap.data() || {};

    const sub = subSnap.data() || {};

    const paymentStatus = String(order.paymentStatus || "");

    if (
      order.paymentMethod !== "BuyNova Wallet" ||
      (paymentStatus !== "paid" && paymentStatus !== "partially_refunded")
    ) {
      return;
    }

    const userId = order.userId || order.customerId;

    if (!userId) return;

    const userRef = db.collection("users").doc(userId);

    const userSnap = await transaction.get(userRef);

    if (!userSnap.exists) return;

    const refundedIds = Array.isArray(order.refundedSubOrderIds)
      ? order.refundedSubOrderIds
      : [];

    const key = `${collectionName}:${subOrderId}`;

    if (refundedIds.includes(key)) {
      return;
    }

    const orderSubtotal = Number(order.subtotal) || 0;

    const discount = Number(order.discount) || 0;

    const deliveryFee = Number(order.deliveryFee) || 0;

    const grandTotal = Number(order.grandTotal ?? order.total) || 0;

    const subBase =
      collectionName === "reseller_orders"
        ? Number(sub.sellingTotal) || 0
        : Number(sub.subtotal ?? sub.sellerSubtotal) || 0;

    let share = subBase;

    if (orderSubtotal > 0 && discount > 0) {
      share =
        subBase * (1 - Math.min(discount, orderSubtotal) / orderSubtotal);
    }

    const allSubOrders = [
      ...sellerOrdersSnap.docs,
      ...resellerOrdersSnap.docs,
    ];

    const allCancelled =
      allSubOrders.length > 0 &&
      allSubOrders.every(
        (d) =>
          String((d.data() || {}).orderStatus || "").toLowerCase() ===
          "cancelled"
      );

    const alreadyRefundedTotal = Number(order.walletRefundedTotal) || 0;

    const deliveryAlreadyRefunded = order.deliveryFeeRefunded === true;

    const maxRefundable = roundMoney(grandTotal - alreadyRefundedTotal);

    let refundAmount = share;

    let refundsDeliveryFee = false;

    if (allCancelled && !deliveryAlreadyRefunded && deliveryFee > 0) {
      refundAmount += deliveryFee;

      refundsDeliveryFee = true;
    }

    if (allCancelled && refundedIds.length + 1 >= allSubOrders.length) {
      refundAmount = maxRefundable;

      refundsDeliveryFee = true;
    }

    refundAmount = roundMoney(refundAmount);

    if (refundAmount > maxRefundable) {
      refundAmount = maxRefundable;
    }

    if (refundAmount <= 0) {
      return;
    }

    const userData = userSnap.data() || {};

    const balanceBefore = Number(
      userData.cashBalance ?? userData.walletBalance ?? 0
    );

    if (!Number.isFinite(balanceBefore)) {
      return;
    }

    const balanceAfter = roundMoney(balanceBefore + refundAmount);

    const newRefundedTotal = roundMoney(alreadyRefundedTotal + refundAmount);

    const fullyRefunded =
      newRefundedTotal >= roundMoney(grandTotal) - 0.005;

    const walletTransactionRef = userRef.collection("walletTransactions").doc();

    transaction.set(walletTransactionRef, {
      type: "credit",
      source: "order_refund",
      status: "approved",
      amount: refundAmount,
      currency: "BDT",
      currencySymbol: "৳",
      userId: userId,
      orderId: orderId,
      subOrderId: subOrderId,
      subOrderCollection: collectionName,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      description: `Refund for cancelled order ${orderId}`,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });

    transaction.update(userRef, {
      cashBalance: balanceAfter,
      walletBalance: balanceAfter,
      updatedAt: serverTimestamp(),
    });

    transaction.update(orderRef, {
      walletRefundedTotal: newRefundedTotal,
      refundedSubOrderIds: [...refundedIds, key],
      deliveryFeeRefunded:
        deliveryAlreadyRefunded || refundsDeliveryFee,
      paymentStatus: fullyRefunded
        ? "refunded"
        : "partially_refunded",
      updatedAt: serverTimestamp(),
    });

    transaction.update(subRef, {
      paymentStatus: "refunded",
      refundedAmount: refundAmount,
      updatedAt: serverTimestamp(),
    });

    const notificationRef = userRef.collection("notifications").doc();

    transaction.set(notificationRef, {
      title: "Order Refund",
      message: `৳${refundAmount.toFixed(
        2
      )} was refunded to your BuyNova Wallet for cancelled order ${orderId}.`,
      type: "order_refund",
      orderId: orderId,
      amount: refundAmount,
      currency: "BDT",
      read: false,
      isRead: false,
      createdAt: serverTimestamp(),
    });
  });
}

async function syncMainOrderStatus(orderId) {
  const orderRef = db.collection("orders").doc(orderId);

  const [orderSnap, sellerSnap, resellerSnap] = await Promise.all([
    orderRef.get(),
    db.collection("seller_orders").where("orderId", "==", orderId).get(),
    db.collection("reseller_orders").where("orderId", "==", orderId).get(),
  ]);

  if (!orderSnap.exists) {
    return;
  }

  const statuses = [...sellerSnap.docs, ...resellerSnap.docs].map((d) =>
    String((d.data() || {}).orderStatus || "placed").toLowerCase()
  );

  if (statuses.length === 0) {
    return;
  }

  const active = statuses.filter((s) => s !== "cancelled");

  let newStatus = "cancelled";

  if (active.length > 0) {
    newStatus = active.reduce(
      (lowest, s) => (statusRank(s) < statusRank(lowest) ? s : lowest),
      active[0]
    );
  }

  const currentStatus = String(
    (orderSnap.data() || {}).orderStatus || "placed"
  ).toLowerCase();

  if (currentStatus === newStatus) {
    return;
  }

  await orderRef.update({
    orderStatus: newStatus,
    updatedAt: serverTimestamp(),
  });
}

async function handleSubOrderStatusChange(event, collectionName) {
  const before =
    event.data &&
    event.data.before &&
    event.data.before.data();

  const after =
    event.data &&
    event.data.after &&
    event.data.after.data();

  if (!before || !after) {
    return null;
  }

  const beforeStatus = String(
    before.orderStatus || "placed"
  ).toLowerCase();

  const afterStatus = String(
    after.orderStatus || "placed"
  ).toLowerCase();

  if (beforeStatus === afterStatus) {
    return null;
  }

  const orderId = after.orderId;

  const subOrderId = event.params.subOrderId;

  if (!orderId) {
    return null;
  }

  if (afterStatus === "cancelled") {
    try {
      await refundCancelledSubOrder(
        orderId,
        collectionName,
        subOrderId
      );
    } catch (error) {
      console.error(
        "Refund failed for",
        collectionName,
        subOrderId,
        "order",
        orderId,
        error
      );
    }
  }

  try {
    await syncMainOrderStatus(orderId);
  } catch (error) {
    console.error(
      "Main order status sync failed for",
      orderId,
      error
    );
  }

  return null;
}

exports.onSellerOrderStatusChanged = onDocumentUpdated(
  "seller_orders/{subOrderId}",
  (event) =>
    handleSubOrderStatusChange(
      event,
      "seller_orders"
    )
);

exports.onResellerOrderStatusChanged = onDocumentUpdated(
  "reseller_orders/{subOrderId}",
  (event) =>
    handleSubOrderStatusChange(
      event,
      "reseller_orders"
    )
);

// ============================================================
// SELLER / RESELLER MEMBERSHIP REGISTRATION FEE
// ============================================================
//
// Server-side membership payment.
//
// IMPORTANT:
// - Client never decides the membership fee.
// - Admin controls the fee from:
//     platformSettings/monetization
// - Seller and Reseller use the same BuyNova Wallet.
// - Free campaign can make the registration fee ৳0.
// - Successful membership payment is recorded in:
//     users/{uid}/membershipPayments
// - BuyNova revenue is recorded privately in:
//     buyNovaProfitLedger
//
// Supported roles:
//     seller
//     reseller
// ============================================================

const MEMBERSHIP_CONFIG_PATH =
  "platformSettings/monetization";

function membershipRoleName(role) {
  if (role === "seller") {
    return "Seller";
  }

  if (role === "reseller") {
    return "Reseller";
  }

  return null;
}

function timestampToDate(value) {
  if (!value) {
    return null;
  }

  if (value instanceof Date) {
    return value;
  }

  if (typeof value.toDate === "function") {
    return value.toDate();
  }

  return null;
}

function isMembershipFreeCampaignActive(config) {
  if (config.freeCampaignEnabled !== true) {
    return false;
  }

  const start = timestampToDate(
    config.freeCampaignStart
  );

  const end = timestampToDate(
    config.freeCampaignEnd
  );

  if (!start || !end) {
    return false;
  }

  const now = new Date();

  return now >= start && now <= end;
}

function getMembershipFee(config, role) {
  if (role === "seller") {
    return Math.max(
      0,
      Number(config.sellerMembershipFee ?? 1000) || 0
    );
  }

  if (role === "reseller") {
    return Math.max(
      0,
      Number(config.resellerMembershipFee ?? 1000) || 0
    );
  }

  return 0;
}

exports.payMembershipRegistrationFee = onCall(
  async (request) => {
    const uid = requireAuth(request);

    const data = request.data || {};

    const role =
      typeof data.role === "string"
        ? data.role.trim().toLowerCase()
        : "";

    const roleName = membershipRoleName(role);

    if (!roleName) {
      throw new HttpsError(
        "invalid-argument",
        "Invalid membership role. Use seller or reseller."
      );
    }

    const configRef = db
      .collection("platformSettings")
      .doc("monetization");

    const userRef = db
      .collection("users")
      .doc(uid);

    const result = await db.runTransaction(
      async (transaction) => {
        // ------------------------------------------------------
        // READ CONFIG
        // ------------------------------------------------------

        const configSnapshot =
          await transaction.get(configRef);

        if (!configSnapshot.exists) {
          throw new HttpsError(
            "not-found",
            "BuyNova membership pricing configuration was not found."
          );
        }

        const config =
          configSnapshot.data() || {};

        // ------------------------------------------------------
        // READ USER
        // ------------------------------------------------------

        const userSnapshot =
          await transaction.get(userRef);

        if (!userSnapshot.exists) {
          throw new HttpsError(
            "not-found",
            "User account not found."
          );
        }

        const userData =
          userSnapshot.data() || {};

        // ------------------------------------------------------
        // CHECK CURRENT MEMBERSHIP STATUS
        // ------------------------------------------------------

        const currentStatus =
          role === "seller"
            ? String(
                userData.sellerStatus || "none"
              ).toLowerCase()
            : String(
                userData.entrepreneurStatus || "none"
              ).toLowerCase();

        if (currentStatus === "approved") {
          throw new HttpsError(
            "already-exists",
            `${roleName} membership is already approved.`
          );
        }

        // ------------------------------------------------------
        // PREVENT DOUBLE PAYMENT
        // ------------------------------------------------------

        const alreadyPaid =
          role === "seller"
            ? userData.sellerRegistrationFeePaid === true
            : userData.entrepreneurRegistrationFeePaid ===
              true;

        if (alreadyPaid) {
          throw new HttpsError(
            "already-exists",
            `${roleName} membership registration fee has already been paid.`
          );
        }

        // ------------------------------------------------------
        // CALCULATE FEE SERVER-SIDE
        // ------------------------------------------------------

        const freeCampaignActive =
          isMembershipFreeCampaignActive(config);

        const configuredFee =
          getMembershipFee(config, role);

        const membershipFee =
          freeCampaignActive
            ? 0
            : configuredFee;

        const pricingPlan =
          freeCampaignActive
            ? "free_campaign"
            : "standard";

        // ------------------------------------------------------
        // CURRENT WALLET BALANCE
        // ------------------------------------------------------

        const currentBalance = Number(
          userData.cashBalance ??
            userData.walletBalance ??
            0
        );

        if (
          !Number.isFinite(currentBalance) ||
          currentBalance < 0
        ) {
          throw new HttpsError(
            "failed-precondition",
            "Invalid BuyNova Wallet balance."
          );
        }

        if (membershipFee > currentBalance) {
          throw new HttpsError(
            "failed-precondition",
            `Insufficient BuyNova Wallet balance. ${roleName} membership fee is ৳${membershipFee.toFixed(
              2
            )}.`
          );
        }

        const balanceBefore =
          currentBalance;

        const balanceAfter =
          balanceBefore - membershipFee;

        // ------------------------------------------------------
        // PAYMENT ID
        // ------------------------------------------------------

        const paymentRef = userRef
          .collection("membershipPayments")
          .doc();

        const paymentId =
          paymentRef.id;

        // ------------------------------------------------------
        // WALLET TRANSACTION
        // ------------------------------------------------------

        let walletTransactionId =
          null;

        if (membershipFee > 0) {
          const walletTransactionRef =
            userRef
              .collection("walletTransactions")
              .doc();

          walletTransactionId =
            walletTransactionRef.id;

          transaction.set(
            walletTransactionRef,
            {
              type: "debit",
              source:
                "membership_registration",
              status: "approved",
              amount: membershipFee,
              currency: "BDT",
              currencySymbol: "৳",
              membershipRole: role,
              membershipRoleName: roleName,
              paymentId: paymentId,
              balanceBefore:
                balanceBefore,
              balanceAfter:
                balanceAfter,
              description:
                `BuyNova ${roleName} membership registration fee`,
              createdAt:
                serverTimestamp(),
              updatedAt:
                serverTimestamp(),
            }
          );
        }

        // ------------------------------------------------------
        // MEMBERSHIP PAYMENT RECORD
        // ------------------------------------------------------

        transaction.set(
          paymentRef,
          {
            paymentId: paymentId,
            uid: uid,
            role: role,
            roleName: roleName,
            amount: membershipFee,
            currency: "BDT",
            currencySymbol: "৳",
            status: "approved",
            paymentMethod:
              membershipFee > 0
                ? "BuyNova Wallet"
                : "Free Campaign",
            pricingPlan:
              pricingPlan,
            freeCampaign:
              freeCampaignActive,
            walletTransactionId:
              walletTransactionId,
            balanceBefore:
              balanceBefore,
            balanceAfter:
              balanceAfter,
            createdAt:
              serverTimestamp(),
            paidAt:
              serverTimestamp(),
            updatedAt:
              serverTimestamp(),
          }
        );

        // ------------------------------------------------------
        // USER MEMBERSHIP STATUS
        // ------------------------------------------------------

        const membershipUpdate = {
          updatedAt:
            serverTimestamp(),

          membershipUpdatedAt:
            serverTimestamp(),

          membershipPricingPlan:
            pricingPlan,

          membershipRegistrationFeePaid:
            true,

          membershipRegistrationFeeAmount:
            membershipFee,

          membershipPaymentId:
            paymentId,

          membershipPaidAt:
            serverTimestamp(),
        };

        if (role === "seller") {
          membershipUpdate.sellerStatus =
            "pending";

          membershipUpdate.sellerRequestedAt =
            serverTimestamp();

          membershipUpdate.sellerRegistrationFeePaid =
            true;

          membershipUpdate.sellerRegistrationFeeAmount =
            membershipFee;

          membershipUpdate.sellerMembershipPaymentId =
            paymentId;

          membershipUpdate.sellerMembershipPaidAt =
            serverTimestamp();
        } else {
          membershipUpdate.entrepreneurStatus =
            "pending";

          membershipUpdate.entrepreneurRequestedAt =
            serverTimestamp();

          membershipUpdate.entrepreneurRegistrationFeePaid =
            true;

          membershipUpdate.entrepreneurRegistrationFeeAmount =
            membershipFee;

          membershipUpdate.entrepreneurMembershipPaymentId =
            paymentId;

          membershipUpdate.entrepreneurMembershipPaidAt =
            serverTimestamp();
        }

        if (membershipFee > 0) {
          membershipUpdate.cashBalance =
            balanceAfter;

          membershipUpdate.walletBalance =
            balanceAfter;
        }

        transaction.update(
          userRef,
          membershipUpdate
        );

        // ------------------------------------------------------
        // BUY NOVA PROFIT LEDGER
        // ------------------------------------------------------
        //
        // Admin-only collection.
        // Client cannot write to this collection.
        //
        // Free campaign produces ৳0 BuyNova revenue.
        // ------------------------------------------------------

        const profitLedgerRef =
          db
            .collection("buyNovaProfitLedger")
            .doc(paymentId);

        transaction.set(
          profitLedgerRef,
          {
            paymentId: paymentId,
            uid: uid,
            role: role,
            roleName: roleName,
            source:
              "membership_registration",
            category:
              "registration_fee",
            amount: membershipFee,
            profitAmount:
              membershipFee,
            currency: "BDT",
            currencySymbol: "৳",
            pricingPlan:
              pricingPlan,
            freeCampaign:
              freeCampaignActive,
            walletTransactionId:
              walletTransactionId,
            createdAt:
              serverTimestamp(),
          }
        );

        return {
          paymentId:
            paymentId,

          role:
            role,

          roleName:
            roleName,

          amount:
            membershipFee,

          currency:
            "BDT",

          balanceBefore:
            balanceBefore,

          balanceAfter:
            balanceAfter,

          pricingPlan:
            pricingPlan,

          freeCampaign:
            freeCampaignActive,

          walletTransactionId:
            walletTransactionId,
        };
      }
    );

    // ----------------------------------------------------------
    // USER NOTIFICATION
    // ----------------------------------------------------------

    try {
      await userRef
        .collection("notifications")
        .add({
          title:
            `${result.roleName} Application Submitted`,

          message:
            result.amount > 0
              ? `৳${result.amount.toFixed(
                  2
                )} membership registration fee paid successfully. Your ${result.roleName} application is now pending Admin approval.`
              : `Your ${result.roleName} membership registration was submitted under the free campaign. Your application is now pending Admin approval.`,

          type:
            "membership",

          membershipRole:
            result.role,

          paymentId:
            result.paymentId,

          amount:
            result.amount,

          currency:
            "BDT",

          read:
            false,

          createdAt:
            serverTimestamp(),
        });
    } catch (notificationError) {
      console.error(
        "Membership notification failed:",
        notificationError
      );
    }

    return {
      success:
        true,

      message:
        `${result.roleName} membership application submitted successfully.`,

      ...result,
    };
  }
);

// ============================================================
// ADMIN DELETE USER
// ============================================================
// IMPORTANT:
// This is a server-side privileged operation.
//
// Only:
//     miamdarif010@gmail.com
//
// can call this function.
//
// It deletes:
// 1. Firebase Authentication account
// 2. users/{uid} document + subcollections
// 3. Products owned by seller
// 4. Seller videos owned by seller
// 5. Reseller products owned by entrepreneur/reseller
// 6. Seller orders owned by seller
// 7. Reseller orders owned by reseller
// 8. Orders where the user is the customer/buyer
//
// The operation is intentionally NOT based on client-side
// Firestore permissions.
// ============================================================

async function deleteQueryDocuments(query) {
  const snapshot = await query.get();

  if (snapshot.empty) {
    return 0;
  }

  let deleted = 0;

  for (const document of snapshot.docs) {
    try {
      await db.recursiveDelete(document.ref);

      deleted++;
    } catch (error) {
      console.error(
        "Failed to delete document:",
        document.ref.path,
        error
      );

      throw error;
    }
  }

  return deleted;
}

async function deleteUserSubcollections(userRef) {
  const subcollections =
    await userRef.listCollections();

  let deleted = 0;

  for (const collectionRef of subcollections) {
    try {
      await db.recursiveDelete(collectionRef);

      deleted++;
    } catch (error) {
      console.error(
        "Failed to delete subcollection:",
        collectionRef.path,
        error
      );

      throw error;
    }
  }

  return deleted;
}

exports.adminDeleteUser = onCall(
  async (request) => {
    // ========================================================
    // ADMIN ONLY
    // ========================================================

    requireAdmin(request);

    const data = request.data || {};

    const uid =
      typeof data.uid === "string"
        ? data.uid.trim()
        : "";

    if (!uid) {
      throw new HttpsError(
        "invalid-argument",
        "User UID is required."
      );
    }

    // Prevent accidental deletion of the Admin account
    // through this function.
    if (uid === request.auth.uid) {
      throw new HttpsError(
        "failed-precondition",
        "The Admin account cannot be deleted from the Admin Panel."
      );
    }

    console.log(
      "Admin delete requested for user:",
      uid
    );

    // ========================================================
    // CHECK AUTH USER
    // ========================================================

    let authUser = null;

    try {
      authUser =
        await admin.auth().getUser(uid);
    } catch (error) {
      if (error.code !== "auth/user-not-found") {
        console.error(
          "Failed to get Firebase Auth user:",
          error
        );

        throw new HttpsError(
          "internal",
          "Unable to find the Firebase Authentication account."
        );
      }
    }

    // ========================================================
    // USER DOCUMENT
    // ========================================================

    const userRef =
      db.collection("users").doc(uid);

    const userSnapshot =
      await userRef.get();

    const userData =
      userSnapshot.exists
        ? userSnapshot.data() || {}
        : {};

    const userEmail = (
      userData.email ||
      authUser?.email ||
      ""
    )
      .toString()
      .trim()
      .toLowerCase();

    const sellerCode = (
      userData.sellerCode || ""
    )
      .toString()
      .trim();

    const entrepreneurCode = (
      userData.entrepreneurCode || ""
    )
      .toString()
      .trim();

    // ========================================================
    // DELETE TOP-LEVEL PRODUCTS
    // ========================================================

    let deletedProducts = 0;

    deletedProducts +=
      await deleteQueryDocuments(
        db
          .collection("products")
          .where("sellerId", "==", uid)
      );

    // Some older product records may use sellerUid.
    deletedProducts +=
      await deleteQueryDocuments(
        db
          .collection("products")
          .where("sellerUid", "==", uid)
      );

    // ========================================================
    // DELETE SELLER VIDEOS
    // ========================================================

    let deletedSellerVideos = 0;

    deletedSellerVideos +=
      await deleteQueryDocuments(
        db
          .collection("sellerVideos")
          .where("sellerId", "==", uid)
      );

    deletedSellerVideos +=
      await deleteQueryDocuments(
        db
          .collection("sellerVideos")
          .where("sellerUid", "==", uid)
      );

    // ========================================================
    // DELETE RESELLER PRODUCTS
    // ========================================================

    let deletedResellerProducts = 0;

    deletedResellerProducts +=
      await deleteQueryDocuments(
        db
          .collection("reseller_products")
          .where(
            "entrepreneurId",
            "==",
            uid
          )
      );

    deletedResellerProducts +=
      await deleteQueryDocuments(
        db
          .collection("reseller_products")
          .where(
            "entrepreneurUid",
            "==",
            uid
          )
      );

    deletedResellerProducts +=
      await deleteQueryDocuments(
        db
          .collection("reseller_products")
          .where(
            "userId",
            "==",
            uid
          )
      );

    // Delete by entrepreneur email only when the email
    // belongs to this exact user.
    if (userEmail) {
      deletedResellerProducts +=
        await deleteQueryDocuments(
          db
            .collection("reseller_products")
            .where(
              "entrepreneurEmail",
              "==",
              userEmail
            )
        );
    }

    // ========================================================
    // DELETE SELLER ORDERS
    // ========================================================

    let deletedSellerOrders = 0;

    deletedSellerOrders +=
      await deleteQueryDocuments(
        db
          .collection("seller_orders")
          .where("sellerId", "==", uid)
      );

    deletedSellerOrders +=
      await deleteQueryDocuments(
        db
          .collection("seller_orders")
          .where("sellerUid", "==", uid)
      );

    // ========================================================
    // DELETE RESELLER ORDERS
    // ========================================================

    let deletedResellerOrders = 0;

    deletedResellerOrders +=
      await deleteQueryDocuments(
        db
          .collection("reseller_orders")
          .where(
            "entrepreneurId",
            "==",
            uid
          )
      );

    deletedResellerOrders +=
      await deleteQueryDocuments(
        db
          .collection("reseller_orders")
          .where(
            "entrepreneurUid",
            "==",
            uid
          )
      );

    deletedResellerOrders +=
      await deleteQueryDocuments(
        db
          .collection("reseller_orders")
          .where(
            "resellerId",
            "==",
            uid
          )
      );

    deletedResellerOrders +=
      await deleteQueryDocuments(
        db
          .collection("reseller_orders")
          .where(
            "userId",
            "==",
            uid
          )
      );

    // ========================================================
    // DELETE MAIN CUSTOMER ORDERS
    // ========================================================
    //
    // IMPORTANT:
    // Main orders are deleted only when the user is recorded
    // as the actual customer/buyer.
    //
    // We do NOT delete orders merely because a seller or
    // reseller is involved with them.
    // ========================================================

    let deletedCustomerOrders = 0;

    deletedCustomerOrders +=
      await deleteQueryDocuments(
        db
          .collection("orders")
          .where(
            "userId",
            "==",
            uid
          )
      );

    deletedCustomerOrders +=
      await deleteQueryDocuments(
        db
          .collection("orders")
          .where(
            "customerId",
            "==",
            uid
          )
      );

    deletedCustomerOrders +=
      await deleteQueryDocuments(
        db
          .collection("orders")
          .where(
            "buyerId",
            "==",
            uid
          )
      );

    // ========================================================
    // DELETE USER SUBCOLLECTIONS
    // ========================================================

    let deletedUserSubcollections = 0;

    if (userSnapshot.exists) {
      deletedUserSubcollections =
        await deleteUserSubcollections(
          userRef
        );

      // Finally delete users/{uid}.
      await userRef.delete();
    }

    // ========================================================
    // DELETE FIREBASE AUTH ACCOUNT
    // ========================================================

    let authDeleted = false;

    if (authUser) {
      try {
        await admin.auth().deleteUser(uid);

        authDeleted = true;
      } catch (error) {
        console.error(
          "Firebase Auth deletion failed:",
          error
        );

        // Firestore data was already removed.
        // Tell the Admin clearly that Auth deletion failed.
        throw new HttpsError(
          "internal",
          "User data was deleted, but Firebase Authentication account deletion failed. Check Cloud Functions logs."
        );
      }
    }

    // ========================================================
    // RESULT
    // ========================================================

    console.log(
      "User deletion completed:",
      {
        uid,
        sellerCode,
        entrepreneurCode,
        deletedProducts,
        deletedSellerVideos,
        deletedResellerProducts,
        deletedSellerOrders,
        deletedResellerOrders,
        deletedCustomerOrders,
        deletedUserSubcollections,
        authDeleted,
      }
    );

    return {
      success: true,
      message:
        "BuyNova user account deleted successfully.",
      uid: uid,
      authDeleted: authDeleted,
      firestoreUserDeleted:
        userSnapshot.exists,
      deletedProducts:
        deletedProducts,
      deletedSellerVideos:
        deletedSellerVideos,
      deletedResellerProducts:
        deletedResellerProducts,
      deletedSellerOrders:
        deletedSellerOrders,
      deletedResellerOrders:
        deletedResellerOrders,
      deletedCustomerOrders:
        deletedCustomerOrders,
      deletedUserSubcollections:
        deletedUserSubcollections,
    };
  }
);
