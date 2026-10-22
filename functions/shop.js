const admin = require('firebase-admin');
const { onCall } = require('firebase-functions/v2/https');

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();
const REGION = 'asia-northeast3';
const LIMIT = 150;

const safeId = (v) => {
  const s = String(v || '');
  return s && !s.includes('/') ? s : '';
};

const pick = (...vals) =>
  vals.find((v) => v !== undefined && v !== null && v !== '');

const isOff = (d) => d.isActive === false || d.active === false;

const firstImage = (...sources) => {
  for (const v of sources) {
    if (typeof v === 'string' && v.trim()) return v.trim();
    if (Array.isArray(v)) {
      const f = v.find((x) => typeof x === 'string' && x.trim());
      if (f) return f.trim();
    }
  }
  return '';
};

const toBdt = (value, currency) => {
  const cur = String(currency || '').trim().toUpperCase();
  const factor = cur === 'BDT' || cur === '৳' ? 1 : 0.09;
  return Math.round((Number(value) || 0) * factor * 100) / 100;
};

const resellerOriginal = (l) => {
  const selling = Number(pick(l.sellingPrice, l.price)) || 0;
  const stored = Number(l.originalPrice) || 0;
  if (stored > selling) return stored;
  const percent = Number(l.discountPercent) || 0;
  if (percent > 0 && percent < 100 && selling > 0) {
    return Math.round((selling / (1 - percent / 100)) * 100) / 100;
  }
  return null;
};

// ============================================================
// getShopProducts
// Public product list for the customer website (/shop/).
// Returns ONLY public fields: no supplier price, no profit.
// ============================================================
exports.getShopProducts = onCall({ region: REGION }, async () => {
  const items = [];
  const seen = new Set();

  // ---------- normal products (seller + admin) ----------
  for (const col of ['products', 'Products']) {
    const snap = await db.collection(col).limit(LIMIT).get();
    for (const doc of snap.docs) {
      if (seen.has(doc.id)) continue;
      const p = doc.data() || {};
      if (isOff(p) || p.sellerApproved === false) continue;

      const price = toBdt(pick(p.price, p.sellingPrice), p.currency);
      if (!(price > 0)) continue;
      const original = toBdt(p.originalPrice, p.currency);

      seen.add(doc.id);
      items.push({
        id: doc.id,
        kind: 'p',
        name: String(pick(p.name, p.productName, p.title) ?? ''),
        imageUrl: firstImage(
          p.imageUrl,
          p.productImageUrl,
          p.imageUrls,
          p.images,
          p.productImages,
          p.gallery
        ),
        price,
        originalPrice: original > price ? original : null,
        category: String(p.category ?? ''),
      });
    }
  }

  // ---------- reseller listings ----------
  const listSnap = await db.collection('reseller_products').limit(LIMIT).get();
  const listings = listSnap.docs.filter((d) => !isOff(d.data() || {}));

  const supplierIds = listings.map((d) => {
    const l = d.data() || {};
    return safeId(l.supplierProductId ?? l.sourceProductId);
  });

  const supplierSnaps = new Map();
  for (const col of ['products', 'Products']) {
    const ids = [...new Set(supplierIds.filter((id) => id && !supplierSnaps.has(id)))];
    if (!ids.length) break;
    const snaps = await db.getAll(...ids.map((id) => db.collection(col).doc(id)));
    snaps.forEach((s) => {
      if (s.exists) supplierSnaps.set(s.id, s.data() || {});
    });
  }

  listings.forEach((doc, i) => {
    const l = doc.data() || {};
    const s = supplierSnaps.get(supplierIds[i]);
    if (!s || isOff(s)) return;

    const price = Number(pick(l.sellingPrice, l.price)) || 0;
    if (!(price > 0)) return;

    items.push({
      id: doc.id,
      kind: 'r',
      name: String(pick(l.productName, l.name, l.title, s.name, s.title) ?? ''),
      imageUrl: firstImage(l.imageUrl, l.images, s.imageUrl, s.imageUrls, s.images),
      price,
      originalPrice: resellerOriginal(l),
      category: String(pick(l.category, s.category) ?? ''),
    });
  });

  return { items };
});
