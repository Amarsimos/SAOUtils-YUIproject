import QtQuick 2.12
import "yui.js" as Yui

// A segmented switch of System Console (the preview's Heart Core / Fragments): joined white segments
// with a light shadow, the chosen one SAO orange with white text.
Row {
    id: control

    property var model: []
    property int current: 0

    signal picked(int index)

    Repeater {
        model: control.model

        Rectangle {
            readonly property bool chosen: index === control.current

            implicitWidth: label.implicitWidth + 24
            implicitHeight: 26
            color: chosen ? "#F1AA03" : (area.containsMouse ? "#FFF3D6" : "#FFFFFF")
            border.color: chosen ? "#F1AA03" : "#26000000"

            Text {
                id: label

                anchors.centerIn: parent
                text: modelData
                font.family: Yui.fontFor(text)
                font.pixelSize: 13
                color: parent.chosen ? "#FFFFFF" : "#4D4D4D"
            }

            MouseArea {
                id: area

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    control.current = index;
                    control.picked(index);
                }
            }

        }

    }

}
