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

// Default delivery fees. Admin can override them in
// platformSettings/monetization -> deliveryFeeInsideDhaka / deliveryFeeOutsideDhaka
const FEE_INSIDE_DHAKA = 60;
const FEE_OUTSIDE_DHAKA = 120;
const PAYMENT_METHODS = ['Cash on Delivery', 'BuyNova Wallet'];

// New email + password accounts made on/after this day must have entered the
// email code (same date as the website: CODE_AFTER in hosting/shop/index.html).
const EMAIL_CODE_AFTER = Date.UTC(2026, 9, 27);

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

// A product / listing counts as switched off when either flag is false.
// (Seller products use `isActive`, reseller listings use `active`.)
const isOff = (d) => d.isActive === false || d.active === false;

// Looks in `products` first, then in the admin `Products` collection.
const getProductDoc = async (id) => {
  const snap = await db.collection(COL.products).doc(id).get();
  if (snap.exists) return snap;
  return db.collection(COL.productsAdmin).doc(id).get();
};

// Throws if the product tracks stock and there is not enough of it.
const assertStock = (d, quantity) => {
  const raw = d.stock ?? d.stockQuantity;
  if (raw === undefined || raw === null || raw === '') return;
  const stock = Number(raw);
  if (Number.isFinite(stock) && stock < quantity) {
    throw new HttpsError(
      'failed-precondition',
      'Not enough stock for a product in your cart.'
    );
  }
};

const productName = (d) => String(d.name ?? d.title ?? d.productName ?? '');
const productImage = (d) =>
  d.imageUrl ??
  d.image ??
  (Array.isArray(d.images) && d.images.length ? d.images[0] : null) ??
  null;
const productSeller = (d) => String(d.sellerId ?? d.ownerId ?? 'unknown_seller');

// Delivery fees come from the admin settings; the constants above are the fallback.
const getDeliveryFees = async () => {
  try {
    const snap = await db.doc('platformSettings/monetization').get();
    const c = snap.exists ? snap.data() || {} : {};
    const inside = num(c.deliveryFeeInsideDhaka);
    const outside = num(c.deliveryFeeOutsideDhaka);
    return {
      inside: inside > 0 ? inside : FEE_INSIDE_DHAKA,
      outside: outside > 0 ? outside : FEE_OUTSIDE_DHAKA,
    };
  } catch (e) {
    console.warn('delivery fee config unavailable, using defaults', e);
    return { inside: FEE_INSIDE_DHAKA, outside: FEE_OUTSIDE_DHAKA };
  }
};

// The website asks brand-new email + password accounts for a 6-digit code.
// Here the same rule is enforced on the server, so calling the function
// directly cannot skip it. Google / older accounts are not affected.
const assertEmailCodeDone = async (uid) => {
  let authUser;
  try {
    authUser = await admin.auth().getUser(uid);
  } catch (e) {
    throw new HttpsError('unauthenticated', 'Please login again.');
  }

  const usesPassword = authUser.providerData.some(
    (p) => p.providerId === 'password'
  );
  const created = Date.parse(authUser.metadata?.creationTime || '') || 0;

  if (!usesPassword || created < EMAIL_CODE_AFTER) return;

  const userSnap = await db.doc(`users/${uid}`).get();
  if (!userSnap.exists || userSnap.data()?.emailCodeVerified !== true) {
    throw new HttpsError(
      'failed-precondition',
      'Please verify your email code before placing an order.'
    );
  }
};

// ---------- size / color options ----------
const listOf = (raw) => {
  if (Array.isArray(raw)) {
    return raw.map((x) => String(x ?? '').trim()).filter(Boolean);
  }
  if (typeof raw === 'string') {
    return raw.split(',').map((x) => x.trim()).filter(Boolean);
  }
  return [];
};

const colorNames = (raw) =>
  Array.isArray(raw)
    ? raw
        .filter((c) => c && typeof c === 'object')
        .map((c) => String(c.name ?? c.hex ?? '').trim())
        .filter(Boolean)
    : [];

