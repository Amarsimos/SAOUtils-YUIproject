import NERvGear 1.0 as NVG
import QtQuick 2.12

// A page button of System Console, as the SAO main menu's: a white disc with an icon of SAO Utils'
// SAO theme (item group, e.g. "System/HW_info"), orange with the theme's -hovered (white) icon while
// checked, its caption under it.
Item {
    id: button

    property string icon
    property string caption
    property bool checked: false
    readonly property string base: "nvg://sao.theme.gpbeta.com/icon/item#" + icon

    signal clicked()

    width: 72
    height: 58 + label.implicitHeight + 4

    Rectangle {
        id: disc

        anchors.horizontalCenter: parent.horizontalCenter
        width: 54
        height: 54
        radius: 27
        color: button.checked ? "#F1AA03" : "#FFFFFF"
        border.width: button.checked ? 4 : 0
        border.color: "#55F1AA03"
        scale: area.containsMouse && !button.checked ? 1.06 : 1

        NVG.IconSource {
            anchors.centerIn: parent
            width: 34
            height: 34
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
        y: 58
        text: button.caption
        font.family: "SAO UI"
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
