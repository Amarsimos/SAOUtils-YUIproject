import QtQuick 2.12

// The code wall behind System Console (as the wall of Cardinal's code in the series): a black ground,
// columns of letters scrolling down at their own speed, white for most of them (brighter ones with a
// glow), a few grey, some gaps; behind them six soft colored tiles in two rows (pink, dark, amber /
// violet, cyan, green). Painted 12 times a second while running.
Canvas {
    id: rain

    property bool running: visible
    readonly property int cellWidth: 11
    readonly property int cellHeight: 14
    readonly property string glyphs: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#$%&@*+=<>?"
    // [x, y, width, height] as parts of the canvas, and the tile's color.
    readonly property var tiles: [[0.06, 0.04, 0.34, 0.46, "232,96,150"], [0.40, 0.0, 0.18, 0.5, "40,40,48"], [0.58, 0.06, 0.38, 0.44, "240,190,90"], [0.06, 0.52, 0.36, 0.44, "130,120,235"], [0.42, 0.48, 0.18, 0.48, "90,210,235"], [0.60, 0.5, 0.36, 0.46, "130,225,110"]]
    // Per column: its cells ({ch, v (brightness 0-1), gap}), top first, its offset and speed (px a frame).
    property var columns: []

    function glyph() {
        return glyphs.charAt(Math.floor(Math.random() * glyphs.length));
    }

    function cell() {
        return {
            "ch": glyph(),
            "v": Math.random(),
            "gap": Math.random() < 0.18
        };
    }

    function build() {
        var count = Math.ceil(width / cellWidth), rows = Math.ceil(height / cellHeight) + 2, list = [];
        for (var i = 0; i < count; i++) {
            var cells = [];
            for (var j = 0; j < rows; j++)
                cells.push(cell());

            list.push({
                "cells": cells,
                "offset": Math.random() * cellHeight,
                "speed": 1 + Math.random() * 3
            });
        }
        columns = list;
    }

    renderTarget: Canvas.FramebufferObject
    onWidthChanged: build()
    onHeightChanged: build()
    onPaint: {
        var ctx = getContext("2d");
        ctx.fillStyle = "#060608";
        ctx.fillRect(0, 0, width, height);
        // The tiles: ten faint fills growing outwards make a soft edge (Canvas has no blur in Qt 5.13).
        for (var t = 0; t < tiles.length; t++) {
            var tile = tiles[t];
            ctx.fillStyle = "rgba(" + tile[4] + ",0.05)";
            for (var k = 0; k < 10; k++) {
                var e = k * 4;
                ctx.fillRect(tile[0] * width - e + 20, tile[1] * height - e + 20, tile[2] * width + 2 * e - 40, tile[3] * height + 2 * e - 40);
            }
        }
        ctx.font = "bold 13px Consolas";
        ctx.textBaseline = "top";
        for (var i = 0; i < columns.length; i++) {
            var column = columns[i];
            column.offset += column.speed;
            if (column.offset >= cellHeight) {
                column.offset -= cellHeight;
                column.cells.pop();
                column.cells.unshift(cell());
            }
            for (var j = 0; j < column.cells.length; j++) {
                var c = column.cells[j];
                if (c.gap)
                    continue;

                if (Math.random() < 0.05)
                    c.ch = glyph();

                if (Math.random() < 0.02)
                    c.v = Math.random();

                if (c.v < 0.25) {
                    ctx.shadowBlur = 0;
                    ctx.fillStyle = "rgba(110,112,120,0.5)";
                } else {
                    ctx.shadowBlur = c.v > 0.8 ? 5 : 0;
                    ctx.shadowColor = "#ffffff";
                    ctx.fillStyle = "rgba(255,255,255," + (0.35 + 0.65 * c.v) + ")";
                }
                ctx.fillText(c.ch, i * cellWidth, (j - 1) * cellHeight + column.offset);
            }
        }
        ctx.shadowBlur = 0;
    }

    Timer {
        interval: 83
        repeat: true
        running: rain.running && rain.width > 0
        onTriggered: rain.requestPaint()
    }

}
