import NERvGear 1.0 as NVG
import QtQuick 2.12

// "Try on Desktop": the code in a desktop view of its own, until it is closed or SAO Utils exits. A thin
// bar appears at its top while hovered: drag it to move the view, ✕ closes it.
NVG.View {
    id: view

    property string code
    property var created: null
    readonly property int barHeight: 18

    color: "transparent"
    width: created ? Math.max(40, created.width) : 200
    height: (created ? Math.max(20, created.height) : 120) + barHeight
    visible: true
    Component.onCompleted: {
        try {
            created = Qt.createQmlObject(code, body, "SeedlingTry");
        } catch (e) {
            console.log("Seedling try failed:", e);
        }
    }

    Item {
        id: body

        y: view.barHeight
        width: view.width
        height: view.height - view.barHeight
    }

    Rectangle {
        id: bar
        width: view.width
        height: view.barHeight
        radius: 4
        color: "#CCF4F4F4"
        border.color: "#D4D4D4"
        opacity: hoverArea.containsMouse || closeArea.containsMouse || dragArea.pressed ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }

        }

        Text {
            anchors.verticalCenter: bar.verticalCenter
            x: 6
            text: "SEEDLING · TRY"
            font.family: "SAO UI"
            font.pixelSize: 11
            color: "#6A6A6A"
        }

        // Moved by the cursor's distance from the grabbed point, in the view's own coordinates (right
        // with display scaling and several screens).
        MouseArea {
            id: dragArea

            property point grab

            anchors.fill: parent
            anchors.rightMargin: 20
            cursorShape: Qt.SizeAllCursor
            onPressed: grab = Qt.point(mouse.x, mouse.y)
            onPositionChanged: {
                view.x += mouse.x - grab.x;
                view.y += mouse.y - grab.y;
            }
        }

        Text {
            anchors.right: bar.right
            anchors.rightMargin: 5
            anchors.verticalCenter: bar.verticalCenter
            text: "✕"
            color: closeArea.containsMouse ? "#D9473B" : "#8A8A8A"
            font.pixelSize: 11

            MouseArea {
                id: closeArea

                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: view.destroy()
            }

        }

    }

    MouseArea {
        id: hoverArea

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        z: -1
    }

}
