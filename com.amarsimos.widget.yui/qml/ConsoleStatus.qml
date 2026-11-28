import QtQuick 2.12
import QtQuick.Layouts 1.12
import "yui.js" as Yui

// System Console, Status (as the preview): Cardinal Load (CPU, GPU, RAM and the battery as SAO HUD
// bars, colored with the crystal's thresholds; the same data sources as SAO Utils' HP bar widgets)
// with what colors the crystal now, then three cards: Link (network), Storage (system drive) and
// Total Tokens (this month's tokens, used and left of the Monthly Budget, as the Storage bar), then
// Links: the plugins and tools Yui works with (Seedling, Media Player, the weather source, Everything).
ConsolePage {
    id: status

    property var yui
    // Refreshed every 2 s while the page is shown.
    property bool active: true
    // Percentages, NaN when unavailable.
    property real cpu: NaN
    property real gpu: NaN
    property real ram: NaN
    property real battery: NaN
    property real diskUsed: NaN
    // The plugins and tools Yui works with (main-stand.qml, linkStatus).
    property var links: []
    // State to [tag (English, as the buttons), color].
    readonly property var linkTags: {
        "linked": ["Linked", "#7CC63E"],
        "off": ["Off", "#9A9A9A"],
        "missing": ["Missing", "#C82864"],
        "waiting": ["Waiting", "#4BB4EC"]
    }
    readonly property var ledger: yui.colLedger
    readonly property real budget: (yui.settings.col_budget || 0) * 1000
    readonly property real spent: ledger ? ledger.input + ledger.output : 0

    function refresh() {
        cpu = yui.readData(yui.cpuLoad);
        gpu = yui.readData(yui.gpuLoad);
        ram = yui.readData(yui.ramUsage);
        // Battery flag 128 means "no system battery".
        var flags = yui.readData(yui.batteryStatus);
        battery = !isNaN(flags) && flags < 128 ? yui.readData(yui.batteryLevel) : NaN;
        diskUsed = yui.readData(yui.diskSpace, yui.systemDrive);
        links = yui.linkStatus();
    }

    function level(value, metric) {
        if (isNaN(value))
            return 0;

        if (metric === "battery")
            return Yui.loadLevel(100 - value, [70, 90], 0);

        return Yui.loadLevel(value, Yui.loadThresholds(yui.settings.load_thresholds, metric), 0);
    }

    // Tokens as "502k".
    function kilo(count) {
        return count >= 1000 ? Math.round(count / 1000) + "k" : String(count);
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 2000
        repeat: true
        running: status.active && status.visible
        onTriggered: status.refresh()
    }

    ConsolePanel {
        Layout.fillWidth: true
        title: "Cardinal Load"
        note: qsTr("refresh 2 s")

        Repeater {
            model: [["CPU", "cpu"], ["GPU", "gpu"], ["RAM", "ram"], ["HP", "battery"]]

            RowLayout {
                readonly property real value: status[modelData[1]]

                Layout.fillWidth: true
                spacing: 10
                visible: modelData[1] !== "battery" || !isNaN(value)

                Text {
                    Layout.preferredWidth: 48
                    text: modelData[0]
                    font.family: Yui.fontFor(text)
                    font.pixelSize: 15
                    color: "#4D4D4D"
                }

                ConsoleHpBar {
                    Layout.fillWidth: true
                    value: parent.value
                    level: status.level(parent.value, modelData[1])
                }

                Text {
                    Layout.preferredWidth: 52
                    horizontalAlignment: Text.AlignRight
                    text: isNaN(parent.value) ? "--" : Math.round(parent.value) + "%"
                    font.family: Yui.fontFor(text)
                    font.pixelSize: 15
                    color: "#4D4D4D"
                }

            }

        }

        // What colors the crystal now.
        RowLayout {
            Layout.topMargin: 2
            spacing: 8

            Rectangle {
                width: 10
                height: 10
                radius: 5
                color: status.yui.crystalColor
            }

            Text {
                font.family: Yui.fontFor(text)
                text: status.yui.raidActive ? qsTr("Yui's Heart: violet (Boss Raid)") : status.yui.crystalLevel === 0 ? qsTr("Yui's Heart: green") : qsTr("Yui's Heart: %1 (%2)").arg(status.yui.crystalLevel === 2 ? qsTr("red") : qsTr("yellow")).arg(status.yui.crystalStatus)
                font.pixelSize: 12
                color: "#7A7A7A"
            }

        }

    }

    // Three cards in a row (one under another when narrow).
    GridLayout {
        Layout.fillWidth: true
        columns: status.width > 520 ? 3 : 1
        columnSpacing: 14
        rowSpacing: 14

        ConsoleCard {
            // The same width for every card whatever its text (a long line widened one; from the page's
            // width, as the grid's own width follows its cards), and the
            // same height as the others in its row.
            Layout.preferredWidth: (status.width - 12 - parent.columnSpacing * (parent.columns - 1)) / parent.columns
            Layout.maximumWidth: Layout.preferredWidth
            Layout.fillHeight: true
            title: "Link"
            note: "Network"
            big: status.yui.settings.network_watch === false ? "--" : status.yui.networkLost ? "Offline" : "Online"
            tag: status.yui.settings.network_watch === false ? "Not Watched" : status.yui.networkLost ? "Offline" : "Online"
            tagColor: status.yui.settings.network_watch === false ? "#9A9A9A" : status.yui.networkLost ? "#C82864" : "#7CC63E"
            sub: status.yui.settings.network_watch === false ? qsTr("System Authority, Network Link") : status.yui.networkLost ? qsTr("No traffic for two minutes") : ""
        }

        ConsoleCard {
            readonly property real minimum: status.yui.settings.storage_free_min !== undefined ? status.yui.settings.storage_free_min : 10

            // The same width for every card whatever its text (a long line widened one; from the page's
            // width, as the grid's own width follows its cards), and the
            // same height as the others in its row.
            Layout.preferredWidth: (status.width - 12 - parent.columnSpacing * (parent.columns - 1)) / parent.columns
            Layout.maximumWidth: Layout.preferredWidth
            Layout.fillHeight: true
            title: "Storage"
            note: status.yui.systemDrive.replace(/\\$/, "")
            big: isNaN(status.diskUsed) ? "--" : Math.round(status.diskUsed) + "%"
            sub: isNaN(status.diskUsed) ? qsTr("Not available") : (minimum > 0 ? qsTr("%1% free · warns below %2%").arg(Math.max(0, Math.round(100 - status.diskUsed))).arg(minimum) : qsTr("%1% free").arg(Math.max(0, Math.round(100 - status.diskUsed))))
            meter: isNaN(status.diskUsed) ? -1 : status.diskUsed / 100
            meterColor: !isNaN(status.diskUsed) && minimum > 0 && 100 - status.diskUsed < minimum ? "#C82864" : "#4BB4EC"
        }

        ConsoleCard {
            // The same width for every card whatever its text (a long line widened one; from the page's
            // width, as the grid's own width follows its cards), and the
            // same height as the others in its row.
            Layout.preferredWidth: (status.width - 12 - parent.columnSpacing * (parent.columns - 1)) / parent.columns
            Layout.maximumWidth: Layout.preferredWidth
            Layout.fillHeight: true
            // With a Monthly Budget (System Authority): the part used in %, used and left, and the bar
            // (red once past it); without one, the tokens alone.
            title: "Total Tokens"
            note: "this month"
            big: status.budget > 0 ? Math.round(status.spent / status.budget * 100) + "%" : status.kilo(status.spent)
            sub: status.budget > 0 ? qsTr("%1 used · %2 left of %3").arg(status.kilo(status.spent)).arg(status.kilo(Math.max(0, status.budget - status.spent))).arg(status.kilo(status.budget)) : (status.ledger ? qsTr("No budget (System Authority) · %1 replies").arg(status.ledger.requests) : qsTr("No replies counted yet this month."))
            meter: status.budget > 0 ? Math.min(1, status.spent / status.budget) : -1
            meterColor: status.budget > 0 && status.spent > status.budget ? "#C82864" : "#4BB4EC"
        }

    }


    ConsolePanel {
        Layout.fillWidth: true
        title: "Links"
        note: qsTr("plugins and tools")

        Repeater {
            model: status.links

            ConsoleRow {
                readonly property var tag: status.linkTags[modelData.state] || [modelData.state, "#9A9A9A"]

                Layout.fillWidth: true
                keyWidth: 110
                key: modelData.name
                text: modelData.detail
                last: index === status.links.length - 1

                ConsoleTag {
                    text: parent.parent.tag[0]
                    color: parent.parent.tag[1]
                }

            }

        }

    }

}
