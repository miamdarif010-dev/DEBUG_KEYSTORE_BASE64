const { onRequest } = require("firebase-functions/v2/https");

const PROJECT_ID = "buynova-cc5dd";
const REGION = "asia-northeast3";
const SITE = "https://buynova-cc5dd.web.app";
const FN_BASE = `https://${REGION}-${PROJECT_ID}.cloudfunctions.net/`;
const DEFAULT_IMG = `${SITE}/og-default.jpg`; // 1200x630 JPG

const esc = (s) =>
  String(s == null ? "" : s).replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])
  );

function shareImage(u) {
  if (typeof u !== "string" || u.indexOf("https://") !== 0) {
    return { url: DEFAULT_IMG, sized: true };
  }
  if (u.indexOf("res.cloudinary.com") > -1 && u.indexOf("/image/upload/") > -1) {
    const url = u
      .replace(
        "/image/upload/",
        "/image/upload/c_pad,b_white,w_1200,h_630,f_jpg,q_auto:eco/"
      )
      .replace(/\.(webp|png|avif|jpeg|gif)(\?.*)?$/i, ".jpg");
    return { url, sized: true };
  }
  return { url: u, sized: false };
}

// Candidate preview images, best first: resized Cloudinary JPG, then the raw URL.
function imageCandidates(u) {
  if (typeof u !== "string" || u.indexOf("https://") !== 0) return [];
  const list = [];
  const sized = shareImage(u);
  if (sized.sized) list.push(sized);
  list.push({ url: u, sized: false });
  return list;
}

// True only if the URL really answers with an image.
async function imageWorks(url) {
  try {
    let r = await fetch(url, { method: "HEAD", signal: AbortSignal.timeout(3500) });
    if (r.status === 405 || r.status === 403) {
      r = await fetch(url, { method: "GET", headers: { Range: "bytes=0-0" }, signal: AbortSignal.timeout(3500) });
    }
    const ct = r.headers.get("content-type") || "";
    return r.ok && ct.indexOf("image/") === 0;
  } catch (e) {
    return false;
  }
}

async function pickImage(rawImg) {
  for (const c of imageCandidates(rawImg)) {
    if (await imageWorks(c.url)) return c;
  }
  return { url: DEFAULT_IMG, sized: true, fallback: true };
}

async function getListing(kind, id) {
  try {
    const fn = kind === "p" ? "getProductListing" : "getResellerListing";
    const payload = kind === "p" ? { productId: id } : { listingId: id };
    const r = await fetch(FN_BASE + fn, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ data: payload }),
      signal: AbortSignal.timeout(6000),
    });
    const j = await r.json();
    return (j && j.result && j.result.listing) || null;
  } catch (e) {
    console.error("getListing error:", e);
    return null;
  }
}

exports.sharePage = onRequest(
  { region: REGION, memory: "256MiB", timeoutSeconds: 30 },
  async (req, res) => {
    const parts = req.path.split("/").filter(Boolean);
    const kind = parts[0];
    let id = null;
    try {
      id = parts[1] ? decodeURIComponent(parts[1]) : null;
    } catch (e) {
      id = null;
    }
    const wants = (kind === "p" || kind === "r") && id;

    let html, l;
    try {
      [html, l] = await Promise.all([
        fetch(`${SITE}/index.html`, { signal: AbortSignal.timeout(6000) }).then((r) => r.text()),
        wants ? getListing(kind, id) : Promise.resolve(null),
      ]);
    } catch (e) {
      return res.status(500).send("Page load error");
    }

    if (req.query && req.query.debug === "1") {
      const raw = l && ((Array.isArray(l.images) && l.images[0]) || l.imageUrl || l.image || "");
      const picked = wants ? await pickImage(raw) : null;
      return res.status(200).json({
        kind, id,
        listingFound: !!l,
        name: l && l.name,
        rawImage: raw,
        chosenImage: picked && picked.url,
        usedDefaultImage: !!(picked && picked.fallback),
      });
    }

    if (wants) {
      try {
        const name = (l && (l.name || l.title || l.productName)) || "BuyNova";
        const price = l ? Number(l.price) : NaN;
        const orig = l ? Number(l.originalPrice) : NaN;
        const rawImg =
          l && ((Array.isArray(l.images) && l.images[0]) || l.imageUrl || l.image || "");
        const img = await pickImage(rawImg);

        let desc = "";
        if (!isNaN(price) && price > 0) {
          desc = `৳ ${price.toLocaleString("en-US")}`;
          if (!isNaN(orig) && orig > price) {
            desc += ` (was ৳ ${orig.toLocaleString("en-US")})`;
          }
          desc += " - ";
        }
        desc +=
          l && l.description
            ? String(l.description).replace(/\s+/g, " ").slice(0, 150)
            : "BuyNova অ্যাপে কিনুন";

        const url = `${SITE}/${kind}/${encodeURIComponent(id)}`;

        const tags =
          `<meta property="og:site_name" content="BuyNova">\n` +
          `<meta property="og:type" content="website">\n` +
          `<meta property="og:title" content="${esc(name)}">\n` +
          `<meta property="og:description" content="${esc(desc)}">\n` +
          `<meta property="og:url" content="${esc(url)}">\n` +
          `<meta name="description" content="${esc(desc)}">\n` +
          `<meta property="og:image" content="${esc(img.url)}">\n` +
          `<meta property="og:image:secure_url" content="${esc(img.url)}">\n` +
          `<meta property="og:image:alt" content="${esc(name)}">\n` +
          (img.sized
            ? `<meta property="og:image:type" content="image/jpeg">\n` +
              `<meta property="og:image:width" content="1200">\n` +
              `<meta property="og:image:height" content="630">\n`
            : "") +
          `<meta name="twitter:card" content="summary_large_image">\n` +
          `<meta name="twitter:image" content="${esc(img.url)}">\n`;

        html = html.replace(
          /<meta\s+(?:property="og:[^"]*"|name="twitter:[^"]*"|name="description")[^>]*>\s*/gi,
          ""
        );
        const titleTag = `<title>${esc(name)} | BuyNova</title>\n${tags}`;
        html = html.replace(/<title>[^<]*<\/title>/i, () => titleTag);
      } catch (e) {
        console.error("sharePage error:", e);
      }
    }

    res
      .set("Content-Type", "text/html; charset=utf-8")
      .set("Cache-Control", "public, max-age=300, s-maxage=600")
      .status(200)
      .send(html);
  }
);
