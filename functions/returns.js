'use strict';

/**
 * BuyNova - return / refund money flow (Cloud Functions, Node.js, v2)
 *
 * completeReturnRefund({ requestId })
 *   Called by the SELLER (or reseller / supplier of that order, or the admin)
 *   when a return / refund request is finished. In ONE transaction it:
 *     1. gives the buyer the money back in the BuyNova Wallet
 *        (goods after the coupon share + the service fee share of the item;
 *        the delivery fee is not refunded)
 *     2. takes back, in the same proportion, what was paid out for that order:
 *          seller_orders   : seller earning
 *          reseller_orders : supplier earning and reseller profit
 *        and the BuyNova income (commission + service fee) from the admin wallet
 *     3. marks the request completed and records everything on the sub-order
 *
 * Safety
 *   - Everything is read from the server-side sub-order (items, prices,
 *     discount / service fee share). The request document is written by the
 *     buyer, so only its ids are used, never its price or total.
 *   - Only the seller / reseller / supplier of that sub-order or the admin can
 *     call it. The buyer cannot approve his own refund.
 *   - Works only after the payout was made (sub-order delivered + payoutDone).
 *   - Idempotent: a request id is processed once (returnedRequestIds), and the
 *     returned quantity of every product can never exceed what was bought.
 *   - A seller whose balance is too low goes below zero (he already withdrew
 *     the money); the wallet then cannot withdraw until it is positive again.
 *
 * Plug in (functions/index.js):
 *     Object.assign(exports, require("./returns"));
 */

const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

const REGION = 'asia-northeast3';
const ADMIN_EMAIL = 'miamdarif010@gmail.com';

const num = (v) => {
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
};

const round2 = (n) => Math.round((Number(n) || 0) * 100) / 100;

let adminUidCache = '';

async function getAdminUid() {
  if (adminUidCache) return adminUidCache;

  try {
    const user = await admin.auth().getUserByEmail(ADMIN_EMAIL);
    adminUidCache = user.uid;
  } catch (error) {
    console.error('Admin wallet lookup failed:', error);
  }

  return adminUidCache;
}

