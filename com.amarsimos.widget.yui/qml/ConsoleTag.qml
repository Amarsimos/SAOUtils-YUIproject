import QtQuick 2.12

// A result tag of System Console: white SAO UI text on a colored block.
Rectangle {
    property alias text: label.text

    implicitWidth: label.implicitWidth + 16
    implicitHeight: label.implicitHeight + 4
    radius: 2

    Text {
        id: label

        anchors.centerIn: parent
        font.family: "SAO UI"
        font.pixelSize: 12
        color: "#FFFFFF"
    }

}
