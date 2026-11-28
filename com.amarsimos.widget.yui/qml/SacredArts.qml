import QtQuick 2.12
import QtGraphicalEffects 1.0
import "sacredarts.js" as Engine

// The effects of the System Call easter egg (the elements, Discharge, Burst Element, Enhance Armament,
// Release Recollection, Transfer Durability) and the two sword skills (Starburst Stream, Mother's
// Rosario), over Yui's expanded view. The drawing is sacredarts.js on a 420 x 520 stage (Yui in its
// middle), scaled to the view's height and centred on her; the boss of Starburst Stream (The Gleam Eyes),
// the dimming and the flash are items here. It paints only while an effect plays.
// Yui herself is told through yuiHidden, aura (her golden glow) and yuiShake (px), bound by main-stand.
Item {
    id: arts

    // The point of the view the stage is centred on horizontally (Yui's middle).
    property real centreX: width / 2
    readonly property real k: height / Engine.H
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
    // enhance, release, transfer, starburst, rosario.
    function play(kind, arg) {
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
        x: arts.centreX - width / 2 + (Math.random() - 0.5) * 14 * arts.stageShake * arts.k
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
            anchors.fill: parent
            color: "black"
            opacity: arts.dim
        }

        Canvas {
            id: canvas

            anchors.fill: parent
            renderTarget: Canvas.FramebufferObject
            onPaint: {
                var ctx = getContext("2d");
                ctx.setTransform(arts.k, 0, 0, arts.k, 0, 0);
                Engine.frame(ctx);
                arts.sync();
                if (!Engine.busy()) {
                    ticker.stop();
                    ctx.setTransform(1, 0, 0, 1, 0, 0);
                    ctx.clearRect(0, 0, width, height);
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "#FFFBE6"
            opacity: arts.flash
        }

    }

}
