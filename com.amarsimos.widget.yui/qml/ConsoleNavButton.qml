import NERvGear 1.0 as NVG
import QtQuick 2.12
import "yui.js" as Yui

// A page button of System Console, as SAO Utils' SAO main menu button (the theme's MainButton): a
// white disc, SAO orange while hovered or on the page shown, with an icon of the theme's main menu
// set ("SAO Main Menu Icons", /icon/main, 42 px, e.g. "System/HW_info"): grey, white on orange; its
// caption under it.
Item {
    id: button

    property string icon
    property string caption
    property bool checked: false
    readonly property bool lit: checked || area.containsMouse
    readonly property string base: "nvg://sao.theme.gpbeta.com/icon/main#" + icon

    signal clicked()

    width: 80
    height: 68 + label.implicitHeight + 4

    // The disc as the theme's btn.png (white, 90 %) and btn-hovered.png (#F1AA03, 80 %), 64 px.
    Rectangle {
        id: disc

        anchors.horizontalCenter: parent.horizontalCenter
        width: 64
        height: 64
        radius: 32
        color: button.lit ? "#CCF1AA03" : "#E6FFFFFF"

        NVG.IconSource {
            anchors.centerIn: parent
            // At the icons' own size, so they stay sharp.
            width: 42
            height: 42
            hovered: button.lit
            pressed: area.pressed
            defaultIcon {
                normal: button.base + ".png"
                hovered: button.base + "-hovered.png"
                pressed: button.base + "-hovered.png"
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
        onPressed: NVG.SystemCall.playSound(NVG.SFX.FeedbackClick)
        onClicked: button.clicked()
    }

}
