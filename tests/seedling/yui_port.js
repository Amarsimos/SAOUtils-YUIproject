// MHCP-YUI as Seedling's tests see her: what her SeedlingPort gives (section 12 of "Seedling
// Development Plan.md"), so these tests run without MHCP-YUI's code. tests/check_deploy.js checks that
// it still says what her yui.js (SEEDLING_DATA) says.
module.exports = {
    "linkVersion": 1,
    "dataKeys": {
        "companion_days": {
            "type": "int",
            "text": "陪伴天数",
            "fast": false
        },
        "mood": {
            "type": "int",
            "text": "今天心情 1-5，0 是没记录",
            "fast": false
        },
        "mood_text": {
            "type": "string",
            "text": "今天心情的文字",
            "fast": false
        },
        "mood_history": {
            "type": "var",
            "text": "最近 30 天心情：[{day: \"yyyy-MM-dd\", score: 1-5}]",
            "fast": false
        },
        "boss_raid": {
            "type": "int",
            "text": "Boss Raid 剩余分钟",
            "fast": true
        },
        "raid_timer": {
            "type": "string",
            "text": "Boss Raid 计时文字",
            "fast": true
        },
        "raid_cleared": {
            "type": "int",
            "text": "刚打赢 Boss Raid 的几秒内是 1",
            "fast": true
        },
        "next_alarm": {
            "type": "int",
            "text": "下一个闹钟还有几分钟",
            "fast": false
        },
        "next_alarm_text": {
            "type": "string",
            "text": "下一个闹钟的文字",
            "fast": false
        },
        "quest_log": {
            "type": "string",
            "text": "待办，每行一条",
            "fast": false
        },
        "heart_core": {
            "type": "int",
            "text": "结衣之心的记忆条数",
            "fast": false
        },
        "col_ledger": {
            "type": "real",
            "text": "本月用掉的 k token",
            "fast": false
        },
        "latest_report": {
            "type": "string",
            "text": "最新周报",
            "fast": false
        }
    }
};
