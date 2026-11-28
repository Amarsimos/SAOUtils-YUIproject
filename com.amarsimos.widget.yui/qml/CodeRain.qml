import QtQuick 2.12

// The code wall behind System Console (as the wall of Cardinal's code in the series): a black ground,
// six soft colored tiles in two rows (pink, dark, amber / violet, cyan, green), and columns of letters
// scrolling down, each at its own speed and brightness, with gaps.
// Cheap to run: the tiles are painted once; each column is a Text drawn twice, one above the other,
// moved by an animation (the GPU only moves it, nothing is painted again); a few columns get new
// letters every half second.
Item {
    id: rain

    property bool running: visible
    readonly property int cellWidth: 11
    readonly property int cellHeight: 14
    readonly property string glyphs: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#$%&@*+=<>?"
    // At least one (the height is 0 or less for a moment while System Console opens).
    readonly property int rows: Math.max(1, Math.ceil(height / cellHeight) + 1)

    // A column of letters, one a line, about one in six a gap.
    function columnText() {
        var lines = [];
        for (var i = 0; i < rows; i++)
            lines.push(Math.random() < 0.17 ? " " : glyphs.charAt(Math.floor(Math.random() * glyphs.length)));

        return lines.join("\n");
    }

    clip: true

    Rectangle {
        anchors.fill: parent
        color: "#060608"
    }

    // The tiles: ten faint fills growing outwards make a soft edge (Canvas has no blur in Qt 5.13).
    Canvas {
        readonly property var tiles: [[0.06, 0.04, 0.34, 0.46, "232,96,150"], [0.40, 0.0, 0.18, 0.5, "40,40,48"], [0.58, 0.06, 0.38, 0.44, "240,190,90"], [0.06, 0.52, 0.36, 0.44, "130,120,235"], [0.42, 0.48, 0.18, 0.48, "90,210,235"], [0.60, 0.5, 0.36, 0.46, "130,225,110"]]

        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            for (var t = 0; t < tiles.length; t++) {
                var tile = tiles[t];
                ctx.fillStyle = "rgba(" + tile[4] + ",0.06)";
                for (var k = 0; k < 10; k++) {
                    var e = k * 4;
                    ctx.fillRect(tile[0] * width - e + 20, tile[1] * height - e + 20, tile[2] * width + 2 * e - 40, tile[3] * height + 2 * e - 40);
                }
            }
        }
    }

    Repeater {
        id: columns

        model: Math.ceil(rain.width / rain.cellWidth)

        // Two copies of the column, one above the other, sliding down by one column height and
        // starting again: seamless.
        Item {
            id: column

            readonly property real brightness: Math.random()
            property string letters: rain.columnText()
            readonly property real span: rain.rows * rain.cellHeight

            x: index * rain.cellWidth
            width: rain.cellWidth
            height: span * 2
            opacity: brightness < 0.22 ? 0.35 : 0.4 + 0.6 * brightness

            Repeater {
                model: 2

                Text {
                    y: index * column.span
                    width: rain.cellWidth
                    text: column.letters
                    color: column.brightness < 0.22 ? "#8A8C94" : "#FFFFFF"
                    font.family: "Consolas"
                    font.pixelSize: 13
                    font.bold: true
                    lineHeightMode: Text.FixedHeight
                    lineHeight: rain.cellHeight
                    horizontalAlignment: Text.AlignHCenter
                    renderType: Text.QtRendering
                }

            }

            NumberAnimation on y {
                from: -column.span
                to: 0
                duration: column.span / (14 + Math.random() * 40) * 1000
                loops: Animation.Infinite
                running: rain.running
            }

        }

    }

    // Now and then some columns change their letters.
    Timer {
        interval: 500
        repeat: true
        running: rain.running && columns.count > 0
        onTriggered: {
            for (var i = 0; i < 3; i++) {
                var column = columns.itemAt(Math.floor(Math.random() * columns.count));
                if (column)
                    column.letters = rain.columnText();

            }
        }
    }

}
