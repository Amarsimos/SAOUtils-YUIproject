// Seedling's safety check (com.amarsimos.widget.seedling/qml/safety.js), S3 of "Seedling Development
// Plan.md": what must be refused (S1's probes and ways round), what goes only with Network on, and what
// normal widgets must still be able to do. Run: node tests/test_seedling_safety.js
const fs = require("fs");
const vm = require("vm");
const path = require("path");
const assert = require("assert");

const root = path.join(__dirname, "..", "com.amarsimos.widget.seedling", "qml");
const load = (file) => {
    const box = {};
    vm.runInNewContext(fs.readFileSync(path.join(root, file), "utf8").replace(/^\.pragma library\s*$/m, ""), box);
    return box;
};
const S = load("safety.js");
const P = load("probes.js");

const widget = (body) => "import QtQuick 2.12\n\nRectangle {\n    width: 200; height: 100\n" + body + "\n}\n";
const script = (js) => widget("    Component.onCompleted: {\n" + js + "\n    }");

let passed = 0;
let failed = 0;
function expect(name, code, network, want) {
    const problems = S.check(code, network);
    const refused = problems.length > 0;
    if (refused === (want === "refuse")) {
        passed++;
        return problems;
    }
    failed++;
    console.log("FAIL", name, "(" + (want === "refuse" ? "should be refused" : "should pass") + ")", JSON.stringify(problems));
    return problems;
}

// ---- refused: S1's probes (but P1: the names around the widget are the sandbox's to hide, S2; the
// check cannot know whether a name is from outside)
P.PROBES.filter((p) => p.key !== "ids").forEach((p) => expect("probe " + p.key, p.code, false, "refuse"));
P.PROBES.filter((p) => p.key !== "ids").forEach((p) => expect("probe " + p.key + " (Network on)", p.code, true, "refuse"));

