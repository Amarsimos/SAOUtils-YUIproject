import NERvGear.Dialogs 1.0 as D
import QtQuick 2.12

// File picker for importing a Yui's Heart export (Option window): the system file dialog, as used by
// SAO Utils' own packages (QtQuick.Dialogs needs Controls 1, which SAO Utils does not ship). The
// chosen file is in fileUrl. Kept in its own file so a missing module only disables importing.
D.FileDialog {
    readonly property url fileUrl: file

    title: qsTr("Import Yui's Heart")
    fileMode: D.FileDialog.OpenFile
    nameFilters: [qsTr("Yui's Heart") + " (*.json)"]
}
