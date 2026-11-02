/* cicrwu.org — progressive enhancement only; the page is complete without it. */

(function () {
  "use strict";

  var root = document.documentElement;
  var css = getComputedStyle(root);
  var ACCENT = css.getPropertyValue("--accent-hi-rgb").trim();   // "r g b"
  var ON_INK = css.getPropertyValue("--on-ink-rgb").trim();
  var still = matchMedia("(prefers-reduced-motion: reduce)").matches;
  var finePointer = matchMedia("(pointer: fine)").matches;

  function rgb(triplet, alpha) { return "rgb(" + triplet + " / " + alpha + ")"; }

  root.classList.add("js");

  /* ---- typed prompt: cycles through a few commands ---- */

  var cmd = document.getElementById("cmd");
  var commands = [
    "./join --no-experience-required",
    "nmap -sV demo.lab",
    "grep -r flag{ ./ctf",
    "ssh member@lab",
    "cat meetings/weekly.md"
  ];

  if (cmd && !still) {
    var line = 0, chars = commands[0].length, deleting = true;
    var type = function () {
      if (deleting) {
        chars--;
        if (chars <= 0) { deleting = false; line = (line + 1) % commands.length; }
      } else {
        chars++;
        if (chars >= commands[line].length) {
          deleting = true;
          cmd.textContent = commands[line];
          return setTimeout(type, 2600);
        }
      }
      cmd.textContent = commands[line].slice(0, Math.max(chars, 0));
      setTimeout(type, deleting ? 28 : 55 + Math.random() * 60);
    };
    setTimeout(type, 2600);
  }

  /* ---- drifting network graph behind the header ---- */

  var net = document.getElementById("net");
  if (net && net.getContext) {
    var ctx = net.getContext("2d");
    var dpr = Math.min(devicePixelRatio || 1, 2);
    var nodes = [], W = 0, H = 0;
    var LINK = 12000; // squared px distance under which nodes connect

    var resizeNet = function () {
      var r = net.getBoundingClientRect();
      W = r.width; H = r.height;
      net.width = W * dpr; net.height = H * dpr;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      nodes = [];
      var n = Math.round(Math.min(70, W * H / 9000));
      for (var i = 0; i < n; i++) {
        nodes.push({ x: Math.random() * W, y: Math.random() * H, vx: (Math.random() - 0.5) * 0.25, vy: (Math.random() - 0.5) * 0.25 });
      }
    };

    var drawNet = function () {
      ctx.clearRect(0, 0, W, H);
      for (var i = 0; i < nodes.length; i++) {
        var p = nodes[i];
        if (!still) {
          p.x += p.vx; p.y += p.vy;
          if (p.x < 0 || p.x > W) p.vx *= -1;
          if (p.y < 0 || p.y > H) p.vy *= -1;
        }
        for (var j = i + 1; j < nodes.length; j++) {
          var q = nodes[j], dx = p.x - q.x, dy = p.y - q.y, d = dx * dx + dy * dy;
          if (d < LINK) {
            ctx.strokeStyle = rgb(ACCENT, 0.22 * (1 - d / LINK));
            ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(q.x, q.y); ctx.stroke();
          }
        }
        ctx.fillStyle = rgb(ON_INK, 0.55);
        ctx.beginPath(); ctx.arc(p.x, p.y, 1.6, 0, Math.PI * 2); ctx.fill();
      }
      if (!still) requestAnimationFrame(drawNet);
    };

    resizeNet();
    drawNet();
    addEventListener("resize", function () { resizeNet(); if (still) drawNet(); });
  }

  /* ---- scroll reveal + active nav link ---- */

  var reveals = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window) {
    var revealer = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) { e.target.classList.add("in"); revealer.unobserve(e.target); }
      });
    }, { threshold: 0.1 });
    reveals.forEach(function (el) { revealer.observe(el); });

    var navLinks = {};
    document.querySelectorAll("nav a").forEach(function (a) { navLinks[a.hash.slice(1)] = a; });
    var spy = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (!e.isIntersecting || !navLinks[e.target.id]) return;
        for (var id in navLinks) navLinks[id].classList.remove("active");
        navLinks[e.target.id].classList.add("active");
      });
    }, { rootMargin: "-40% 0px -55% 0px" });
    Object.keys(navLinks).forEach(function (id) {
      var el = document.getElementById(id);
      if (el) spy.observe(el);
    });
  } else {
    reveals.forEach(function (el) { el.classList.add("in"); });
  }

  /* ---- scroll progress + back-to-top ---- */

  var bar = document.getElementById("progress");
  var toTop = document.getElementById("top");
  toTop.hidden = false;
  toTop.addEventListener("click", function () { scrollTo({ top: 0, behavior: still ? "auto" : "smooth" }); });

  var onScroll = function () {
    var max = root.scrollHeight - innerHeight;
    bar.style.transform = "scaleX(" + (max > 0 ? scrollY / max : 0) + ")";
    toTop.classList.toggle("show", scrollY > 400);
  };
  addEventListener("scroll", onScroll, { passive: true });
  addEventListener("resize", onScroll);
  onScroll();

  /* ---- decrypt: scramble an element's text, then resolve it left to right ---- */

  var GLYPHS = "!<>-_\\/[]{}=+*^?#$%&01";
  var decrypt = function (el, ms) {
    if (still || el.dataset.busy) return;
    el.dataset.busy = "1";
    if (!el.hasAttribute("aria-label")) el.setAttribute("aria-label", el.textContent.replace(/\s+/g, " ").trim());

    var texts = [], walk = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
    while (walk.nextNode()) texts.push({ node: walk.currentNode, value: walk.currentNode.nodeValue });
    var total = texts.reduce(function (sum, t) { return sum + t.value.length; }, 0);
    var t0 = performance.now();

    (function frame(now) {
      var progress = Math.min(1, (now - t0) / ms), keep = Math.floor(progress * total), seen = 0;
      texts.forEach(function (t) {
        var out = "";
        for (var i = 0; i < t.value.length; i++, seen++) {
          var c = t.value[i];
          out += (seen < keep || /\s/.test(c)) ? c : GLYPHS[(Math.random() * GLYPHS.length) | 0];
        }
        t.node.nodeValue = out;
      });
      if (progress < 1) requestAnimationFrame(frame);
      else delete el.dataset.busy;
    })(t0);
  };

  var title = document.querySelector(".hero h1");
  if (title) setTimeout(function () { decrypt(title, 1100); }, 150);
  document.querySelectorAll(".card h2").forEach(function (h) {
    h.closest(".card").addEventListener("mouseenter", function () { decrypt(h, 450); });
  });

  /* ---- pointer effects (mouse/trackpad only) ---- */

  var track = function (el, onMove, onLeave) {
    el.addEventListener("pointermove", function (e) {
      var r = el.getBoundingClientRect();
      onMove(e.clientX - r.left, e.clientY - r.top, r);
    });
    el.addEventListener("pointerleave", onLeave);
  };

  if (finePointer && !still) {
    // header glow + logo parallax
    var band = document.querySelector(".band");
    var logo = document.querySelector(".logo");
    track(band, function (x, y, r) {
      band.style.setProperty("--gx", x + "px");
      band.style.setProperty("--gy", y + "px");
      if (logo) {
        logo.style.setProperty("--px", (x / r.width - 0.5) * -24 + "px");
        logo.style.setProperty("--py", (y / r.height - 0.5) * -16 + "px");
      }
    }, function () {
      band.style.setProperty("--gy", "-50%");
      if (logo) { logo.style.setProperty("--px", "0px"); logo.style.setProperty("--py", "0px"); }
    });

    // card spotlight
    document.querySelectorAll(".card:not(.join)").forEach(function (card) {
      track(card, function (x, y) {
        card.style.setProperty("--mx", x + "px");
        card.style.setProperty("--my", y + "px");
      }, function () { card.style.setProperty("--mx", "-999px"); });
    });

    // e-board tilt
    document.querySelectorAll(".role").forEach(function (role) {
      track(role, function (x, y, r) {
        role.style.setProperty("--ry", (x / r.width - 0.5) * 14 + "deg");
        role.style.setProperty("--rx", (y / r.height - 0.5) * -14 + "deg");
      }, function () {
        role.style.setProperty("--rx", "0deg");
        role.style.setProperty("--ry", "0deg");
      });
    });
  }

  /* ---- ripple on buttons ---- */

  document.querySelectorAll(".btn").forEach(function (btn) {
    btn.addEventListener("pointerdown", function (e) {
      if (still) return;
      var r = btn.getBoundingClientRect(), d = Math.max(r.width, r.height);
      var ripple = document.createElement("span");
      ripple.className = "ripple";
      ripple.style.width = ripple.style.height = d + "px";
      ripple.style.left = e.clientX - r.left - d / 2 + "px";
      ripple.style.top = e.clientY - r.top - d / 2 + "px";
      btn.appendChild(ripple);
      setTimeout(function () { ripple.remove(); }, 650);
    });
  });

  /* ---- easter egg: Konami code, or type "hack" ---- */

  var KONAMI = ["ArrowUp", "ArrowUp", "ArrowDown", "ArrowDown", "ArrowLeft", "ArrowRight", "ArrowLeft", "ArrowRight", "b", "a"];
  var konamiPos = 0, typed = "";

  addEventListener("keydown", function (e) {
    if (/input|textarea/i.test(e.target.tagName)) return;
    var key = e.key.length === 1 ? e.key.toLowerCase() : e.key;
    konamiPos = key === KONAMI[konamiPos] ? konamiPos + 1 : (key === KONAMI[0] ? 1 : 0);
    typed = (typed + (e.key.length === 1 ? key : "")).slice(-4);
    if (konamiPos === KONAMI.length || typed === "hack") {
      konamiPos = 0;
      typed = "";
      rain();
    }
  });

  function rain() {
    if (document.getElementById("rain")) return;

    var overlay = document.createElement("div");
    overlay.id = "rain";
    overlay.setAttribute("role", "dialog");
    overlay.setAttribute("aria-label", "Access granted");
    overlay.innerHTML = '<canvas></canvas><div class="granted">ACCESS GRANTED<small>welcome to CIC &mdash; click or press Esc</small></div>';
    document.body.appendChild(overlay);

    var canvas = overlay.querySelector("canvas"), g = canvas.getContext("2d");
    var FONT = 16, CHARS = "01CICRWU{}<>/#$アカサタナ";
    var cols, drops, raf;

    var fit = function () {
      canvas.width = innerWidth;
      canvas.height = innerHeight;
      cols = Math.ceil(canvas.width / FONT);
      drops = [];
      for (var i = 0; i < cols; i++) drops.push(Math.random() * -40);
    };

    var fall = function () {
      g.fillStyle = "rgb(5 12 24 / 0.18)";
      g.fillRect(0, 0, canvas.width, canvas.height);
      g.font = FONT + "px monospace";
      for (var i = 0; i < cols; i++) {
        var y = drops[i] * FONT;
        g.fillStyle = Math.random() < 0.03 ? "#fff" : rgb(ACCENT, 1);
        g.fillText(CHARS[(Math.random() * CHARS.length) | 0], i * FONT, y);
        drops[i] = (y > canvas.height && Math.random() > 0.975) ? 0 : drops[i] + 1;
      }
      if (!still) raf = requestAnimationFrame(fall);
    };

    var onKey = function (e) { if (e.key === "Escape") close(); };
    var close = function () {
      cancelAnimationFrame(raf);
      removeEventListener("keydown", onKey);
      removeEventListener("resize", fit);
      overlay.remove();
    };

    fit();
    fall();
    overlay.addEventListener("click", close);
    addEventListener("keydown", onKey);
    addEventListener("resize", fit);
    setTimeout(close, 8000);
  }

  /* ---- for the curious ---- */

  console.log(
    "%c CIC @ RWU ",
    "background:#0b2545;color:" + rgb(ACCENT, 1) + ";font:700 16px monospace;padding:4px 8px",
    "\nPoking around? You'd fit right in. Say hi: cic@g.rwu.edu\n(psst: ↑↑↓↓←→←→ B A)"
  );
})();
