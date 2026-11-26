// Seedling's @setting / @keep / @name (com.amarsimos.widget.seedling/qml/props.js), section 9 of
// "Seedling Development Plan.md": what is read, what does not take effect (and says why), how values
// are made to fit, and what stays when the code changes. Run: node tests/test_seedling_props.js
const fs = require("fs");
const vm = require("vm");
const path = require("path");
const assert = require("assert");

const box = { console };
vm.runInNewContext(fs.readFileSync(path.join(__dirname, "..", "com.amarsimos.widget.seedling", "qml", "props.js"), "utf8").replace(/^\.pragma library\s*$/m, ""), box);
const P = box;
const S = {};
vm.runInNewContext(fs.readFileSync(path.join(__dirname, "..", "com.amarsimos.widget.seedling", "qml", "safety.js"), "utf8").replace(/^\.pragma library\s*$/m, ""), S);

let passed = 0;
let failed = 0;
function test(name, fn) {
    try {
        fn();
        passed++;
    } catch (e) {
        failed++;
        console.log("FAIL", name, "-", e.message);
    }
}
const plain = (x) => JSON.parse(JSON.stringify(x));

const todo = `import QtQuick 2.12

// @name 待办
Rectangle {
    id: root
    width: 240; height: 200
    // @setting 字号 | 12 - 48
    property int fontSize: 16
    // @setting 主题 | 浅色 / 深色 / 跟随时间
    property string theme: "浅色"
    //@setting: 文字颜色
    property color textColor: "white"
    // @setting 显示完成的 ：
    property bool showDone: true
    // @setting 透明度 | 0.2~1
    property real level: 0.8
    // @keep
    property var todos: []
    // @keep
    property int count: 0

    Text {
        // @setting 子项里的
        property string inner: "x"
        text: root.todos.length + " · " + root.count
    }
}
`;

test("reads the name, settings and keeps", () => {
    const r = P.parse(todo);
    assert.strictEqual(r.name, "待办");
    assert.deepStrictEqual(plain(r.settings.map((s) => s.name)), ["fontSize", "theme", "textColor", "showDone", "level"]);
    assert.deepStrictEqual(plain(r.keeps.map((k) => k.name + ":" + k.type)), ["todos:var", "count:int"]);
});

test("ranges, choices and labels", () => {
    const r = P.parse(todo);
    const by = (n) => r.settings.find((s) => s.name === n);
    assert.strictEqual(by("fontSize").label, "字号");
    assert.strictEqual(by("fontSize").min, 12);
    assert.strictEqual(by("fontSize").max, 48);
    assert.deepStrictEqual(plain(by("theme").choices), ["浅色", "深色", "跟随时间"]);
    assert.strictEqual(by("textColor").label, "文字颜色");
    assert.strictEqual(by("level").min, 0.2);
    assert.strictEqual(by("level").max, 1);
    assert.strictEqual(by("level").type, "real");
});

test("a property inside a child item does not count, and says so", () => {
    const r = P.parse(todo);
    assert.ok(!r.settings.some((s) => s.name === "inner"));
    assert.ok(r.notes.some((n) => /inner: only properties of the outermost item/.test(n.message)), JSON.stringify(r.notes));
});

test("what does not take effect: no property next, wrong types, addresses, readonly, twice", () => {
    const code = `import QtQuick 2.12
Item {
    // @setting 没有属性

    Rectangle {}
    // @setting 列表
    property var list: []
    // @keep
    property color c: "red"
    // @setting 图片
    property url pic: ""
    // @setting 来源
    property string source: ""
    // @setting 只读
    readonly property int r: 1
    // @setting 一
    property int a: 1
    // @setting 二
    property int a2: 1
    // @keep
    property int k: 0
    // @keep
    property int k: 0
    // @setting 选项不对 | 甲 / 乙
    property int b: 1
}
`;
    const r = P.parse(code);
    const says = (re) => assert.ok(r.notes.some((n) => re.test(n.message)), re + " in " + JSON.stringify(r.notes));
    says(/the next line must be a property/);
    says(/list: a setting is a string/);
    says(/c: kept values are/);
    says(/pic: addresses/);
    says(/source: addresses/);
    says(/r: a readonly/);
    says(/k: declared twice/);
    says(/b: choices are for a string/);
    assert.deepStrictEqual(plain(r.settings.map((s) => s.name)), ["a", "a2", "b"]);
    assert.deepStrictEqual(plain(r.keeps.map((k) => k.name)), ["k"]);
});

test("braces in strings and comments do not change the depth", () => {
    const code = `import QtQuick 2.12
Item {
    property string s: "{ { {"
    // a } comment {
    /* } */
    // @setting 名字
    property string who: "x"
}
`;
    const r = P.parse(code);
    assert.deepStrictEqual(plain(r.settings.map((s) => s.name)), ["who"]);
    assert.strictEqual(r.notes.length, 0);
});

test("limits: at most 20 settings", () => {
    let body = "";
    for (let i = 0; i < 22; i++)
        body += `    // @setting s${i}\n    property int s${i}: 0\n`;
    const r = P.parse("import QtQuick 2.12\nItem {\n" + body + "}\n");
    assert.strictEqual(r.settings.length, 20);
    assert.strictEqual(r.notes.filter((n) => /more than 20/.test(n.message)).length, 2);
});

