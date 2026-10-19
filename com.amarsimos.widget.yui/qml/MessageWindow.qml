import NERvGear 1.0 as NVG
import QtQuick 2.12
import QtQuick.Shapes 1.12

// One chat message as an SAO instant message window (after SAO Utils' SAO-style mail box panel):
// a white title bar with the sender's name in the SAO UI font, the text on a light gray body, and a
// white button bar with the message's note and actions; buttons turn SAO orange when hovered.
// New messages pop up like the mail box panel (popUp()).
Item {
    id: messageWindow

    property string sender
    property string text
    // Rich text with clickable links (Yui.linkify), or "" to show text as plain text.
    property string linkedText
    property string note
    // Label of a desktop action / link Yui offers ("" when none), and its state:
    // "pending" (Confirm... button), "done" or "cancelled".
    property string actionLabel
    property string actionState
    property bool canRegenerate: false
    property string fontFamily
    property int fontSize: 14
    // Widest the window may get.
    property real maximumWidth: 400
    // Side of the pointer toward the speaker: "left" (Yui), "right" (user) or "" (none). It sticks out
    // tailSize px beyond the window.
    property string tailSide: ""
    readonly property real tailSize: 8

    signal linkActivated(string link)
    signal confirmRequested()
    signal regenerateRequested()

    readonly property bool hasFooter: note !== "" || actionLabel !== "" || canRegenerate
    // Width the button bar needs: the action label (up to 220 px) and the buttons, with margins.
    readonly property real footerWidth: actionLabel === "" && !canRegenerate ? 0 : Math.min(actionMeasure.implicitWidth, 220) + buttons.width + 32
    readonly property color orange: "#F1AA03"
    // A message window pops up once; later calls (e.g. a streamed reply finishing) are ignored.
    property bool poppedUp: false

    // Opens like the mail box message panel: a thin line widens, then the body unfolds and the
    // text fades in, with the message notification sound. The window is hidden at once, and the
    // animation starts on the next turn of the event loop: a message window pops up while the chat
    // list is still creating and placing it, and an animation started right then was not seen.
    function popUp(sound) {
        if (poppedUp)
            return ;

        poppedUp = true;
        windowScale.xScale = 0.1;
        windowScale.yScale = 0.05;
        frame.opacity = 0;
        messageText.opacity = 0;
        Qt.callLater(function() {
            if (sound)
                NVG.SystemCall.playSound(NVG.SFX.NotifyMessage);

            popAnimation.restart();
        });
    }

    // Wide enough for the text (up to maximumWidth) and always for the whole button bar, so the
    // action and its buttons are never cut off under a short message.
    width: Math.max(180, footerWidth, Math.min(maximumWidth, measure.implicitWidth + 28))
    height: frame.height

    // The action label's natural width (for footerWidth).
    Text {
        id: actionMeasure

        visible: false
        text: messageWindow.actionLabel
        font.pixelSize: 12
    }

    // Unwrapped text, only to measure the natural width of the longest line.
    Text {
        id: measure

        visible: false
        text: messageWindow.text
        textFormat: Text.PlainText
        font: messageText.font
    }

    Rectangle {
        id: frame

        width: parent.width
        height: header.height + body.height + footer.height
        radius: 3
        color: "#F8F8F8"
        border.color: "#C8C8C8"
        border.width: 1

        // Title bar.
        Rectangle {
            id: header

            x: 1
            y: 1
            width: parent.width - 2
            height: 26
            radius: 2
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "#FFFFFF"
                }

                GradientStop {
                    position: 1
                    color: "#EEEEEE"
                }

            }

            Text {
                anchors.centerIn: parent
                width: parent.width - 16
                horizontalAlignment: Text.AlignHCenter
                text: messageWindow.sender
                color: "#777777"
                font.family: "SAO UI"
                font.pixelSize: 15
                elide: Text.ElideRight
            }

        }

        // Body: the message text on light gray, between thin shadow lines.
        Rectangle {
            id: body

            x: 1
            y: header.y + header.height
            width: parent.width - 2
            height: messageText.implicitHeight + 20
            color: "#E4E4E4"
            clip: true

            // A streamed reply grows smoothly as its text arrives (only once the window has popped up,
            // so its first layout is not animated).
            Behavior on height {
                enabled: messageWindow.poppedUp

                NumberAnimation {
                    duration: 100
                    easing.type: Easing.OutQuad
                }

            }

            Rectangle {
                width: parent.width
                height: 1
                color: "#CFCFCF"
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: "#D6D6D6"
            }

            TextEdit {
                id: messageText

                x: 12
                y: 10
                width: parent.width - 24
                text: messageWindow.linkedText || messageWindow.text
                // Shown verbatim: only the escaped, link-marked text is rich text.
                textFormat: messageWindow.linkedText ? TextEdit.RichText : TextEdit.PlainText
                wrapMode: TextEdit.Wrap
                readOnly: true
                selectByMouse: true
                selectionColor: messageWindow.orange
                color: "#3A3A3A"
                font.family: messageWindow.fontFamily
                font.pixelSize: messageWindow.fontSize
                onLinkActivated: messageWindow.linkActivated(link)

                // Hand cursor over a link; clicks still go to the text.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    cursorShape: messageText.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor
                }

            }

        }

        // Button bar: the note on its own line, then the action label and the buttons on the right.
        Item {
            id: footer

            x: 1
            y: body.y + body.height
            width: parent.width - 2
            height: messageWindow.hasFooter ? footerColumn.height + 12 : 6

            Column {
                id: footerColumn

                x: 8
                y: 6
                width: parent.width - 16
                spacing: 5
                visible: messageWindow.hasFooter

                Text {
                    visible: messageWindow.note !== ""
                    width: parent.width
                    text: messageWindow.note
                    color: "#888888"
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                }

                Item {
                    visible: messageWindow.actionLabel !== "" || messageWindow.canRegenerate
                    width: parent.width
                    height: 24

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - buttons.width - 8
                        text: messageWindow.actionLabel
                        color: "#666666"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Row {
                        id: buttons

                        anchors.right: parent.right
                        spacing: 6

                        Repeater {
                            // [label, kind]: "confirm" and "regenerate" are buttons, "status" is not.
                            model: (messageWindow.actionLabel === "" ? [] : [messageWindow.actionState === "pending" ? [qsTr("Confirm..."), "confirm"] : [messageWindow.actionState === "done" ? qsTr("Done ✓") : qsTr("Cancelled"), "status"]]).concat(messageWindow.canRegenerate ? [["↻ " + qsTr("Regenerate"), "regenerate"]] : [])

                            Rectangle {
                                readonly property bool isButton: modelData[1] !== "status"

                                width: buttonText.implicitWidth + 18
                                height: 24
                                radius: 2
                                color: !isButton ? "transparent" : (buttonArea.pressed ? messageWindow.orange : (buttonArea.containsMouse ? "#CCF1AA03" : "#FFFFFF"))
                                border.color: isButton ? "#D0D0D0" : "transparent"

                                Text {
                                    id: buttonText

                                    anchors.centerIn: parent
                                    text: modelData[0]
                                    color: parent.isButton && buttonArea.containsMouse ? "#FFFFFF" : "#BB333333"
                                    font.pixelSize: 12
                                }

                                MouseArea {
                                    id: buttonArea

                                    anchors.fill: parent
                                    enabled: parent.isButton
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData[1] === "confirm")
                                            messageWindow.confirmRequested();
                                        else
                                            messageWindow.regenerateRequested();
                                    }
                                }

                            }

                        }

                    }

                }

            }

        }

        // Pointer at the middle of the left (Yui) or right (user) side, toward the speaker. Drawn in
        // the body's gray over the frame's edge so it joins seamlessly; only its two outer edges are
        // stroked.
        Shape {
            id: tail

            readonly property real size: messageWindow.tailSize
            readonly property bool onRight: messageWindow.tailSide === "right"

            visible: messageWindow.tailSide !== ""
            x: onRight ? frame.width - 1 : -size + 1
            y: Math.round(frame.height / 2 - size)
            width: size
            height: size * 2
            layer.enabled: visible
            layer.samples: 4

            ShapePath {
                fillColor: body.color
                strokeColor: frame.border.color
                strokeWidth: 1
                joinStyle: ShapePath.MiterJoin
                startX: tail.onRight ? 0 : tail.size
                startY: 0

                PathLine {
                    x: tail.onRight ? tail.size : 0
                    y: tail.size
                }

                PathLine {
                    x: tail.onRight ? 0 : tail.size
                    y: tail.size * 2
                }

            }

        }

        transform: Scale {
            id: windowScale

            origin.x: frame.width / 2
            origin.y: frame.height / 2
        }

    }

    SequentialAnimation {
        id: popAnimation

        ParallelAnimation {
            NumberAnimation {
                target: windowScale
                property: "xScale"
                to: 1
                duration: 200
                easing.type: Easing.OutQuart
            }

            NumberAnimation {
                target: frame
                property: "opacity"
                to: 1
                duration: 200
            }

        }

        NumberAnimation {
            target: windowScale
            property: "yScale"
            to: 1
            duration: 250
            easing.type: Easing.OutQuart
        }

        NumberAnimation {
            target: messageText
            property: "opacity"
            to: 1
            duration: 200
        }

    }

}
