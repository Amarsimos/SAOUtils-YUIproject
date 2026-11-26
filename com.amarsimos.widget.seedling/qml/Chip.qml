import QtQuick 2.12

// A small light button on the grey band (as SAO_UI-Window's): orange while hovered or checked.
Rectangle {
    id: chip

    property alias text: label.text
    property bool checked: false

    signal clicked()

    implicitWidth: label.implicitWidth + 24
    implicitHeight: 30
    color: (area.containsMouse || checked) && enabled ? "#F1AA03" : "#F9F9F9"
    opacity: enabled ? 1 : 0.5

    // The light shade under it.
    Rectangle {
        anchors.top: parent.bottom
        width: parent.width
        height: 1
        color: "#33000000"
    }

    Text {
        id: label

        anchors.centerIn: parent
        font.family: "SAO UI"
        font.pixelSize: 15
        color: (area.containsMouse || chip.checked) && chip.enabled ? "#FFFFFF" : "#4D4D4D"
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }

}