test("coerce: numbers clamped and rounded, choices, colors, bools, strings cut", () => {
    const int = { type: "int", min: 12, max: 48 };
    assert.strictEqual(P.coerce(int, "30.6").value, 31);
    assert.strictEqual(P.coerce(int, 100).value, 48);
    assert.strictEqual(P.coerce(int, "x").ok, false);
    assert.strictEqual(P.coerce({ type: "real", min: null, max: null }, 1.5).value, 1.5);
    const choice = { type: "string", choices: ["A", "B"] };
    assert.strictEqual(P.coerce(choice, "B").value, "B");
    assert.strictEqual(P.coerce(choice, "C").ok, false);
    assert.strictEqual(P.coerce({ type: "color" }, "#FF0000").ok, true);
    assert.strictEqual(P.coerce({ type: "color" }, "#80FF0000").ok, true);
    assert.strictEqual(P.coerce({ type: "color" }, "red").ok, true);
    assert.strictEqual(P.coerce({ type: "color" }, "javascript:x").ok, false);
    assert.strictEqual(P.coerce({ type: "color" }, "#12").ok, false);
    assert.strictEqual(P.coerce({ type: "bool" }, "true").value, true);
    assert.strictEqual(P.coerce({ type: "bool" }, 1).value, false);
    assert.strictEqual(P.coerce({ type: "string" }, "x".repeat(900)).value.length, 500);
    assert.strictEqual(P.coerce({ type: "string" }, null).ok, false);
});

test("coerce: var keeps only JSON", () => {
    const v = P.coerce({ type: "var" }, [{ text: "a", done: false }, 3, "x", null]);
    assert.deepStrictEqual(plain(v.value), [{ text: "a", done: false }, 3, "x", null]);
    assert.deepStrictEqual(plain(P.coerce({ type: "var" }, { f: function() {} , n: 1 }).value), { n: 1 });
    assert.strictEqual(P.coerce({ type: "var" }, function() {}).ok, false);
});

test("carry: same name and type stay, the rest is dropped", () => {
    const stored = { fontSize: { t: "int", v: 30 }, theme: { t: "string", v: "深色" }, gone: { t: "int", v: 1 }, level: { t: "int", v: 1 } };
    const r = P.parse(todo);
    const kept = P.carry(stored, r.settings);
    assert.deepStrictEqual(Object.keys(kept).sort(), ["fontSize", "theme"]);
    // A choice no longer offered is dropped.
    const changed = P.parse(todo.replace("浅色 / 深色 / 跟随时间", "浅色 / 跟随时间"));
    assert.deepStrictEqual(Object.keys(P.carry(stored, changed.settings)), ["fontSize"]);
});

test("snapshot and apply: a round trip, and nothing saved over 64 KB", () => {
    const keeps = [{ name: "todos", type: "var" }, { name: "count", type: "int" }];
    const item = { todos: [{ text: "milk" }], count: 2 };
    const snap = P.snapshot(item, keeps);
    const other = { todos: [], count: 0 };
    assert.strictEqual(P.apply(other, keeps, snap), 2);
    assert.deepStrictEqual(plain(other), { todos: [{ text: "milk" }], count: 2 });
    // push changes the same array: the next snapshot sees it (Seedling compares every 2 s).
    item.todos.push({ text: "eggs" });
    assert.strictEqual(P.snapshot(item, keeps).todos.v.length, 2);
    assert.strictEqual(P.snapshot({ todos: ["x".repeat(70000)], count: 0 }, keeps), null);
});

test("declarations are only comments: the safety check is the same with or without them", () => {
    assert.deepStrictEqual(plain(S.check(todo, false)), []);
    const bare = todo.split("\n").filter((l) => !/^\s*\/\/\s*@/.test(l)).join("\n");
    assert.deepStrictEqual(plain(S.check(bare, false)), []);
});

test("Yui's code prompt (rule 14) says the same as props.js: its examples are read", () => {
    const Y = {};
    vm.runInNewContext(fs.readFileSync(path.join(__dirname, "..", "com.amarsimos.widget.yui", "qml", "yui.js"), "utf8").replace(/^\.pragma library\s*$/m, ""), Y);
    const rule = Y.seedlingCodePrompt(false, false).split("\n").find((l) => l.indexOf("14. ") === 0);
    assert.ok(rule, "rule 14 is in the prompt");
    const r = P.parse(`import QtQuick 2.12
// @name 天气
Item {
    // @setting 字号 | 12 - 48
    property int fontSize: 16
    // @setting 主题 | 浅色 / 深色
    property string theme: "浅色"
    // @keep
    property var todos: []
}
`);
    assert.strictEqual(r.notes.length, 0);
    assert.strictEqual(r.name, "天气");
    ["string", "int", "real", "bool", "color"].forEach((t) => assert.ok(rule.indexOf(t) !== -1 && P.SETTING_TYPES.indexOf(t) !== -1, t));
    ["// @setting 字号 | 12 - 48", "// @setting 主题 | 浅色 / 深色", "// @keep", "// @name"].forEach((x) => assert.ok(rule.indexOf(x) !== -1, x));
});

console.log(passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
