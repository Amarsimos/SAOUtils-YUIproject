import NERvGear 1.0 as NVG
import QtQuick 2.12
import QtQuick.Window 2.12

// Yui's expanded form (character and chat) in its own desktop view, opened by clicking her collapsed
// form (crystal, pixie or avatar) and closed with ✕ or Esc. The widget keeps all the logic; it puts
// its expanded layer into host. A bar at the top (shown while hovered) moves the view, the grip
// at the bottom-right resizes it; the geometry is remembered in the widget's settings.
NVG.View {
    id: view

    // The widget (main-stand.qml).
    property var yui
    // Where the widget's expanded layer goes.
    readonly property Item host: hostItem
    readonly property int barHeight: 16
    readonly property int minimumViewWidth: Math.ceil(yui.characterMinimumWidth * 0.6 + yui.chatMinimumWidth + 40)
    readonly property int minimumViewHeight: 320

    signal closeRequested()

    // Remembers the geometry (after moving / resizing).
    function saveGeometry() {
        yui.settings.view_geometry = {
            "x": Math.round(x),
            "y": Math.round(y),
            "width": Math.round(width),
            "height": Math.round(height)
        };
    }

    // The screen containing a point, or null.
    function screenAt(px, py) {
        var screens = Qt.application.screens;
        for (var i = 0; i < screens.length; i++) {
            var s = screens[i];
            if (px >= s.virtualX && px < s.virtualX + s.width && py >= s.virtualY && py < s.virtualY + s.height)
                return s;

        }
        return null;
    }

    // Where to open: the remembered geometry while it is on a screen; otherwise (first time, or the
    // screen is gone) next to the collapsed form, on the side with more room, on its screen.
    // anchor: the collapsed form's rectangle on screen.
    function place(anchor) {
        var saved = yui.settings.view_geometry;
        width = Math.max(minimumViewWidth, saved ? saved.width : (yui.settings.expanded_width || 800));
        height = Math.max(minimumViewHeight, saved ? saved.height : (yui.settings.expanded_height || 420));
        if (saved && screenAt(saved.x + 40, saved.y + 10)) {
            x = saved.x;
            y = saved.y;
            return ;
        }
        var s = screenAt(anchor.x + anchor.width / 2, anchor.y + anchor.height / 2) || Qt.application.screens[0];
        var left = s.virtualX, top = s.virtualY, right = left + s.width, bottom = top + s.height;
        var roomRight = right - (anchor.x + anchor.width);
        var roomLeft = anchor.x - left;
        x = roomRight >= width || roomRight >= roomLeft ? anchor.x + anchor.width : anchor.x - width;
        y = anchor.y + anchor.height / 2 - height / 2;
        x = Math.round(Math.max(left, Math.min(right - width, x)));
        y = Math.round(Math.max(top, Math.min(bottom - height, y)));
    }

    color: "transparent"
    acceptFocus: true
    acceptInput: true
    solid: true
    visible: false

    Item {
        id: hostItem

        anchors.fill: parent
        anchors.topMargin: view.barHeight
    }

    // Any mouse movement over the view counts as the user being around.
    HoverHandler {
        id: viewHover

        onHoveredChanged: {
            if (hovered)
                view.yui.noteActivity();

        }
    }

    // Move bar with the close button.
    Rectangle {
        width: parent.width
        height: view.barHeight
        radius: 4
        color: "#CC1A1D24"
        opacity: viewHover.hovered || moveArea.pressed ? 1 : 0.35

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }

        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            x: 8
            text: "MHCP001 · Yui"
            color: "#DDFFFFFF"
            font.pixelSize: 10
        }

        MouseArea {
            id: moveArea

            property point start
            property point origin

            anchors.fill: parent
            anchors.rightMargin: 24
            cursorShape: Qt.SizeAllCursor
            onPressed: {
                start = mapToGlobal(mouse.x, mouse.y);
                origin = Qt.point(view.x, view.y);
            }
            onPositionChanged: {
                var now = mapToGlobal(mouse.x, mouse.y);
                view.x = Math.round(origin.x + now.x - start.x);
                view.y = Math.round(origin.y + now.y - start.y);
            }
            onReleased: view.saveGeometry()
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            text: "✕"
            color: closeArea.containsMouse ? "#F59B00" : "#DDFFFFFF"
            font.pixelSize: 11

            MouseArea {
                id: closeArea

                anchors.fill: parent
                anchors.margins: -5
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: view.closeRequested()
            }

        }

    }

    // Resize grip (bottom-right corner).
    Item {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 16
        height: 16
        z: 100

        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: "◢"
            color: resizeArea.containsMouse || resizeArea.pressed ? "#F59B00" : "#88888888"
            font.pixelSize: 12
        }

        MouseArea {
            id: resizeArea

            property point start
            property size origin

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeFDiagCursor
            onPressed: {
                start = mapToGlobal(mouse.x, mouse.y);
                origin = Qt.size(view.width, view.height);
            }
            onPositionChanged: {
                var now = mapToGlobal(mouse.x, mouse.y);
                view.width = Math.round(Math.max(view.minimumViewWidth, origin.width + now.x - start.x));
                view.height = Math.round(Math.max(view.minimumViewHeight, origin.height + now.y - start.y));
            }
            onReleased: view.saveGeometry()
        }

    }

    Shortcut {
        sequence: "Esc"
        onActivated: view.closeRequested()
    }

}
