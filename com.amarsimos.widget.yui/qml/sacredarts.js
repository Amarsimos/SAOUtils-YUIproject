// The effects of the System Call easter egg and the two sword skills (SacredArts.qml paints them), ported
// from system-call-fx-preview.html. Everything is drawn on one 420 x 520 stage (Yui in its middle); the
// QML side scales the stage to the view and reads `state` after each frame for what it shows itself
// (the flash and dim layers, Yui hidden / glowing / shaking, the stage shake and zoom, the boss image).
// Not a library: each SacredArts has its own copy of this state.

var W = 420, H = 520, cx = 210, cy = 260;
var EL = {
    "luminous": "#FFF59D",
    "thermal": "#FF7043",
    "cryogenic": "#4FC3F7",
    "aerial": "#A5D6A7",
    "aqueous": "#4DD0E1",
    "metallic": "#B0BEC5",
    "umbra": "#9575CD"
};

// What the QML side shows (read after every frame).
var state = {
    "flash": 0,
    "dim": 0,
    "yuiHidden": false,
    // A sword skill plays: the stage is centred on the whole view instead of on Yui.
    "centred": false,
    "aura": 0,
    "yuiShake": 0,
    "stageShake": 0,
    "zoom": 1,
    "boss": { "show": 0, "flinch": 0, "white": 0 }
};

var x = null; // the context of the frame being painted
// The whole view in stage units (set by SacredArts each frame): the edge glow covers it, not just the stage.
var view = { "x0": 0, "y0": 0, "x1": W, "y1": H };
var P = [], FX = [], roses = [], marks = [], timers = [];
var orb = null, freeze = 0, hitGlow = 0, zoomTo = 1, edgeGlow = 0, edgeGlowC = "rgba(41,182,246,";
var shakeLeft = 0;
var boss = { "show": 0, "target": 0, "flinch": 0, "white": 0, "hp": 1, "shown": 1 };
var atk = { "x": cx, "y": 300 };

function rgb(h, a) {
    var n = parseInt(h.slice(1), 16);
    return "rgba(" + (n >> 16) + "," + (n >> 8 & 255) + "," + (n & 255) + "," + a + ")";
}

function add(p) {
    p.life = p.life || 1;
    p.age = 0;
    P.push(p);
}

// Things to do after ms (wall clock, so the hit-stop does not hold them up).
function later(ms, f) {
    timers.push({ "at": Date.now() + ms, "f": f });
}

// True while something is still playing (SacredArts keeps painting only then).
function busy() {
    return P.length > 0 || FX.length > 0 || roses.length > 0 || marks.length > 0 || timers.length > 0 || !!orb || freeze > 0
        || state.flash > 0.01 || state.dim > 0.01 || state.aura > 0.01 || shakeLeft > 0.01 || state.stageShake > 0.01
        || Math.abs(state.zoom - 1) > 0.002 || boss.show > 0.01 || boss.target > 0 || hitGlow > 0 || edgeGlow > 0;
}

// ---------------------------------------------------------------- playing
// kind: element (arg: its name), discharge, burst, enhance, release, transfer, starburst, rosario.
function play(kind, arg) {
    if (kind === "element")
        conjure(EL[arg] ? arg : "luminous");
    else if (kind === "starburst")
        starburst();
    else if (kind === "rosario")
        rosario();
    else
        spell(kind);
}

// An element gathers in front of Yui, slowly, and floats there (gone after 12 s if not used).
function conjure(k) {
    var c = EL[k];
    orb = { "k": k, "c": c, "t": -60, "x": cx, "y": cy, "vx": 0, "vy": 0, "mode": "hold" };
    for (var i = 0; i < 26; i++) {
        var a = Math.random() * 6.28, d = 50 + Math.random() * 50;
        add({ "x": cx + Math.cos(a) * d, "y": cy + Math.sin(a) * d, "tx": cx, "ty": cy, "r": 1.5 + Math.random() * 1.5, "c": c, "life": 60, "seek": 1, "rate": 0.045, "glow": 1, "delay": Math.random() * 30 });
    }
}

function petal(x0, y0, vx, vy, life, spin) {
    add({ "x": x0, "y": y0, "vx": vx, "vy": vy, "r": 4 + Math.random() * 3, "c": Math.random() < 0.5 ? "#FFD54F" : "#FFECB3", "life": life, "petal": 1, "rot": Math.random() * 6, "vr": (Math.random() - 0.5) * 0.3, "spin": spin });
}

