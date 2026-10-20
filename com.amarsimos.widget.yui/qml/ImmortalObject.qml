import NERvGear 1.0 as NVG
import NERvGear.Private 1.0 as NVG
import QtQuick 2.12

// SAO Utils' own "Immortal Object" warning, rebuilt from its built-in WarningView (the system
// package's compiled qml/system/WarningView.qml, which plugins cannot reach): the same image,
// sizes, animations and timings. Created once and reused; call popup() to show it on the screen
// under the cursor.
NVG.HelperView {
    id: view

    function popup() {
        if (aniFadeIn.running)
            return ;

        if (aniFadeOut.running) {
            aniFadeOut.stop();
            aniFadeIn.start();
            hideTimer.stop();
            return ;
        }
        if (visible) {
            hideTimer.restart();
        } else {
            showOnCursorScreen();
            aniFadeIn.start();
        }
    }

    color: "transparent"
    solid: true
    acceptFocus: false
    acceptInput: false
    x: screen.virtualX + (screen.width - width) / 2
    y: screen.virtualY + (screen.height - height) / 2
    z: NVG.WindowCompositor.TopMostZ
    width: image.implicitWidth
    height: image.implicitHeight

    Image {
        id: image

        anchors.centerIn: parent
        cache: false
        opacity: 0
        // The system package's own image (Packages/system/Images), next to this package.
        source: Qt.resolvedUrl("../../system/Images/immortal.png")

        transform: Scale {
            id: imageScale

            xScale: 0.1
            yScale: 0.05
            origin.x: image.width / 2
            origin.y: image.height / 2
        }

    }

    // Opens as a thin line, widens, then unfolds vertically with an overshoot.
    ParallelAnimation {
        id: aniFadeIn

        onFinished: hideTimer.start()

        NumberAnimation {
            target: image
            property: "opacity"
            duration: 250
            from: 0
            to: 1
        }

        SequentialAnimation {
            NumberAnimation {
                target: imageScale
                property: "xScale"
                duration: 100
                from: 0.1
                to: 1
                easing.type: Easing.OutQuad
            }

            NumberAnimation {
                target: imageScale
                property: "yScale"
                duration: 200
                from: 0.05
                to: 1
                easing.type: Easing.OutBack
                easing.overshoot: 3
            }

        }

    }

    // The reverse: folds vertically, narrows to a line and fades out, then hides the view.
    ParallelAnimation {
        id: aniFadeOut

        onFinished: view.visible = false

        NumberAnimation {
            target: image
            property: "opacity"
            duration: 400
            from: 1
            to: 0
        }

        SequentialAnimation {
            NumberAnimation {
                target: imageScale
                property: "yScale"
                duration: 250
                from: 1
                to: 0.05
                easing.type: Easing.InBack
                easing.overshoot: 3
            }

            NumberAnimation {
                target: imageScale
                property: "xScale"
                duration: 150
                from: 1
                to: 0.1
                easing.type: Easing.OutQuad
            }

        }

    }

    Timer {
        id: hideTimer

        interval: 2000
        onTriggered: {
            aniFadeIn.stop();
            aniFadeOut.start();
        }
    }

}