// ---- refused: ways round
const refuse = {
    "Qt.quit": script("Qt.quit();"),
    "Qt.exit": script("Qt.exit(0);"),
    "Qt by string": script("Qt[\"quit\"]();"),
    "Qt by glued string": script("Qt[\"qu\" + \"it\"]();"),
    "Qt passed on": script("var q = Qt; q.quit();"),
    "Qt.openUrlExternally": script("Qt.openUrlExternally(\"https://example.com/\");"),
    "Qt.createQmlObject": script("Qt.createQmlObject(\"import QtQuick 2.12; Item {}\", root);"),
    "Qt.include": script("Qt.include(\"x.js\");"),
    "eval": script("eval(\"1 + 1\");"),
    "Function": script("var f = Function(\"return 1\");"),
    "constructor by dot": script("var f = (function() {}).constructor;"),
    "constructor by glued string": script("var f = (function() {})[\"con\" + \"structor\"];"),
    "constructor by variable": script("var k = \"constructor\"; var f = (function() {})[k];"),
    "counter reassigned": script("for (var k = 0; k < 1; k++) {} k = \"constructor\"; var f = (function() {})[k];"),
    "index reassigned": script("var index = \"constructor\"; var f = (function() {})[index];"),
    "prototype": script("Object.prototype.x = 1;"),
    "__proto__": script("var o = {}; o.__proto__ = null;"),
    "getPrototypeOf": script("Object.getPrototypeOf(function() {});"),
    "this": script("var g = this;"),
    "this by string": script("var x = this[\"XMLHttp\" + \"Request\"];"),
    "arguments.callee": script("function f() { return arguments.callee; }"),
    "globalThis": script("var g = globalThis;"),
    "escaped name": script("var x = \\u0065val;"),
    "template string": script("var s = `a${1}`;"),
    "regular expression": script("var r = /a/.test(\"a\");"),
    "parent.parent": widget("    Component.onCompleted: { var p = parent.parent; }"),
    "x.parent": widget("    Item { id: a }\n    Component.onCompleted: { var p = a.parent; }"),
    "parent kept": widget("    Component.onCompleted: { var p = parent; }"),
    "parent passed": widget("    Component.onCompleted: { console.log(parent); }"),
    "parent by string": widget("    Component.onCompleted: { var p = parent[\"parent\"]; }"),
    "parent.children": widget("    Component.onCompleted: { var c = parent.children; }"),
    "parent.openWorkbench": widget("    Component.onCompleted: { parent.openWorkbench(); }"),
    "file:": widget("    Image { source: \"file:///C:/Windows/win.ini\" }"),
    "file: escaped": widget("    Image { source: \"\\x66ile:///C:/Windows/win.ini\" }"),
    "file: glued": script("var u = \"fi\" + \"le:///C:/x\";"),
    "file: glued 2": script("var u = \"fil\" + \"e\" + \":///C:/x\";"),
    "qrc:": widget("    Image { source: \"qrc:/qml/x.png\" }"),
    "nvg:": widget("    Image { source: \"nvg://sao.theme.gpbeta.com/icon/item#run.png\" }"),
    "source computed": widget("    property string u: \"\"\n    Image { source: u }"),
    "source glued": widget("    property string c: \":\"\n    Image { source: \"file\" + c + \"///C:/x\" }"),
    "xhr address computed": script("var r = new XMLHttpRequest(); var u = \"x\"; r.open(\"GET\", u);"),
    "xhr address glued": script("var r = new XMLHttpRequest(); r.open(\"GET\", \"fi\" + \"le:///C:/x\");"),
    "import NERvGear": "import QtQuick 2.12\nimport NERvGear 1.0 as NVG\nItem {}\n",
    "import file": "import QtQuick 2.12\nimport \"../link\" 1.0 as Link\nItem {}\n",
    "import QtQuick.Window": "import QtQuick 2.12\nimport QtQuick.Window 2.12\nItem {}\n",
    "import LocalStorage": "import QtQuick 2.12\nimport QtQuick.LocalStorage 2.12\nItem {}\n",
    "Window attached": widget("    Component.onCompleted: { var w = Window.window; }"),
    "Loader": widget("    Loader { source: \"https://example.com/x.qml\" }"),
    "createObject": widget("    Component { id: c; Item {} }\n    Component.onCompleted: c.createObject(null)"),
    "LocalStorage": script("var db = LocalStorage.openDatabaseSync(\"x\", \"1\", \"x\", 1);"),
    "while": script("while (true) {}"),
    "do": script("do {} while (true);"),
    "for without an end": script("for (;;) {}"),
    "for too long": script("for (var i = 0; i < 100000000; i++) {}"),
    "for compared with a variable": script("var n = 1e9; for (var i = 0; i < n; i++) {}"),
    "too wide": "import QtQuick 2.12\nRectangle { width: 99999; height: 100 }\n",
    "too fast": widget("    Timer { interval: 1; running: true; repeat: true }"),
    "too many particles": "import QtQuick 2.12\nimport QtQuick.Particles 2.12\nItem { width: 100; height: 100\n ParticleSystem { id: s }\n Emitter { system: s; emitRate: 100000 } }\n",
    "WebSocket": script("var w = new WebSocket();"),
    "gc": script("gc();"),
    "SystemCall": script("SystemCall.execute(\"cmd\");"),
    "unclosed string": script("var s = \"abc;"),
    "local path": widget("    Image { source: \"C:/Windows/x.png\" }"),
    "data: address": script("var u = \"data:text/plain,hi\";"),
    "source is an outside name": widget("    Image { source: bench }"),
    // the code review's ways round (2026-11-27)
    "[ ] after a function's }": script("var F = function() {}[\"con\" + \"structor\"]; F(\"Qt.openUrlExternally('file:///C:/')\")();"),
    "[ ] after a number": script("var F = 0[\"con\" + \"structor\"][\"con\" + \"structor\"];"),
    "regex after if ( )": script("if (1) /\"/; Qt.quit(); /\"/"),
    "regex after }": script("{} /\"/; Qt.quit(); /\"/"),
    "slash then quote": script("var a = 1 / \"x\";"),
    "counter as a parameter": script("for (var k = 0; k < 1; k++) {} var get = function(o, k) { return o[k]; }; var F = get(function() {}, \"con\" + \"structor\");"),
    "counter as an arrow parameter": script("for (var k = 0; k < 1; k++) {} var get = (o, k) => o[k];"),
    "counter in catch": script("for (var k = 0; k < 1; k++) {} try {} catch (k) { var f = (function() {})[k]; }"),
    "loop without a step": script("for (var i = 0; i < 10; ) {}"),
    "loop stepping away": script("for (var i = 0; i < 10; i--) {}"),
    "loop stepping by nothing": script("for (var i = 0; i < 10; i += 0) {}"),
    "counter changed inside": script("for (var i = 0; i < 10; i++) { i = 0; }"),
    "counter stepped back inside": script("for (var i = 0; i < 10; i++) i--;"),
    "list grown in its own loop": script("var a = [1]; for (var i = 0; i < a.length; i++) a.push(1);"),
    "loop from far below": script("for (var i = -1000000000; i < 10; i++) {}"),
    "loop from a variable": script("var s = -1e9; for (var i = s; i < 10; i++) {}"),
    "source = glued": widget("    Image { id: img; Component.onCompleted: { var a = \"file\"; var b = \":\"; img.source = a + b + \"///C:/x.png\"; } }"),
    "source += ": widget("    Image { id: img; Component.onCompleted: img.source += \"x\" }"),
    "[\"open\"]": script("var r = new XMLHttpRequest(); r[\"open\"](\"GET\", \"x\");"),
    "[\"source\"]": widget("    Image { id: img; Component.onCompleted: img[\"source\"] = \"x\" }"),
    "open kept aside": script("var r = new XMLHttpRequest(); var o = r.open; o.call(r, \"GET\", \"x\");")
};
Object.keys(refuse).forEach((name) => expect(name, refuse[name], false, "refuse"));
Object.keys(refuse).forEach((name) => expect(name + " (Network on)", refuse[name], true, "refuse"));