function spell(s) {
    var i, a;
    if (s === "discharge") {
        if (!orb)
            conjure("thermal");
        orb.mode = "form";
        orb.f = 0;
    } else if (s === "burst") {
        if (!orb)
            conjure("luminous");
        var o = orb;
        if (o.k === "luminous")
            state.flash = 1;
        for (i = 0; i < 80; i++) {
            a = Math.random() * 6.28;
            var v = 2 + Math.random() * 6;
            add({ "x": o.x, "y": o.y, "vx": Math.cos(a) * v, "vy": Math.sin(a) * v, "r": 2 + Math.random() * 3, "c": o.c, "life": 45 + Math.random() * 30, "drag": 0.95, "glow": 1 });
        }
        orb = null;
    } else if (s === "enhance") {
        state.aura = 1;
        for (i = 0; i < 46; i++)
            petal(cx, cy, 0, 0, 140 + Math.random() * 40, { "a": Math.random() * 6.28, "r": 70 + Math.random() * 40, "y": H - 60 - Math.random() * 40, "vy": -1.4 - Math.random() * 0.8, "va": 0.05 + Math.random() * 0.03 });
    } else if (s === "release") {
        shakeLeft = 1;
        for (i = 0; i < 30; i++) {
            a = Math.random() * 6.28;
            add({ "x": cx + Math.cos(a) * 120, "y": cy + Math.sin(a) * 120, "tx": cx, "ty": cy, "r": 2, "c": "#FFF8E1", "life": 22, "seek": 1, "glow": 1 });
        }
        later(420, function() {
            for (var j = 0; j < 120; j++) {
                var b = Math.random() * 6.28, w = 3 + Math.random() * 7;
                petal(cx, cy, Math.cos(b) * w, Math.sin(b) * w, 70 + Math.random() * 40);
            }
            for (var k = 0; k < 7; k++)
                roses.push({ "x": 30 + Math.random() * (W - 60), "y": 60 + Math.random() * (H - 140), "t": -k * 6, "s": 14 + Math.random() * 12 });
        });
    } else if (s === "transfer") {
        for (i = 0; i < 60; i++) {
            a = Math.random() * 6.28;
            var d = 180 + Math.random() * 80;
            add({ "x": cx + Math.cos(a) * d, "y": cy + Math.sin(a) * d, "tx": cx, "ty": cy, "r": 2 + Math.random() * 2, "c": "#69F0AE", "life": 70, "seek": 1, "delay": Math.random() * 30, "glow": 1 });
        }
        later(1300, function() {
            for (var j = 0; j < 50; j++)
                add({ "x": cx + (Math.random() - 0.5) * 20, "y": cy, "vx": (Math.random() - 0.5) * 1.5, "vy": 4 + Math.random() * 3, "r": 2 + Math.random() * 2, "c": "#B9F6CA", "life": 50, "glow": 1 });
        });
    }
}

function elemParticles(o) {
    var k = o.k, i, a;
    if (k === "luminous" && Math.random() < 0.5) {
        a = Math.random() * 6.28;
        add({ "x": o.x, "y": o.y, "vx": Math.cos(a) * 2, "vy": Math.sin(a) * 2, "r": 1.3, "c": "#ffffff", "life": 26, "glow": 1, "star": 1 });
    }
    if (k === "thermal")
        for (i = 0; i < 2; i++)
            add({ "x": o.x + (Math.random() - 0.5) * 14, "y": o.y + 4, "vx": (Math.random() - 0.5) * 0.6, "vy": -1.2 - Math.random() * 1.5, "r": 3 + Math.random() * 3, "c": Math.random() < 0.5 ? "#FF7043" : "#FFCA28", "life": 22, "shrink": 1, "glow": 1 });
    if (k === "cryogenic" && Math.random() < 0.3) {
        a = Math.random() * 6.28;
        add({ "x": o.x + Math.cos(a) * 18, "y": o.y + Math.sin(a) * 18, "vx": Math.cos(a) * 0.5, "vy": Math.sin(a) * 0.5 + 0.2, "r": 3 + Math.random() * 3, "c": "#E1F5FE", "life": 45, "shard": 1, "rot": Math.random() * 6, "vr": (Math.random() - 0.5) * 0.1 });
    }
    if (k === "aerial") {
        a = o.t * 0.3;
        add({ "x": o.x + Math.cos(a) * 22, "y": o.y + Math.sin(a) * 9, "vx": -Math.sin(a) * 1.5, "vy": -0.6, "r": 1.6, "c": "#C8E6C9", "life": 24, "glow": 1 });
    }
    if (k === "aqueous" && Math.random() < 0.12)
        add({ "x": o.x + (Math.random() - 0.5) * 10, "y": o.y + 12, "vx": 0, "vy": 0.8, "r": 2.2, "c": "#80DEEA", "life": 50, "grav": 0.12 });
    if (k === "metallic" && o.t % 7 === 0) {
        a = o.t * 0.4;
        add({ "x": o.x, "y": o.y, "vx": Math.cos(a) * 2.4, "vy": Math.sin(a) * 2.4, "r": 5, "c": "#ECEFF1", "life": 24, "blade": 1, "rot": a, "vr": 0.3 });
    }
    if (k === "umbra" && Math.random() < 0.6) {
        a = Math.random() * 6.28;
        var d = 40 + Math.random() * 25;
        add({ "x": o.x + Math.cos(a) * d, "y": o.y + Math.sin(a) * d, "tx": o.x, "ty": o.y, "r": 1.6, "c": "#D1C4E9", "life": 34, "seek": 1, "glow": 1 });
    }
}

function circle(px, py, r) {
    x.beginPath();
    x.arc(px, py, r, 0, 6.2832);
}

function drawOrb(o) {
    var k = o.k, c = o.c, r = Math.min(1, o.t / 36) * 13;
    if (r <= 0)
        return;
    // Fading away when held too long.
    var fade = o.mode === "hold" && o.t > 680 ? Math.max(0, 1 - (o.t - 680) / 40) : 1;
    x.save();
    x.globalAlpha = fade;
    x.translate(o.x, o.y);
    if (o.mode === "form" || o.mode === "shoot") {
        var st = o.mode === "shoot" ? 1 : Math.min(1, o.f / 18);
        x.rotate(Math.atan2(-6, 7));
        x.scale(1 + st * 1.6, 1 - st * 0.55);
    }
    var g = x.createRadialGradient(0, 0, 0, 0, 0, r * 3);
    g.addColorStop(0, rgb(c, 0.6));
    g.addColorStop(1, rgb(c, 0));
    x.fillStyle = g;
    circle(0, 0, r * 3);
    x.fill();
    x.fillStyle = k === "umbra" ? "#1A0033" : rgb(c, 0.9);
    circle(0, 0, r);
    x.fill();
    if (k === "umbra") {
        x.strokeStyle = "#B388FF";
        x.lineWidth = 1.5;
        x.stroke();
    }
    x.fillStyle = k === "umbra" ? "#311B92" : "#ffffff";
    circle(0, 0, r * 0.42);
    x.fill();
    x.restore();
}

