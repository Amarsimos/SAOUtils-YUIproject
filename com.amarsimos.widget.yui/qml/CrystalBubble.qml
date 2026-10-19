import NERvGear 1.0 as NVG
import QtQuick 2.12
import QtQuick.Shapes 1.12
// Fills Qt.application.screens (the monitors), used to keep the bubble on the crystal's screen.
import QtQuick.Window 2.12

// What Yui says while she is a crystal (Yui's Heart): a small SAO message window next to the crystal,
// in its own view so it is not clipped by the small widget, with a comic-style tail pointing at the
// crystal. Its title bar takes the crystal's status color. It never takes focus; it stays stayTime ms
// (paused while hovered) and a click closes it. Created once and reused; call show().
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
    readonly property int tailSize: 18
    readonly property color edgeColor: "#99888888"

    function show(heading, text, accent, target) {
        bubble.heading = heading;
        bubble.text = text;
        bubble.accent = accent;
        bubble.target = target;
        place();
        aniOut.stop();
        if (!visible || content.opacity < 1) {
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

    // The screen the crystal is on (with several monitors the bubble must follow it, not stay on the
    // screen its own view was created on).
    function targetScreen() {
        var cx = target.x + target.width / 2;
        var cy = target.y + target.height / 2;
        var screens = Qt.application.screens;
        for (var i = 0; i < screens.length; i++) {
            var s = screens[i];
            if (cx >= s.virtualX && cx < s.virtualX + s.width && cy >= s.virtualY && cy < s.virtualY + s.height)
                return s;

        }
        return screens.length > 0 ? screens[0] : null;
    }

    // Moves with the crystal while shown (its floating, the widget being dragged); the side (above /
    // below) chosen in show() is kept, so the bubble does not flip while following.
    function follow(newTarget) {
        if (newTarget.x === target.x && newTarget.y === target.y && newTarget.width === target.width)
            return ;

        target = newTarget;
        place(true);
    }

    // Above the crystal, centered on it; below it when there is no room above (unless keepSide).
    // Kept on its screen.
    function place(keepSide) {
        var s = targetScreen();
        var left = s ? s.virtualX : 0;
        var top = s ? s.virtualY : 0;
        var right = left + (s ? s.width : 1920);
        if (!keepSide)
            below = target.y - height < top;

        x = Math.round(Math.max(left, Math.min(right - width, target.x + target.width / 2 - width / 2)));
        y = Math.round(below ? target.y + target.height : target.y - height);
    }

    color: "transparent"
    // Never steals focus, but takes mouse input (with acceptInput false SAO Utils lets clicks pass
    // through the view, as with its own Immortal Object warning) over its whole rectangle.
    acceptFocus: false
    acceptInput: true
    solid: true
    width: 300
    height: panel.height + tailSize
    visible: false
    onHeightChanged: {
        if (visible)
            place();

    }

    Item {
        id: content

        anchors.fill: parent
        opacity: 0

        // SAO message window: light translucent panel under a title bar.
        Rectangle {
            id: panel

            y: bubble.below ? bubble.tailSize : 0
            width: parent.width
            height: header.height + body.implicitHeight + 20
            radius: 4
            color: "#F2F4F4F4"
            border.color: bubble.edgeColor
            border.width: 1

            Rectangle {
                id: header

                x: 1
                y: 1
                width: parent.width - 2
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

        }

        // Comic-style tail: two curved sides from the panel edge to a point aimed at the crystal,
        // leaning toward it. Drawn over the panel's edge so it joins the panel seamlessly; mirrored
        // when the bubble is below the crystal (then it starts from the title bar).
        Shape {
            id: tail

            // Tip: straight toward the crystal's center; base: up to 14 px back toward the middle.
            readonly property real tipX: Math.max(10, Math.min(bubble.width - 10, bubble.target.x + bubble.target.width / 2 - bubble.x))
            readonly property real baseX: Math.max(16, Math.min(bubble.width - 16, tipX + Math.max(-14, Math.min(14, bubble.width / 2 - tipX))))
            readonly property real h: bubble.tailSize

            y: bubble.below ? 0 : panel.height - 1
            width: bubble.width
            height: h + 1
            layer.enabled: true
            layer.samples: 4

            ShapePath {
                fillColor: bubble.below ? bubble.accent : panel.color
                strokeColor: bubble.below ? "transparent" : bubble.edgeColor
                strokeWidth: 1
                joinStyle: ShapePath.RoundJoin
                // From the panel edge (left of the base) out to the tip and back (right of the base).
                startX: tail.baseX - 9
                startY: bubble.below ? tail.h + 1 : 0

                PathQuad {
                    x: tail.tipX
                    y: bubble.below ? 0 : tail.h
                    controlX: tail.baseX - 3
                    controlY: bubble.below ? tail.h * 0.4 : tail.h * 0.6
                }

                PathQuad {
                    x: tail.baseX + 9
                    y: bubble.below ? tail.h + 1 : 0
                    controlX: tail.baseX + 5
                    controlY: bubble.below ? tail.h * 0.6 : tail.h * 0.4
                }

            }

        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: {
                console.log("[bubble] hovered:", containsMouse);
                if (containsMouse)
                    stayTimer.stop();
                else if (bubble.visible && !aniOut.running)
                    stayTimer.restart();
            }
            // A click closes the bubble (the crystal itself opens the chat).
            onClicked: {
                console.log("[bubble] clicked, closing");
                bubble.hide();
            }
        }

        transform: Scale {
            id: contentScale

            xScale: 0.1
            yScale: 0.05
            origin.x: tail.tipX
            origin.y: bubble.below ? 0 : bubble.height
        }

    }

    // Opens like SAO Utils' own warning: a thin line widens, then unfolds (from the tail's tip).
    ParallelAnimation {
        id: aniIn

        NumberAnimation {
            target: content
            property: "opacity"
            duration: 250
            to: 1
        }

        SequentialAnimation {
            NumberAnimation {
                target: contentScale
                property: "xScale"
                duration: 100
                from: 0.1
                to: 1
                easing.type: Easing.OutQuad
            }

            NumberAnimation {
                target: contentScale
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
            target: content
            property: "opacity"
            duration: 300
            to: 0
        }

        SequentialAnimation {
            NumberAnimation {
                target: contentScale
                property: "yScale"
                duration: 180
                to: 0.05
                easing.type: Easing.InQuad
            }

            NumberAnimation {
                target: contentScale
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