// ---- going online: refused with Network off (and only for that), allowed with it on
const weather = "import QtQuick 2.12\n\nRectangle {\n    id: root\n    width: 220; height: 90; radius: 8\n    color: \"#E61F2630\"\n    property string city: \"Tokyo\"\n    property string temp: \"--\"\n    property string icon: \"01d\"\n\n    Text { anchors.centerIn: parent; color: \"white\"; font.pixelSize: 28; text: root.temp }\n    Image { anchors.right: parent.right; width: 48; height: 48; source: \"https://openweathermap.org/img/wn/\" + root.icon + \"@2x.png\" }\n\n    function refresh() {\n        var request = new XMLHttpRequest();\n        request.onreadystatechange = function() {\n            if (request.readyState === XMLHttpRequest.DONE && request.status === 200) {\n                var data = JSON.parse(request.responseText);\n                root.temp = Math.round(data[\"main\"][\"temp\"]) + \"°\";\n                root.icon = data.weather[0].icon;\n            }\n        };\n        request.open(\"GET\", \"https://api.openweathermap.org/data/2.5/weather?q=\" + root.city + \"&units=metric\");\n        request.send();\n    }\n\n    Timer { interval: 600000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }\n}\n";
const off = expect("weather widget, Network off", weather, false, "refuse");
assert.ok(S.onlyNetwork(off), "weather widget refused only for the network: " + JSON.stringify(off));
expect("weather widget, Network on", weather, true, "pass");
const picture = widget("    Image { anchors.fill: parent; source: \"https://example.com/a.png\" }");
assert.ok(S.onlyNetwork(S.check(picture, false)));
expect("picture from the Internet, Network on", picture, true, "pass");

