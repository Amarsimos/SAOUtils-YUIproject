import NERvGear.Controls 1.0
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12

// System Console, Status: the loads as HP bars (LoadBars.qml, the same data sources as SAO Utils' own
// HP bar widgets), what colors the crystal, the network, the system drive and this month's Col.
SettingsPage {
    id: status

    property var yui
    // Refreshed every 2 s while the page is shown.
    property bool active: true
    property real diskUsed: NaN
    property double now: Date.now()

    function refresh() {
        diskUsed = yui.readData(yui.diskSpace, yui.systemDrive);
        now = Date.now();
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 2000
        repeat: true
        running: status.active && status.visible
        onTriggered: status.refresh()
    }

    Heading {
        text: qsTr("Load")
    }

    LoadBars {
        Layout.fillWidth: true
        yui: status.yui
    }

    // What colors the crystal now.
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        spacing: 8

        Rectangle {
            width: 10
            height: 10
            radius: 5
            color: status.yui.crystalColor
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            opacity: 0.8
            text: status.yui.raidActive ? qsTr("Yui's Heart: violet (Boss Raid)") : status.yui.crystalLevel === 0 ? qsTr("Yui's Heart: green") : qsTr("Yui's Heart: %1 (%2)").arg(status.yui.crystalLevel === 2 ? qsTr("red") : qsTr("yellow")).arg(status.yui.crystalStatus)
        }

    }

    Heading {
        text: qsTr("Link")
    }

    Label {
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        wrapMode: Text.Wrap
        text: status.yui.settings.network_watch === false ? qsTr("Not watched (System Authority, Network Link)") : status.yui.networkLost ? qsTr("Offline: no traffic for two minutes") : qsTr("Online")
        color: status.yui.networkLost ? "#C82864" : palette.text
    }

    Heading {
        text: qsTr("Storage")
    }

    Label {
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        wrapMode: Text.Wrap
        text: isNaN(status.diskUsed) ? qsTr("%1 not available").arg(status.yui.systemDrive) : qsTr("%1 %2% used, %3% free").arg(status.yui.systemDrive.replace(/\\$/, "")).arg(Math.round(status.diskUsed)).arg(Math.max(0, Math.round(100 - status.diskUsed)))
    }

    ProgressBar {
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        visible: !isNaN(status.diskUsed)
        from: 0
        to: 100
        value: isNaN(status.diskUsed) ? 0 : status.diskUsed
    }

    // Col Ledger: the tokens of this month's replies, as the servers report them.
    Heading {
        text: qsTr("Col Ledger")
    }

    Label {
        readonly property var ledger: status.yui.colLedger

        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        wrapMode: Text.Wrap
        text: ledger ? qsTr("%1: %2 tokens sent, %3 received, %4 replies").arg(ledger.month).arg(ledger.input.toLocaleString(Qt.locale(), "f", 0)).arg(ledger.output.toLocaleString(Qt.locale(), "f", 0)).arg(ledger.requests) : qsTr("No replies counted yet this month.")
    }

    // Against the Monthly Budget (System Authority), when there is one.
    ProgressBar {
        readonly property var ledger: status.yui.colLedger
        readonly property real budget: (status.yui.settings.col_budget || 0) * 1000

        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        visible: budget > 0
        from: 0
        to: Math.max(1, budget)
        value: ledger ? Math.min(budget, ledger.input + ledger.output) : 0
    }

    Label {
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        visible: (status.yui.settings.col_budget || 0) > 0
        opacity: 0.7
        wrapMode: Text.Wrap
        text: qsTr("Monthly Budget: %1k tokens").arg(status.yui.settings.col_budget || 0)
    }

}
