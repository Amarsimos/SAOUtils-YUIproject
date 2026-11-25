import NERvGear 1.0 as NVG
import QtQuick 2.12
import QtQuick.Shapes 1.12
// Fills Qt.application.screens (the monitors), used to keep the bubble on the crystal's screen.
import QtQuick.Window 2.12

// What Yui says while she is a crystal (Yui's Heart): a small SAO instant message window next to the
// crystal, in its own view so it is not clipped by the small widget, pointing at the crystal. Its title bar takes the crystal's status color; it pops up like SAO Utils' GGO mail box
// menu. It never takes focus; it stays stayTime ms (paused while hovered) and a click closes it.
// Created once and reused; call show().
NVG.View {
    id: bubble

    // Crystal rectangle in screen coordinates; the bubble points at it.
    property rect target
    property string heading: "Yui"
    property string text
    property color accent: "#2CE67C"
    // The message font (Equipment, Message Font), as in the chat window. Without it the system's font is
    // used: on a Japanese system Chinese text then mixes Japanese glyphs with fallback ones of other weights.
    property string fontFamily: "Source Han Sans SC"
    // True when the bubble sits below the crystal (no room above it).
    property bool below: false
    // Time on screen and opacity (Equipment, set by the widget), and whether it pops up with a sound.
    property int stayTime: 8000
    readonly property int tailSize: 10
    // Room left between the bubble and Yui, for the widget's drag bar that SAO Utils shows above the
    // widget (the bubble's whole rectangle takes the mouse, so it must not cover it).
    readonly property int gap: 28
    readonly property color edgeColor: "#99888888"
    property real shownOpacity: 0.8
    property bool sound: true
    // Opacity of the texts, faded out first when the bubble closes.
    property real textOpacity: 1

    // Closed by a click (not by its time running out).
    signal dismissed()

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

    // Moves with the crystal while shown (its floating, the widget being dragged), changing sides
    // when it reaches the top or bottom of its screen.
    function follow(newTarget) {
        if (newTarget.x === target.x && newTarget.y === target.y && newTarget.width === target.width)
            return ;

        target = newTarget;
        place();
    }

    // Above Yui (gap away), centered on her; below her when there is no room above, and back above
    // once there is room again (with a margin, so her floating does not make it flip back and forth).
    // When neither side has room, the side with more. Kept on her screen.
    function place() {
        var s = targetScreen();
        var left = s ? s.virtualX : 0;
        var top = s ? s.virtualY : 0;
        var right = left + (s ? s.width : 1920);
        var bottom = top + (s ? s.height : 1080);
        var margin = 12;
        var roomAbove = target.y - gap - top;
        var roomBelow = bottom - (target.y + target.height + gap);
        if (roomAbove < height && roomBelow < height)
            below = roomBelow > roomAbove;
        else if (below)
            below = roomBelow >= height && roomAbove < height + margin;
        else
            below = roomAbove < height;
        x = Math.round(Math.max(left, Math.min(right - width, target.x + target.width / 2 - width / 2)));
        y = Math.round(below ? target.y + target.height + gap : target.y - gap - height);
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

        // The bubble's background (panel and tail), at the Bubble Opacity (shownOpacity, Equipment) as
        // one layer (so overlapping parts do not show through twice); the texts are above it and stay
        // fully visible, as in the chat panel.
        Item {
            id: backgroundLayer

            anchors.fill: parent
            opacity: bubble.shownOpacity
            layer.enabled: true

            // SAO instant message window (as the chat's MessageWindow.qml): a white title bar in the SAO
            // UI font, a thin strip in the crystal's status color, the text on light gray, a white bottom
            // edge.
            Rectangle {
                id: panel

                y: bubble.below ? bubble.tailSize : 0
                width: parent.width
                height: header.height + statusStrip.height + body.height + 6
                radius: 3
                color: "#F8F8F8"
                border.color: "#C8C8C8"
                border.width: 1

                Rectangle {
                    id: header

                    x: 1
                    y: 1
                    width: parent.width - 2
                    height: 24
                    radius: 2
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: "#FFFFFF"
                        }

                        GradientStop {
                            position: 1
                            color: "#EEEEEE"
                        }

                    }

                }

                Rectangle {
                    id: statusStrip

                    x: 1
                    y: header.y + header.height
                    width: parent.width - 2
                    height: 2
                    color: bubble.accent

                    // Breathing like the chat window's thinking strip (MessageWindow).
                    SequentialAnimation on opacity {
                        running: bubble.visible
                        loops: Animation.Infinite

                        NumberAnimation {
                            from: 0.25
                            to: 1
                            duration: 700
                            easing.type: Easing.InOutSine
                        }

                        NumberAnimation {
                            from: 1
                            to: 0.25
                            duration: 700
                            easing.type: Easing.InOutSine
                        }

                    }

                }

                Rectangle {
                    id: body

                    x: 1
                    y: statusStrip.y + statusStrip.height
                    width: parent.width - 2
                    height: bodyText.implicitHeight + 18
                    color: "#E4E4E4"

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: "#D6D6D6"
                    }

                }

            }

            // SAO pointer: a straight triangle from the panel's edge to the crystal (as the message
            // windows' pointers), over the edge so it joins the panel; at the top when the bubble is below.
            Shape {
                id: tail

                readonly property real tipX: Math.max(12, Math.min(bubble.width - 12, bubble.target.x + bubble.target.width / 2 - bubble.x))
                readonly property real h: bubble.tailSize

                y: bubble.below ? 0 : panel.height - 1
                width: bubble.width
                height: h + 1
                layer.enabled: true
                layer.samples: 4

                ShapePath {
                    fillColor: panel.color
                    strokeColor: panel.border.color
                    strokeWidth: 1
                    joinStyle: ShapePath.MiterJoin
                    startX: tail.tipX - tail.h
                    startY: bubble.below ? tail.h + 1 : 0

                    PathLine {
                        x: tail.tipX
                        y: bubble.below ? 0 : tail.h
                    }

                    PathLine {
                        x: tail.tipX + tail.h
                        y: bubble.below ? tail.h + 1 : 0
                    }

                }

            }

        }

        Text {
            x: panel.x + header.x + 8
            y: panel.y + header.y
            width: header.width - 16
            height: header.height
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: bubble.heading
            opacity: bubble.textOpacity
            color: "#777777"
            font.family: "SAO UI"
            font.pixelSize: 15
            elide: Text.ElideRight
        }

        Text {
            id: bodyText

            x: panel.x + body.x + 11
            y: panel.y + body.y + 9
            width: body.width - 22
            text: bubble.text
            opacity: bubble.textOpacity
            color: "#3A3A3A"
            font.family: bubble.fontFamily
            font.pixelSize: 13
            wrapMode: Text.Wrap
            maximumLineCount: 6
            elide: Text.ElideRight
            textFormat: Text.PlainText
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
                bubble.dismissed();
                bubble.hide();
            }
        }

        // Scaled toward the tail's tip, slid in from the crystal's side (see aniIn / aniOut).
        transform: [
            Scale {
                id: contentScale

                origin.x: tail.tipX
                origin.y: bubble.below ? 0 : bubble.height
            },
            Translate {
                id: contentSlide
            }
        ]

    }

    // Pop-up as in SAO Utils' GGO mail box menu (com.gpbeta.mail-box, MessagePanelMenuGGO.qml):
    // rises 100 px into place while fading in, with the system notification sound...
    ParallelAnimation {
        id: aniIn

        PropertyAction {
            target: bubble
            property: "textOpacity"
            value: 1
        }

        PropertyAction {
            target: contentScale
            property: "xScale"
            value: 1
        }

        PropertyAction {
            target: contentScale
            property: "yScale"
            value: 1
        }

        ScriptAction {
            script: if (bubble.sound) NVG.SystemCall.playSound(NVG.SFX.NotifyMessage)
        }

        NumberAnimation {
            target: contentSlide
            property: "y"
            from: bubble.below ? -100 : 100
            to: 0
            duration: 300
            easing.type: Easing.OutQuart
        }

        NumberAnimation {
            target: content
            property: "opacity"
            from: 0
            to: 1
            duration: 200
        }

    }

    // ...and closes by fading its texts while shrinking toward the tail and fading out.
    SequentialAnimation {
        id: aniOut

        ParallelAnimation {
            NumberAnimation {
                target: bubble
                property: "textOpacity"
                from: 1
                to: 0
                duration: 200
            }

            NumberAnimation {
                target: contentScale
                properties: "xScale,yScale"
                from: 1
                to: 0.1
                duration: 300
                easing.type: Easing.OutQuart
            }

            NumberAnimation {
                target: content
                property: "opacity"
                from: 1
                to: 0
                duration: 300
            }

        }

        ScriptAction {
            script: bubble.visible = false
        }

    }

    Timer {
        id: stayTimer

        interval: bubble.stayTime
        onTriggered: bubble.hide()
    }

}
