import NERvGear 1.0 as NVG
import QtQuick 2.12

// A button drawn with an icon of SAO Utils' SAO theme (nvg://sao.theme.gpbeta.com/icon/...), using
// the theme's own -hovered picture while hovered or checked. Text under it, so it still reads when the
// theme is missing.
Item {
    id: button

    // "item/modify", "misc/ok", ...: the theme's icon group and the file name without .png.
    property string icon
    property string caption
    property bool checked: false
    property int size: 40
    readonly property string base: "nvg://sao.theme.gpbeta.com/icon/" + icon.split("/")[0] + "#" + icon.split("/").slice(1).join("/")

    signal clicked()

    implicitWidth: Math.max(size, label.implicitWidth)
    implicitHeight: size + (caption ? label.implicitHeight + 2 : 0)
    opacity: enabled ? 1 : 0.4

    NVG.IconSource {
        anchors.horizontalCenter: parent.horizontalCenter
        width: button.size
        height: button.size
        hovered: area.containsMouse || button.checked
        pressed: area.pressed
        defaultIcon {
            normal: button.base + ".png"
            hovered: button.base + "-hovered.png"
            pressed: button.base + "-hovered.png"
        }
    }

    Text {
        id: label

        anchors.horizontalCenter: parent.horizontalCenter
        y: button.size + 2
        visible: button.caption !== ""
        text: button.caption
        font.family: "SAO UI"
        font.pixelSize: 11
        font.letterSpacing: 1
        color: button.checked ? "#F1AA03" : "#8A8A8A"
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }

}