const completeReturnRefund = onCall({ region: REGION }, async (request) => {
  const uid = request.auth && request.auth.uid;

  if (!uid) {
    throw new HttpsError('unauthenticated', 'Please login again.');
  }

  const requestId = String((request.data || {}).requestId || '').trim();

  if (!requestId || requestId.includes('/')) {
    throw new HttpsError('invalid-argument', 'requestId is required.');
  }

  const email = String((request.auth.token || {}).email || '').toLowerCase();
  const callerIsAdmin =
    email === ADMIN_EMAIL && request.auth.token.email_verified === true;

  const adminUid = await getAdminUid();

  const reqRef = db.collection('return_refund_requests').doc(requestId);

  return db.runTransaction(async (tx) => {
    // ====================================================================
    // READS (a transaction must read everything before it writes)
    // ====================================================================

    const reqSnap = await tx.get(reqRef);

    if (!reqSnap.exists) {
      throw new HttpsError('not-found', 'Request not found.');
    }

    const rr = reqSnap.data() || {};

    if (String(rr.status || '').toLowerCase() === 'rejected') {
      throw new HttpsError(
        'failed-precondition',
        'This request was rejected.'
      );
    }

    const orderId = String(rr.orderId || '');
    const subId = String(rr.sellerOrderId || '');
    const productId = String(rr.productId || '');

    if (!orderId || !subId || subId.includes('/') || !productId) {
      throw new HttpsError('invalid-argument', 'The request is incomplete.');
    }

    let subCollection = 'seller_orders';
    let subRef = db.collection(subCollection).doc(subId);
    let subSnap = await tx.get(subRef);

    if (!subSnap.exists) {
      subCollection = 'reseller_orders';
      subRef = db.collection(subCollection).doc(subId);
      subSnap = await tx.get(subRef);
    }

    if (!subSnap.exists) {
      throw new HttpsError('not-found', 'The order was not found.');
    }

    const sub = subSnap.data() || {};

    const buyerUid = String(sub.buyerId || sub.userId || sub.customerId || '');

    if (
      String(sub.orderId || '') !== orderId ||
      !buyerUid ||
      buyerUid !== String(rr.customerId || '')
    ) {
      throw new HttpsError(
        'failed-precondition',
        'This request does not match the order.'
      );
    }

    const isReseller = subCollection === 'reseller_orders';

    const allowed =
      callerIsAdmin ||
      uid === String(sub.sellerId || '') ||
      (isReseller && uid === String(sub.entrepreneurUid || ''));

    if (!allowed) {
      throw new HttpsError(
        'permission-denied',
        'You cannot complete this request.'
      );
    }

    // Already processed (retry / double tap): nothing more to do.
    const doneIds = Array.isArray(sub.returnedRequestIds)
      ? sub.returnedRequestIds
      : [];

    if (doneIds.includes(requestId)) {
      return {
        success: true,
        alreadyDone: true,
        refundAmount: num(rr.refundAmount),
      };
    }

    const subStatus = String(sub.orderStatus || '').toLowerCase();

    if (subStatus !== 'delivered') {
      throw new HttpsError(
        'failed-precondition',
        subStatus === 'returned'
          ? 'This order was already returned completely.'
          : 'Only a delivered order can be returned or refunded.'
      );
    }

    if (sub.payoutDone !== true) {
      throw new HttpsError(
        'failed-precondition',
        'The payout of this order is not completed yet. ' +
          'Complete the payout first, or cancel the order instead.'
      );
    }

    // ---- the returned item, from the server copy of the order ----
    const items = Array.isArray(sub.items) ? sub.items : [];
    const item = items.find((i) => String((i || {}).productId) === productId);

    if (!item) {
      throw new HttpsError('failed-precondition', 'Product not in this order.');
    }

    const boughtQty = Math.max(0, Math.floor(num(item.quantity)));
    const wantQty = Math.max(1, Math.floor(num(rr.quantity) || 1));

    const returnedMap =
      sub.returnedQty && typeof sub.returnedQty === 'object'
        ? sub.returnedQty
        : {};

    const alreadyQty = Math.max(0, Math.floor(num(returnedMap[productId])));

    if (alreadyQty + wantQty > boughtQty) {
      throw new HttpsError(
        'failed-precondition',
        'This product was already returned or refunded.'
      );
    }

    const subBase = isReseller ? num(sub.sellingTotal) : num(sub.subtotal);

    if (!(subBase > 0) || !(num(item.price) > 0)) {
      throw new HttpsError('failed-precondition', 'Invalid order amounts.');
    }

    const lineTotal = round2(num(item.price) * wantQty);

    // Share of the sub-order that is returned (0 < f <= 1).
    const f = Math.min(1, lineTotal / subBase);

    const goodsPaid = subBase - num(sub.discountShare);
    const feePaid = num(sub.serviceFeeShare);

    const goodsRefund = round2(f * goodsPaid);
    const feeRefund = round2(f * feePaid);
    const refundAmount = round2(goodsRefund + feeRefund);

    if (!(refundAmount > 0)) {
      throw new HttpsError('failed-precondition', 'Nothing to refund.');
    }

    const orderRef = db.collection('orders').doc(orderId);
    const orderSnap = await tx.get(orderRef);

    // ---- wallets ----
    const wallets = new Map();

    const loadWallet = async (walletUid) => {
      if (!walletUid) return null;

      if (wallets.has(walletUid)) return wallets.get(walletUid);

      const ref = db.collection('users').doc(walletUid);
      const snap = await tx.get(ref);
      const data = snap.exists ? snap.data() || {} : {};

      const wallet = {
        ref,
        uid: walletUid,
        exists: snap.exists,
        balance: num(data.cashBalance ?? data.walletBalance ?? 0),
        changed: false,
        incomeDelta: 0,
      };

      wallets.set(walletUid, wallet);

      return wallet;
    };

    const buyerWallet = await loadWallet(buyerUid);

    if (!buyerWallet.exists) {
      throw new HttpsError('not-found', 'The buyer wallet was not found.');
    }

    // Who was paid for this sub-order, and how much (read from the real
    // payout transactions, so the right amount is taken back).
    const payees = isReseller
      ? [
          { uid: String(sub.sellerId || ''), role: 'supplier', source: 'supplier_payout' },
          { uid: String(sub.entrepreneurUid || ''), role: 'reseller', source: 'reseller_profit' },
        ]
      : [{ uid: String(sub.sellerId || ''), role: 'seller', source: 'sale_earning' }];

    for (const payee of payees) {
      payee.paid = 0;

      if (!payee.uid) continue;

      const q = await tx.get(
        db
          .collection('users')
          .doc(payee.uid)
          .collection('walletTransactions')
          .where('subOrderId', '==', subId)
      );

      for (const doc of q.docs) {
        const d = doc.data() || {};

        if (
          d.type === 'credit' &&
          d.source === payee.source &&
          d.status === 'approved'
        ) {
          payee.paid = round2(payee.paid + num(d.amount));
        }
      }

      payee.wallet = await loadWallet(payee.uid);
    }

    // BuyNova income that was credited to the admin wallet for this order.
    let adminPaid = 0;
    let adminWallet = null;

    if (adminUid) {
      const adminTxSnap = await tx.get(
        db
          .collection('users')
          .doc(adminUid)
          .collection('walletTransactions')
          .doc(`commission_${subId}`)
      );

      if (adminTxSnap.exists && (adminTxSnap.data() || {}).type === 'credit') {
        adminPaid = num(adminTxSnap.data().amount);
      }

      if (adminPaid > 0) {
        adminWallet = await loadWallet(adminUid);
      }
    }

    // ====================================================================
    // WRITES
    // ====================================================================

    const now = FieldValue.serverTimestamp();

    const base = {
      currency: 'BDT',
      currencySymbol: '৳',
      orderId,
      subOrderId: subId,
      subOrderCollection: subCollection,
      requestId,
      productId,
      quantity: wantQty,
      createdAt: now,
      updatedAt: now,
    };

    // 1) buyer gets the money back
    {
      const before = buyerWallet.balance;
      const after = round2(before + refundAmount);

      buyerWallet.balance = after;
      buyerWallet.changed = true;

      tx.set(
        buyerWallet.ref
          .collection('walletTransactions')
          .doc(`return_refund_${requestId}`),
        {
          ...base,
          type: 'credit',
          source: 'return_refund',
          status: 'approved',
          amount: refundAmount,
          goodsAmount: goodsRefund,
          serviceFeeAmount: feeRefund,
          userId: buyerUid,
          balanceBefore: before,
          balanceAfter: after,
          description: `Refund for returned product in order ${orderId}`,
        }
      );

      tx.set(buyerWallet.ref.collection('notifications').doc(), {
        title: 'Refund Completed',
        message:
          `৳${refundAmount.toFixed(2)} was refunded to your BuyNova ` +
          `Wallet for order ${orderId}.`,
        type: 'return_refund',
        orderId,
        amount: refundAmount,
        currency: 'BDT',
        read: false,
        isRead: false,
        createdAt: now,
      });
    }

    // 2) take back what was paid out for this item
    let takenFromPayees = 0;

    for (const payee of payees) {
      const wallet = payee.wallet;
      const amount = Math.min(payee.paid, round2(f * payee.paid));

      if (!wallet || !wallet.exists || !(amount > 0)) continue;

      const before = wallet.balance;
      const after = round2(before - amount);

      wallet.balance = after;
      wallet.changed = true;

      takenFromPayees = round2(takenFromPayees + amount);

      tx.set(
        wallet.ref
          .collection('walletTransactions')
          .doc(`return_deduction_${requestId}`),
        {
          ...base,
          type: 'debit',
          source: 'return_deduction',
          status: 'approved',
          amount,
          role: payee.role,
          userId: payee.uid,
          balanceBefore: before,
          balanceAfter: after,
          description: `Returned product in order ${orderId}`,
        }
      );
    }

    // 3) take back BuyNova's income (commission + service fee)
    const adminReversal =
      adminWallet && adminWallet.exists
        ? Math.min(adminPaid, round2(f * adminPaid))
        : 0;

    if (adminReversal > 0) {
      const before = adminWallet.balance;
      const after = round2(before - adminReversal);

      adminWallet.balance = after;
      adminWallet.changed = true;
      adminWallet.incomeDelta = round2(adminWallet.incomeDelta - adminReversal);

      tx.set(
        adminWallet.ref
          .collection('walletTransactions')
          .doc(`commission_reversal_${requestId}`),
        {
          ...base,
          type: 'debit',
          source: 'commission',
          status: 'approved',
          amount: adminReversal,
          userId: adminUid,
          balanceBefore: before,
          balanceAfter: after,
          description: `BuyNova income reversed for returned product in order ${orderId}`,
        }
      );

      tx.set(db.collection('buyNovaProfitLedger').doc(`${requestId}_return`), {
        orderId,
        subOrderId: subId,
        subOrderCollection: subCollection,
        requestId,
        source: 'return_refund',
        category: 'return_reversal',
        amount: -adminReversal,
        profitAmount: -adminReversal,
        currency: 'BDT',
        currencySymbol: '৳',
        createdAt: now,
      });
    }

    for (const wallet of wallets.values()) {
      if (!wallet.changed) continue;

      const update = {
        cashBalance: wallet.balance,
        walletBalance: wallet.balance,
        updatedAt: now,
      };

      if (wallet.incomeDelta !== 0) {
        update.totalCommissionEarned = FieldValue.increment(wallet.incomeDelta);
      }

      tx.update(wallet.ref, update);
    }

    // 4) record it on the sub-order, the order and the request
    const newReturnedQty = { ...returnedMap, [productId]: alreadyQty + wantQty };

    const returnedLineTotal = round2(num(sub.returnedLineTotal) + lineTotal);

    const fullyReturned = returnedLineTotal >= round2(subBase) - 0.005;

    const subUpdate = {
      returnedQty: newReturnedQty,
      returnedLineTotal,
      returnedAmount: round2(num(sub.returnedAmount) + refundAmount),
      returnedRequestIds: FieldValue.arrayUnion(requestId),
      updatedAt: now,
    };

    if (fullyReturned) {
      subUpdate.orderStatus = 'returned';
      subUpdate.returnedAt = now;
    }

    tx.update(subRef, subUpdate);

    if (orderSnap.exists) {
      tx.update(orderRef, {
        walletRefundedTotal: FieldValue.increment(refundAmount),
        returnRefundedTotal: FieldValue.increment(refundAmount),
        updatedAt: now,
      });
    }

    tx.update(reqRef, {
      status: 'completed',
      refundDone: true,
      refundAmount,
      refundedAt: now,
      completedAt: now,
      completedBy: uid,
      updatedAt: now,
    });

    return {
      success: true,
      alreadyDone: false,
      refundAmount,
      takenFromSeller: takenFromPayees,
      takenFromAdmin: adminReversal,
      orderReturnedCompletely: fullyReturned,
    };
  });
});

module.exports = { completeReturnRefund };

