import NERvGear 1.0 as NVG
import QtQuick 2.12
import QtQuick.Shapes 1.12

// What Yui says while she is a crystal (Yui's Heart): a small SAO message window next to the crystal,
// in its own view so it is not clipped by the small widget. Its title bar takes the crystal's status
// color. It never takes focus; it stays BUBBLE_TIME ms (paused while hovered), and a click opens the
// chat. Created once and reused; call show().
NVG.View {
    id: bubble

    // Crystal rectangle in screen coordinates; the bubble points at it.
    property rect target
    property string heading: "MHCP001 · Yui"
    property string text
    property color accent: "#2CE67C"
    // True when the bubble sits below the crystal (no room above it).
    property bool below: false
    readonly property int stayTime: 8000
    readonly property int tailSize: 9

    signal clicked()

    function show(heading, text, accent, target) {
        bubble.heading = heading;
        bubble.text = text;
        bubble.accent = accent;
        bubble.target = target;
        place();
        aniOut.stop();
        if (!visible || panel.opacity < 1) {
            visible = true;
            aniIn.restart();
        }
        stayTimer.restart();
    }

    function hide() {
        stayTimer.stop();
        if (visible && !aniOut.running) {
            aniIn.stop();
            aniOut.start();
        }
    }

    // Above the crystal, centered on it; below it when there is no room above. Kept on its screen.
    function place() {
        var left = screen ? screen.virtualX : 0;
        var top = screen ? screen.virtualY : 0;
        var right = left + (screen ? screen.width : 1920);
        below = target.y - height < top;
        x = Math.round(Math.max(left, Math.min(right - width, target.x + target.width / 2 - width / 2)));
        y = Math.round(below ? target.y + target.height : target.y - height);
    }

    color: "transparent"
    acceptFocus: false
    acceptInput: false
    width: 300
    height: panel.height + tailSize + 4
    visible: false
    onHeightChanged: if (visible)
        place()

    Item {
        id: content

        anchors.fill: parent

        // SAO message window: light translucent panel under a title bar.
        Rectangle {
            id: panel

            y: bubble.below ? bubble.tailSize : 0
            width: parent.width
            height: header.height + body.implicitHeight + 20
            radius: 3
            color: "#EEF4F4F4"
            border.color: "#FFFFFF"
            border.width: 1
            opacity: 0

            Rectangle {
                id: header

                width: parent.width
                height: 24
                radius: 3
                color: bubble.accent

                // Square off the bottom corners of the title bar.
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: parent.radius
                    color: parent.color
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 10
                    width: parent.width - 20
                    text: bubble.heading
                    color: "#FFFFFF"
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                }

            }

            Text {
                id: body

                x: 12
                y: header.height + 10
                width: parent.width - 24
                text: bubble.text
                color: "#333333"
                font.pixelSize: 13
                wrapMode: Text.Wrap
                maximumLineCount: 6
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }

            transform: Scale {
                id: panelScale

                xScale: 0.1
                yScale: 0.05
                origin.x: panel.width / 2
                origin.y: bubble.below ? 0 : panel.height
            }

        }

        // Pointer toward the crystal (below the panel, or above it when the bubble is below).
        Shape {
            id: tail

            readonly property real tipX: Math.max(bubble.tailSize + 4, Math.min(bubble.width - bubble.tailSize - 4, bubble.target.x + bubble.target.width / 2 - bubble.x))

            opacity: panel.opacity
            width: bubble.width
            height: bubble.tailSize
            y: bubble.below ? 0 : panel.height

            ShapePath {
                fillColor: bubble.below ? bubble.accent : panel.color
                strokeColor: "transparent"
                startX: tail.tipX - bubble.tailSize
                startY: bubble.below ? bubble.tailSize : 0

                PathLine {
                    x: tail.tipX
                    y: bubble.below ? 0 : bubble.tailSize
                }

                PathLine {
                    x: tail.tipX + bubble.tailSize
                    y: bubble.below ? bubble.tailSize : 0
                }

            }

        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: {
                if (containsMouse)
                    stayTimer.stop();
                else if (bubble.visible && !aniOut.running)
                    stayTimer.restart();
            }
            onClicked: {
                bubble.hide();
                bubble.clicked();
            }
        }

    }

    // Opens like SAO Utils' own warning: a thin line widens, then unfolds.
    ParallelAnimation {
        id: aniIn

        NumberAnimation {
            target: panel
            property: "opacity"
            duration: 250
            to: 1
        }

        SequentialAnimation {
            NumberAnimation {
                target: panelScale
                property: "xScale"
                duration: 100
                from: 0.1
                to: 1
                easing.type: Easing.OutQuad
            }

            NumberAnimation {
                target: panelScale
                property: "yScale"
                duration: 200
                from: 0.05
                to: 1
                easing.type: Easing.OutBack
                easing.overshoot: 1.5
            }

        }

    }

    ParallelAnimation {
        id: aniOut

        onFinished: bubble.visible = false

        NumberAnimation {
            target: panel
            property: "opacity"
            duration: 300
            to: 0
        }

        SequentialAnimation {
            NumberAnimation {
                target: panelScale
                property: "yScale"
                duration: 180
                to: 0.05
                easing.type: Easing.InQuad
            }

            NumberAnimation {
                target: panelScale
                property: "xScale"
                duration: 120
                to: 0.1
                easing.type: Easing.OutQuad
            }

        }

    }

    Timer {
        id: stayTimer

        interval: bubble.stayTime
        onTriggered: bubble.hide()
    }

}
