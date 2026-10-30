import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// Short explanation shown under a setting, for preference types without a "message" property.
// The text is passed through qsTr() by the caller, so it is translated with the settings dialog.
Label {
    id: note

    // Under SAO Utils' settings: inset as their own texts, 16 px at each side.
    property bool besidePreferences: false
    // In a window that takes its size from its content (a DialogPreference's), the width the text is
    // wrapped at: the note then asks for that width and the height of the text wrapped there (its own
    // implicit size is the text in one line, which made the dialog too wide, or too short once wrapped).
    property real wrapWidth: 0

    width: parent ? parent.width : implicitWidth
    Layout.fillWidth: true
    Layout.preferredWidth: wrapWidth > 0 ? wrapWidth : -1
    Layout.preferredHeight: wrapWidth > 0 ? sizer.contentHeight : -1
    Layout.leftMargin: besidePreferences ? 16 : 4
    Layout.rightMargin: besidePreferences ? 16 : 0
    wrapMode: Text.Wrap
    font.pixelSize: 11
    opacity: 0.7

    // The text wrapped at wrapWidth, measured only.
    Text {
        id: sizer

        visible: false
        width: note.wrapWidth
        wrapMode: Text.Wrap
        font: note.font
        text: note.text
    }

}
