const admin = require('firebase-admin');
const { onCall } = require('firebase-functions/v2/https');

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();
const REGION = 'asia-northeast3';
const LIMIT = 500;
const CACHE_MS = 60 * 1000;

let cache = { at: 0, items: null };

const safeId = (v) => {
  const s = String(v || '');
  return s && !s.includes('/') ? s : '';
};

const pick = (...vals) =>
  vals.find((v) => v !== undefined && v !== null && v !== '');

const isOff = (d) => d.isActive === false || d.active === false;

const millis = (v) =>
  v && typeof v.toMillis === 'function' ? v.toMillis() : 0;

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

// True when the product has sizes or colors the buyer must choose.
const hasOptions = (p) =>
  listOf(p.sizes ?? p.availableSizes).length > 0 ||
  (Array.isArray(p.colors) &&
    p.colors.some(
      (c) => c && typeof c === 'object' && String(c.name ?? c.hex ?? '').trim()
    ));

// ============================================================
// getShopProducts
// Public product list for the customer website (/shop/).
// Returns ONLY public fields: no supplier price, no profit.
// Newest products first. Result is cached for 60 seconds per
// server instance, so a new product shows up within a minute.
// hasOptions = true means the buyer must pick a size / color,
// so the website sends them to the product page first.
// ============================================================
exports.getShopProducts = onCall({ region: REGION }, async () => {
  if (cache.items && Date.now() - cache.at < CACHE_MS) {
    return { items: cache.items };
  }

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
        category: String(p.category ?? '').trim(),
        hasOptions: hasOptions(p),
        t: millis(p.createdAt),
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
      category: String(pick(l.category, s.category) ?? '').trim(),
      hasOptions: hasOptions(s),
      t: millis(l.createdAt),
    });
  });

  // newest first (products without createdAt go last), then hide the helper field
  items.sort((a, b) => b.t - a.t);
  const out = items.map(({ t, ...rest }) => rest);

  cache = { at: Date.now(), items: out };
  return { items: out };
});