// An ice rose of Release Recollection: three rings of petals blooming, then shattering.
function drawRose(rs) {
    if (rs.t < 0)
        return;
    var k = Math.min(1, rs.t / 14), fade = rs.t > 60 ? Math.max(0, 1 - (rs.t - 60) / 16) : 1;
    x.save();
    x.translate(rs.x, rs.y);
    x.scale(k, k);
    x.globalAlpha = fade;
    var fills = ["rgba(179,229,252,.55)", "rgba(129,212,250,.7)", "rgba(225,245,254,.9)"];
    for (var layer = 0; layer < 3; layer++) {
        var rr = rs.s * (1 - layer * 0.28);
        for (var i = 0; i < 5; i++) {
            x.save();
            x.rotate(i * 6.2832 / 5 + layer * 0.6);
            x.translate(0, -rr * 0.55);
            x.scale(rr * 0.42, rr * 0.62);
            circle(0, 0, 1);
            x.restore();
            x.fillStyle = fills[layer];
            x.fill();
            x.strokeStyle = "rgba(255,255,255,.7)";
            x.lineWidth = 1;
            x.stroke();
        }
    }
    x.restore();
    if (rs.t === 62)
        for (var j = 0; j < 12; j++) {
            var a = Math.random() * 6.28;
            add({ "x": rs.x, "y": rs.y, "vx": Math.cos(a) * 3, "vy": Math.sin(a) * 3, "r": 3 + Math.random() * 2, "c": "#E1F5FE", "life": 30, "shard": 1, "rot": a, "vr": 0.2, "grav": 0.1 });
        }
}

function sparks(x0, y0, c, n, v) {
    for (var i = 0; i < n; i++) {
        var a = Math.random() * 6.28, s = (1 + Math.random()) * v;
        add({ "x": x0, "y": y0, "vx": Math.cos(a) * s, "vy": Math.sin(a) * s, "r": 1.5 + Math.random() * 1.5, "c": c, "life": 25 + Math.random() * 20, "drag": 0.92, "glow": 1, "star": Math.random() < 0.3 });
    }
}

// A sword's trail seen from the swordsman (the user, facing the screen): the band the blade sweeps along
// the near half of a flattened, tilted ellipse (centre ox,oy, radius r, flattening sy, tilt rot), as wide
// as the blade, only its ends tapered; swept out in 9 frames with a glare at the tip and blue wisps, then
// fading as an afterimage.
function crescent(ox, oy, r, a0, sweep, c, edge, w, life, sy, rot) {
    sy = sy || 1;
    rot = rot || 0;
    var cr = Math.cos(rot), sr = Math.sin(rot);
    function pt(a, rr) {
        var dx = Math.cos(a) * rr, dy = Math.sin(a) * rr * sy;
        x.lineTo(ox + dx * cr - dy * sr, oy + dx * sr + dy * cr);
    }
    FX.push({ "t": 0, "step": function() {
        if (this.t >= life)
            return false;
        var head = Math.min(1, (this.t + 1) / 9), tail = Math.max(0, (this.t - 8) / (life - 8)) * 0.25;
        var fade = 1 - Math.max(0, (this.t - 8) / (life - 8));
        fade = fade * fade;
        function shape(width, inset) {
            x.beginPath();
            var N = 28, i, u, a, th;
            for (i = 0; i <= N; i++) {
                u = tail + (head - tail) * i / N;
                a = a0 + sweep * u;
                pt(a, r);
            }
            for (i = N; i >= 0; i--) {
                u = tail + (head - tail) * i / N;
                a = a0 + sweep * u;
                th = width * Math.pow(Math.sin(Math.PI * i / N), 0.3);
                pt(a, r - th - inset);
            }
            x.closePath();
        }
        x.save();
        x.globalAlpha = fade;
        x.globalCompositeOperation = "source-over";
        x.fillStyle = rgb(edge, 0.35);
        shape(w * 1.25, -w * 0.12);
        x.fill();
        x.fillStyle = rgb(c, 0.72);
        shape(w, 0);
        x.fill();
        x.fillStyle = rgb(edge, 0.55);
        shape(w * 0.45, w * 0.2);
        x.fill();
        if (this.t < 10) {
            var ha = a0 + sweep * head, hdx = Math.cos(ha) * r, hdy = Math.sin(ha) * r * sy;
            var hx = ox + hdx * cr - hdy * sr, hy = oy + hdx * sr + hdy * cr;
            x.globalCompositeOperation = "lighter";
            var hg = x.createRadialGradient(hx, hy, 0, hx, hy, 46);
            hg.addColorStop(0, "rgba(255,255,255,.95)");
            hg.addColorStop(0.25, rgb(c, 0.6));
            hg.addColorStop(1, rgb(c, 0));
            x.fillStyle = hg;
            circle(hx, hy, 46);
            x.fill();
            x.fillStyle = "rgba(255,255,255,.9)";
            x.fillRect(hx - 30, hy - 1, 60, 2);
            x.fillRect(hx - 1, hy - 18, 2, 36);
            for (var q = 0; q < 2; q++)
                add({ "x": hx + (Math.random() - 0.5) * 30, "y": hy + (Math.random() - 0.5) * 30, "vx": (Math.random() - 0.5) * 0.6, "vy": -0.6 - Math.random() * 0.8, "r": 2.5 + Math.random() * 2.5, "c": Math.random() < 0.5 ? "#4FC3F7" : "#B3E5FC", "life": 40 + Math.random() * 20, "shrink": 1, "glow": 1 });
        }
        x.restore();
        this.t++;
        return true;
    } });
}

