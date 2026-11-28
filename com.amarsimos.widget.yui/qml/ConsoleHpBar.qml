import QtQuick 2.12

// The SAO HUD bar of System Console: a dark frame slanted at its right end, filled with green, yellow
// or red (as the HP bar over a player's head). Painted again only when its value or level changes.
Canvas {
    id: bar

    // 0-100, NaN when unknown (empty frame).
    property real value: NaN
    // 0 green, 1 yellow, 2 red.
    property int level: 0
    readonly property var fills: [["#A7E46A", "#6CB32C"], ["#FFD85A", "#E2A400"], ["#F2668F", "#C0204F"]]

    implicitHeight: 14
    onValueChanged: requestPaint()
    onLevelChanged: requestPaint()
    onWidthChanged: requestPaint()
    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        var w = width, h = height, slant = 9;
        ctx.fillStyle = "#3A3F47";
        ctx.beginPath();
        ctx.moveTo(0, 0);
        ctx.lineTo(w, 0);
        ctx.lineTo(w - slant, h);
        ctx.lineTo(0, h);
        ctx.closePath();
        ctx.fill();
        if (isNaN(value))
            return ;

        var inner = Math.max(0, Math.min(1, value / 100)) * (w - 4);
        if (inner <= 0)
            return ;

        var g = ctx.createLinearGradient(0, 2, 0, h - 2);
        g.addColorStop(0, fills[level][0]);
        g.addColorStop(1, fills[level][1]);
        ctx.fillStyle = g;
        ctx.beginPath();
        ctx.moveTo(2, 2);
        ctx.lineTo(2 + inner, 2);
        ctx.lineTo(Math.max(2, 2 + inner - (slant - 2)), h - 2);
        ctx.lineTo(2, h - 2);
        ctx.closePath();
        ctx.fill();
    }
}
