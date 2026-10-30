const { onRequest } = require("firebase-functions/v2/https");

const PROJECT_ID = "buynova-cc5dd";
const REGION = "asia-northeast3";
const SITE = "https://buynova-cc5dd.web.app";
const FN_BASE = `https://${REGION}-${PROJECT_ID}.cloudfunctions.net/`;

const esc = (s) =>
  String(s == null ? "" : s).replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])
  );

// Messenger/Facebook show the preview image only when it is a normal
// JPG/PNG of a sensible size. For Cloudinary images we ask Cloudinary
// for a 1200x630 white-padded JPG, so the whole product is visible.
function shareImage(u) {
  if (typeof u !== "string" || u.indexOf("https://") !== 0) {
    return { url: "", sized: false };
  }
  if (u.indexOf("res.cloudinary.com") > -1 && u.indexOf("/image/upload/") > -1) {
    const url = u
      .replace(
        "/image/upload/",
        "/image/upload/c_pad,b_white,w_1200,h_630,f_jpg,q_auto/"
      )
      .replace(/\.(webp|png|avif|jpeg|gif)(\?.*)?$/i, ".jpg");
    return { url, sized: true };
  }
  return { url: u, sized: false };
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

    // The static landing page (hosting/index.html)
    let html;
    try {
      const r = await fetch(`${SITE}/index.html`);
      html = await r.text();
    } catch (e) {
      return res.status(500).send("Page load error");
    }

    if ((kind === "p" || kind === "r") && id) {
      try {
        const fn = kind === "p" ? "getProductListing" : "getResellerListing";
        const payload = kind === "p" ? { productId: id } : { listingId: id };

        const r = await fetch(FN_BASE + fn, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ data: payload }),
        });
        const j = await r.json();
        const l = j && j.result && j.result.listing;

        if (l) {
          const name = l.name || l.title || l.productName || "BuyNova";
          const price = Number(l.price);
          const orig = Number(l.originalPrice);
          const rawImg =
            (Array.isArray(l.images) && l.images[0]) ||
            l.imageUrl ||
            l.image ||
            "";
          const img = shareImage(rawImg);

          let desc = "";
          if (!isNaN(price) && price > 0) {
            desc = `৳ ${price.toLocaleString("en-US")}`;
            if (!isNaN(orig) && orig > price) {
              desc += ` (was ৳ ${orig.toLocaleString("en-US")})`;
            }
            desc += " - ";
          }
          desc += l.description
            ? String(l.description).replace(/\s+/g, " ").slice(0, 150)
            : "BuyNova অ্যাপে কিনুন";

          const url = `${SITE}/${kind}/${encodeURIComponent(id)}`;

          let tags =
            `<meta property="og:site_name" content="BuyNova">\n` +
            `<meta property="og:type" content="website">\n` +
            `<meta property="og:title" content="${esc(name)}">\n` +
            `<meta property="og:description" content="${esc(desc)}">\n` +
            `<meta property="og:url" content="${esc(url)}">\n` +
            `<meta name="description" content="${esc(desc)}">\n`;

          if (img.url) {
            tags +=
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
          }

          // Remove the default og/description tags of the landing page first,
          // otherwise crawlers read the first (default) one and ignore ours.
          html = html.replace(
            /<meta\s+(?:property="og:[^"]*"|name="twitter:[^"]*"|name="description")[^>]*>\s*/gi,
            ""
          );

          // Function replacer: "$&" or "$'" inside a product name stays literal.
          const titleTag = `<title>${esc(name)} | BuyNova</title>\n${tags}`;
          html = html.replace(/<title>[^<]*<\/title>/i, () => titleTag);
        }
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
