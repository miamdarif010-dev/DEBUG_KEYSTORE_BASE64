const admin = require('firebase-admin');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();

const REGION = 'asia-northeast3';

const safeId = (v) => {
  const s = String(v || '');
  return s && !s.includes('/') ? s : '';
};

const getProductDoc = async (id) => {
  const snap = await db.collection('products').doc(id).get();
  if (snap.exists) return snap;
  return db.collection('Products').doc(id).get();
};

const unavailable = () =>
  new HttpsError('failed-precondition', 'This product is no longer available.');

const pick = (...vals) =>
  vals.find((v) => v !== undefined && v !== null && v !== '');

const collectImages = (...sources) => {
  const images = [];
  const add = (v) => {
    if (typeof v === 'string' && v.trim() && !images.includes(v.trim())) {
      images.push(v.trim());
    } else if (Array.isArray(v)) {
      v.forEach(add);
    }
  };
  sources.forEach(add);
  return images;
};

// ============================================================
// getResellerListing  (link: /r/<reseller_products id>)
// Returns ONLY public fields. supplierPrice and profit are
// never returned.
// ============================================================
// Regular price of a reseller listing (null when there is no discount).
// Falls back to the stored percent for listings saved without originalPrice.
const resellerOriginalPrice = (listing) => {
  const selling = Number(pick(listing.sellingPrice, listing.price)) || 0;
  const stored = Number(listing.originalPrice) || 0;
  if (stored > selling) return stored;

  const percent = Number(listing.discountPercent) || 0;
  if (percent > 0 && percent < 100 && selling > 0) {
    return Math.round((selling / (1 - percent / 100)) * 100) / 100;
  }
  return null;
};

exports.getResellerListing = onCall({ region: REGION }, async (request) => {
  const listingId = safeId(request.data?.listingId);
  if (!listingId) throw new HttpsError('invalid-argument', 'Invalid link.');

  const listingSnap = await db.collection('reseller_products').doc(listingId).get();
  if (!listingSnap.exists) throw unavailable();
  const listing = listingSnap.data();
  if (listing.isActive === false || listing.active === false) throw unavailable();

  const supplierProductId = safeId(
    listing.supplierProductId ?? listing.sourceProductId
  );
  if (!supplierProductId) throw unavailable();

  const supplierSnap = await getProductDoc(supplierProductId);
  if (!supplierSnap.exists) throw unavailable();
  const supplier = supplierSnap.data();
  if (supplier.isActive === false || supplier.active === false) throw unavailable();

  const resellerUid = String(listing.entrepreneurUid || '');
  if (!resellerUid) throw unavailable();

  const resellerSnap = await db.doc(`users/${resellerUid}`).get();
  const reseller = resellerSnap.data() || {};
  if (String(reseller.entrepreneurStatus || 'none') !== 'approved') {
    throw unavailable();
  }

  const images = collectImages(
    listing.imageUrl,
    listing.images,
    supplier.imageUrl,
    supplier.imageUrls,
    supplier.images
  );

  return {
    listing: {
      name: String(pick(listing.name, listing.title, supplier.name, supplier.title) ?? ''),
      description: String(pick(listing.description, supplier.description) ?? ''),
      imageUrl: images[0] ?? '',
      images,
      videoUrl: String(pick(supplier.videoUrl, supplier.productVideoUrl) ?? ''),
      category: String(pick(listing.category, supplier.category) ?? ''),
      sizes: pick(supplier.sizes, supplier.availableSizes) ?? null,
      colors: supplier.colors ?? null,
      stock: pick(supplier.stock, supplier.stockQuantity) ?? null,
      price: Number(pick(listing.sellingPrice, listing.price)) || 0,
      originalPrice: resellerOriginalPrice(listing),
      discountPercent: Number(listing.discountPercent) || 0,
      currency: 'BDT',
      isResellerProduct: true,
      entrepreneurUid: resellerUid,
      entrepreneurName: String(pick(reseller.name, reseller.displayName) ?? ''),
      sellerId: String(pick(supplier.sellerId, supplier.ownerId) ?? ''),
    },
  };
});

// ============================================================
// getProductListing  (link: /p/<products id>)
// Normal seller product. Returns ONLY public fields.
// ============================================================
exports.getProductListing = onCall({ region: REGION }, async (request) => {
  const productId = safeId(request.data?.productId);
  if (!productId) throw new HttpsError('invalid-argument', 'Invalid link.');

  const snap = await getProductDoc(productId);
  if (!snap.exists) throw unavailable();
  const p = snap.data();
  if (p.isActive === false || p.active === false) throw unavailable();

  const images = collectImages(
    p.imageUrl,
    p.productImageUrl,
    p.imageUrls,
    p.images,
    p.productImages,
    p.gallery
  );

  // Same rule as the app: if currency is not BDT, price * 0.09
  const raw = Number(pick(p.price, p.sellingPrice)) || 0;
  const cur = String(p.currency || '').trim().toUpperCase();
  const factor = cur === 'BDT' || cur === '৳' ? 1 : 0.09;
  const price = raw * factor;
  const originalRaw = Number(p.originalPrice) || 0;
  const originalPrice = originalRaw > 0 ? originalRaw * factor : null;

  return {
    listing: {
      name: String(pick(p.name, p.productName, p.title) ?? ''),
      description: String(p.description ?? ''),
      imageUrl: images[0] ?? '',
      images,
      videoUrl: String(pick(p.videoUrl, p.productVideoUrl) ?? ''),
      category: String(p.category ?? ''),
      sizes: pick(p.sizes, p.availableSizes) ?? null,
      colors: p.colors ?? null,
      stock: pick(p.stock, p.stockQuantity) ?? null,
      price: Math.round(price * 100) / 100,
      originalPrice: originalPrice ? Math.round(originalPrice * 100) / 100 : null,
      discountPercent: Number(p.discountPercent) || 0,
      currency: 'BDT',
      isResellerProduct: false,
      sellerId: String(pick(p.sellerId, p.ownerId) ?? ''),
      sellerName: String(p.sellerName ?? ''),
      sellerCode: String(p.sellerCode ?? ''),
    },
  };
});