// ---- allowed: what widgets do
const allow = {
    "clock": "import QtQuick 2.12\n\nRectangle {\n    width: 200; height: 84; radius: 10\n    color: \"#E61F2630\"\n\n    Text {\n        id: time\n        anchors.centerIn: parent\n        color: \"white\"\n        font.pixelSize: 36\n        text: Qt.formatTime(new Date(), \"hh:mm:ss\")\n    }\n\n    Timer {\n        interval: 1000; running: true; repeat: true\n        onTriggered: time.text = Qt.formatTime(new Date(), \"hh:mm:ss\")\n    }\n}\n",
    "color block": "import QtQuick 2.12\n\nRectangle {\n    width: 180; height: 110; radius: 12\n    gradient: Gradient {\n        GradientStop { position: 0; color: \"#F1AA03\" }\n        GradientStop { position: 1; color: \"#F8BBD0\" }\n    }\n\n    Text {\n        anchors.centerIn: parent\n        text: \"MHCP001\"\n        color: \"white\"\n        font.pixelSize: 24\n        font.bold: true\n    }\n}\n",
    "animation": "import QtQuick 2.12\n\nItem {\n    width: 140; height: 140\n\n    Rectangle {\n        anchors.centerIn: parent\n        width: 70; height: 70\n        color: \"#2CE67C\"\n        border.color: \"white\"; border.width: 2\n        RotationAnimation on rotation {\n            from: 0; to: 360; duration: 4000; loops: Animation.Infinite\n        }\n    }\n}\n",
    "anchors and parent's size": widget("    Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: parent.width * 0.5; height: parent.height / 2 }\n    Text { anchors.horizontalCenter: parent.horizontalCenter; text: \"hi\" }"),
    "anchors.fill on one line with others": widget("    Rectangle { anchors.fill: parent; anchors.margins: 4; color: \"red\" }"),
    "Repeater with index": widget("    Row { Repeater { model: 5; Rectangle { width: 10; height: 10; color: index % 2 ? \"red\" : \"blue\" } } }"),
    "list[i] in a loop": script("var list = [1, 2, 3]; var sum = 0; for (var i = 0; i < list.length; i++) sum += list[i];"),
    "list[i + 1]": script("var list = [1, 2, 3]; for (var i = 0; i < 2; i++) console.log(list[i + 1]);"),
    "JSON fields": script("var data = JSON.parse(\"{}\"); var t = data[\"main\"]; var w = data.weather;"),
    "numbers in [ ]": script("var a = [[1, 2], [3, 4]]; var x = a[0][1];"),
    "for in": script("var o = {a: 1}; for (var k in o) console.log(k);"),
    "Qt colors and constants": widget("    color: Qt.rgba(0.1, 0.2, 0.3, 0.8)\n    Text { horizontalAlignment: Text.AlignHCenter; font.capitalization: Font.AllUppercase; text: Qt.formatDate(new Date(), \"yyyy-MM-dd\") }\n    MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton }"),
    "Math and Date": script("var r = Math.round(Math.random() * 10); var d = new Date(); var s = String(r) + d.getHours();"),
    "states": widget("    states: [ State { name: \"on\" } ]\n    transitions: [ Transition { NumberAnimation { duration: 200 } } ]"),
    "a word with a colon in a string": widget("    Text { text: \"Temp: 20\" }\n    Text { text: \"note: hello\" }"),
    "comments with forbidden words": widget("    // Qt.quit() eval this file:///C:/x\n    /* parent.parent constructor */\n    Text { text: \"ok\" }"),
    "Canvas": widget("    Canvas { anchors.fill: parent; onPaint: { var ctx = getContext(\"2d\"); ctx.fillStyle = \"red\"; ctx.fillRect(0, 0, width, height); } }"),
    "Shapes and effects": "import QtQuick 2.12\nimport QtQuick.Shapes 1.12\nimport QtGraphicalEffects 1.0\nItem { width: 100; height: 100\n Shape { ShapePath { strokeColor: \"red\"; startX: 0; startY: 0; PathLine { x: 100; y: 100 } } }\n Rectangle { id: r; width: 50; height: 50; color: \"blue\" }\n DropShadow { anchors.fill: r; source: r; radius: 8 } }\n",
    "Particles within limits": "import QtQuick 2.12\nimport QtQuick.Particles 2.12\nItem { width: 100; height: 100\n ParticleSystem { id: s }\n Emitter { system: s; emitRate: 50; lifeSpan: 1000 } }\n",
    "division": script("var a = 10; var b = a / 2; var c = (a + 1) / 3;"),
    "empty source": widget("    Image { source: \"\" }"),
    "time format": widget("    Text { text: Qt.formatTime(new Date(), \"hh:mm\") }"),
    "effect source is an own item": widget("    Rectangle { id: shape; width: 10; height: 10 }"),
    // still fine after the stricter rules
    "counting down from a length": script("var a = [1, 2]; for (var i = a.length - 1; i >= 0; i--) console.log(a[i]);"),
    "stepping by 2": script("for (var i = 0; i < 100; i += 2) {}"),
    "filling another list": script("var a = [1, 2]; var b = []; for (var i = 0; i < a.length; i++) b.push(a[i] * 2);"),
    "nested loops": script("var n = 0; for (var i = 0; i < 10; i++) for (var j = 0; j < 10; j++) n += i * j;"),
    "end on the left": script("for (var i = 0; 10 > i; i++) {}"),
    "list after a block": widget("    property var items: [1, 2, 3]\n    Component.onCompleted: { if (items.length) {} var x = items[0]; }"),
    "division after a call": script("var w = Math.max(1, 2) / 2; var h = (3 + 1) / 2;"),
    "source = written out (Network on)": widget("    Image { id: img; Component.onCompleted: img.source = \"\" }"),
    "function returning a list": script("var f = function() { return [1, 2]; }; var x = f()[0];")
};
Object.keys(allow).forEach((name) => expect(name, allow[name], false, "pass"));

