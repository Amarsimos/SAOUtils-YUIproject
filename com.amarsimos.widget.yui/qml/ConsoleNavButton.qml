import NERvGear 1.0 as NVG
import QtQuick 2.12
import "yui.js" as Yui

// A page button of System Console, as the ringed SAO menu icon (see the disc below), with an icon of
// SAO Utils' SAO theme main menu set ("SAO Main Menu Icons", /icon/main, e.g. "System/HW_info"):
// grey, white on orange; its caption under it.
Item {
    id: button

    property string icon
    property string caption
    property bool checked: false
    readonly property bool lit: checked || area.containsMouse
    readonly property string base: "nvg://sao.theme.gpbeta.com/icon/main#" + icon

    signal clicked()

    width: 80
    height: 76 + label.implicitHeight + 4

    // As the ringed SAO menu icons (sao-assets, SAO_Icons 2_Menu-1_Ringed, 120 px): a disc (100) inside a
    // thin ring (outer 120, 2.5 wide, a 7.5 gap between), both #FBFBFB with a grey icon, or both
    // #EBA601 with a white icon while hovered or on the page shown. Here 72 px across.
    Item {
        id: disc

        anchors.horizontalCenter: parent.horizontalCenter
        width: 72
        height: 72

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 1.5
            border.color: button.lit ? "#EBA601" : "#FBFBFB"
        }

        Rectangle {
            anchors.centerIn: parent
            width: 60
            height: 60
            radius: 30
            color: button.lit ? "#EBA601" : "#FBFBFB"
        }

        NVG.IconSource {
            anchors.centerIn: parent
            // The theme's main menu icons at their own size, so they stay sharp.
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
        y: 76
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
