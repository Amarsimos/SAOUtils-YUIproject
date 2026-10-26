import NERvGear.Templates 1.0 as T
import QtQml 2.12
import "link" 1.0 as Link

// MHCP-YUI as a SAO Utils data source, for HP bars, HUD widgets and the like: each value is read from
// the running Yui (Link.Server, see her linkValue) and is empty while she is not running.
T.Data {
    id: root

    title: qsTr("MHCP-YUI")
    description: qsTr("Yui's companion days, today's mood, this month's tokens, the Boss Raid, the next alarm and the heart core; as text, the open to-dos, the next alarm, the Boss Raid timer, today's mood and the latest weekly report.")

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
        id: nextAlarmValue

        name: "next_alarm"
        title: qsTr("Next Alarm (minutes)")
        unit: "min"
        units: ["min"]
        interval: 15000
        current: 0
        minimum: 0
        maximum: 1
        update.execute: function() {
            root.read(nextAlarmValue, "next_alarm");
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

    T.Value {
        id: questLogValue

        name: "quest_log"
        title: qsTr("Quest Log (text)")
        interval: 10000
        current: ""
        minimum: ""
        maximum: ""
        update.execute: function() {
            root.read(questLogValue, "quest_log");
        }
    }

    T.Value {
        id: alarmTextValue

        name: "next_alarm_text"
        title: qsTr("Next Alarm (text)")
        interval: 15000
        current: ""
        minimum: ""
        maximum: ""
        update.execute: function() {
            root.read(alarmTextValue, "next_alarm_text");
        }
    }

    T.Value {
        id: raidTimerValue

        name: "raid_timer"
        title: qsTr("Boss Raid Timer (text)")
        interval: 1000
        current: ""
        minimum: ""
        maximum: ""
        update.execute: function() {
            root.read(raidTimerValue, "raid_timer");
        }
    }

    T.Value {
        id: moodTextValue

        name: "mood_text"
        title: qsTr("Today's Mood (text)")
        interval: 60000
        current: ""
        minimum: ""
        maximum: ""
        update.execute: function() {
            root.read(moodTextValue, "mood_text");
        }
    }

    T.Value {
        id: latestReportValue

        name: "latest_report"
        title: qsTr("Latest Weekly Report (text)")
        interval: 60000
        current: ""
        minimum: ""
        maximum: ""
        update.execute: function() {
            root.read(latestReportValue, "latest_report");
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
