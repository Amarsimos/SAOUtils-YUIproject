import QtQuick 2.12

// A line whose characters hop 3 px one by one (the next only when the one before has landed, 240 ms
// each), then a short rest and again from the start: something going on (Seedling's status).
Row {
    id: hopText

    property string text
    property alias fontFamily: probe.font.family
    property int fontSize: 13
    property color color: "#3A3A3A"
    property bool running: visible

    Text {
        id: probe

        visible: false
    }

    Repeater {
        model: hopText.text.split("")

        Text {
            id: hopChar

            property real hop: 0

            text: modelData
            color: hopText.color
            font.family: probe.font.family
            font.pixelSize: hopText.fontSize

            transform: Translate {
                y: hopChar.hop
            }

            SequentialAnimation on hop {
                running: hopText.running
                loops: Animation.Infinite

                PauseAnimation {
                    duration: index * 240
                }

                NumberAnimation {
                    to: -3
                    duration: 120
                    easing.type: Easing.OutQuad
                }

                NumberAnimation {
                    to: 0
                    duration: 120
                    easing.type: Easing.InQuad
                }

                PauseAnimation {
                    duration: Math.max(0, hopText.text.length - index - 1) * 240 + 600
                }

            }

        }

    }

}
