.pragma library

// Seedling Settings' Test, Writing: the model's replies made up (no API), so the whole writing flow
// (Bench.write: progress, edits, the safety check, retries, the questions) runs without a request.
// (Moved from MHCP-YUI's System Console, section 12 of "Seedling Development Plan.md".)

function fence(code) {
    return "```qml\n" + code + "```";
}

var CLOCK = "import QtQuick 2.12\n\nRectangle {\n    width: 220; height: 90; radius: 10\n    color: \"#E61F2630\"\n\n    Text {\n        id: time\n        anchors.centerIn: parent\n        color: \"white\"\n        font.pixelSize: 36\n        text: Qt.formatTime(new Date(), \"hh:mm:ss\")\n    }\n\n    Timer {\n        interval: 1000; running: true; repeat: true\n        onTriggered: time.text = Qt.formatTime(new Date(), \"hh:mm:ss\")\n    }\n}\n";

// The replies for kind, in order: "write" (a clock), "edit" (one color of current changed; [] when
// current has none), "fix" (a mistake, then fixed when the error comes back), "network" (asks the
// Internet), "props" (a todo with @setting / @keep), "moods" (reads Yui's moods, @yui).
function replies(kind, current) {
    if (kind === "edit") {
        var line = String(current || "").split("\n").filter(function(l) {
            return /^\s*color:\s*"#/.test(l);
        })[0];
        return line ? ["<<<<<<< SEARCH\n" + line + "\n=======\n" + line.replace(/"#[0-9A-Fa-f]+"/, "\"#E6C82864\"") + "\n>>>>>>> REPLACE\n"] : [];
    }
    if (kind === "fix")
        return [fence("import QtQuick 2.12\n\nRectangle {\n    width: 220; height: 90; radius: 10\n    color: \"#E61F2630\"\n\n    Text {\n        colr: \"white\"\n        id: time\n        anchors.centerIn: parent\n        color: \"white\"\n        font.pixelSize: 36\n        text: Qt.formatTime(new Date(), \"hh:mm:ss\")\n    }\n\n    Timer {\n        interval: 1000; running: true; repeat: true\n        onTriggered: time.text = Qt.formatTime(new Date(), \"hh:mm:ss\")\n    }\n}\n"), fence(CLOCK)];

    if (kind === "moods")
        return [fence("import QtQuick 2.12\n\n// @name Mood Calendar\nRectangle {\n    id: root\n    width: 250; height: 150; radius: 10\n    color: \"#E6F4F4F4\"\n    border.color: \"#D4D4D4\"\n\n    // @yui mood_history\n    property var moods: []\n    // @yui companion_days\n    property int days: 0\n    // @setting Accent\n    property color accent: \"#F1AA03\"\n\n    // The last 30 days, oldest first: the score of each (0: not recorded).\n    readonly property var cells: {\n        var out = [];\n        var now = new Date();\n        for (var i = 0; i < 30; i++) {\n            var d = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 29 + i);\n            var key = Qt.formatDate(d, \"yyyy-MM-dd\");\n            var score = 0;\n            for (var j = 0; j < root.moods.length; j++)\n                if (root.moods[j].day === key)\n                    score = root.moods[j].score;\n            out.push(score);\n        }\n        return out;\n    }\n\n    function shade(score) {\n        if (score === 0)\n            return \"#E2E2E2\";\n        return Qt.rgba(0.95, 0.67, 0.01, 0.25 + score * 0.15);\n    }\n\n    Text {\n        x: 12; y: 8\n        text: \"MOOD · 30 DAYS\"\n        color: root.accent\n        font.family: \"SAO UI\"\n        font.pixelSize: 15\n    }\n\n    Text {\n        anchors.right: parent.right; anchors.rightMargin: 12\n        y: 8\n        text: \"DAY \" + root.days\n        color: \"#888888\"\n        font.family: \"SAO UI\"\n        font.pixelSize: 15\n    }\n\n    Grid {\n        x: 12; y: 34\n        columns: 10\n        spacing: 4\n\n        Repeater {\n            model: root.cells\n\n            Rectangle {\n                width: 19; height: 19; radius: 4\n                color: root.shade(modelData)\n                border.color: index === 29 ? root.accent : \"transparent\"\n                border.width: 2\n            }\n        }\n    }\n\n    Text {\n        x: 12\n        anchors.bottom: parent.bottom; anchors.bottomMargin: 8\n        text: \"颜色越深，那天心情越好\"\n        color: \"#999999\"\n        font.pixelSize: 11\n    }\n}\n")];

    if (kind === "props")
        return [fence("import QtQuick 2.12\nimport QtQuick.Controls 2.12\n\n// @name Todo\nRectangle {\n    id: root\n    width: 240; height: 220; radius: 8\n    color: root.dark ? \"#E61F2630\" : \"#E6F4F4F4\"\n\n    // @setting Title\n    property string heading: \"TODO\"\n    // @setting Theme | Light / Dark\n    property string theme: \"Light\"\n    // @setting Font Size | 12 - 24\n    property int fontSize: 15\n    // @setting Accent\n    property color accent: \"#F1AA03\"\n    // @setting Show Done\n    property bool showDone: true\n    // @keep\n    property var todos: []\n\n    readonly property bool dark: root.theme === \"Dark\"\n\n    Column {\n        anchors.fill: parent\n        anchors.margins: 10\n        spacing: 6\n\n        Text {\n            text: root.heading + \" · \" + root.todos.filter(function(t) { return !t.done; }).length\n            color: root.accent\n            font.pixelSize: root.fontSize + 3\n            font.bold: true\n        }\n\n        TextField {\n            id: input\n            width: parent.width\n            placeholderText: \"+\"\n            onAccepted: {\n                if (input.text.trim() === \"\")\n                    return;\n                root.todos = root.todos.concat([{\"text\": input.text, \"done\": false}]);\n                input.text = \"\";\n            }\n        }\n\n        Repeater {\n            model: root.todos\n            Text {\n                visible: root.showDone || !modelData.done\n                width: parent.width\n                elide: Text.ElideRight\n                text: (modelData.done ? \"✓ \" : \"○ \") + modelData.text\n                color: modelData.done ? \"#888888\" : (root.dark ? \"white\" : \"#333333\")\n                font.pixelSize: root.fontSize\n                font.strikeout: modelData.done\n                MouseArea {\n                    anchors.fill: parent\n                    onClicked: {\n                        var list = root.todos.slice();\n                        list[index] = {\"text\": modelData.text, \"done\": !modelData.done};\n                        root.todos = list;\n                    }\n                }\n            }\n        }\n    }\n}\n")];

    if (kind === "network")
        return [fence("import QtQuick 2.12\n\nRectangle {\n    id: root\n    width: 220; height: 80; radius: 8\n    color: \"#E61F2630\"\n    property string temp: \"--\"\n\n    Text { anchors.centerIn: parent; color: \"white\"; font.pixelSize: 28; text: root.temp }\n\n    Component.onCompleted: {\n        var request = new XMLHttpRequest();\n        request.onreadystatechange = function() {\n            if (request.readyState === XMLHttpRequest.DONE)\n                root.temp = request.status === 200 ? \"online\" : \"offline\";\n        };\n        request.open(\"GET\", \"https://www.bing.com/\");\n        request.send();\n    }\n}\n")];

    return [fence(CLOCK)];
}
