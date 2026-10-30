import NERvGear 1.0 as NVG
import QtGraphicalEffects 1.0
import QtQuick 2.12
import QtQuick.Shapes 1.12

// Boss Raid's banner, after the "Congratulations!!" of the anime when a floor boss falls: big white
// letters with a soft shadow over a thick white bar notched in the middle. During the raid it is a
// small banner (dragged anywhere, kept there) with the time left; when the raid is won it shows
// "Congratulations!!" large across the screen for a few seconds (a flash, the letters lighting one
// by one, light motes drifting up and a sound), then the rest the same way as the
// raid. It goes away when the raid and the rest are over (or by its ×; the raid goes on).
NVG.View {
    id: banner

    // The widget (main-stand.qml).
    property var yui
    // Updated while shown.
    property double now: Date.now()
    // "Congratulations!!" across the screen (celebrate()).
    property bool celebrating: false
    readonly property bool running: yui.raidActive || yui.resting
    readonly property double left: Math.max(0, (yui.raidActive ? yui.raidEnd : yui.restEnd) - now)
    readonly property string clock: {
        var seconds = Math.ceil(left / 1000);
        return Math.floor(seconds / 60) + ":" + ("0" + seconds % 60).slice(-2);
    }
    readonly property string cheer: "Congratulations!!"
    // The celebration: how many letters of cheer are lit (one after another), and the light motes
    // drifting up (0 while none).
    property int revealed: 0
    property int motes: 0
    // The small banner's size; the celebration takes the screen's width.
    readonly property int compactWidth: 360
    readonly property int compactHeight: 130

    // The screen holding a point (from Qt.application.screens).
    function screenAt(middleX, middleY) {
        var screens = Qt.application.screens;
        for (var i = 0; i < screens.length; i++) {
            var s = screens[i];
            if (middleX >= s.virtualX && middleX < s.virtualX + s.width && middleY >= s.virtualY && middleY < s.virtualY + s.height)
                return s;

        }
        // Not on any screen (a widget partly off it): the screen of that column, else the first.
        for (var j = 0; j < screens.length; j++) {
            if (middleX >= screens[j].virtualX && middleX < screens[j].virtualX + screens[j].width)
                return screens[j];

        }
        return screens[0];
    }

    // The screen the banner is on, for the celebration.
    function currentScreen() {
        return screenAt(x + width / 2, y + height / 2);
    }

    function placeCompact() {
        width = compactWidth;
        height = compactHeight;
        var saved = yui.settings.raid_banner_position;
        if (saved && saved.x !== undefined) {
            x = saved.x;
            y = saved.y;
        } else {
            // Yui's screen (where she or her chat is), at the top in the middle.
            var at = yui.bannerScreenPoint();
            var s = screenAt(at.x, at.y);
            x = s.virtualX + (s.width - width) / 2;
            y = s.virtualY + 40;
        }
    }

    function open() {
        if (!visible || width !== compactWidth)
            placeCompact();

        visible = true;
        now = Date.now();
        appear.restart();
    }

    // The raid is won: "Congratulations!!" across the screen, then back to the small banner for the rest.
    function celebrate() {
        var s = currentScreen();
        celebrating = true;
        visible = true;
        revealed = 0;
        motes = 0;
        motes = 48;
        if (yui.interfaceSounds)
            NVG.SystemCall.playSound(NVG.SFX.PopupMessage);

        width = s.width;
        height = 300;
        x = s.virtualX;
        y = s.virtualY + Math.round(s.height * 0.3) - height / 2;
        celebration.restart();
    }

    // A view is drawn only on a compositor (Yui's other views follow hers); the banner is always on
    // the desktop, above everything.
    compositor: NVG.WindowCompositor
    color: "transparent"
    solid: true
    acceptFocus: false
    // Clicks go through the celebration; the small banner is dragged.
    acceptInput: !celebrating
    z: NVG.WindowCompositor.TopMostZ
    visible: false
    onRunningChanged: {
        if (!running && !celebrating)
            visible = false;

    }

    Timer {
        interval: 250
        repeat: true
        running: banner.visible
        onTriggered: banner.now = Date.now()
    }

    // The letters (RAID / REST and the time left, or "Congratulations!!") over the bar.
    Item {
        id: letters

        anchors.centerIn: parent
        width: Math.max(words.width, bar.width)
        height: words.height + bar.anchors.topMargin + bar.height
        opacity: 0

        Column {
            id: words

            anchors.horizontalCenter: parent.horizontalCenter
            spacing: -4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !banner.celebrating
                font.family: "SAO UI"
                font.pixelSize: 15
                font.letterSpacing: 6
                color: "#E8E8E8"
                text: banner.yui.resting ? "REST" : "BOSS RAID"
            }

            Text {
                id: bigText

                anchors.horizontalCenter: parent.horizontalCenter
                font.family: "SAO UI"
                font.pixelSize: banner.celebrating ? 112 : 64
                font.letterSpacing: 2
                // The last ten seconds of a raid turn warm.
                // While celebrating it only gives the size; the letters light up one by one over it.
                color: banner.celebrating ? "transparent" : (banner.yui.raidActive && banner.left <= 10000 ? "#FFE2CF" : "#F4F4F4")
                text: banner.celebrating ? banner.cheer : banner.clock

                Row {
                    anchors.centerIn: parent
                    spacing: bigText.font.letterSpacing
                    visible: banner.celebrating

                    Repeater {
                        model: banner.cheer.split("")

                        Text {
                            font.family: "SAO UI"
                            font.pixelSize: bigText.font.pixelSize
                            color: "#F4F4F4"
                            text: modelData
                            opacity: index < banner.revealed ? 1 : 0
                            scale: index < banner.revealed ? 1 : 1.8

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 180
                                }

                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 260
                                    easing.type: Easing.OutBack
                                }

                            }

                        }

                    }

                }

                transform: Scale {
                    id: pulse

                    origin.x: bigText.width / 2
                    origin.y: bigText.height / 2
                }

            }

        }

        // The white bar, notched above and below in the middle; it grows out from the middle.
        Shape {
            id: bar

            readonly property real notch: height * 0.45

            anchors.top: words.bottom
            anchors.topMargin: banner.celebrating ? 14 : 6
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(bigText.width * 1.02, 160)
            height: banner.celebrating ? 30 : 12

            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: "#F4F4F4"
                startX: 0
                startY: 0

                PathLine {
                    x: bar.width / 2 - bar.notch
                    y: 0
                }

                PathLine {
                    x: bar.width / 2
                    y: bar.notch
                }

                PathLine {
                    x: bar.width / 2 + bar.notch
                    y: 0
                }

                PathLine {
                    x: bar.width
                    y: 0
                }

                PathLine {
                    x: bar.width
                    y: bar.height
                }

                PathLine {
                    x: bar.width / 2 + bar.notch
                    y: bar.height
                }

                PathLine {
                    x: bar.width / 2
                    y: bar.height - bar.notch
                }

                PathLine {
                    x: bar.width / 2 - bar.notch
                    y: bar.height
                }

                PathLine {
                    x: 0
                    y: bar.height
                }

                PathLine {
                    x: 0
                    y: 0
                }

            }

            transform: Scale {
                id: barScale

                origin.x: bar.width / 2
            }

        }

    }

    // A white flash across as the letters start to light.
    Rectangle {
        id: flash

        anchors.centerIn: parent
        width: parent.width
        height: 160
        opacity: 0

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: 0
                color: "#00FFFFFF"
            }

            GradientStop {
                position: 0.5
                color: "#CCFFFFFF"
            }

            GradientStop {
                position: 1
                color: "#00FFFFFF"
            }

        }

    }

    // Light motes drifting up around the letters, as in the boss room (each its own place, size,
    // speed and delay).
    Item {
        anchors.fill: parent
        visible: banner.celebrating

        Repeater {
            model: banner.motes

            Rectangle {
                id: mote

                readonly property real size: 2 + Math.random() * 5

                x: Math.random() * banner.width
                width: size
                height: size
                radius: size / 2
                color: Math.random() < 0.5 ? "#D8ECFF" : "#9CD3FF"
                opacity: 0

                SequentialAnimation {
                    running: true

                    PauseAnimation {
                        duration: Math.random() * 1800
                    }

                    ParallelAnimation {
                        NumberAnimation {
                            target: mote
                            property: "y"
                            from: banner.height * (0.55 + Math.random() * 0.45)
                            to: banner.height * Math.random() * 0.4
                            duration: 2200 + Math.random() * 1800
                            easing.type: Easing.OutQuad
                        }

                        SequentialAnimation {
                            NumberAnimation {
                                target: mote
                                property: "opacity"
                                to: 0.9
                                duration: 400
                            }

                            NumberAnimation {
                                target: mote
                                property: "opacity"
                                to: 0
                                duration: 1800 + Math.random() * 1200
                                easing.type: Easing.InQuad
                            }

                        }

                    }

                }

            }

        }

    }

    // One letter more every 45 ms while celebrating.
    Timer {
        interval: 45
        repeat: true
        running: banner.celebrating && banner.revealed < banner.cheer.length
        onTriggered: banner.revealed++
    }

    // The soft dark shadow that keeps the white readable on any background.
    DropShadow {
        anchors.fill: letters
        source: letters
        verticalOffset: 2
        radius: banner.celebrating ? 16 : 8
        samples: 17
        color: "#AA000000"
        opacity: letters.opacity
    }

    // Each of the last ten seconds beats once.
    SequentialAnimation {
        id: beat

        NumberAnimation {
            target: pulse
            properties: "xScale,yScale"
            to: 1.12
            duration: 120
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: pulse
            properties: "xScale,yScale"
            to: 1
            duration: 300
            easing.type: Easing.InOutQuad
        }

    }

    Connections {
        target: banner
        onClockChanged: {
            if (banner.yui.raidActive && banner.left <= 10000 && banner.left > 0 && !banner.celebrating)
                beat.restart();

        }
    }

    // The small banner opening: the letters come up, then the bar grows out from the middle.
    SequentialAnimation {
        id: appear

        PropertyAction {
            target: barScale
            property: "xScale"
            value: 0
        }

        NumberAnimation {
            target: letters
            property: "opacity"
            from: 0
            to: 1
            duration: 220
        }

        NumberAnimation {
            target: barScale
            property: "xScale"
            to: 1
            duration: 320
            easing.type: Easing.OutCubic
        }

    }

    // "Congratulations!!": the letters land from a little larger, the bar grows out from the middle,
    // they stay and fade; then the small banner comes back for the rest.
    SequentialAnimation {
        id: celebration

        PropertyAction {
            target: letters
            property: "opacity"
            value: 0
        }

        PropertyAction {
            target: barScale
            property: "xScale"
            value: 0
        }

        ParallelAnimation {
            NumberAnimation {
                target: letters
                property: "opacity"
                from: 0
                to: 1
                duration: 450
            }

            SequentialAnimation {
                NumberAnimation {
                    target: flash
                    property: "opacity"
                    from: 0
                    to: 0.6
                    duration: 120
                }

                NumberAnimation {
                    target: flash
                    property: "opacity"
                    to: 0
                    duration: 500
                    easing.type: Easing.OutQuad
                }

            }

            NumberAnimation {
                target: pulse
                properties: "xScale,yScale"
                from: 1.35
                to: 1
                duration: 600
                easing.type: Easing.OutCubic
            }

            SequentialAnimation {
                PauseAnimation {
                    duration: 250
                }

                NumberAnimation {
                    target: barScale
                    property: "xScale"
                    to: 1
                    duration: 450
                    easing.type: Easing.OutCubic
                }

            }

        }

        PauseAnimation {
            duration: 3500
        }

        NumberAnimation {
            target: letters
            property: "opacity"
            to: 0
            duration: 600
        }

        ScriptAction {
            script: {
                banner.celebrating = false;
                banner.motes = 0;
                if (banner.running)
                    banner.open();
                else
                    banner.visible = false;
            }
        }

    }

    // Dragged by any part; the place is kept. Hovering shows × (hides it; the raid goes on).
    MouseArea {
        id: dragArea

        property point start
        property point origin

        anchors.fill: parent
        enabled: !banner.celebrating
        hoverEnabled: true
        onPressed: {
            start = mapToGlobal(mouse.x, mouse.y);
            origin = Qt.point(banner.x, banner.y);
        }
        onPositionChanged: {
            if (!pressed)
                return ;

            var at = mapToGlobal(mouse.x, mouse.y);
            banner.x = origin.x + at.x - start.x;
            banner.y = origin.y + at.y - start.y;
        }
        onReleased: banner.yui.settings.raid_banner_position = {
            "x": banner.x,
            "y": banner.y
        }

        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 4
            visible: dragArea.containsMouse
            font.pixelSize: 16
            color: "#E8E8E8"
            style: Text.Outline
            styleColor: "#66000000"
            text: "✕"

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                onClicked: banner.visible = false
            }

        }

    }

}