function speedLine(ox, oy, a) {
    var len = 60 + Math.random() * 80, start = 30 + Math.random() * 30;
    FX.push({ "t": 0, "step": function() {
        var k = 1 - this.t / 16;
        if (k <= 0)
            return false;
        var d = start + this.t * 22;
        x.save();
        x.strokeStyle = rgb("#ffffff", 0.9 * k);
        x.lineWidth = 2.5 * k + 0.5;
        x.beginPath();
        x.moveTo(ox + Math.cos(a) * d, oy + Math.sin(a) * d);
        x.lineTo(ox + Math.cos(a) * (d + len), oy + Math.sin(a) * (d + len));
        x.stroke();
        x.restore();
        this.t++;
        return true;
    } });
}

// A long thin streak across the picture through the attack point.
function streak(a, off, c, life) {
    var L = 600, mx = atk.x + Math.cos(a + 1.57) * off, my = atk.y + Math.sin(a + 1.57) * off;
    FX.push({ "t": 0, "step": function() {
        var k = 1 - this.t / life;
        if (k <= 0)
            return false;
        var g = Math.min(1, this.t / 3);
        x.save();
        x.strokeStyle = rgb(c, 0.85 * k);
        x.lineWidth = 2.2;
        x.beginPath();
        x.moveTo(mx - Math.cos(a) * L * g, my - Math.sin(a) * L * g);
        x.lineTo(mx + Math.cos(a) * L * g, my + Math.sin(a) * L * g);
        x.stroke();
        x.restore();
        this.t++;
        return true;
    } });
}

// Soft white smoke puffs (the anime's impact smoke).
function smoke(x0, y0, n, size) {
    for (var i = 0; i < n; i++)
        (function() {
            var px = x0 + (Math.random() - 0.5) * size, py = y0 + (Math.random() - 0.5) * size * 0.6, r0 = size * (0.15 + Math.random() * 0.2);
            var vx = (Math.random() - 0.5) * 1.6, vy = -0.3 - Math.random() * 0.6, life = 45 + Math.random() * 25;
            FX.push({ "t": 0, "step": function() {
                var k = 1 - this.t / life;
                if (k <= 0)
                    return false;
                var r = r0 * (1 + this.t / life * 1.4);
                px += vx;
                py += vy;
                x.save();
                x.globalCompositeOperation = "source-over";
                x.fillStyle = "rgba(255,255,255," + (0.85 * Math.min(1, k * 1.6)) + ")";
                circle(px, py, r);
                x.fill();
                x.fillStyle = "rgba(179,229,252," + (0.5 * k) + ")";
                circle(px + r * 0.25, py + r * 0.3, r * 0.7);
                x.fill();
                x.restore();
                this.t++;
                return true;
            } });
        })();
}

// A four-rayed star at a hit, turning.
function impactStar(px, py, size, c) {
    var turn = Math.random() * 1.57;
    FX.push({ "t": 0, "step": function() {
        var k = 1 - this.t / 14;
        if (k <= 0)
            return false;
        var L = size * (0.6 + this.t / 14 * 0.8);
        x.save();
        x.translate(px, py);
        x.rotate(turn + this.t * 0.04);
        x.globalCompositeOperation = "lighter";
        for (var i = 0; i < 4; i++) {
            x.rotate(1.5708);
            var g = x.createLinearGradient(0, 0, L, 0);
            g.addColorStop(0, "rgba(255,255,255," + k + ")");
            g.addColorStop(1, rgb(c, 0));
            x.fillStyle = g;
            x.beginPath();
            x.moveTo(0, -size * 0.09 * k);
            x.lineTo(L, 0);
            x.lineTo(0, size * 0.09 * k);
            x.closePath();
            x.fill();
        }
        x.restore();
        this.t++;
        return true;
    } });
}

// Rays of light out of a point (a finishing blow); c: the color's "rgba(r,g,b," prefix.
function godRays(px, py, c) {
    var rays = [];
    for (var i = 0; i < 14; i++)
        rays.push({ "a": Math.random() * 6.28, "w": 0.05 + Math.random() * 0.08 });
    FX.push({ "t": 0, "step": function() {
        var k = 1 - this.t / 50;
        if (k <= 0)
            return false;
        x.save();
        x.translate(px, py);
        x.globalCompositeOperation = "lighter";
        rays.forEach(function(ry) {
            var g = x.createLinearGradient(0, 0, Math.cos(ry.a) * 600, Math.sin(ry.a) * 600);
            g.addColorStop(0, "rgba(255,255,255," + (0.55 * k) + ")");
            g.addColorStop(1, c + "0)");
            x.fillStyle = g;
            x.beginPath();
            x.moveTo(0, 0);
            x.lineTo(Math.cos(ry.a - ry.w) * 600, Math.sin(ry.a - ry.w) * 600);
            x.lineTo(Math.cos(ry.a + ry.w) * 600, Math.sin(ry.a + ry.w) * 600);
            x.closePath();
            x.fill();
        });
        x.restore();
        this.t++;
        return true;
    } });
}

// ---------------------------------------------------------------- Starburst Stream
// The Gleam Eyes: fading in, flinching when struck, shattering at the end.
function bossHit(big) {
    boss.flinch = big ? 1 : 0.5;
    boss.white = big ? 1 : 0.7;
    boss.hp = big ? 0 : Math.max(1 / 30, boss.hp - 1 / 30);
}

