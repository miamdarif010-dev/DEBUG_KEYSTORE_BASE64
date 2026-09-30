const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

// ============================================================
// CONFIG - change these if your Firestore names are different
// ============================================================
const REGION = 'asia-northeast3';

const COL = {
  products: 'products', // seller products
  productsAdmin: 'Products', // admin products (capital P)
  resellerProducts: 'reseller_products', // reseller listing (selling price set by entrepreneur)
  coupons: 'coupons',
  orders: 'orders',
  sellerOrders: 'seller_orders',
  resellerOrders: 'reseller_orders',
};

const FEE_INSIDE_DHAKA = 60;
const FEE_OUTSIDE_DHAKA = 120;
const PAYMENT_METHODS = ['Cash on Delivery', 'BuyNova Wallet'];

// ============================================================
// HELPERS
// ============================================================
const num = (v) => {
  if (typeof v === 'number') return v;
  const n = parseFloat(v);
  return Number.isFinite(n) ? n : 0;
};

const round2 = (n) => Math.round(n * 100) / 100;

const toDate = (v) => {
  if (!v) return null;
  if (typeof v.toDate === 'function') return v.toDate();
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
};

const safeId = (v) => {
  const s = String(v || '');
  return s && !s.includes('/') ? s : '';
};

// Looks in `products` first, then in the admin `Products` collection.
const getProductDoc = async (id) => {
  const snap = await db.collection(COL.products).doc(id).get();
  if (snap.exists) return snap;
  return db.collection(COL.productsAdmin).doc(id).get();
};

const productName = (d) => String(d.name ?? d.title ?? '');
const productImage = (d) =>
  d.imageUrl ??
  d.image ??
  (Array.isArray(d.images) && d.images.length ? d.images[0] : null) ??
  null;
const productSeller = (d) => String(d.sellerId ?? d.ownerId ?? 'unknown_seller');

