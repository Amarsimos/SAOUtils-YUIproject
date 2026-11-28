import NERvGear 1.0 as NVG
import QtQuick 2.12
import "yui.js" as Yui

// A page button of System Console, as the SAO main menu's: an icon of SAO Utils' SAO theme (item group,
// e.g. "System/HW_info") large on a white disc, orange with the theme's -hovered icon while checked,
// its caption under it.
Item {
    id: button

    property string icon
    property string caption
    property bool checked: false
    readonly property string base: "nvg://sao.theme.gpbeta.com/icon/item#" + icon

    signal clicked()

    width: 80
    height: 68 + label.implicitHeight + 4

    // A white disc (orange on the page shown) with the theme's round icon large inside it, so it reads
    // on the code wall.
    Rectangle {
        id: disc

        anchors.horizontalCenter: parent.horizontalCenter
        width: 64
        height: 64
        radius: 32
        color: button.checked ? "#F1AA03" : "#FFFFFF"
        border.width: button.checked ? 3 : 0
        border.color: "#66F1AA03"
        scale: area.containsMouse && !button.checked ? 1.06 : 1

        NVG.IconSource {
            anchors.centerIn: parent
            width: 54
            height: 54
            hovered: button.checked
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
        y: 68
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