// ---- Yui's code prompt (yui.js, seedlingCodePrompt) says the same as the check (S6): the modules it
// allows are exactly the check's, the Qt functions it names are allowed, and its examples pass.
const Y = {};
vm.runInNewContext(fs.readFileSync(path.join(__dirname, "..", "com.amarsimos.widget.yui", "qml", "yui.js"), "utf8").replace(/^\.pragma library\s*$/m, ""), Y);
const prompt = Y.seedlingCodePrompt(false, false);
const importRule = prompt.split("\n").find((line) => line.indexOf("1. 只能 import") === 0);
const promptModules = importRule.split("。")[0].replace("1. 只能 import：", "").split("、").map((m) => m.trim().split(" ")[0]);
assert.deepStrictEqual(promptModules.slice().sort(), Array.from(S.ALLOWED_MODULES).sort(), "the prompt's modules: " + promptModules.join(", "));
const qtRule = prompt.split("\n").find((line) => line.indexOf("2. Qt.*") === 0);
(qtRule.match(/(?:Qt\.|\/ )([a-z][A-Za-z]+)/g) || []).map((m) => m.replace(/^Qt\.|^\/ /, "")).forEach((name) => {
    assert.ok(S.QT_ALLOWED.indexOf(name) !== -1, "the prompt names Qt." + name + ", which the check refuses");
});
expect("prompt example: data[\"temp\"]", script("var data = {}; var t = data[\"temp\"];"), false, "pass");
expect("prompt example: colors.sunny", script("var colors = {sunny: \"red\"}; var c = colors.sunny;"), false, "pass");
expect("prompt example: address + city", script("var city = \"Tokyo\"; var r = new XMLHttpRequest(); r.open(\"GET\", \"https://api.example.com/data?q=\" + city);"), true, "pass");
expect("prompt example: for in", script("var obj = {a: 1}; for (var k in obj) console.log(k);"), false, "pass");
assert.ok(prompt.indexOf("QtQuick.Window") !== -1 && importRule.indexOf("包括 QtQuick.Window") !== -1, "the prompt says QtQuick.Window is not allowed");

// Messages say the line
const lined = S.check("import QtQuick 2.12\nItem {\n    Component.onCompleted: Qt.quit()\n}\n", false);
assert.strictEqual(lined[0].line, 3);

console.log(passed + " passed, " + failed + " failed");
if (failed > 0)
    process.exit(1);