function bossShatter() {
    marks = [];
    boss.target = 0;
    boss.show = 0;
    for (var i = 0; i < 90; i++) {
        var a = Math.random() * 6.28, v = 1 + Math.random() * 5;
        add({ "x": cx + (Math.random() - 0.5) * 260, "y": 150 + Math.random() * 160, "vx": Math.cos(a) * v, "vy": Math.sin(a) * v - 1, "r": 4 + Math.random() * 6, "c": Math.random() < 0.5 ? "#64B5F6" : "#E3F2FD", "life": 60 + Math.random() * 30, "shard": 1, "rot": Math.random() * 6, "vr": (Math.random() - 0.5) * 0.3, "drag": 0.97 });
    }
    state.flash = Math.max(state.flash, 0.6);
}

// 29 swings: hands R L L R ..., the screen direction alternating; the tilt taken from eight spread out
// (near vertical cuts, diagonals, near horizontal sweeps), each eight shuffled, neighbours at least about
// 30 degrees apart; size, flattening and where on the belly it lands vary.
function combo() {
    var TILTS = [-1.25, -0.9, -0.55, -0.2, 0.15, 0.5, 0.85, 1.2], list = [], hands = "RLLR", bag = [], last = 9;
    function next() {
        if (!bag.length) {
            bag = TILTS.slice();
            for (var j = bag.length - 1; j > 0; j--) {
                var k = Math.floor(Math.random() * (j + 1)), tmp = bag[j];
                bag[j] = bag[k];
                bag[k] = tmp;
            }
        }
        for (var i = 0; i < bag.length; i++)
            if (Math.abs(bag[i] - last) >= 0.5) {
                last = bag.splice(i, 1)[0];
                return last;
            }
        last = bag.shift();
        return last;
    }
    for (var i = 0; i < 29; i++)
        list.push([hands[i % 4], next() + (Math.random() - 0.5) * 0.12, i % 2 ? -1 : 1, 400 + Math.random() * 160, 0.3 + Math.random() * 0.32, (Math.random() - 0.5) * 60, (Math.random() - 0.5) * 40]);
    return list;
}

function swing(m) {
    var right = m[0] === "R", rot = m[1], r = m[3], sy = m[4], ry = r * sy;
    atk.x = cx + m[5];
    atk.y = 300 + m[6];
    var ox = atk.x + Math.sin(rot) * ry, oy = atk.y - Math.cos(rot) * ry, S = 2.9;
    crescent(ox, oy, r, Math.PI / 2 - S / 2 * m[2], S * m[2], right ? "#4FC3F7" : "#29B6F6", "#E1F5FE", 62 + Math.random() * 14, 70, sy, rot);
    var hx = atk.x, hy = atk.y;
    later(64, function() {
        bossHit(false);
        impactStar(hx, hy, 90, "#81D4FA");
        edgeGlow = Math.max(edgeGlow, 0.55);
        sparks(hx, hy, "#E1F5FE", 18, 4.5);
        hitGlow = 1;
        state.stageShake = Math.max(state.stageShake, 0.45);
        streak(rot + (Math.random() - 0.5) * 0.3, (Math.random() - 0.5) * 30, "#ffffff", 16);
        if (Math.random() < 0.35)
            smoke(hx, hy + 24, 3, 70);
    });
}

function swingBig(rot, dir, c) {
    var r = 560, sy = 0.5, ry = r * sy, ox = atk.x + Math.sin(rot) * ry, oy = atk.y - Math.cos(rot) * ry, S = 3;
    crescent(ox, oy, r, Math.PI / 2 - S / 2 * dir, S * dir, c, "#E1F5FE", 100, 90, sy, rot);
}

function starburst() {
    edgeGlowC = "rgba(41,182,246,";
    state.yuiHidden = true;
    state.centred = true;
    boss.target = 1;
    boss.hp = 1;
    boss.shown = 1;
    var t = 200, moves = combo();
    moves.forEach(function(m, i) {
        t += Math.round(340 - 270 * Math.pow(i / (moves.length - 1), 0.7));
        later(t, function() {
            swing(m);
        });
    });
    // The wind-up: darker, light drawn in, the picture closing in.
    later(t + 250, function() {
        state.dim = 0.7;
        zoomTo = 1.05;
        for (var i = 0; i < 40; i++) {
            var a = Math.random() * 6.28, d = 170 + Math.random() * 90;
            add({ "x": cx + Math.cos(a) * d, "y": 300 + Math.sin(a) * d, "tx": cx, "ty": 300, "r": 1.5 + Math.random() * 1.5, "c": "#E3F2FD", "life": 34, "seek": 1, "glow": 1, "delay": 10 + Math.random() * 16 });
        }
    });
    // The finishing blow: both blades crossing on the foe.
    later(t + 900, function() {
        atk.x = cx;
        atk.y = 300;
        swingBig(-0.75, 1, "#4FC3F7");
        swingBig(0.75, -1, "#29B6F6");
    });
    later(t + 1050, function() {
        freeze = 12;
        state.flash = 1;
        state.dim = 0;
        state.stageShake = 2.8;
        state.zoom = 1.12;
        zoomTo = 1;
        bossHit(true);
        later(800, bossShatter);
        later(220, function() {
            state.flash = 0.8;
            state.stageShake = Math.max(state.stageShake, 1.6);
            sparks(atk.x, atk.y, "#E3F2FD", 80, 9);
        });
        for (var i = 0; i < 44; i++)
            speedLine(atk.x, atk.y, i / 44 * 6.28 + Math.random() * 0.08);
        godRays(atk.x, atk.y, "rgba(129,212,250,");
        impactStar(atk.x, atk.y, 240, "#E1F5FE");
        edgeGlow = 1.2;
        for (var j = 0; j < 6; j++)
            streak(Math.random() * 3.14, (Math.random() - 0.5) * 60, "#ffffff", 22);
        smoke(atk.x, atk.y, 10, 170);
        smoke(cx, H - 30, 12, W);
        sparks(atk.x, atk.y, "#ffffff", 60, 8);
        sparks(atk.x, atk.y, "#82B1FF", 60, 6);
        later(500, function() {
            for (var k = 0; k < 30; k++)
                add({ "x": cx + (Math.random() - 0.5) * 200, "y": cy + (Math.random() - 0.5) * 200, "vx": (Math.random() - 0.5) * 0.6, "vy": -0.4 - Math.random() * 0.8, "r": 1.5 + Math.random(), "c": Math.random() < 0.5 ? "#BBDEFB" : "#ffffff", "life": 90, "glow": 1 });
        });
    });
    later(t + 3200, function() {
        state.yuiHidden = false;
        state.centred = false;
        sparks(cx, cy, "#ffffff", 30, 2.5);
    });
}

