/* BuyNova shop: Chrome-এ রঙ ঠিক রাখা + Messenger/Facebook থেকে Chrome-এ খোলা */
(function () {
  var UA = navigator.userAgent || "";
  var IN_APP = /FBAN|FBAV|FB_IAB|Messenger|Instagram|Line\/|TikTok|Snapchat|; wv\)/i.test(UA);
  var IS_ANDROID = /Android/i.test(UA);

  // 1) Chrome-এর Auto Dark Mode বন্ধ (সঠিক মান: "only light")
  //    polish.css এখন index.html-এর <head> থেকেই লোড হয়, তাই পেজ আনস্টাইল্ড ঝলকে না।
  try {
    document.querySelectorAll('meta[name="color-scheme"]').forEach(function (m) { m.remove(); });
    var meta = document.createElement("meta");
    meta.name = "color-scheme"; meta.content = "only light";
    document.head.appendChild(meta);

    var th = document.createElement("meta");
    th.name = "theme-color"; th.content = "#ff5252";
    document.head.appendChild(th);

    document.documentElement.style.colorScheme = "only light";

    var st = document.createElement("style");
    st.textContent =
      ":root{color-scheme:only light!important}" +
      ".cbar{background:#fff3cd;color:#5c4400;padding:10px 14px;font-size:13.5px;display:flex;gap:10px;align-items:center;justify-content:space-between;flex-wrap:wrap}" +
      ".cbar button{border:0;background:#ff5252;color:#fff;border-radius:18px;padding:8px 16px;font-weight:700;font-family:inherit;cursor:pointer}" +
      ".cbar .x{background:none;color:#5c4400;font-size:18px;padding:0 4px}";
    document.head.appendChild(st);
  } catch (e) {}

  // 2) Chrome-এ খুললে ?go=... থেকে প্রোডাক্ট রুট (#/p/ID) ফিরিয়ে আনা
  try {
    var g = new URLSearchParams(location.search).get("go");
    if (g) history.replaceState(null, "", location.pathname + "#" + g);
  } catch (e) {}

  // 3) Messenger/Facebook/Instagram-এর ভেতরে "Chrome-এ খুলুন" বার
  if (!IN_APP) return;
  document.addEventListener("DOMContentLoaded", function () {
    var bar = document.createElement("div");
    bar.className = "cbar";
    bar.innerHTML = '<span>🌐 ভালোভাবে কেনাকাটা ও লগইনের জন্য Chrome-এ খুলুন</span>' +
      '<span><button id="cbOpen">Chrome-এ খুলুন</button><button class="x" id="cbX">✕</button></span>';
    document.body.insertBefore(bar, document.body.firstChild);
    document.getElementById("cbX").onclick = function () { bar.remove(); };
    document.getElementById("cbOpen").onclick = function () {
      var u = location.origin + location.pathname +
        (location.hash.length > 1 ? "?go=" + encodeURIComponent(location.hash.slice(1)) : "");
      if (IS_ANDROID) {
        location.href = "intent://" + u.replace(/^https?:\/\//, "") +
          "#Intent;scheme=https;package=com.android.chrome;S.browser_fallback_url=" +
          encodeURIComponent(u) + ";end";
        setTimeout(function () {
          try { navigator.clipboard.writeText(u); } catch (e) {}
          alert("Chrome খোলেনি? উপরের ⋮ মেনু থেকে 'Chrome-এ খুলুন' চাপুন। লিংক কপি হয়েছে।");
        }, 1500);
      } else {
        try { navigator.clipboard.writeText(u); } catch (e) {}
        alert("লিংক কপি হয়েছে। Safari-তে পেস্ট করুন।");
      }
    };
  });
})();
