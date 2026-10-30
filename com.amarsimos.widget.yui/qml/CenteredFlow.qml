import QtQuick 2.12
import QtQuick.Layouts 1.12

// Buttons of a settings page in one centered row (Flow itself cannot center its rows): the row is as
// wide as the buttons, centered in the page; when they do not fit, they wrap within the page (inset
// 16 px each side, so the slanted buttons stay inside it).
Item {
    id: box

    default property alias content: flow.data
    property int spacing: 8
    // The buttons' width side by side.
    readonly property real naturalWidth: {
        var total = 0, count = 0;
        for (var i = 0; i < flow.children.length; i++) {
            var child = flow.children[i];
            if (child.visible && child.width > 0) {
                total += child.width;
                count++;
            }
        }
        return total + Math.max(0, count - 1) * spacing;
    }

    Layout.fillWidth: true
    Layout.leftMargin: 16
    Layout.rightMargin: 16
    implicitHeight: flow.implicitHeight

    Flow {
        id: flow

        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(box.width, box.naturalWidth + 1)
        spacing: box.spacing
    }

}
