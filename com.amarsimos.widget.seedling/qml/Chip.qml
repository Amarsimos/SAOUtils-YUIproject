import NERvGear 1.0 as NVG
import QtQuick 2.12

// A button as the original's submenu items: a white bar with a round icon at its left (SAO Utils'
// SAO theme, /icon/item) and the text in SAO UI; hovered or checked the bar turns SAO orange and the
// icon its light (-hovered) picture. iconOnly: the round icon alone (− / +).
Item {
    id: chip

    property alias text: label.text
    // The theme's submenu icon, e.g. "run" (nvg://sao.theme.gpbeta.com/icon/item#run.png).
    property string icon
    property bool checked: false
    property bool iconOnly: false
    readonly property bool lit: (area.containsMouse || checked) && enabled
    readonly property int iconSize: iconOnly ? 26 : 22
    readonly property string iconBase: "nvg://sao.theme.gpbeta.com/icon/item#" + icon

    signal clicked()

    implicitWidth: iconOnly ? iconSize : (icon ? 5 + iconSize + 7 : 12) + label.implicitWidth + 12
    implicitHeight: iconOnly ? iconSize : 30
    opacity: enabled ? 1 : 0.45

    // The bar (not for an icon alone), with the light shade under it.
    Rectangle {
        anchors.fill: parent
        visible: !chip.iconOnly
        color: chip.lit ? "#EBA601" : "#FBFBFB"

        Rectangle {
            anchors.top: parent.bottom
            width: parent.width
            height: 1
            color: "#33000000"
        }

        Behavior on color {
            ColorAnimation {
                duration: 120
            }

        }

    }

    NVG.IconSource {
        visible: chip.icon !== ""
        x: chip.iconOnly ? 0 : 5
        anchors.verticalCenter: parent.verticalCenter
        width: chip.iconSize
        height: chip.iconSize
        hovered: chip.lit
        pressed: area.pressed
        defaultIcon {
            normal: chip.iconBase + ".png"
            hovered: chip.iconBase + "-hovered.png"
            pressed: chip.iconBase + "-hovered.png"
        }
    }

    Text {
        id: label

        visible: !chip.iconOnly
        x: chip.icon ? 5 + chip.iconSize + 7 : 12
        anchors.verticalCenter: parent.verticalCenter
        font.family: "SAO UI"
        font.pixelSize: 16
        color: chip.lit ? "#FFFFFF" : "#7A7A7A"
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }

}
