import QtQuick 2.12

// The frame of a panel set into the grey band (the code, the preview): the grey line and the white
// line inside it of SAO Utils' dialogs, and a faint shade under its top edge. Laid over the panel; it
// takes no input.
Item {
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: "#B9B9B9"
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        color: "transparent"
        border.color: "#E0FFFFFF"
    }

    Rectangle {
        x: 2
        y: 2
        width: parent.width - 4
        height: 6

        gradient: Gradient {
            GradientStop {
                position: 0
                color: "#1A000000"
            }

            GradientStop {
                position: 1
                color: "#00000000"
            }

        }

    }

}
