import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// Short explanation shown under a setting, for preference types without a "message" property.
// The text is passed through qsTr() by the caller, so it is translated with the settings dialog.
Label {
    // Under SAO Utils' settings: inset as their own texts, 16 px at each side.
    property bool besidePreferences: false

    width: parent ? parent.width : implicitWidth
    Layout.fillWidth: true
    Layout.leftMargin: besidePreferences ? 16 : 4
    Layout.rightMargin: besidePreferences ? 16 : 0
    wrapMode: Text.Wrap
    font.pixelSize: 11
    opacity: 0.7
}
