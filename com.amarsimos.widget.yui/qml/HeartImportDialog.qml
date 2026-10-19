import QtQuick 2.12
import QtQuick.Dialogs 1.3

// File picker for importing a Yui's Heart export (Option window). Kept in its own file so a missing
// QtQuick.Dialogs module only disables importing.
FileDialog {
    title: qsTr("Import Yui's Heart")
    selectExisting: true
    nameFilters: [qsTr("Yui's Heart") + " (*.json)"]
}