// Checks the size / color the buyer chose against what the product really
// offers. A wrong value is always rejected. A missing value is rejected only
// when `required` is true (the website sends requireOptions: true).
const resolveOptions = (source, raw, required, name) => {
  const sizes = listOf(source.sizes ?? source.availableSizes).map((s) =>
    s.toUpperCase()
  );
  const colors = colorNames(source.colors);

  const wantSize = String(raw?.size ?? '').trim().toUpperCase();
  const wantColor = String(raw?.color ?? '').trim();

  let size = null;
  let color = null;

  if (sizes.length) {
    if (wantSize) {
      if (!sizes.includes(wantSize)) {
        throw new HttpsError(
          'invalid-argument',
          `The selected size is not available for "${name}".`
        );
      }
      size = wantSize;
    } else if (required) {
      throw new HttpsError(
        'failed-precondition',
        `Please select a size for "${name}".`
      );
    }
  }

  if (colors.length) {
    if (wantColor) {
      const found = colors.find(
        (c) => c.toLowerCase() === wantColor.toLowerCase()
      );
      if (!found) {
        throw new HttpsError(
          'invalid-argument',
          `The selected color is not available for "${name}".`
        );
      }
      color = found;
    } else if (required) {
      throw new HttpsError(
        'failed-precondition',
        `Please select a color for "${name}".`
      );
    }
  }

  return { size, color };
};

