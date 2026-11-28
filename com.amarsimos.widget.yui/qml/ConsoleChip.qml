import QtQuick 2.12
import "yui.js" as Yui

// A small button of System Console (the preview's chip): paper with a light shadow, SAO UI text; SAO
// orange with white text while hovered or checked.
Rectangle {
    id: chip

    property string text
    property bool checked: false
    property bool small: false
    readonly property bool lit: (area.containsMouse && enabled) || checked

    signal clicked()

    implicitWidth: label.implicitWidth + (small ? 18 : 24)
    implicitHeight: small ? 24 : 30
    color: lit ? "#F1AA03" : "#F9F9F9"
    border.color: lit ? "#F1AA03" : "#26000000"
    opacity: enabled ? 1 : 0.45

    Text {
        id: label

        anchors.centerIn: parent
        text: chip.text
        font.family: Yui.fontFor(text)
        font.pixelSize: chip.small ? 12 : 14
        color: chip.lit ? "#FFFFFF" : "#4D4D4D"
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }

}
