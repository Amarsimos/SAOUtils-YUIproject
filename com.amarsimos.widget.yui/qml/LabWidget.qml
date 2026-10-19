import NERvGear 1.0 as NVG
import QtQuick 2.12

// A widget made from QML source in the Seedling (WidgetLab.qml), shown in its own desktop view.
// It is not a registered SAO Utils widget, so it lasts until it is closed or SAO Utils exits. A thin
// bar appears at its top while hovered: drag it to move the widget, ✕ closes it.
NVG.View {
    id: view

    // The QML source; the view takes the size of what it creates.
    property string code
    // Shown in the move bar ("title" is a FINAL property of View).
    property string label: "Lab Widget"
    property var created: null
    readonly property int barHeight: 18

    signal removed()

    function remove() {
        visible = false;
        view.removed();
        destroy();
    }

    color: "transparent"
    width: created ? Math.max(40, created.width) : 200
    height: (created ? Math.max(20, created.height) : 120) + barHeight
    visible: true
    Component.onCompleted: {
        try {
            created = Qt.createQmlObject(code, body, "LabWidget");
        } catch (e) {
            console.log("lab widget failed:", e);
        }
    }

    Item {
        id: body

        y: view.barHeight
        width: view.width
        height: view.height - view.barHeight
    }

    // Move / close bar, shown while the mouse is over the widget.
    Rectangle {
        id: bar

        width: view.width
        height: view.barHeight
        radius: 4
        color: "#CC1A1D24"
        opacity: hoverArea.containsMouse || closeArea.containsMouse || dragArea.pressed ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }

        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            x: 6
            width: parent.width - 30
            text: view.label
            color: "#DDFFFFFF"
            font.pixelSize: 10
            elide: Text.ElideRight
        }

        // Drag to move: the view follows the mouse in screen coordinates.
        MouseArea {
            id: dragArea

            property point start
            property point origin

            anchors.fill: parent
            anchors.rightMargin: 20
            cursorShape: Qt.SizeAllCursor
            onPressed: {
                start = mapToGlobal(mouse.x, mouse.y);
                origin = Qt.point(view.x, view.y);
            }
            onPositionChanged: {
                var now = mapToGlobal(mouse.x, mouse.y);
                view.x = origin.x + now.x - start.x;
                view.y = origin.y + now.y - start.y;
            }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 5
            anchors.verticalCenter: parent.verticalCenter
            text: "✕"
            color: closeArea.containsMouse ? "#F59B00" : "#DDFFFFFF"
            font.pixelSize: 11

            MouseArea {
                id: closeArea

                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: view.remove()
            }

        }

    }

    // Hover detection over the whole view, without taking clicks from the widget's own content.
    MouseArea {
        id: hoverArea

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        z: -1
    }

}