// ============================================================
// createOrder
// The client only sends WHAT it wants (product ids + quantities).
// Prices, discount, delivery fee and totals are all computed here.
// ============================================================
exports.createOrder = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Please login again.');

  const { items, couponCode, paymentMethod, addressId } = request.data || {};

  if (!Array.isArray(items) || items.length === 0 || items.length > 50) {
    throw new HttpsError('invalid-argument', 'Your cart is empty.');
  }
  if (!PAYMENT_METHODS.includes(paymentMethod)) {
    throw new HttpsError('invalid-argument', 'Invalid payment method.');
  }

  // ---------------- Address (read from Firestore, not from client) ----
  let address;
  const cleanAddressId = safeId(addressId);

  if (cleanAddressId) {
    const snap = await db.doc(`users/${uid}/addresses/${cleanAddressId}`).get();
    address = snap.data();
  } else {
    const snap = await db.doc(`users/${uid}`).get();
    address = snap.data()?.address;
  }

  if (!address || typeof address !== 'object') {
    throw new HttpsError('failed-precondition', 'Please select a delivery address.');
  }

  const zone = address.deliveryZone;
  if (zone !== 'inside_dhaka' && zone !== 'outside_dhaka') {
    throw new HttpsError(
      'failed-precondition',
      'Please edit your address and choose Inside Dhaka or Outside Dhaka.'
    );
  }
  const deliveryFee = zone === 'inside_dhaka' ? FEE_INSIDE_DHAKA : FEE_OUTSIDE_DHAKA;

  // ---------------- Items (prices from Firestore) ---------------------
  const lines = await Promise.all(
    items.map(async (raw) => {
      const id = safeId(raw?.productId);
      const quantity = Number.parseInt(raw?.quantity, 10);

      if (!id || !(quantity > 0) || quantity > 100) {
        throw new HttpsError('invalid-argument', 'Invalid item in cart.');
      }

      // ----- Reseller product -----
      if (raw?.isResellerProduct === true) {
        const listingSnap = await db.collection(COL.resellerProducts).doc(id).get();
        if (!listingSnap.exists) {
          throw new HttpsError('not-found', 'A product in your cart is no longer available.');
        }
        const listing = listingSnap.data();

        const supplierProductId = safeId(listing.supplierProductId);
        const supplierSnap = supplierProductId
          ? await getProductDoc(supplierProductId)
          : null;

        if (!supplierSnap || !supplierSnap.exists) {
          throw new HttpsError('not-found', 'A product in your cart is no longer available.');
        }
        const supplier = supplierSnap.data();

        if (listing.isActive === false || supplier.isActive === false) {
          throw new HttpsError('failed-precondition', 'A product in your cart is unavailable.');
        }

        const price = num(listing.sellingPrice ?? listing.price);
        const supplierPrice = num(supplier.price);

        if (!(price > 0) || !(supplierPrice > 0) || price < supplierPrice) {
          throw new HttpsError('failed-precondition', 'A product in your cart has an invalid price.');
        }

        return {
          id,
          name: productName(listing) || productName(supplier),
          imageUrl: productImage(listing) ?? productImage(supplier),
          price,
          quantity,
          total: round2(price * quantity),
          isResellerProduct: true,
          entrepreneurUid: String(listing.entrepreneurUid ?? ''),
          sellerId: productSeller(supplier),
          supplierProductId,
          supplierPrice,
          resellerProfit: round2(price - supplierPrice),
        };
      }

      // ----- Normal product -----
      const productSnap = await getProductDoc(id);
      if (!productSnap.exists) {
        throw new HttpsError('not-found', 'A product in your cart is no longer available.');
      }
      const product = productSnap.data();

      if (product.isActive === false) {
        throw new HttpsError('failed-precondition', 'A product in your cart is unavailable.');
      }

      const price = num(product.price);
      if (!(price > 0)) {
        throw new HttpsError('failed-precondition', 'A product in your cart has an invalid price.');
      }

      return {
        id,
        name: productName(product),
        imageUrl: productImage(product),
        price,
        quantity,
        total: round2(price * quantity),
        isResellerProduct: false,
        entrepreneurUid: null,
        sellerId: productSeller(product),
        supplierProductId: null,
        supplierPrice: null,
        resellerProfit: null,
      };
    })
  );

  const subtotal = round2(lines.reduce((sum, l) => sum + l.total, 0));

  // ---------------- Transaction: coupon + order writes ----------------
  const orderRef = db.collection(COL.orders).doc();
  const orderId = orderRef.id;

  let discount = 0;
  let appliedCode = null;
  let grandTotal = 0;

  await db.runTransaction(async (tx) => {
    discount = 0;
    appliedCode = null;

    // ----- Coupon (all reads before writes) -----
    const code = String(couponCode || '').trim().toUpperCase();

    if (code) {
      const q = await tx.get(
        db.collection(COL.coupons).where('code', '==', code).limit(1)
      );

      if (q.empty) throw new HttpsError('failed-precondition', 'Invalid coupon code.');

      const couponRef = q.docs[0].ref;
      const c = q.docs[0].data();

      if (c.isActive !== true) {
        throw new HttpsError('failed-precondition', 'This coupon is not active.');
      }

      const expiry = toDate(c.expiresAt);
      if (expiry && expiry.getTime() < Date.now()) {
        throw new HttpsError('failed-precondition', 'This coupon has expired.');
      }

      const usageLimit = num(c.usageLimit);
      if (usageLimit > 0 && num(c.usedCount) >= usageLimit) {
        throw new HttpsError('failed-precondition', 'This coupon has reached its usage limit.');
      }

      const minimumOrder = num(c.minimumOrder);
      if (minimumOrder > 0 && subtotal < minimumOrder) {
        throw new HttpsError(
          'failed-precondition',
          `Minimum order amount is ā§ģ${minimumOrder.toFixed(2)}.`
        );
      }

      const type = String(c.discountType ?? 'fixed').toLowerCase().trim();
      const value = num(c.discountValue);
      const maxDiscount = num(c.maximumDiscount);

      let d = type === 'percentage' ? (subtotal * value) / 100 : value;
      if (type === 'percentage' && maxDiscount > 0 && d > maxDiscount) d = maxDiscount;
      if (d < 0) d = 0;
      if (d > subtotal) d = subtotal;

      discount = round2(d);
      appliedCode = code;

      tx.update(couponRef, { usedCount: FieldValue.increment(1) });
    }

    grandTotal = Math.max(0, round2(subtotal + deliveryFee - discount));

    // ----- Main order -----
    const orderItems = lines.map((l) => ({
      productId: l.id,
      name: l.name,
      price: l.price,
      quantity: l.quantity,
      total: l.total,
      imageUrl: l.imageUrl,
      isResellerProduct: l.isResellerProduct,
      entrepreneurUid: l.entrepreneurUid,
      sellerId: l.sellerId,
      supplierProductId: l.supplierProductId,
      supplierPrice: l.supplierPrice,
      resellerProfit: l.resellerProfit,
    }));

    tx.set(orderRef, {
      orderId,
      userId: uid,
      customerId: uid,
      items: orderItems,
      subtotal,
      deliveryFee,
      deliveryZone: zone,
      discount,
      total: grandTotal,
      grandTotal,
      currency: 'BDT',
      couponCode: appliedCode,
      paymentMethod,
      paymentStatus: 'pending',
      orderStatus: 'placed',
      address,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    // ----- Seller orders -----
    const sellerGroups = new Map();
    for (const l of lines.filter((x) => !x.isResellerProduct)) {
      if (!sellerGroups.has(l.sellerId)) sellerGroups.set(l.sellerId, []);
      sellerGroups.get(l.sellerId).push(l);
    }

    for (const [sellerId, group] of sellerGroups) {
      const ref = db.collection(COL.sellerOrders).doc();
      tx.set(ref, {
        orderId,
        sellerOrderId: ref.id,
        sellerId,
        buyerId: uid,
        customerId: uid,
        userId: uid,
        items: group.map((l) => ({
          productId: l.id,
          name: l.name,
          price: l.price,
          quantity: l.quantity,
          total: l.total,
          imageUrl: l.imageUrl,
        })),
        subtotal: round2(group.reduce((s, l) => s + l.total, 0)),
        currency: 'BDT',
        paymentMethod,
        paymentStatus: 'pending',
        orderStatus: 'placed',
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    // ----- Reseller orders -----
    const resellerGroups = new Map();
    for (const l of lines.filter((x) => x.isResellerProduct)) {
      const key = `${l.entrepreneurUid}_${l.sellerId}`;
      if (!resellerGroups.has(key)) resellerGroups.set(key, []);
      resellerGroups.get(key).push(l);
    }

    for (const group of resellerGroups.values()) {
      const first = group[0];
      const sellingTotal = round2(group.reduce((s, l) => s + l.total, 0));
      const supplierTotal = round2(
        group.reduce((s, l) => s + l.supplierPrice * l.quantity, 0)
      );
      const profit = round2(sellingTotal - supplierTotal);

      const ref = db.collection(COL.resellerOrders).doc();
      tx.set(ref, {
        orderId,
        resellerOrderId: ref.id,
        entrepreneurUid: first.entrepreneurUid,
        buyerId: uid,
        customerId: uid,
        userId: uid,
        sellerId: first.sellerId,
        customerName: String(address.name ?? ''),
        customerPhone: String(address.phone ?? ''),
        address: String(address.address ?? address.addressLine1 ?? ''),
        deliveryZone: zone,
        items: group.map((l) => ({
          productId: l.id,
          name: l.name,
          price: l.price,
          quantity: l.quantity,
          total: l.total,
          imageUrl: l.imageUrl,
          supplierProductId: l.supplierProductId,
          supplierPrice: l.supplierPrice,
          resellerProfit: l.resellerProfit,
        })),
        sellingTotal,
        supplierTotal,
        resellerProfit: profit,
        profit,
        currency: 'BDT',
        paymentMethod,
        paymentStatus: 'pending',
        orderStatus: 'placed',
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  });

  return { success: true, orderId, subtotal, deliveryFee, discount, total: grandTotal };
});

// ============================================================
// cancelUnpaidOrder
// Called by the app when a Wallet payment fails after the order was
// created, so no unpaid "placed" order is left behind.
// ============================================================
exports.cancelUnpaidOrder = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Please login again.');

  const orderId = safeId(request.data?.orderId);
  if (!orderId) throw new HttpsError('invalid-argument', 'Invalid order.');

  const orderRef = db.collection(COL.orders).doc(orderId);
  const snap = await orderRef.get();

  if (!snap.exists) return { success: true };

  const order = snap.data();

  if (order.userId !== uid) {
    throw new HttpsError('permission-denied', 'Not allowed.');
  }
  if (order.paymentMethod !== 'BuyNova Wallet' || order.paymentStatus === 'paid') {
    throw new HttpsError('failed-precondition', 'This order cannot be cancelled here.');
  }

  const [sellerSnap, resellerSnap] = await Promise.all([
    db.collection(COL.sellerOrders).where('orderId', '==', orderId).get(),
    db.collection(COL.resellerOrders).where('orderId', '==', orderId).get(),
  ]);

  const batch = db.batch();

  sellerSnap.docs.forEach((d) => batch.delete(d.ref));
  resellerSnap.docs.forEach((d) => batch.delete(d.ref));
  batch.delete(orderRef);

  if (order.couponCode) {
    const q = await db
      .collection(COL.coupons)
      .where('code', '==', order.couponCode)
      .limit(1)
      .get();
    if (!q.empty) {
      batch.update(q.docs[0].ref, { usedCount: FieldValue.increment(-1) });
    }
  }

  await batch.commit();
  return { success: true };
});
