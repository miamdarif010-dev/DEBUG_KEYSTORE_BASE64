const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');

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
exports.getResellerListing = onCall({ region: REGION }, async (request) => {
  const listingId = safeId(request.data?.listingId);
  if (!listingId) throw new HttpsError('invalid-argument', 'Invalid link.');

  const listingSnap = await db.collection('reseller_products').doc(listingId).get();
  if (!listingSnap.exists) throw unavailable();
  const listing = listingSnap.data();
  if (listing.isActive === false) throw unavailable();

  const supplierProductId = safeId(
    listing.supplierProductId ?? listing.sourceProductId
  );
  if (!supplierProductId) throw unavailable();

  const supplierSnap = await getProductDoc(supplierProductId);
  if (!supplierSnap.exists) throw unavailable();
  const supplier = supplierSnap.data();
  if (supplier.isActive === false) throw unavailable();

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
  if (p.isActive === false) throw unavailable();

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
  const price = cur === 'BDT' || cur === '৳' ? raw : raw * 0.09;

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
      currency: 'BDT',
      isResellerProduct: false,
      sellerId: String(pick(p.sellerId, p.ownerId) ?? ''),
      sellerName: String(p.sellerName ?? ''),
      sellerCode: String(p.sellerCode ?? ''),
    },
  };
});