// ---------------------------------------------------------------- Mother's Rosario
// One thrust, first person: a beam from the sword hand (below the stage, right) narrowing into the depth
// to the point struck, out in 3 frames and fading as an afterimage; a violet star, sparks and a mark at
// the point; big: the eleventh, with everything of a finishing blow.
function stab(px, py, big) {
    var sx = W * 0.78 + (Math.random() - 0.5) * 40, sy = H + 50, w0 = big ? 90 : 46, life = big ? 50 : 30;
    var layers = [[1.6, "rgba(186,104,200,", 0.35], [1, "rgba(206,147,216,", 0.8], [0.3, "rgba(255,255,255,", 0.95]];
    FX.push({ "t": 0, "step": function() {
        if (this.t >= life)
            return false;
        var g = Math.min(1, (this.t + 1) / 3), k = 1 - Math.max(0, (this.t - 3) / (life - 3));
        k = k * k;
        var ex = sx + (px - sx) * g, ey = sy + (py - sy) * g, ang = Math.atan2(ey - sy, ex - sx), nx = -Math.sin(ang), ny = Math.cos(ang);
        x.save();
        x.globalCompositeOperation = "lighter";
        layers.forEach(function(l) {
            var hw = w0 * l[0] / 2;
            x.fillStyle = l[1] + (l[2] * k) + ")";
            x.beginPath();
            x.moveTo(sx + nx * hw, sy + ny * hw);
            x.lineTo(ex + nx * 1.5, ey + ny * 1.5);
            x.lineTo(ex - nx * 1.5, ey - ny * 1.5);
            x.lineTo(sx - nx * hw, sy - ny * hw);
            x.closePath();
            x.fill();
        });
        x.restore();
        this.t++;
        return true;
    } });
    later(48, function() {
        edgeGlowC = "rgba(171,71,188,";
        if (big) {
            freeze = 12;
            state.flash = 1;
            state.dim = 0;
            state.zoom = 1.12;
            zoomTo = 1;
            state.stageShake = 2.6;
            later(800, function() {
                marks.forEach(function(m) {
                    sparks(m.x, m.y, "#E1BEE7", 10, 4);
                });
                marks = [];
            });
            godRays(px, py, "rgba(206,147,216,");
            impactStar(px, py, 240, "#E1BEE7");
            edgeGlow = 1.2;
            for (var i = 0; i < 40; i++)
                speedLine(px, py, i / 40 * 6.28);
            sparks(px, py, "#ffffff", 70, 8);
            sparks(px, py, "#CE93D8", 70, 6);
            smoke(px, py, 8, 150);
            later(220, function() {
                state.flash = 0.7;
                sparks(px, py, "#E1BEE7", 60, 8);
            });
        } else {
            impactStar(px, py, 80, "#CE93D8");
            sparks(px, py, "#E1BEE7", 16, 4);
            edgeGlow = Math.max(edgeGlow, 0.5);
            state.stageShake = Math.max(state.stageShake, 0.4);
            marks.push({ "x": px, "y": py, "t": 0 });
        }
    });
}

// Ten thrusts, five along one diagonal and five along the other (a violet cross of marks), faster and
// faster; a beat; the eleventh through the middle. No foe: Yui is hidden meanwhile.
function rosario() {
    state.yuiHidden = true;
    state.centred = true;
    boss.target = 0;
    var mx = cx, my = cy, pts = [], i;
    for (i = 0; i < 5; i++)
        pts.push([mx - 80 + i * 40, my - 60 + i * 30]);
    for (i = 0; i < 5; i++)
        pts.push([mx + 80 - i * 40, my - 60 + i * 30]);
    var t = 700;
    pts.forEach(function(q, j) {
        t += Math.round(190 - 12 * j);
        later(t, function() {
            stab(q[0], q[1], false);
        });
    });
    later(t + 300, function() {
        state.dim = 0.6;
        zoomTo = 1.04;
        for (var k = 0; k < 30; k++) {
            var a = Math.random() * 6.28, d = 150 + Math.random() * 80;
            add({ "x": mx + Math.cos(a) * d, "y": my + Math.sin(a) * d, "tx": mx, "ty": my, "r": 1.5 + Math.random() * 1.5, "c": "#E1BEE7", "life": 34, "seek": 1, "glow": 1, "delay": Math.random() * 14 });
        }
    });
    later(t + 800, function() {
        stab(mx, my, true);
    });
    later(t + 3000, function() {
        state.yuiHidden = false;
        state.centred = false;
        marks = [];
    });
}

