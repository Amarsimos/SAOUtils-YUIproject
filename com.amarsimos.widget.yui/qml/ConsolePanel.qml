import QtQuick 2.12
import QtQuick.Layouts 1.12
import "yui.js" as Yui

// A panel of System Console (as the preview): a light paper card over the code wall with a header
// band (white to #EFEFEF) holding its title in SAO UI and a small note at the right (or tools, put in
// `tools`), and its content below with 16 px padding.
Rectangle {
    id: panel

    property string title
    property string note
    default property alias content: body.data
    property alias tools: toolSlot.data
    property int padding: 12

    implicitHeight: (header.visible ? header.y + header.height : 0) + body.implicitHeight + padding * 2
    color: "#F2F9F9F9"

    Rectangle {
        id: header

        // Inside the outline (drawn last, over it), so the band and the body share the same edges.
        x: 1
        y: 1
        width: parent.width - 2
        height: 33
        visible: panel.title !== ""

        Text {
            anchors.left: parent.left
            // Lined up with the body (16 px from the panel's edge).
            anchors.leftMargin: 15
            anchors.verticalCenter: parent.verticalCenter
            text: panel.title
            font.family: Yui.fontFor(text)
            font.pixelSize: 17
            color: "#4D4D4D"
        }

        Row {
            id: toolRow

            anchors.right: parent.right
            anchors.rightMargin: 15
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: panel.note !== ""
                text: panel.note
                font.family: Yui.fontFor(text)
                font.pixelSize: 12
                color: "#7A7A7A"
            }

            Row {
                id: toolSlot

                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
            }

        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: "#E2E2E2"
        }

        gradient: Gradient {
            GradientStop {
                position: 0
                color: "#FFFFFF"
            }

            GradientStop {
                position: 1
                color: "#EFEFEF"
            }

        }

    }

    ColumnLayout {
        id: body

        x: 16
        y: (header.visible ? header.y + header.height : 0) + panel.padding
        width: parent.width - 32
        spacing: 6
    }

    // The outline, over the header band.
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: "#22000000"
    }

}
