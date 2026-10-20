import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// Short explanation shown under a setting, for preference types without a "message" property.
// The text is passed through qsTr() by the caller, so it is translated with the settings dialog.
Label {
    width: parent ? parent.width : implicitWidth
    Layout.fillWidth: true
    Layout.leftMargin: 4
    wrapMode: Text.Wrap
    font.pixelSize: 11
    opacity: 0.7
}
