import QtQuick 2.12
import QtQuick.Controls 2.12

// SAO-style vertical scroll bar: a thin translucent track with round end caps and a rounded
// white thumb that widens and turns SAO orange while hovered or dragged. Fades out when idle.
// Set onLight on light backgrounds (e.g. the white input box) to draw it in dark gray instead.
ScrollBar {
    id: control

    property bool onLight: false
    // A thumb of this many pixels whatever the content's length (0: proportional, at least
    // minimumSize), and this width when not hovered.
    property real fixedThumb: 0
    property real thumbWidth: 5
    readonly property bool highlighted: hovered || pressed
    readonly property bool shown: active || hovered

    policy: ScrollBar.AsNeeded
    padding: 3
    minimumSize: fixedThumb > 0 && height > 0 ? Math.min(1, fixedThumb / height) : 0.08

    contentItem: Item {
        implicitWidth: Math.max(8, control.thumbWidth + 3)
        implicitHeight: 40
        opacity: control.shown ? 1 : 0

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: control.highlighted ? control.thumbWidth + 3 : control.thumbWidth
            height: parent.height
            radius: width / 2
            // SAO orange on hover / drag, as in the SAO theme of SAO Utils.
            color: control.pressed ? "#F1AA03" : (control.hovered ? "#E6F1AA03" : (control.onLight ? "#99707070" : "#E6FFFFFF"))
            border.color: control.onLight ? "transparent" : "#55000000"
            border.width: 1

            Behavior on width {
                NumberAnimation {
                    duration: 120
                }

            }

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }

            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: 400
            }

        }

    }

    background: Item {
        implicitWidth: 14
        opacity: control.shown ? 1 : 0

        // Track line
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 6
            width: 2
            height: parent.height - 12
            radius: 1
            color: control.onLight ? "#33000000" : "#55FFFFFF"
        }

        // Round end caps
        Repeater {
            model: 2

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: index === 0 ? 1 : parent.height - height - 1
                width: 6
                height: 6
                radius: 3
                color: "transparent"
                border.color: control.onLight ? "#55000000" : "#AAFFFFFF"
                border.width: 1
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: 400
            }

        }

    }

}