// ============================================================
// createOrder
// Everyone (Buyer, Seller, Reseller) uses the same checkout.
// The only restriction: nobody can buy their own product/listing.
// The client only sends WHAT it wants (product ids + quantities,
// plus the chosen size / color).
// Prices, discount, delivery fee and totals are all computed here.
//
// Product discounts: `price` (seller) and `sellingPrice` (reseller)
// are already the price AFTER the product discount, so they are used
// as they are. `originalPrice` is only for display.
// ============================================================
exports.createOrder = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Please login again.');

  const { items, couponCode, paymentMethod, addressId, requireOptions } =
    request.data || {};

  const mustChooseOptions = requireOptions === true;

  if (!Array.isArray(items) || items.length === 0 || items.length > 50) {
    throw new HttpsError('invalid-argument', 'Your cart is empty.');
  }
  if (!PAYMENT_METHODS.includes(paymentMethod)) {
    throw new HttpsError('invalid-argument', 'Invalid payment method.');
  }

  // New email + password accounts must finish the email code first.
  await assertEmailCodeDone(uid);

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
  const fees = await getDeliveryFees();
  const deliveryFee = zone === 'inside_dhaka' ? fees.inside : fees.outside;

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

        const supplierProductId = safeId(
          listing.supplierProductId ?? listing.sourceProductId
        );
        const supplierSnap = supplierProductId
          ? await getProductDoc(supplierProductId)
          : null;

        if (!supplierSnap || !supplierSnap.exists) {
          throw new HttpsError('not-found', 'A product in your cart is no longer available.');
        }
        const supplier = supplierSnap.data();

        if (isOff(listing) || isOff(supplier) || supplier.sellerApproved === false) {
          throw new HttpsError('failed-precondition', 'A product in your cart is unavailable.');
        }
        assertStock(supplier, quantity);

        const price = num(listing.sellingPrice ?? listing.price);
        const supplierPrice = num(supplier.price);

        if (!(price > 0) || !(supplierPrice > 0) || price < supplierPrice) {
          throw new HttpsError('failed-precondition', 'A product in your cart has an invalid price.');
        }

        const lineName = productName(listing) || productName(supplier);

        // Sizes and colors come from the supplier's product.
        const { size, color } = resolveOptions(
          supplier,
          raw,
          mustChooseOptions,
          lineName
        );

        return {
          id,
          name: lineName,
          imageUrl: productImage(listing) ?? productImage(supplier),
          price,
          quantity,
          total: round2(price * quantity),
          size,
          color,
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

      if (isOff(product) || product.sellerApproved === false) {
        throw new HttpsError('failed-precondition', 'A product in your cart is unavailable.');
      }
      assertStock(product, quantity);

      const price = num(product.price);
      if (!(price > 0)) {
        throw new HttpsError('failed-precondition', 'A product in your cart has an invalid price.');
      }

      const lineName = productName(product);

      const { size, color } = resolveOptions(
        product,
        raw,
        mustChooseOptions,
        lineName
      );

      return {
        id,
        name: lineName,
        imageUrl: productImage(product),
        price,
        quantity,
        total: round2(price * quantity),
        size,
        color,
        isResellerProduct: false,
        entrepreneurUid: null,
        sellerId: productSeller(product),
        supplierProductId: null,
        supplierPrice: null,
        resellerProfit: null,
      };
    })
  );

  // ---------------- Own-product check --------------------------------
  // Nobody can buy their own product:
  //  - a seller cannot buy his own product (sellerId)
  //  - a reseller cannot buy his own listing (entrepreneurUid)
  //  - for a reseller listing, the supplier (sellerId) is also checked,
  //    so a seller cannot buy a reseller listing of his own product
  const ownItem = lines.some(
    (l) => l.sellerId === uid || l.entrepreneurUid === uid
  );
  if (ownItem) {
    throw new HttpsError(
      'failed-precondition',
      'You cannot buy your own product.'
    );
  }

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
          `Minimum order amount is ৳${minimumOrder.toFixed(2)}.`
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
    // The buyer can read this document, so it must NOT contain the
    // supplier price or the reseller profit. Those stay only in the
    // reseller_orders document.
    const orderItems = lines.map((l) => ({
      productId: l.id,
      name: l.name,
      price: l.price,
      quantity: l.quantity,
      total: l.total,
      size: l.size,
      color: l.color,
      imageUrl: l.imageUrl,
      isResellerProduct: l.isResellerProduct,
      entrepreneurUid: l.entrepreneurUid,
      sellerId: l.sellerId,
      supplierProductId: l.supplierProductId,
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

    // ----- Group lines: per seller, and per reseller+supplier -----
    const sellerGroups = new Map();
    for (const l of lines.filter((x) => !x.isResellerProduct)) {
      if (!sellerGroups.has(l.sellerId)) sellerGroups.set(l.sellerId, []);
      sellerGroups.get(l.sellerId).push(l);
    }

    const resellerGroups = new Map();
    for (const l of lines.filter((x) => x.isResellerProduct)) {
      const key = `${l.entrepreneurUid}_${l.sellerId}`;
      if (!resellerGroups.has(key)) resellerGroups.set(key, []);
      resellerGroups.get(key).push(l);
    }

    // ----- Split the coupon discount -----
    // Whoever sells the product bears the discount on it, in proportion to
    // that sub-order's share of the subtotal:
    //   normal seller -> comes out of the seller's earning
    //   reseller      -> comes out of the reseller's profit
    // The supplier of a reseller product is never reduced.
    const parts = [
      ...[...sellerGroups.values()].map((g) => ({ type: 'seller', group: g })),
      ...[...resellerGroups.values()].map((g) => ({ type: 'reseller', group: g })),
    ];

    let allocated = 0;
    parts.forEach((p, i) => {
      p.base = round2(p.group.reduce((s, l) => s + l.total, 0));

      let share;
      if (i === parts.length - 1) {
        share = round2(discount - allocated); // remainder, so shares add up exactly
      } else {
        share = subtotal > 0 ? round2((discount * p.base) / subtotal) : 0;
      }

      p.discountShare = Math.min(p.base, Math.max(0, share));
      allocated = round2(allocated + p.discountShare);
    });

    // ----- Seller orders -----
    for (const p of parts.filter((x) => x.type === 'seller')) {
      const group = p.group;
      const ref = db.collection(COL.sellerOrders).doc();
      tx.set(ref, {
        orderId,
        sellerOrderId: ref.id,
        sellerId: group[0].sellerId,
        buyerId: uid,
        customerId: uid,
        userId: uid,
        items: group.map((l) => ({
          productId: l.id,
          name: l.name,
          price: l.price,
          quantity: l.quantity,
          total: l.total,
          size: l.size,
          color: l.color,
          imageUrl: l.imageUrl,
        })),
        subtotal: p.base,
        discountShare: p.discountShare,
        sellerEarning: round2(p.base - p.discountShare),
        currency: 'BDT',
        paymentMethod,
        paymentStatus: 'pending',
        orderStatus: 'placed',
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    // ----- Reseller orders -----
    for (const p of parts.filter((x) => x.type === 'reseller')) {
      const group = p.group;
      const first = group[0];
      const sellingTotal = p.base;
      const supplierTotal = round2(
        group.reduce((s, l) => s + l.supplierPrice * l.quantity, 0)
      );

      // profit = selling total - this reseller's share of the coupon - supplier total
      const profit = round2(sellingTotal - p.discountShare - supplierTotal);

      if (profit < 0) {
        throw new HttpsError(
          'failed-precondition',
          'This coupon cannot be used with a reseller product in your cart.'
        );
      }

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
          size: l.size,
          color: l.color,
          imageUrl: l.imageUrl,
          supplierProductId: l.supplierProductId,
          supplierPrice: l.supplierPrice,
          resellerProfit: l.resellerProfit,
        })),
        sellingTotal,
        supplierTotal,
        supplierEarning: supplierTotal,
        couponDiscount: p.discountShare,
        discountShare: p.discountShare,
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
