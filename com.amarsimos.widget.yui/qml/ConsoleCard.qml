import QtQuick 2.12
import QtQuick.Layouts 1.12
import "yui.js" as Yui

// A card of System Console (as the preview): a panel with one big SAO UI value, an optional tag, a
// small line under it and an optional thin meter (0-1; -1 hides it).
ConsolePanel {
    id: card

    property string big
    property string sub
    property string tag
    property color tagColor: "#7CC63E"
    property real meter: -1
    property color meterColor: "#4BB4EC"

    implicitHeight: Math.max(126, 34 + cardBody.implicitHeight + padding * 2)

    ColumnLayout {
        id: cardBody

        Layout.fillWidth: true
        spacing: 4

        Text {
            text: card.big
            font.family: Yui.fontFor(text)
            font.pixelSize: 30
            color: "#4D4D4D"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            ConsoleTag {
                visible: card.tag !== ""
                text: card.tag
                color: card.tagColor
            }

            // Cut short with … when the card is narrow.
            Text {
                Layout.fillWidth: true
                font.family: Yui.fontFor(text)
                elide: Text.ElideRight
                visible: card.sub !== ""
                text: card.sub
                font.pixelSize: 12
                color: "#7A7A7A"
            }

        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 4
            visible: card.meter >= 0
            height: 6
            color: "#E3E3E3"

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, card.meter))
                height: parent.height
                color: card.meterColor
            }

        }

    }

}
