import NERvGear 1.0 as NVG
import QtQuick 2.12
import "yui.js" as Yui

// A page button of System Console, as the SAO main menu's: an icon of SAO Utils' SAO theme (item group,
// e.g. "System/HW_info"), the theme's -hovered (white) icon while hovered or checked, an orange ring
// while checked, its caption under it.
Item {
    id: button

    property string icon
    property string caption
    property bool checked: false
    readonly property string base: "nvg://sao.theme.gpbeta.com/icon/item#" + icon

    signal clicked()

    width: 72
    height: 58 + label.implicitHeight + 4

    // The theme's icon is a disc of its own (grey, white while hovered): shown large, no disc around
    // it; the page shown has an orange ring.
    Item {
        id: disc

        anchors.horizontalCenter: parent.horizontalCenter
        width: 54
        height: 54
        scale: area.containsMouse && !button.checked ? 1.06 : 1

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 3
            border.color: "#F1AA03"
            visible: button.checked
        }

        NVG.IconSource {
            anchors.centerIn: parent
            width: 46
            height: 46
            hovered: button.checked || area.containsMouse
            pressed: area.pressed
            defaultIcon {
                normal: button.base + ".png"
                hovered: button.base + "-hovered.png"
                pressed: button.base + "-hovered.png"
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 120
            }

        }

    }

    Text {
        id: label

        anchors.horizontalCenter: parent.horizontalCenter
        y: 58
        text: button.caption
        font.family: Yui.fontFor(text)
        font.pixelSize: 13
        color: "#FFFFFF"
        style: Text.Raised
        styleColor: "#99000000"
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }

}
