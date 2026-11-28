import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// A page of System Console: its panels in a column over the code wall, scrolling vertically when
// they do not fit (the SAO scroll bar at the right).
Flickable {
    id: page

    default property alias content: column.data

    clip: true
    contentWidth: width
    contentHeight: column.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: column

        width: page.width - 12
        spacing: 14
    }

    ScrollBar.vertical: SaoScrollBar {
    }

}
