import QtQuick 2.12
import QtQuick.Layouts 1.12

// A section heading of the workbench: an orange mark, the title in SAO UI, a thin line and a note.
RowLayout {
    property alias text: title.text
    property alias note: noteText.text

    spacing: 8

    Rectangle {
        width: 4
        height: 12
        radius: 1
        color: "#F1AA03"
    }

    Text {
        id: title

        font.family: "SAO UI"
        font.pixelSize: 13
        font.letterSpacing: 3
        color: "#8A8A8A"
    }

    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: "#D4D4D4"
    }

    Text {
        id: noteText

        visible: text !== ""
        font.pixelSize: 11
        color: "#9A9A9A"
    }

}