// ============================================================
// downloadApp
// Streams the APK from Firebase Storage as a real file download
// (Content-Disposition: attachment), so tapping the button on the
// web page downloads it directly instead of opening a preview page.
// Link: https://asia-northeast3-<project>.cloudfunctions.net/downloadApp
// ============================================================
const APK_BUCKET = 'buynova-cc5dd.firebasestorage.app';
const APK_PATH = 'app-release.apk';

exports.downloadApp = onRequest(
  { region: REGION, memory: '512MiB', timeoutSeconds: 540, cors: true },
  async (req, res) => {
    try {
      const file = admin.storage().bucket(APK_BUCKET).file(APK_PATH);
      const [exists] = await file.exists();

      if (!exists) {
        res.status(404).send('App file not found.');
        return;
      }

            res.setHeader('Content-Type', 'application/vnd.android.package-archive');
      res.setHeader('Content-Disposition', 'attachment; filename="BuyNova.apk"');
      res.setHeader('Cache-Control', 'no-store');
      // No Content-Length on purpose: Cloud Run only allows responses over
      // 32 MiB when they are streamed (chunked), and the APK is bigger.

      file
        .createReadStream()
        .on('error', (e) => {
          console.error('APK stream failed:', e);
          if (!res.headersSent) res.status(500).send('Download failed.');
          else res.end();
        })
        .pipe(res);
    } catch (e) {
      console.error('downloadApp failed:', e);
      res.status(500).send('Download failed.');
    }
  }
);

// ============================================================
// getPublicStore
// Public profile data for a seller / reseller (opened from the
// product page). Anyone logged in can call it, it returns ONLY
// safe fields: no email, phone, wallet, supplier price or profit.
// A reseller's store lists only the reseller's own listings; the
// supplier behind them is never shown.
// ============================================================
const PUBLIC_STORE_LIMIT = 60;

const toBdt = (value, currency) => {
  const cur = String(currency || '').trim().toUpperCase();
  const factor = cur === 'BDT' || cur === '৳' ? 1 : 0.09;
  return Math.round((Number(value) || 0) * factor * 100) / 100;
};

exports.getPublicStore = onCall({ region: REGION }, async (request) => {
  const userId = safeId(request.data?.userId);
  if (!userId) throw new HttpsError('invalid-argument', 'Invalid user.');

  const userSnap = await db.doc(`users/${userId}`).get();
  if (!userSnap.exists) throw new HttpsError('not-found', 'User not found.');
  const user = userSnap.data() || {};

  const isSeller = String(user.sellerStatus || 'none') === 'approved';
  const isEntrepreneur = String(user.entrepreneurStatus || 'none') === 'approved';

  // ---------- seller products ----------
  const sellerProducts = [];

  if (isSeller) {
    const snap = await db
      .collection('products')
      .where('sellerId', '==', userId)
      .limit(PUBLIC_STORE_LIMIT)
      .get();

    for (const doc of snap.docs) {
      const p = doc.data();
      if (p.isActive === false || p.active === false) continue;
      if (p.sellerApproved === false) continue;

      const price = toBdt(pick(p.price, p.sellingPrice), p.currency);
      const original = toBdt(p.originalPrice, p.currency);

      sellerProducts.push({
        id: doc.id,
        name: String(pick(p.name, p.productName, p.title) ?? ''),
        imageUrl: String(collectImages(p.imageUrl, p.imageUrls, p.images)[0] ?? ''),
        price,
        originalPrice: original > price ? original : null,
        category: String(p.category ?? ''),
      });
    }
  }

  // ---------- reseller store ----------
  const resellerProducts = [];

  if (isEntrepreneur) {
    const snap = await db
      .collection('reseller_products')
      .where('entrepreneurUid', '==', userId)
      .limit(PUBLIC_STORE_LIMIT)
      .get();

    const listings = snap.docs.filter((d) => {
      const l = d.data();
      return l.active !== false && l.isActive !== false;
    });

    // Hide listings whose original product was removed or switched off.
    const sourceRefs = listings.map((d) => {
      const l = d.data();
      const id = safeId(l.supplierProductId ?? l.sourceProductId);
      return db.collection('products').doc(id || '_missing_');
    });

    const sourceSnaps = sourceRefs.length ? await db.getAll(...sourceRefs) : [];

    listings.forEach((doc, i) => {
      const l = doc.data();
      const source = sourceSnaps[i];

      if (!source || !source.exists) return;

      const s = source.data() || {};
      if (s.isActive === false || s.active === false) return;

      const price = Number(pick(l.sellingPrice, l.price)) || 0;
      if (!(price > 0)) return;

      resellerProducts.push({
        id: doc.id,
        name: String(pick(l.productName, l.name, s.name) ?? ''),
        imageUrl: String(pick(l.imageUrl, collectImages(s.imageUrl, s.imageUrls, s.images)[0]) ?? ''),
        price,
        originalPrice: resellerOriginalPrice(l),
        category: String(pick(l.category, s.category) ?? ''),
      });
    });
  }

  return {
    profile: {
      userId,
      name: String(pick(user.name, user.displayName) ?? ''),
      shopName: String(pick(user.shopName, user.storeName) ?? ''),
      profileImageUrl: String(user.profileImageUrl ?? ''),
      isSeller,
      isEntrepreneur,
    },
    sellerProducts,
    resellerProducts,
  };
});
