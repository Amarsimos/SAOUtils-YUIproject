import NERvGear 1.0 as NVG
import QtQuick 2.12
import QtQuick.Window 2.12

// Yui's expanded form (character and chat) in its own desktop view, opened by clicking her collapsed
// form (crystal, pixie or avatar) and closed with ✕ or Esc. The widget keeps all the logic; it puts
// its expanded layer into host, and moves the view by its chat panel's "Message" title (beginMove /
// moveTo / endMove). The grip at the bottom-right resizes it; the geometry is remembered.
// It opens and closes like SAO Utils' SAO theme panels (com.gpbeta.theme.sao PanelView.qml).
NVG.View {
    id: view

    // The widget (main-stand.qml).
    property var yui
    // Where the widget's expanded layer goes.
    readonly property Item host: hostItem
    readonly property int minimumViewWidth: Math.ceil(yui.characterMinimumWidth * 0.6 + yui.chatMinimumWidth + 40)
    readonly property int minimumViewHeight: 320
    // Height the panel first opens to before unfolding fully (PanelView's collapsedHeight).
    readonly property real collapsedHeight: Math.round(height * 0.66)
    property point moveStart
    property point moveOrigin

    signal closeRequested()
    // The close animation has finished and the view is hidden.
    signal folded()

    // Opens: the clip grows from 80 x 80 at the right edge to the full width and collapsedHeight
    // (400 ms) while the view fades in (500 ms) with the panel sound, then unfolds to the full height
    // (250 ms); the character and chat fade in at the end. The content stays where it is while the
    // clip reveals it (no scaling).
    function popUp() {
        aniClose.stop();
        panelClip.width = 80;
        panelClip.height = 80;
        hostItem.opacity = 0;
        opacity = 0;
        visible = true;
        requestActivate();
        aniOpen.restart();
    }

    // Closes: fades out (250 ms), then folded().
    function fold() {
        if (!visible || aniClose.running)
            return ;

        aniOpen.stop();
        aniClose.start();
    }

    // Moving by the chat panel's title: global mouse positions.
    function beginMove(point) {
        moveStart = point;
        moveOrigin = Qt.point(x, y);
    }

    function moveTo(point) {
        x = Math.round(moveOrigin.x + point.x - moveStart.x);
        y = Math.round(moveOrigin.y + point.y - moveStart.y);
    }

    function endMove() {
        saveGeometry();
    }

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
    // Starts transparent and is only shown by popUp, so nothing flashes before the open animation.
    opacity: 0
    visible: false

    // The panel clip (as PanelView: anchored to the right edge, growing up from collapsedHeight while
    // it is lower than that, then down), with the content kept in place inside it.
    Item {
        id: panelClip

        x: view.width - width
        y: Math.max(view.collapsedHeight - height, 0)
        width: view.width
        height: view.height
        clip: true

        Item {
            id: inner

            x: -panelClip.x
            y: -panelClip.y
            width: view.width
            height: view.height

            Item {
                id: hostItem

                anchors.fill: parent
            }

            // Any mouse movement over the view counts as the user being around.
            HoverHandler {
                onHoveredChanged: {
                    if (hovered)
                        view.yui.noteActivity();

                }
            }

            // Resize grip (bottom-right corner); only a drag with the button held resizes.
            Item {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 18
                height: 18
                z: 100

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 2
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
                        if (!pressed)
                            return ;

                        var now = mapToGlobal(mouse.x, mouse.y);
                        view.width = Math.round(Math.max(view.minimumViewWidth, origin.width + now.x - start.x));
                        view.height = Math.round(Math.max(view.minimumViewHeight, origin.height + now.y - start.y));
                    }
                    onReleased: view.saveGeometry()
                }

            }

        }

    }

    SequentialAnimation {
        id: aniOpen

        ParallelAnimation {
            ScriptAction {
                script: NVG.SystemCall.playSound(NVG.SFX.PopupPanel)
            }

            NumberAnimation {
                target: panelClip
                property: "width"
                from: 80
                to: view.width
                duration: 400
                easing.type: Easing.OutQuart
            }

            NumberAnimation {
                target: panelClip
                property: "height"
                from: 80
                to: view.collapsedHeight
                duration: 400
                easing.type: Easing.OutQuart
            }

            NumberAnimation {
                target: view
                property: "opacity"
                from: 0
                to: 1
                duration: 500
            }

        }

        NumberAnimation {
            target: panelClip
            property: "height"
            to: view.height
            duration: 250
            easing.type: Easing.OutQuart
        }

        NumberAnimation {
            target: hostItem
            property: "opacity"
            to: 1
            duration: 250
        }

        // The clip follows the view's size again (for resizing).
        ScriptAction {
            script: {
                panelClip.width = Qt.binding(function() {
                    return view.width;
                });
                panelClip.height = Qt.binding(function() {
                    return view.height;
                });
            }
        }

    }

    SequentialAnimation {
        id: aniClose

        NumberAnimation {
            target: view
            property: "opacity"
            to: 0
            duration: 250
        }

        ScriptAction {
            script: {
                view.visible = false;
                view.folded();
            }
        }

    }

    Shortcut {
        sequence: "Esc"
        onActivated: view.closeRequested()
    }

}