// Everything shown on the QML side back to rest (when nothing plays any more: values that faded to
// almost nothing must not stay, e.g. Yui's glow layer would stay on).
function settle() {
    state.flash = 0;
    state.dim = 0;
    state.yuiHidden = false;
    state.centred = false;
    state.aura = 0;
    state.yuiShake = 0;
    state.stageShake = 0;
    state.zoom = 1;
    state.boss = { "show": 0, "flinch": 0, "white": 0 };
}

// ---------------------------------------------------------------- one frame
// Advances everything one frame and draws it on ctx (the stage's 2D context); state is updated.
function frame(ctx) {
    x = ctx;
    var now = Date.now(), due = timers.filter(function(tm) {
        return tm.at <= now;
    });
    timers = timers.filter(function(tm) {
        return tm.at > now;
    });
    due.forEach(function(tm) {
        tm.f();
    });
    // Hit-stop: the picture holds still for a few frames.
    if (freeze > 0) {
        freeze--;
        return;
    }
    // The canvas reaches past the stage on every side (the trails and rays go beyond it).
    x.clearRect(-W * 3, -H, W * 7, H * 3);
    x.globalCompositeOperation = "lighter";
    if (state.flash > 0)
        state.flash = Math.max(0, state.flash - 0.04);
    if (state.aura > 0)
        state.aura = Math.max(0, state.aura - 0.004);
    state.yuiShake = shakeLeft > 0 ? Math.sin(now / 25) * 10 * shakeLeft : 0;
    if (shakeLeft > 0)
        shakeLeft = Math.max(0, shakeLeft - 0.012);
    if (orb) {
        orb.t++;
        if (orb.mode === "form") {
            orb.f++;
            if (orb.f > 20) {
                orb.mode = "shoot";
                orb.vx = 6;
                orb.vy = -5.2;
            }
        }
        if (orb.mode === "shoot") {
            orb.x += orb.vx;
            orb.y += orb.vy;
            orb.vx *= 1.06;
            orb.vy *= 1.06;
            for (var i = 0; i < 4; i++)
                add({ "x": orb.x, "y": orb.y, "vx": -orb.vx * 0.1 + (Math.random() - 0.5), "vy": -orb.vy * 0.1 + (Math.random() - 0.5), "r": 3.5, "c": orb.c, "life": 24, "shrink": 1, "glow": 1 });
            if (orb.x > W + 60 || orb.y < -60)
                orb = null;
        } else if (orb.t > 0) {
            orb.y = cy + Math.sin(orb.t * 0.05) * 3;
            if (orb.t < 680)
                elemParticles(orb);
        }
        if (orb)
            drawOrb(orb);
        if (orb && orb.mode === "hold" && orb.t > 720)
            orb = null;
    }
    x.globalCompositeOperation = "source-over";
    roses = roses.filter(function(rs) {
        rs.t++;
        drawRose(rs);
        return rs.t < 80;
    });
    x.globalCompositeOperation = "lighter";
    P = P.filter(function(p) {
        if (p.delay && p.delay-- > 0)
            return true;
        p.age++;
        var k = 1 - p.age / p.life;
        if (k <= 0)
            return false;
        if (p.spin) {
            var sp = p.spin;
            sp.a += sp.va;
            sp.y += sp.vy;
            p.x = cx + Math.cos(sp.a) * sp.r;
            p.y = sp.y + Math.sin(sp.a) * sp.r * 0.25;
        } else if (p.seek) {
            var sk = p.rate || 0.09;
            p.x += (p.tx - p.x) * sk;
            p.y += (p.ty - p.y) * sk;
        } else {
            p.x += p.vx;
            p.y += p.vy;
            if (p.grav)
                p.vy += p.grav;
            if (p.drag) {
                p.vx *= p.drag;
                p.vy *= p.drag;
            }
            if (p.petal) {
                p.vx *= 0.97;
                p.vy = p.vy * 0.97 + 0.04;
            }
        }
        if (p.rot !== undefined)
            p.rot += p.vr || 0;
        var r = p.shrink ? p.r * k : p.r;
        x.save();
        x.translate(p.x, p.y);
        if (p.petal) {
            x.globalCompositeOperation = "source-over";
            x.rotate(p.rot);
            x.fillStyle = rgb(p.c, 0.9 * Math.min(1, k * 2));
            x.save();
            x.scale(1, 0.5);
            circle(0, 0, r);
            x.restore();
            x.fill();
        } else if (p.shard) {
            x.rotate(p.rot);
            x.fillStyle = rgb(p.c, 0.85 * k);
            x.beginPath();
            x.moveTo(0, -r);
            x.lineTo(r * 0.5, 0);
            x.lineTo(0, r);
            x.lineTo(-r * 0.5, 0);
            x.closePath();
            x.fill();
        } else if (p.blade) {
            x.rotate(p.rot);
            x.fillStyle = rgb(p.c, k);
            x.fillRect(-r, -1.2, r * 2, 2.4);
        } else {
            // The glow: two faint circles (a gradient per particle and frame cost too much).
            if (p.glow) {
                x.fillStyle = rgb(p.c, 0.12 * k);
                circle(0, 0, r * 3);
                x.fill();
                circle(0, 0, r * 1.8);
                x.fill();
            }
            x.fillStyle = rgb(p.c, k);
            circle(0, 0, r);
            x.fill();
            if (p.star) {
                x.fillRect(-r * 3, -0.5, r * 6, 1);
                x.fillRect(-0.5, -r * 3, 1, r * 6);
            }
        }
        x.restore();
        return true;
    });
    if (hitGlow > 0) {
        var hg = x.createRadialGradient(atk.x, atk.y, 0, atk.x, atk.y, 60);
        hg.addColorStop(0, "rgba(255,255,255," + (0.9 * hitGlow) + ")");
        hg.addColorStop(0.3, "rgba(179,229,252," + (0.6 * hitGlow) + ")");
        hg.addColorStop(1, "rgba(179,229,252,0)");
        x.globalCompositeOperation = "lighter";
        x.fillStyle = hg;
        circle(atk.x, atk.y, 60);
        x.fill();
        hitGlow = Math.max(0, hitGlow - 0.12);
    }
    // The boss (an image on the QML side) and its HP bar (the SAO HUD bar).
    boss.show += (boss.target - boss.show) * 0.08;
    boss.flinch *= 0.85;
    boss.white *= 0.82;
    state.boss = { "show": boss.show, "flinch": boss.flinch, "white": boss.white };
    if (boss.show > 0.05) {
        boss.shown += (boss.hp - boss.shown) * 0.15;
        var bx = 70, by = 22, bw = 280, bh = 12, v = Math.max(0, boss.shown);
        x.save();
        x.globalAlpha = Math.min(1, boss.show * 1.3);
        x.globalCompositeOperation = "source-over";
        x.fillStyle = "#2a2f37";
        x.beginPath();
        x.moveTo(bx, by);
        x.lineTo(bx + bw, by);
        x.lineTo(bx + bw - 8, by + bh);
        x.lineTo(bx, by + bh);
        x.closePath();
        x.fill();
        x.strokeStyle = "rgba(255,255,255,.55)";
        x.lineWidth = 1;
        x.stroke();
        var fw = (bw - 4) * v, col = v > 0.5 ? ["#A7E46A", "#6CB32C"] : v > 0.2 ? ["#FFD85A", "#E2A400"] : ["#F2668F", "#C0204F"];
        if (fw > 0) {
            var bg = x.createLinearGradient(0, by + 2, 0, by + bh - 2);
            bg.addColorStop(0, col[0]);
            bg.addColorStop(1, col[1]);
            x.fillStyle = bg;
            x.beginPath();
            x.moveTo(bx + 2, by + 2);
            x.lineTo(bx + 2 + fw, by + 2);
            x.lineTo(Math.max(bx + 2, bx + 2 + fw - 6), by + bh - 2);
            x.lineTo(bx + 2, by + bh - 2);
            x.closePath();
            x.fill();
        }
        x.fillStyle = "#ffffff";
        x.font = "12px 'SAO UI'";
        x.fillText("The Gleam Eyes", bx, by - 5);
        x.restore();
    }
    // The edges glowing in the color of the move: four bands fading inwards, filled as paths (Qt's
    // fillRect / strokeRect ignored the alpha when adding light, and filled the whole stage).
    if (edgeGlow > 0) {
        var ea = (Math.min(1, edgeGlow) * 0.55).toFixed(3), vx0 = view.x0, vy0 = view.y0, vw = view.x1 - view.x0, vh = view.y1 - view.y0, bx = Math.min(vw, vh) * 0.3;
        x.globalCompositeOperation = "lighter";
        [[vx0, vy0, vx0, vy0 + bx, vx0, vy0, vw, bx], [vx0, vy0 + vh, vx0, vy0 + vh - bx, vx0, vy0 + vh - bx, vw, bx], [vx0, vy0, vx0 + bx, vy0, vx0, vy0, bx, vh], [vx0 + vw, vy0, vx0 + vw - bx, vy0, vx0 + vw - bx, vy0, bx, vh]].forEach(function(band) {
            var lg = x.createLinearGradient(band[0], band[1], band[2], band[3]);
            lg.addColorStop(0, edgeGlowC + ea + ")");
            lg.addColorStop(1, edgeGlowC + "0)");
            x.fillStyle = lg;
            x.beginPath();
            x.moveTo(band[4], band[5]);
            x.lineTo(band[4] + band[6], band[5]);
            x.lineTo(band[4] + band[6], band[5] + band[7]);
            x.lineTo(band[4], band[5] + band[7]);
            x.closePath();
            x.fill();
        });
        edgeGlow = Math.max(0, edgeGlow - 0.05);
    }
    // Mother's Rosario's marks, pulsing.
    marks.forEach(function(m) {
        m.t++;
        var pulse = 0.75 + 0.25 * Math.sin(m.t * 0.2), R = 16 * pulse;
        var mg = x.createRadialGradient(m.x, m.y, 0, m.x, m.y, R * 2.2);
        mg.addColorStop(0, "rgba(255,255,255,.9)");
        mg.addColorStop(0.35, "rgba(206,147,216,.8)");
        mg.addColorStop(1, "rgba(171,71,188,0)");
        x.globalCompositeOperation = "lighter";
        x.fillStyle = mg;
        circle(m.x, m.y, R * 2.2);
        x.fill();
    });
    x.globalCompositeOperation = "lighter";
    FX = FX.filter(function(f) {
        return f.step();
    });
    x.globalCompositeOperation = "source-over";
    // The stage's shake and zoom.
    state.zoom += (zoomTo - state.zoom) * 0.12;
    state.stageShake = Math.max(0, state.stageShake * 0.9 - 0.01);
    if (state.stageShake < 0.01)
        state.stageShake = 0;
}
