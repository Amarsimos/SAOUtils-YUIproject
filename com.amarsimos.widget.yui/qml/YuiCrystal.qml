import QtQuick 2.12

// "Yui's Heart": the crystal Yui's core was saved in (SAO S1E16), worn by Asuna as a pendant; used as a
// collapsed form. A sky-blue briolette (a teardrop covered in diamond facets): narrow at the top, widest
// two thirds down, round at the bottom, turning slowly about its axis. The facets are lit as a real solid
// (a light from the upper left, light coming through from behind, darker thick glass at the rim, soft
// glints); a still layer over them gives the body its volume (shadow away from the light, a bright rim,
// a soft highlight). The status color lives only in the glow behind and the heart inside, which beats.
// Everything is laid out in a 140 x 200 box and scaled to the item.
Item {
    id: crystal

    // Status color (green / yellow / red), see main-stand.qml crystalColor.
    property color statusColor: "#2CE67C"
    property bool sleeping: false
    // Thinking or talking: the heart beats and the light sweeps faster.
    property bool busy: false
    // Something Yui said was not seen: the heart blinks slowly and a blue dot breathes beside her.
    property bool unread: false
    property real blink: 0
    // Vertical float offset (in box units), animated while awake.
    property real hover: 0
    // Animation phases (0 - 1).
    property real beat: 0
    property real sweep: 0
    property real motes: 0
    // Turn about the vertical axis (radians) while awake: a full turn in spinSeconds (Equipment, Crystal
    // Spin; 0 does not turn).
    property real spinSeconds: 40
    property real spin: 0
    readonly property real unit: Math.min(width / 140, height / 200)

    // The teardrop's half width at t (0 at the top point, 1 at the bottom).
    function halfWidth(t) {
        var tm = 0.68, w = 42;
        if (t < tm)
            return w * Math.pow(Math.sin(Math.PI / 2 * t / tm), 0.85);

        return w * Math.sqrt(Math.max(0, 1 - Math.pow((t - tm) / (1 - tm), 2)));
    }

    // Outline points and the facets facing the viewer (each a diamond with its color) at a turn of rot.
    function geometry(rot) {
        var cx = 70, top = 14, h = 176, rows = 8, cols = 2;
        var outline = [], left = [], i, k, j;
        for (i = 0; i <= 40; i++) {
            var tt = i / 40;
            outline.push([cx + halfWidth(tt), top + h * tt]);
            left.unshift([cx - halfWidth(tt), top + h * tt]);
        }
        outline = outline.concat(left);
        // Rows at equal distances along the outline, so the round bottom keeps facets as large as the sides.
        var n = 600, len = [0], rowT = [];
        for (i = 1; i <= n; i++)
            len.push(len[i - 1] + Math.sqrt(Math.pow(halfWidth(i / n) - halfWidth((i - 1) / n), 2) + Math.pow(h / n, 2)));

        for (k = 0; k <= rows; k++) {
            var goal = len[n] * k / rows, s = 0;
            while (s < n && len[s] < goal)
                s++;

            rowT.push(s / n);
        }
        // Columns all the way round; column c sits at the angle c * step + rot.
        var step = Math.PI / 2 / cols;
        function point(row, c) {
            var t = rowT[Math.max(0, Math.min(rows, row))];
            return [cx + halfWidth(t) * Math.sin(c * step + rot), top + h * t];
        }
        function norm(v) {
            var l = Math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
            return [v[0] / l, v[1] / l, v[2] / l];
        }
        function dot(a, b) {
            return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
        }
        var seed = 7;
        function rnd() {
            seed = (seed * 9301 + 49297) % 233280;
            return seed / 233280;
        }
        var light = norm([-0.55, -0.65, 0.55]), back = norm([0.45, 0.5, 0.6]);
        var deep = [92, 168, 202], pale = [240, 252, 255];
        var facets = [];
        // Diamond lattice: staggered rows of points; each diamond spans rows k-1..k+1.
        for (k = 0; k <= rows; k++) {
            var o = (k + 1) % 2 ? 0.5 : 0;
            for (j = -2 * cols; j < 2 * cols; j++) {
                var c = j + o;
                var p = [point(k - 1, c), point(k, c + 0.5), point(k + 1, c), point(k, c - 0.5)];
                var y = (p[0][1] + p[1][1] + p[2][1] + p[3][1]) / 4;
                var t = Math.max(0.001, Math.min(0.999, (y - top) / h));
                var th = c * step + rot;
                var slope = (halfWidth(t + 0.002) - halfWidth(t - 0.002)) / (h * 0.004);
                // The facet's normal: the surface's at its centre, tilted up or down by row (the briolette zigzag).
                var tilt = (k % 2 ? 0.22 : -0.22) + (rnd() - 0.5) * 0.06;
                var nv = norm([Math.sin(th), -slope + tilt, Math.cos(th)]);
                // The back is not drawn.
                if (nv[2] <= 0)
                    continue;

                var d = dot(nv, light);
                var r = [2 * d * nv[0] - light[0], 2 * d * nv[1] - light[1], 2 * d * nv[2] - light[2]];
                var spec = Math.pow(Math.max(0, r[2]), 12);
                var fres = 0.55 + 0.45 * Math.max(0, nv[2]);
                var lit = Math.max(0, Math.min(1, (0.18 + 0.55 * Math.max(0, d) + 0.35 * Math.max(0, dot(nv, back))) * fres));
                var rgb = [];
                for (var m = 0; m < 3; m++) {
                    var v = deep[m] + (pale[m] - deep[m]) * lit;
                    // A glint brightens a facet towards white but never fills it.
                    rgb.push(Math.round(v + (250 - v) * 0.5 * spec));
                }
                facets.push({
                    "points": p,
                    "color": "rgba(" + rgb.join(",") + ",0.92)"
                });
            }
        }
        return {
            "outline": outline,
            "facets": facets
        };
    }

    function tracePath(ctx, points) {
        ctx.beginPath();
        ctx.moveTo(points[0][0], points[0][1]);
        for (var i = 1; i < points.length; i++)
            ctx.lineTo(points[i][0], points[i][1]);
        ctx.closePath();
    }

    // Heartbeat: bright twice, then a rest. Returns [opacity, scale] for a phase 0 - 1.
    function beatAt(phase) {
        var keys = [[0, 0.55, 0.85], [0.1, 1, 1.1], [0.2, 0.7, 0.95], [0.3, 1, 1.05], [0.5, 0.6, 0.9], [1, 0.55, 0.85]];
        for (var i = 1; i < keys.length; i++) {
            if (phase <= keys[i][0]) {
                var a = keys[i - 1], b = keys[i];
                var f = (phase - a[0]) / (b[0] - a[0]);
                f = 0.5 - Math.cos(Math.PI * f) / 2;
                return [a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f];
            }
        }
        return [0.55, 0.85];
    }

    // ---- The halo's heart (box units; from yui-halo-editor.html): the right half's cubic curves, the
    // left half mirrored. Upside down: point at y 35 behind the crystal, notch at y 164 under it.
    readonly property var haloCurves: [[107.1, 70.1, 134.1, 78.3, 173.5, 140.4], [194.9, 179, 162.8, 216.3, 119.1, 202.6], [70, 176, 71.1, 170.4, 70, 164]]
    readonly property real haloMiddle: (35 + 202.6) / 2
    // The whole halo (both layers, the sparkles) scaled about its middle to fit the widget: drawn at
    // full size its lobes reached past the sides and were cut off.
    readonly property real haloScale: 0.58
    // Glitter phase (0 - 1, a round of 3.2 s) for the sparkles of the halo's inner layer.
    property real glitter: 0

    function heartPath(ctx) {
        var k = haloCurves, i, m = function(x) {
            return 140 - x;
        };
        ctx.beginPath();
        ctx.moveTo(70, 35);
        for (i = 0; i < k.length; i++)
            ctx.bezierCurveTo(k[i][0], k[i][1], k[i][2], k[i][3], k[i][4], k[i][5]);

        // back up the left side, the same curves mirrored and reversed
        var ends = [[70, 35]].concat(k.map(function(s) {
            return [s[4], s[5]];
        }));
        for (i = k.length - 1; i >= 0; i--)
            ctx.bezierCurveTo(m(k[i][2]), k[i][3], m(k[i][0]), k[i][1], m(ends[i][0]), ends[i][1]);

        ctx.closePath();
    }

    // Where the sparkles sit (inside the inner layer: the heart at 0.76 about its middle, 4 lower), the
    // same every time (a seeded random). dots: [x, y, r, speed, offset]; glints: [x, y, r, offset].
    readonly property var sparkles: {
        var poly = [], k = haloCurves, p = [70, 35], i, j, t;
        function at(a, b, c, d, t) {
            var s = 1 - t;
            return s * s * s * a + 3 * s * s * t * b + 3 * s * t * t * c + t * t * t * d;
        }
        for (i = 0; i < k.length; i++) {
            for (j = 1; j <= 12; j++) {
                t = j / 12;
                poly.push([at(p[0], k[i][0], k[i][2], k[i][4], t), at(p[1], k[i][1], k[i][3], k[i][5], t)]);
            }
            p = [k[i][4], k[i][5]];
        }
        poly = poly.concat(poly.slice().reverse().map(function(q) {
            return [140 - q[0], q[1]];
        })).map(function(q) {
            return [70 + (q[0] - 70) * 0.76, haloMiddle + (q[1] - haloMiddle) * 0.76 + 4];
        });
        function inside(x, y) {
            var w = false;
            for (var a = 0, b = poly.length - 1; a < poly.length; b = a++)
                if ((poly[a][1] > y) !== (poly[b][1] > y) && x < (poly[b][0] - poly[a][0]) * (y - poly[a][1]) / (poly[b][1] - poly[a][1]) + poly[a][0])
                    w = !w;

            return w;
        }
        var seed = 21;
        function rnd() {
            seed = (seed * 9301 + 49297) % 233280;
            return seed / 233280;
        }
        var dots = [], glints = [], x, y;
        while (dots.length < 60) {
            x = -30 + rnd() * 200;
            y = 40 + rnd() * 170;
            if (inside(x, y))
                dots.push([x, y, 0.3 + rnd() * 0.55, 0.7 + rnd() * 0.8, rnd()]);

        }
        while (glints.length < 9) {
            x = -20 + rnd() * 180;
            y = 60 + rnd() * 140;
            // not behind the crystal
            if (inside(x, y) && !(Math.abs(x - 70) < 30 && y < 190))
                glints.push([x, y, 2.2 + rnd() * 2.6, rnd()]);

        }
        // to the halo's size (haloScale about its middle)
        var hs = haloScale;
        function fit(q) {
            var r = q.slice();
            r[0] = 70 + (q[0] - 70) * hs;
            r[1] = haloMiddle + (q[1] - haloMiddle) * hs;
            r[2] = Math.max(0.3, q[2] * hs);
            return r;
        }
        return {
            "dots": dots.map(fit),
            "glints": glints.map(fit)
        };
    }

    implicitWidth: 80
    implicitHeight: 120

    Item {
        id: box

        property var shape: crystal.geometry(0)

        // Drawn at the real size (not a scaled 140 x 200 picture), so it stays sharp at any size.
        readonly property real u: crystal.unit

        width: 140 * u
        height: 200 * u
        anchors.centerIn: parent
        onUChanged: {
            glow.requestPaint();
            facets.requestPaint();
            shade.requestPaint();
            heart.requestPaint();
        }

        // The halo behind the crystal, breathing: an upside-down heart (point behind the upper body,
        // lobes wide at the lower sides, notch under the crystal; drawn in yui-halo-editor.html) in two
        // layers: outside a faint rosy haze, much blurred, touched with the status color; inside, 0.76
        // the size and 4 lower, a film of the crystal's own ice, glittering (sparkles, below). Wider than
        // the box: drawn on a larger canvas. Painted once (the breathing is its opacity).
        Item {
            id: halo

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: crystal.visible

                NumberAnimation {
                    from: 0.55
                    to: 1
                    duration: 1600
                    easing.type: Easing.InOutSine
                }

                NumberAnimation {
                    from: 1
                    to: 0.55
                    duration: 1600
                    easing.type: Easing.InOutSine
                }

            }

            Canvas {
                id: glow

                // box units -90 .. 230 across, 0 .. 260 down
                x: -90 * box.u
                width: 320 * box.u
                height: 260 * box.u
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    var u = box.u;
                    var c = crystal.statusColor;
                    // A layer with a soft edge: the heart filled many times, from a little larger to a
                    // little smaller (spread: how far the edge fades, in box units), each faint, so they
                    // add up to alpha inside and fade out over the edge (Canvas has no blur here).
                    function layer(scale, dy, rgb, alpha, spread) {
                        var n = 24, each = 1 - Math.pow(1 - alpha, 1 / n);
                        var half = spread / 125;
                        for (var i = 0; i < n; i++) {
                            var s = crystal.haloScale * scale * (1 + half - 2 * half * i / (n - 1));
                            ctx.save();
                            ctx.scale(u, u);
                            ctx.translate(90, dy * crystal.haloScale);
                            ctx.translate(70, crystal.haloMiddle);
                            ctx.scale(s, s);
                            ctx.translate(-70, -crystal.haloMiddle);
                            crystal.heartPath(ctx);
                            ctx.fillStyle = Qt.rgba(rgb[0], rgb[1], rgb[2], each);
                            ctx.fill();
                            ctx.restore();
                        }
                    }
                    layer(1, 0, [0.91 * 0.85 + c.r * 0.15, 0.85 * 0.85 + c.g * 0.15, 0.88 * 0.85 + c.b * 0.15], 0.3, 24);
                    layer(0.76, 4, [0.66, 0.86, 0.93], 0.66, 9);
                }
            }

            // Glitter in the inner layer: fine dots twinkling, and a few four-point glints now and then.
            Repeater {
                model: crystal.sparkles.dots

                delegate: Rectangle {
                    readonly property real wave: Math.max(0, Math.sin(Math.PI * 2 * (crystal.glitter * modelData[3] + modelData[4])))

                    visible: !crystal.sleeping
                    x: (modelData[0] - modelData[2]) * box.u
                    y: (modelData[1] - modelData[2]) * box.u
                    width: modelData[2] * 2 * box.u
                    height: width
                    radius: width / 2
                    color: "#ffffff"
                    opacity: 0.15 + 0.85 * wave
                }

            }

            Repeater {
                model: crystal.sparkles.glints

                delegate: Canvas {
                    // each lights up briefly once a round, at its own moment
                    readonly property real phase: (crystal.glitter / 1.4 + modelData[3]) % 1

                    visible: !crystal.sleeping
                    x: (modelData[0] - modelData[2]) * box.u
                    y: (modelData[1] - modelData[2]) * box.u
                    width: modelData[2] * 2 * box.u
                    height: width
                    opacity: phase < 0.7 ? 0 : phase < 0.8 ? (phase - 0.7) / 0.1 : phase < 0.9 ? 1 - 0.7 * (phase - 0.8) / 0.1 : 0.3 * (1 - (phase - 0.9) / 0.1)
                    onWidthChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        var r = width / 2, w = r * 0.22;
                        ctx.translate(r, r);
                        ctx.beginPath();
                        ctx.moveTo(0, -r);
                        ctx.lineTo(w, -w);
                        ctx.lineTo(r, 0);
                        ctx.lineTo(w, w);
                        ctx.lineTo(0, r);
                        ctx.lineTo(-w, w);
                        ctx.lineTo(-r, 0);
                        ctx.lineTo(-w, -w);
                        ctx.closePath();
                        ctx.fillStyle = "#ffffff";
                        ctx.fill();
                    }
                }

            }

        }

        Item {
            id: body

            width: box.width
            height: box.height
            y: crystal.hover * box.u
            opacity: crystal.sleeping ? 0.5 : 1

            // The facets: a still picture, painted once.
            Canvas {
                id: facets

                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.scale(box.u, box.u);
                    crystal.tracePath(ctx, box.shape.outline);
                    ctx.fillStyle = "#a8dcee";
                    ctx.fill();
                    ctx.save();
                    crystal.tracePath(ctx, box.shape.outline);
                    ctx.clip();
                    ctx.lineWidth = 0.5;
                    ctx.strokeStyle = "rgba(255,255,255,0.45)";
                    var list = crystal.geometry(crystal.spin).facets;
                    for (var i = 0; i < list.length; i++) {
                        crystal.tracePath(ctx, list[i].points);
                        ctx.fillStyle = list[i].color;
                        ctx.fill();
                        ctx.stroke();
                    }
                    ctx.restore();
                }
            }

            // Volume, still: shadow away from the light, a bright rim at the upper left, a soft highlight.
            Canvas {
                id: shade

                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.scale(box.u, box.u);
                    var outline = box.shape.outline;
                    ctx.save();
                    crystal.tracePath(ctx, outline);
                    ctx.clip();
                    ctx.save();
                    ctx.translate(58, 102);
                    ctx.scale(1, 127 / 60);
                    var g = ctx.createRadialGradient(0, 0, 0, 0, 0, 60);
                    g.addColorStop(0.45, "rgba(40,110,150,0)");
                    g.addColorStop(1, "rgba(40,110,150,0.32)");
                    ctx.fillStyle = g;
                    ctx.fillRect(-80, -80, 160, 160);
                    ctx.restore();
                    ctx.save();
                    ctx.translate(52, 92);
                    ctx.rotate(18 * Math.PI / 180);
                    ctx.scale(1, 15 / 6);
                    var hl = ctx.createRadialGradient(0, 0, 0, 0, 0, 6);
                    hl.addColorStop(0, "rgba(255,255,255,0.75)");
                    hl.addColorStop(1, "rgba(255,255,255,0)");
                    ctx.fillStyle = hl;
                    ctx.beginPath();
                    ctx.arc(0, 0, 6, 0, Math.PI * 2);
                    ctx.fill();
                    ctx.restore();
                    ctx.restore();
                    var rim = ctx.createLinearGradient(28, 14, 112, 67);
                    rim.addColorStop(0, "rgba(255,255,255,0.85)");
                    rim.addColorStop(0.4, "rgba(255,255,255,0)");
                    rim.addColorStop(0.85, "rgba(200,238,252,0)");
                    rim.addColorStop(1, "rgba(200,238,252,0.35)");
                    ctx.strokeStyle = rim;
                    ctx.lineWidth = 1.4;
                    crystal.tracePath(ctx, outline);
                    ctx.stroke();
                }
            }

            // The heart: Yui's light in the round bottom, beating.
            Canvas {
                id: heart

                readonly property var pulse: crystal.beatAt(crystal.beat)

                x: (70 - 26) * box.u
                y: (135 - 26) * box.u
                width: 52 * box.u
                height: 52 * box.u
                readonly property real wave: 0.5 - Math.cos(Math.PI * 2 * crystal.blink) / 2

                opacity: crystal.unread ? 0.25 + 0.75 * wave : crystal.sleeping ? 0.2 + 0.25 * (0.5 - Math.cos(Math.PI * 2 * crystal.beat) / 2) : pulse[0]
                scale: crystal.unread ? 0.8 + 0.45 * wave : crystal.sleeping ? 0.9 : pulse[1]
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.scale(box.u, box.u);
                    var g = ctx.createRadialGradient(26, 26, 0, 26, 26, 26);
                    var c = crystal.statusColor;
                    g.addColorStop(0, "#ffffff");
                    g.addColorStop(0.3, Qt.rgba(c.r, c.g, c.b, 1));
                    g.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0));
                    ctx.fillStyle = g;
                    ctx.beginPath();
                    ctx.arc(26, 26, 26, 0, Math.PI * 2);
                    ctx.fill();
                }
            }

            // A streak of light passing over the facets now and then (from 70% to 90% of each round).
            Canvas {
                id: streak

                readonly property real offset: {
                    // The light crosses in the last 1/16 of the cycle (4 s of 64) and waits the rest.
                    var p = crystal.sweep;
                    var start = 1 - 1 / 16;
                    if (p < start)
                        return -120;

                    var f = (p - start) * 16;
                    return -120 + 240 * (0.5 - Math.cos(Math.PI * f) / 2);
                }

                anchors.fill: parent
                visible: !crystal.sleeping
                onOffsetChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.scale(box.u, box.u);
                    if (Math.abs(offset) >= 120)
                        return ;

                    crystal.tracePath(ctx, box.shape.outline);
                    ctx.clip();
                    ctx.fillStyle = "rgba(255,255,255,0.45)";
                    ctx.fillRect(40 + offset, 0, 8, 200);
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 600
                }

            }

        }

        // Unread mark: a breathing blue dot at the upper right.
        Rectangle {
            visible: crystal.unread
            x: 112 * box.u
            y: 10 * box.u
            width: Math.max(8, 10 * box.u)
            height: width
            radius: width / 2
            color: "#4BB4EC"
            opacity: 0.35 + 0.65 * (0.5 - Math.cos(Math.PI * 2 * crystal.blink) / 2)
        }

        // Motes of light rising around the crystal and fading.
        Repeater {
            model: [[50, 150, 1.4, "#cdeeff", 0], [90, 145, 1.2, "", 0.44], [62, 175, 1, "#ffffff", 0.72], [84, 168, 1.3, "#cdeeff", 0.22]]

            delegate: Rectangle {
                readonly property real phase: (crystal.motes + 1 - modelData[4]) % 1

                visible: !crystal.sleeping
                x: (modelData[0] - modelData[2]) * box.u
                y: (modelData[1] - modelData[2] - 90 * phase) * box.u
                width: modelData[2] * 2 * box.u
                height: width
                radius: width / 2
                color: modelData[3] || crystal.statusColor
                opacity: phase < 0.2 ? 0.9 * phase / 0.2 : 0.9 * (1 - phase) / 0.8
            }

        }

    }

    onSpinChanged: facets.requestPaint()
    onStatusColorChanged: {
        glow.requestPaint();
        heart.requestPaint();
    }

    SequentialAnimation on hover {
        running: crystal.visible && !crystal.sleeping
        loops: Animation.Infinite

        NumberAnimation {
            from: -4
            to: 4
            duration: 1800
            easing.type: Easing.InOutSine
        }

        NumberAnimation {
            from: 4
            to: -4
            duration: 1800
            easing.type: Easing.InOutSine
        }

    }

    NumberAnimation on beat {
        from: 0
        to: 1
        duration: crystal.sleeping ? 6000 : crystal.busy ? 1000 : 2400
        loops: Animation.Infinite
        running: crystal.visible
    }

    NumberAnimation on sweep {
        from: 0
        to: 1
        duration: crystal.busy ? 16000 : 64000
        loops: Animation.Infinite
        running: crystal.visible && !crystal.sleeping
    }

    // About 30 frames a second is enough for a slow turn and halves the repainting.
    Timer {
        interval: 33
        repeat: true
        running: crystal.visible && !crystal.sleeping && crystal.spinSeconds > 0
        onTriggered: crystal.spin = (crystal.spin + Math.PI * 2 * interval / (crystal.spinSeconds * 1000)) % (Math.PI * 2)
    }

    NumberAnimation on glitter {
        from: 0
        to: 1
        duration: 3200
        loops: Animation.Infinite
        running: crystal.visible && !crystal.sleeping
    }

    NumberAnimation on blink {
        from: 0
        to: 1
        duration: 1600
        loops: Animation.Infinite
        running: crystal.visible && crystal.unread
    }

    NumberAnimation on motes {
        from: 0
        to: 1
        duration: 5000
        loops: Animation.Infinite
        running: crystal.visible && !crystal.sleeping
    }

}
