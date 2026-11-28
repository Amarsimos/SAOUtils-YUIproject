import QtQuick 2.12
import QtQuick.Layouts 1.12
import "yui.js" as Yui

// A list row of System Console (as the preview's lists): a grey SAO UI key at the left (a time, a kind,
// a date), the text, and at the right what is put in it (chips, tags); a thin line under it unless last.
Item {
    id: row

    property string key
    property int keyWidth: 76
    property string text
    property bool done: false
    property bool last: false
    default property alias actions: actionRow.data

    implicitHeight: Math.max(30, Math.max(label.implicitHeight, actionRow.implicitHeight) + 12)

    Text {
        id: keyText

        anchors.verticalCenter: parent.verticalCenter
        width: row.keyWidth
        visible: row.key !== ""
        text: row.key
        font.family: Yui.fontFor(text)
        font.pixelSize: 14
        color: "#7A7A7A"
    }

    Text {
        id: label

        font.family: Yui.fontFor(text)
        anchors.left: parent.left
        anchors.leftMargin: row.key !== "" ? row.keyWidth + 10 : 0
        anchors.right: actionRow.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: row.text
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        font.pixelSize: 13
        font.strikeout: row.done
        color: row.done ? "#AAAAAA" : "#333333"
    }

    Row {
        id: actionRow

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: "#E9E9E9"
        visible: !row.last
    }

}
