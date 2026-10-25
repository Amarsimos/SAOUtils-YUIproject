import NERvGear.Templates 1.0 as T
import QtQml 2.12
import "link" 1.0 as Link

// MHCP-YUI as a SAO Utils data source, for HP bars, HUD widgets and the like: each value is read from
// the running Yui (Link.Server, see her linkValue) and is empty while she is not running.
T.Data {
    id: root

    title: qsTr("MHCP-YUI")
    description: qsTr("Yui's companion days, today's mood, this month's tokens, the Boss Raid and the heart core.")

    T.Value {
        id: companionDaysValue

        name: "companion_days"
        title: qsTr("Companion Days")
        unit: "d"
        units: ["d"]
        interval: 60000
        current: 0
        minimum: 0
        maximum: 365
        update.execute: function() {
            root.read(companionDaysValue, "companion_days");
        }
    }

    T.Value {
        id: moodValue

        name: "mood"
        title: qsTr("Today's Mood")
        interval: 60000
        current: 0
        minimum: 0
        maximum: 5
        update.execute: function() {
            root.read(moodValue, "mood");
        }
    }

    T.Value {
        id: colLedgerValue

        name: "col_ledger"
        title: qsTr("Col Ledger (k tokens)")
        unit: "k"
        units: ["k"]
        interval: 10000
        current: 0
        minimum: 0
        maximum: 0
        update.execute: function() {
            root.read(colLedgerValue, "col_ledger");
        }
    }

    T.Value {
        id: bossRaidValue

        name: "boss_raid"
        title: qsTr("Boss Raid (minutes left)")
        unit: "min"
        units: ["min"]
        interval: 1000
        current: 0
        minimum: 0
        maximum: 0
        update.execute: function() {
            root.read(bossRaidValue, "boss_raid");
        }
    }

    T.Value {
        id: heartCoreValue

        name: "heart_core"
        title: qsTr("Heart Core")
        interval: 10000
        current: 0
        minimum: 0
        maximum: 0
        update.execute: function() {
            root.read(heartCoreValue, "heart_core");
        }
    }

    // Updates a value from Yui ({current, maximum}); Null while she is not running.
    function read(value, name) {
        var yui = Link.Server.yui;
        var found = yui ? yui.linkValue(name) : null;
        if (!found) {
            value.status = T.Value.Null;
            return ;
        }
        value.current = found.current;
        if (found.maximum !== undefined)
            value.maximum = found.maximum;

        value.status = T.Value.Ready;
    }
}
