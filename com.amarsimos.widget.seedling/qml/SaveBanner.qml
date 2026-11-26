import QtGraphicalEffects 1.0
import QtQuick 2.12
import QtQuick.Shapes 1.12

// SAVED / NOT SAVED after Save, in the style of MHCP-YUI's Boss Raid banner (after the anime's
// "Congratulations!!"): a white flash across, big white SAO UI letters lighting one by one (landing
// from a little larger), a thick white bar notched in the middle growing out from the middle, a soft
// dark shadow; then they stay a moment and fade. Not saved: the bar and the flash in SAO red.
// show(saved) starts it; it takes no input.
Item {
    id: banner

    property string word: "SAVED"
    property color accent: "#F4F4F4"
    // How many letters are lit.
    property int revealed: 0

    function show(saved) {
        run.stop();
        word = saved ? "SAVED" : "NOT SAVED";
        accent = saved ? "#F4F4F4" : "#C82864";
        revealed = 0;
        run.start();
    }

    // The letters over the bar.
    Item {
        id: letters

        anchors.centerIn: parent
        width: Math.max(sizer.width, bar.width)
        height: sizer.height + 10 + bar.height
        opacity: 0

        // Gives the size; the letters light one by one over it.
        Text {
            id: sizer

            anchors.horizontalCenter: parent.horizontalCenter
            font.family: "SAO UI"
            font.pixelSize: 54
            font.letterSpacing: 2
            color: "transparent"
            text: banner.word

            Row {
                anchors.centerIn: parent
                spacing: sizer.font.letterSpacing

                Repeater {
                    model: banner.word.split("")

                    Text {
                        font.family: "SAO UI"
                        font.pixelSize: sizer.font.pixelSize
                        color: "#F4F4F4"
                        text: modelData
                        opacity: index < banner.revealed ? 1 : 0
                        scale: index < banner.revealed ? 1 : 1.8

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 140
                            }

                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.OutBack
                            }

                        }

                    }

                }

            }

        }

        // The bar, notched above and below in the middle; it grows out from the middle.
        Shape {
            id: bar

            readonly property real notch: height * 0.45

            anchors.top: sizer.bottom
            anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(sizer.width * 1.02, 140)
            height: 16

            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: banner.accent
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
                xScale: 0
            }

        }

    }

    // The soft dark shadow that keeps the white readable on the light preview.
    DropShadow {
        anchors.fill: letters
        source: letters
        verticalOffset: 2
        radius: 10
        samples: 17
        color: "#AA000000"
        opacity: letters.opacity
    }

    // A flash across as the letters start to light.
    Rectangle {
        id: flash

        anchors.centerIn: parent
        width: parent.width
        height: 110
        opacity: 0

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: 0
                color: "#00FFFFFF"
            }

            GradientStop {
                position: 0.5
                color: Qt.rgba(banner.accent.r, banner.accent.g, banner.accent.b, 0.8)
            }

            GradientStop {
                position: 1
                color: "#00FFFFFF"
            }

        }

    }

    SequentialAnimation {
        id: run

        PropertyAction {
            target: barScale
            property: "xScale"
            value: 0
        }

        PropertyAction {
            target: letters
            property: "opacity"
            value: 1
        }

        ParallelAnimation {
            SequentialAnimation {
                NumberAnimation {
                    target: flash
                    property: "opacity"
                    to: 1
                    duration: 90
                }

                NumberAnimation {
                    target: flash
                    property: "opacity"
                    to: 0
                    duration: 350
                }

            }

            // The letters, one every 55 ms.
            NumberAnimation {
                target: banner
                property: "revealed"
                from: 0
                to: banner.word.length
                duration: banner.word.length * 55
            }

        }

        NumberAnimation {
            target: barScale
            property: "xScale"
            to: 1
            duration: 280
            easing.type: Easing.OutCubic
        }

        PauseAnimation {
            duration: 700
        }

        NumberAnimation {
            target: letters
            property: "opacity"
            to: 0
            duration: 450
        }

    }

}
