import QtQuick 2.12
import QtGraphicalEffects 1.0
import "sacredarts.js" as Engine
import "yui.js" as Yui

// The effects of the System Call easter egg (the elements, Discharge, Burst Element, Enhance Armament,
// Release Recollection, Transfer Durability) and the two sword skills (Starburst Stream, Mother's
// Rosario), over Yui's expanded view. The drawing is sacredarts.js on a 420 x 520 stage (Yui in its
// middle), scaled to the view's height and centred on her; the boss of Starburst Stream (The Gleam Eyes),
// the dimming and the flash are items here. It paints only while an effect plays.
// Yui herself is told through yuiHidden, aura (her golden glow) and yuiShake (px), bound by main-stand.
// Inspect Entire Command List opens Stacia's window (the translucent violet system window) with every
// easter egg (Yui.COMMAND_LIST); a click or 10 s closes it.
Item {
    id: arts

    // The point of the view the stage is centred on horizontally (Yui's middle).
    property real centreX: width / 2
    readonly property real k: height / Engine.H
    // Where the stage starts in the view (without the shake); the canvas, the dimming and the flash cover
    // the whole view, so nothing reaching past the stage is cut off.
    readonly property real baseX: centreX - Engine.W * k / 2
    property bool yuiHidden: false
    property real aura: 0
    property real yuiShake: 0
    property real stageShake: 0
    property real zoom: 1
    property real flash: 0
    property real dim: 0
    property real bossShow: 0
    property real bossFlinch: 0
    property real bossWhite: 0

    // kind: element (arg: luminous, thermal, cryogenic, aerial, aqueous, metallic, umbra), discharge, burst,
    // enhance, release, transfer, starburst, rosario, inspect (the window).
    function play(kind, arg) {
        if (kind === "inspect") {
            stacia.open = true;
            staciaTimer.restart();
            return ;
        }
        Engine.play(kind, arg);
        ticker.start();
    }

    // The state the engine left after a frame, onto the items.
    function sync() {
        var s = Engine.state;
        yuiHidden = s.yuiHidden;
        aura = s.aura;
        yuiShake = s.yuiShake;
        stageShake = s.stageShake;
        zoom = s.zoom;
        flash = s.flash;
        dim = s.dim;
        bossShow = s.boss.show;
        bossFlinch = s.boss.flinch;
        bossWhite = s.boss.white;
    }

    Timer {
        id: ticker

        interval: 16
        repeat: true
        onTriggered: canvas.requestPaint()
    }

    Item {
        id: stage

        width: Engine.W * arts.k
        height: Engine.H * arts.k
        x: arts.baseX + (Math.random() - 0.5) * 14 * arts.stageShake * arts.k
        y: (Math.random() - 0.5) * 14 * arts.stageShake * arts.k
        scale: arts.zoom
        visible: ticker.running

        // Starburst Stream's foe: The Gleam Eyes (cut out with a soft mask), flinching back and white
        // when struck.
        Item {
            id: boss

            x: (stage.width - width) / 2 + arts.bossFlinch * 14 * arts.k
            y: 40 * arts.k - arts.bossFlinch * 6 * arts.k
            width: 420 * arts.k
            height: bossImage.implicitHeight > 0 ? width * bossImage.implicitHeight / bossImage.implicitWidth : 0
            scale: 1 - arts.bossFlinch * 0.04
            opacity: arts.bossShow
            visible: opacity > 0.01

            Image {
                id: bossImage

                anchors.fill: parent
                source: "../Images/gleam-eyes.png"
                smooth: true
            }

            ColorOverlay {
                anchors.fill: parent
                source: bossImage
                color: "white"
                opacity: arts.bossWhite * 0.8
            }

        }

        // The dimming of a wind-up, under the effects.
        Rectangle {
            x: -arts.baseX
            width: arts.width
            height: arts.height
            color: "black"
            opacity: arts.dim
        }

        Canvas {
            id: canvas

            x: -arts.baseX
            width: arts.width
            height: arts.height
            renderTarget: Canvas.FramebufferObject
            onPaint: {
                var ctx = getContext("2d");
                ctx.setTransform(arts.k, 0, 0, arts.k, arts.baseX, 0);
                Engine.view = { "x0": -arts.baseX / arts.k, "y0": 0, "x1": (arts.width - arts.baseX) / arts.k, "y1": arts.height / arts.k };
                Engine.frame(ctx);
                arts.sync();
                if (!Engine.busy()) {
                    ticker.stop();
                    Engine.settle();
                    arts.sync();
                    ctx.setTransform(1, 0, 0, 1, 0, 0);
                    ctx.clearRect(0, 0, width, height);
                }
            }
        }

        Rectangle {
            x: -arts.baseX
            width: arts.width
            height: arts.height
            color: "#FFFBE6"
            opacity: arts.flash
        }

    }


    // Stacia's window: opening downwards from its top edge, violet glass with a light edge.
    Rectangle {
        id: stacia

        property bool open: false

        width: 300 * arts.k
        height: staciaColumn.implicitHeight + 24 * arts.k
        x: Math.max(8, Math.min(arts.width - width - 8, arts.centreX - width / 2))
        y: 60 * arts.k
        transformOrigin: Item.Top
        scale: open ? 1 : 0.6
        opacity: open ? 1 : 0
        visible: opacity > 0.01
        border.color: "#D9C8FF"
        border.width: 1

        Behavior on scale {
            NumberAnimation {
                duration: 320
                easing.type: Easing.OutBack
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: 250
            }

        }

        Column {
            id: staciaColumn

            x: 14 * arts.k
            y: 10 * arts.k
            width: parent.width - 28 * arts.k
            spacing: 3 * arts.k

            Text {
                text: "SYSTEM COMMAND LIST"
                font.family: "SAO UI"
                font.pixelSize: 16 * arts.k
                font.letterSpacing: 1
                color: "#FFFFFF"
            }

            Rectangle {
                width: parent.width
                height: 1
                color: "#88D9C8FF"
            }

            Repeater {
                model: Yui.COMMAND_LIST

                Column {
                    width: staciaColumn.width
                    spacing: 2 * arts.k
                    topPadding: 4 * arts.k

                    Text {
                        text: modelData[0]
                        font.family: Yui.fontFor(text)
                        font.pixelSize: 12 * arts.k
                        color: "#E8DDFF"
                    }

                    Repeater {
                        model: modelData[1]

                        Text {
                            width: staciaColumn.width
                            leftPadding: 8 * arts.k
                            wrapMode: Text.Wrap
                            text: "· " + modelData
                            font.family: Yui.fontFor(text)
                            font.pixelSize: 13 * arts.k
                            color: "#FFFFFF"
                        }

                    }

                }

            }

        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: stacia.open = false
        }

        gradient: Gradient {
            GradientStop {
                position: 0
                color: "#D97A5CC8"
            }

            GradientStop {
                position: 1
                color: "#D94A3290"
            }

        }

    }

    Timer {
        id: staciaTimer

        interval: 10000
        onTriggered: stacia.open = false
    }

}
