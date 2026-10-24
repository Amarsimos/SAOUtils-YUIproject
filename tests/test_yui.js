// Unit tests for qml/yui.js (the ".pragma library" line is stripped before evaluation).
const fs = require("fs");
const vm = require("vm");
const assert = require("assert");

const src = fs.readFileSync(process.argv[2] || require("path").join(__dirname, "..", "com.amarsimos.widget.yui", "qml", "yui.js"), "utf8").replace(/^\.pragma library\s*$/m, "");
const Yui = {};
vm.runInNewContext(src, Yui);

let passed = 0;
function test(name, fn) {
    fn();
    passed++;
    console.log("PASS", name);
}

test("parseReply strips tags and reads them", () => {
    const r = Yui.parseReply("爸爸好呀～\n今天要加油哦！ <<emotion:happy>>\n<<memory:爸爸喜欢猫>>");
    assert.strictEqual(r.text, "爸爸好呀～\n今天要加油哦！");
    assert.strictEqual(r.emotion, "happy");
    assert.deepStrictEqual(Array.from(r.memories), ["爸爸喜欢猫"]);
    assert.strictEqual(r.action, null);
});

test("parseReply accepts full-width colon and spaces, ignores unknown emotion", () => {
    const r = Yui.parseReply("嗯 << emotion ： SAD >> <<emotion:crying>>");
    assert.strictEqual(r.emotion, "sad");
    assert.strictEqual(r.text, "嗯");
});

test("open action only allows http(s) links", () => {
    assert.strictEqual(Yui.parseReply("<<open:https://www.bilibili.com>>").action.url, "https://www.bilibili.com");
    assert.strictEqual(Yui.parseReply("<<open:file:///C:/Windows/system32/cmd.exe>>").action, null);
    assert.strictEqual(Yui.parseReply("<<open:javascript:alert(1)>>").action, null);
});

test("search action builds an encoded search URL", () => {
    const a = Yui.parseReply("好的！<<search:刀剑神域 结衣>>").action;
    assert.strictEqual(a.type, "search");
    assert.strictEqual(a.url, "https://www.bing.com/search?q=" + encodeURIComponent("刀剑神域 结衣"));
});

test("displayText hides complete and half-received tags", () => {
    assert.strictEqual(Yui.displayText("你好 <<emotion:happy>>"), "你好");
    assert.strictEqual(Yui.displayText("你好 <<emot"), "你好");
    assert.strictEqual(Yui.displayText("你好 <<memory:爸爸喜"), "你好");
    assert.strictEqual(Yui.displayText("a << b"), "a");
    assert.strictEqual(Yui.displayText("普通文字"), "普通文字");
});

test("memory keywords and similarity", () => {
    assert.deepStrictEqual(Array.from(Yui.memoryKeywords("爸爸喜欢猫, likes Cats 2")), ["爸爸", "爸喜", "喜欢", "欢猫", "likes", "cats", "2"]);
    assert.strictEqual(Yui.memorySimilarity("爸爸喜欢猫", "爸爸喜欢猫和狗"), 1);
    assert.ok(Yui.memorySimilarity("爸爸喜欢猫", "爸爸喜欢狗") < Yui.SAME_MEMORY);
    assert.ok(Yui.memorySimilarity("爸爸喜欢猫", "妈妈的生日是五月") < 0.2);
});

test("rememberMemory dedupes, promotes and caps the core", () => {
    let heart = Yui.rememberMemory([], "爸爸喜欢猫", "fragment", 1);
    heart = Yui.rememberMemory(heart, "爸爸喜欢猫", "fragment", 2);
    assert.strictEqual(heart.length, 1);
    heart = Yui.rememberMemory(heart, "爸爸喜欢狗", "fragment", 3);         // a different memory
    heart = Yui.rememberMemory(heart, "爸爸喜欢狗，尤其是柴犬", "fragment", 4); // contains it: replaces it
    assert.strictEqual(heart.length, 2);
    assert.strictEqual(heart[1].text, "爸爸喜欢狗，尤其是柴犬");
    heart = Yui.rememberMemory(heart, "爸爸喜欢猫", "core", 5);              // promoted, not duplicated
    assert.strictEqual(heart.length, 2);
    assert.strictEqual(heart[0].kind, "core");
    heart[0].pinned = true;
    for (let i = 0; i < Yui.MAX_CORE + 3; i++) heart = Yui.rememberMemory(heart, "核心记忆第" + i + "条：" + "甲乙丙丁戊己庚辛壬癸".charAt(i % 10) + i, "core", 10 + i);
    const core = heart.filter(e => e.kind === "core");
    assert.strictEqual(core.length, Yui.MAX_CORE);
    assert.ok(core.some(e => e.text === "爸爸喜欢猫"));                     // pinned stays in the core
    assert.ok(heart.some(e => e.kind === "fragment" && e.text.indexOf("核心记忆第0条") === 0)); // oldest demoted
});

test("forgetMemory, coreMemories, recallFragments", () => {
    let heart = [];
    ["爸爸喜欢猫", "爸爸的生日是五月三日", "爸爸在学吉他", "爸爸讨厌下雨天"].forEach((t, i) => { heart = Yui.rememberMemory(heart, t, "fragment", i); });
    heart = Yui.rememberMemory(heart, "叫用户爸爸", "core", 9);
    const result = Yui.forgetMemory(heart, "爸爸在学吉他");
    assert.strictEqual(result.removed.length, 1);
    assert.strictEqual(result.entries.length, 4);
    assert.deepStrictEqual(Yui.coreMemories(heart).map(e => e.text), ["叫用户爸爸"]);
    assert.deepStrictEqual(Yui.recallFragments(heart, "今天下雨了好烦", 3).map(e => e.text), ["爸爸讨厌下雨天"]);
    assert.strictEqual(Yui.recallFragments(heart, "hello", 3).length, 0);
    assert.strictEqual(Yui.recallFragments(heart, "", 3).length, 0);
});

test("mergeHeart skips known memories and keeps the core limit", () => {
    let heart = Yui.rememberMemory([], "爸爸喜欢猫", "fragment", 1);
    const imported = [{ text: "爸爸喜欢猫", kind: "core" }, { text: "叫用户爸爸", kind: "core", pinned: true, created: 5 }, { text: "爸爸在学吉他", kind: "fragment" }, { text: " " }];
    let result = Yui.mergeHeart(heart, imported);
    assert.strictEqual(result.added, 2);
    assert.deepStrictEqual(result.entries.map(e => e.kind + (e.pinned ? "*" : "") + ":" + e.text), ["fragment:爸爸喜欢猫", "core*:叫用户爸爸", "fragment:爸爸在学吉他"]);
    const many = [];
    for (let i = 0; i < Yui.MAX_CORE + 2; i++) many.push({ text: "核心" + i + "号" + "甲乙丙丁戊己庚辛壬癸".charAt(i % 10), kind: "core", lastUsed: i });
    result = Yui.mergeHeart(result.entries, many);
    assert.strictEqual(Yui.coreMemories(result.entries).length, Yui.MAX_CORE);
    assert.ok(Yui.coreMemories(result.entries).some(e => e.text === "叫用户爸爸"));  // pinned stays
});

test("featureInstructions lists the core, recallContext the fragments", () => {
    const text = Yui.featureInstructions("爸爸", [{ text: "爸爸喜欢猫" }]);
    assert.ok(text.includes("<<emotion:happy>>") && text.includes("<<core:") && text.includes("<<forget:"));
    assert.ok(text.includes("- 爸爸喜欢猫"));
    assert.ok(!Yui.featureInstructions("妈妈", []).includes("心核（"));
    assert.strictEqual(Yui.recallContext("爸爸", []), "");
    assert.ok(Yui.recallContext("爸爸", [{ text: "爸爸讨厌下雨天" }]).includes("- 爸爸讨厌下雨天"));
    const reply = Yui.parseReply("好的 <<core:叫我哥哥>><<memory:喜欢猫>><<forget:学吉他>>");
    assert.deepStrictEqual([Array.from(reply.cores), Array.from(reply.memories), Array.from(reply.forgets), reply.text], [["叫我哥哥"], ["喜欢猫"], ["学吉他"], "好的"]);
});

test("formatDuration", () => {
    assert.strictEqual(Yui.formatDuration(5 * 60000), "5 分钟");
    assert.strictEqual(Yui.formatDuration(200 * 60000), "3 小时 20 分钟");
    assert.strictEqual(Yui.formatDuration(120 * 60000), "2 小时");
    assert.strictEqual(Yui.formatDuration(3 * 24 * 3600000), "3 天");
});

test("systemCall recognises commands", () => {
    assert.strictEqual(Yui.systemCall("你好", "爸爸"), null);
    const lum = Yui.systemCall("System Call, Generate Luminous Element.", "爸爸");
    assert.strictEqual(lum.effect.color, "#FFF59D");
    assert.ok(lum.reply.includes("光素"));
    assert.strictEqual(Yui.systemCall("system call discharge", "爸爸").effect.burst, true);
    assert.strictEqual(Yui.systemCall("システムコール、generate thermal element", "爸爸").effect.color, "#FF7043");
    assert.ok(Yui.systemCall("System Call, Inspect Entire Command List", "爸爸").reply.includes("Discharge"));
    assert.strictEqual(Yui.systemCall("System Call", "爸爸").effect, null);
    assert.ok(Yui.systemCall("System Call, do something", "爸爸").reply.includes("无法识别"));
});

test("wakeLine uses the title", () => {
    for (let i = 0; i < 20; i++) assert.ok(Yui.wakeLine("妈妈").includes("妈妈"));
});

test("launch action takes a program name or path, not quotes", () => {
    assert.deepStrictEqual(Object.assign({}, Yui.parseReply("好～ <<launch:notepad>>").action), { type: "launch", target: "notepad" });
    assert.strictEqual(Yui.parseReply("<<launch:C:\\Program Files\\App\\app.exe>>").action.target, "C:\\Program Files\\App\\app.exe");
    assert.strictEqual(Yui.parseReply('<<launch:cmd" /c del>>').action, null);
});

test("find action strips quotes", () => {
    const a = Yui.parseReply('<<find:"report" 2026.docx>>').action;
    assert.strictEqual(a.type, "find");
    assert.strictEqual(a.target, "report 2026.docx");
    assert.strictEqual(Yui.parseReply('<<find:"">>').action, null);
});

test("kill action normalizes names and refuses protected processes", () => {
    assert.strictEqual(Yui.parseReply("<<kill:chrome>>").action.target, "chrome.exe");
    assert.strictEqual(Yui.parseReply("<<kill:Code.exe>>").action.target, "Code.exe");
    const blocked = Yui.parseReply("好的 <<kill:explorer.exe>>");
    assert.strictEqual(blocked.action, null);
    assert.strictEqual(blocked.blocked, "explorer.exe");
    assert.strictEqual(Yui.parseReply("<<kill:SAO Utils.exe>>").blocked, "SAO Utils.exe");
    assert.strictEqual(Yui.parseReply("<<kill:a & del *>>").action, null);
    assert.strictEqual(Yui.parseReply("<<kill:a & del *>>").blocked, "");
});

test("actionCommand builds find.bat and taskkill command lines", () => {
    assert.strictEqual(Yui.actionCommand({ type: "find", target: "report" }, "C:/s/find-1.txt", "", "C:/s/find-1.status", "C:/s/find.bat"),
        'cmd /c ""C:/s/find.bat" "" "report" "C:/s/find-1.txt" "C:/s/find-1.status""');
    assert.strictEqual(Yui.actionCommand({ type: "find", target: "r" }, "f", ' "D:\\es.exe" ', "s", "b"), 'cmd /c ""b" "D:\\es.exe" "r" "f" "s""');
    assert.strictEqual(Yui.actionCommand({ type: "kill", target: "chrome.exe" }), 'taskkill /IM "chrome.exe"');
    assert.strictEqual(Yui.actionCommand({ type: "launch", target: "notepad" }), "");
});

test("parseFindStatus reads find.bat status files", () => {
    assert.strictEqual(Yui.parseFindStatus(""), null);
    assert.deepStrictEqual(Object.assign({}, Yui.parseFindStatus('code=0\r\nes="D:\\Tools\\es.exe"\r\n')), { code: "0", es: "D:\\Tools\\es.exe" });
    assert.deepStrictEqual(Object.assign({}, Yui.parseFindStatus('code=missing\r\nes=""\r\n')), { code: "missing", es: "" });
});

test("parseSearchResults drops BOM and blank lines", () => {
    assert.deepStrictEqual(Array.from(Yui.parseSearchResults("\uFEFFC:\\a.txt\r\n\r\nD:\\b.txt\r\n")), ["C:\\a.txt", "D:\\b.txt"]);
    assert.strictEqual(Yui.parseSearchResults("").length, 0);
});

test("linkify links paths, web links and Option", () => {
    assert.strictEqual(Yui.linkify("没有链接 <b>", "#00f"), "");
    const html = Yui.linkify("结果：\nD:\\SAO Utils 2\\a&b.txt\n文件在 C:/x/y.exe 里。", "#00f");
    assert.ok(html.includes('href="yui-path:' + encodeURIComponent("D:\\SAO Utils 2\\a&b.txt") + '"'));
    assert.ok(html.includes(">D:\\SAO Utils 2\\a&amp;b.txt</a>"));
    assert.ok(html.includes(">C:/x/y.exe</a> 里"));
    assert.ok(html.includes("<br>"));
    const web = Yui.linkify("去 https://www.voidtools.com/downloads/ 下载，再到「Option」里填写。", "#00f");
    assert.ok(web.includes('href="https://www.voidtools.com/downloads/"'));
    assert.ok(web.includes('href="yui-option:"'));
    assert.ok(!web.includes("yui-path"));
    assert.strictEqual(Yui.linkedPath('yui-path:' + encodeURIComponent("C:/x/y.exe")), "C:\\x\\y.exe");
    assert.strictEqual(Yui.linkedPath("https://a.com"), "");
});

test("process lists: clean, match, user protected", () => {
    assert.deepStrictEqual(Array.from(Yui.processList(["Notepad", "notepad.exe", "bad\"name", "Code.exe"])), ["notepad.exe", "code.exe"]);
    assert.ok(Yui.processListHas(["notepad.exe"], "NOTEPAD"));
    assert.ok(!Yui.processListHas(undefined, "notepad"));
    assert.ok(Yui.isProtectedProcess("explorer.exe"));
    assert.ok(Yui.isProtectedProcess("qq.exe", ["QQ"]));
    assert.strictEqual(Yui.parseReply("好 <<kill:qq>>", ["qq.exe"]).blocked, "qq.exe");
    assert.strictEqual(Yui.parseReply("好 <<kill:qq>>").action.target, "qq.exe");
});

test("load thresholds: defaults, custom, hysteresis, hold", () => {
    assert.deepStrictEqual(Array.from(Yui.loadThresholds(null, "gpu")), [85, 97]);
    assert.deepStrictEqual(Array.from(Yui.loadThresholds({ cpu: [60, 80] }, "cpu")), [60, 80]);
    assert.deepStrictEqual(Array.from(Yui.loadThresholds({ cpu: [90, 80] }, "cpu")), [70, 90]);
    const pair = [70, 90];
    assert.strictEqual(Yui.loadLevel(NaN, pair, 0), 0);
    assert.strictEqual(Yui.loadLevel(75, pair, 0), 1);
    assert.strictEqual(Yui.loadLevel(95, pair, 0), 2);
    assert.strictEqual(Yui.loadLevel(87, pair, 2), 2);   // within 5 of the red threshold: stays red
    assert.strictEqual(Yui.loadLevel(84, pair, 2), 1);
    assert.strictEqual(Yui.loadLevel(66, pair, 1), 1);
    assert.strictEqual(Yui.loadLevel(64, pair, 1), 0);
    let state;
    for (let i = 0; i < 4; i++) state = Yui.loadStep(state, 95, pair);
    assert.strictEqual(state.level, 0);                  // a 4 s peak does not change the color
    state = Yui.loadStep(state, 95, pair);
    assert.strictEqual(state.level, 2);                  // after 5 s it does
    state = Yui.loadStep(state, 50, pair);
    assert.strictEqual(state.level, 2);
    state = Yui.loadStep(state, 95, pair);               // the drop was interrupted: hold restarts
    for (let i = 0; i < 4; i++) state = Yui.loadStep(state, 50, pair);
    assert.strictEqual(state.level, 2);
    state = Yui.loadStep(state, 50, pair);
    assert.strictEqual(state.level, 0);
});

test("seedlingPresetFiles writes preset.json and settings.xml", () => {
    const files = Yui.seedlingPresetFiles("时钟 <1>", 'import QtQuick 2.12\nText { text: "a<b" }', 220.4, 90, "2026-10-19T00:00:00.000Z");
    const preset = JSON.parse(files.preset);
    assert.strictEqual(preset.source, "nvg://yui.widget.amarsimos.com/widget/mhcp-yui");
    assert.strictEqual(preset.title, "时钟 <1>");
    assert.strictEqual(preset.settings, "settings.xml");
    assert.ok(files.settings.startsWith('<?xml version="1.0" encoding="UTF-8"?>\n<map>'));
    assert.ok(files.settings.includes('<value name="seedling_width">220</value>'));
    assert.ok(files.settings.includes('<value name="seedling_widget">true</value>'));
    const stored = /<value name="seedling_code_uri">(.*)<\/value>/.exec(files.settings)[1];
    assert.ok(!/[<>\\\n]/.test(stored));
    const uri = JSON.parse(stored.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&"));
    assert.strictEqual(Yui.seedlingCode({ seedling_code_uri: uri }), 'import QtQuick 2.12\nText { text: "a<b" }');
    assert.strictEqual(Yui.seedlingCode({ seedling_code: "old" }), "old");
    assert.strictEqual(Yui.seedlingCode(null), "");
});

test("feature instructions mention desktop actions", () => {
    const text = Yui.featureInstructions("爸爸", []);
    assert.ok(text.includes("<<launch:") && text.includes("<<find:") && text.includes("<<kill:"));
});

test("migrateSeedlingKeys moves lab_* to seedling_*", () => {
    const settings = { lab_widget: true, lab_code_uri: "a%0Ab", seedling_title: "new", lab_title: "old", other: 1 };
    assert.strictEqual(Yui.migrateSeedlingKeys(settings), true);
    assert.deepStrictEqual(settings, { seedling_widget: true, seedling_code_uri: "a%0Ab", seedling_title: "new", other: 1 });
    assert.strictEqual(Yui.seedlingCode(settings), "a\nb");
    assert.strictEqual(Yui.migrateSeedlingKeys(settings), false);
});

test("forbidden actions are dropped and not explained", () => {
    const reply = Yui.parseReply("好 <<kill:chrome>> <<launch:notepad>> <<search:cats>>", [], { allowed: { kill: false, web: false }, searchEngine: "baidu" });
    assert.strictEqual(reply.text, "好");
    assert.strictEqual(reply.disabled, "kill");
    assert.strictEqual(reply.action.type, "launch");
    const text = Yui.featureInstructions("爸爸", [], { web: false, kill: false });
    assert.ok(!text.includes("<<open:") && !text.includes("<<kill:") && text.includes("<<launch:"));
    assert.strictEqual(Yui.searchUrl("baidu", "", "a b"), "https://www.baidu.com/s?wd=a%20b");
});

test("heart core capacity and Auto Memory", () => {
    let entries = [];
    for (let i = 0; i < 4; i++)
        entries = Yui.rememberMemory(entries, "第" + "一二三四"[i] + "件很重要的事情 " + i, "core", i, 3);
    assert.strictEqual(Yui.coreMemories(entries).length, 3);
    assert.strictEqual(entries.filter(e => e.kind === "fragment")[0].created, 0);
    Yui.fitCore(entries, 1);
    assert.strictEqual(Yui.coreMemories(entries).length, 1);
    const reply = Yui.parseReply("好 <<memory:喜欢猫>> <<core:叫我爸爸>> <<forget:x>> <<emotion:happy>>", [], { allowed: { memory: false } });
    assert.strictEqual(reply.memories.length + reply.cores.length + reply.forgets.length, 0);
    assert.strictEqual(reply.emotion, "happy");
    assert.ok(!Yui.featureInstructions("爸爸", [], { memory: false }).includes("<<memory:"));
    assert.ok(Yui.featureInstructions("爸爸", []).includes("<<memory:"));
});

const same = (a, b) => assert.strictEqual(JSON.stringify(a), JSON.stringify(b));

test("tool definitions follow the switches", () => {
    same(Yui.toolDefinitions({}).map(t => t.name), ["open_url", "web_search", "launch_program", "find_file", "close_program"]);
    same(Yui.toolDefinitions({}, true).map(t => t.name), ["open_url", "web_search", "launch_program", "find_file", "close_program", "remember", "forget"]);
    same(Yui.toolDefinitions({ web: false, kill: false, memory: false }).map(t => t.name), ["launch_program", "find_file"]);
    assert.strictEqual(Yui.toolDefinitions({})[0].parameters.required[0], "url");
});

test("tool calls become the same actions as tags", () => {
    const tag = Yui.parseReply("<<kill:notepad>>", []).action;
    const tool = Yui.toolCallToAction("close_program", '{"process":"notepad"}', []);
    same(tool, { kind: "action", action: tag });
    same(Yui.toolCallToAction("close_program", { process: "explorer.exe" }, []), { kind: "blocked", blocked: "explorer.exe" });
    assert.strictEqual(Yui.toolCallToAction("open_url", { url: "file:///c:/x" }, []).kind, "error");
    assert.strictEqual(Yui.toolCallToAction("web_search", { query: "天气" }, [], { searchEngine: "baidu" }).action.url, "https://www.baidu.com/s?wd=%E5%A4%A9%E6%B0%94");
    same(Yui.toolCallToAction("remember", '{"text":"喜欢猫","core":true}', []), { kind: "remember", text: "喜欢猫", core: true });
    assert.strictEqual(Yui.toolCallToAction("forget", { text: "猫" }, [], { allowed: { memory: false } }).kind, "error");
    assert.strictEqual(Yui.toolCallToAction("launch_program", "{bad json", []).kind, "error");
    assert.strictEqual(Yui.toolCallToAction("navigation", {}, []).kind, "error");
});

test("tools mode instructions and the emotion guess", () => {
    const tools = Yui.featureInstructions("爸爸", [], {}, "tools");
    assert.ok(tools.includes("<<emotion:") && tools.includes("<<memory:") && tools.includes("启动程序"));
    assert.ok(!tools.includes("<<launch:") && !tools.includes("<<open:") && !tools.includes("remember"));
    assert.ok(!Yui.featureInstructions("爸爸", [], { memory: false }, "tools").includes("<<memory:"));
    assert.strictEqual(Yui.guessEmotion("呜呜，结衣好难过 (T_T)"), "sad");
    assert.strictEqual(Yui.guessEmotion("太好了！(≧◡≦)"), "happy");
    assert.strictEqual(Yui.guessEmotion("咦？真的吗！？"), "surprised");
    assert.strictEqual(Yui.guessEmotion("1+1 等于 2。"), "normal");
});

test("priority rules and the small model reminder", () => {
    const tools = Yui.priorityRules("爸爸", {}, "tools");
    assert.ok(tools.startsWith("【最重要的规则】") && tools.includes("必须调用提供的工具") && tools.includes("记住、忘记事情时，必须在回复里写对应的标签") && tools.includes("必须搜索"));
    const tags = Yui.priorityRules("爸爸", { web: false }, "tags");
    assert.ok(tags.includes("写对应的标签") && !tags.includes("必须搜索") && !tags.includes("打开网页"));
    const none = Yui.priorityRules("爸爸", { web: false, launch: false, find: false, kill: false, memory: false }, "tools");
    assert.ok(!none.includes("2."));
    assert.ok(Yui.smallModelReminder("tags", {}).includes("写对应的标签"));
});

test("misspelled and full-width tags are hidden", () => {
    const r = Yui.parseReply("好开心呀～ <<emphy:happy>>", []);
    assert.strictEqual(r.text, "好开心呀～");
    assert.strictEqual(r.emotion, "happy");
    assert.strictEqual(r.unknown.length, 1);
    const w = Yui.parseReply("嗯嗯 《《emotion：sad》》 <<navigation:weather>>", []);
    assert.strictEqual(w.text, "嗯嗯");
    assert.strictEqual(w.emotion, "sad");
    assert.strictEqual(Yui.parseReply("<<emotion:shy>> <<emphy:happy>>", []).emotion, "shy");
    assert.strictEqual(Yui.displayText("好的 <<emphy:happy>>"), "好的");
});

test("light markdown in messages", () => {
    assert.strictEqual(Yui.linkify("普通的一句话", "#00f"), "");
    const b = Yui.linkify("这是**重点**哦", "#00f");
    assert.ok(b.includes("<b>重点</b>") && !b.includes("**"));
    const l = Yui.linkify("清单：\n- 牛奶\n* 面包", "#00f");
    assert.ok(l.includes("・牛奶") && l.includes("・面包") && l.includes("<br>"));
    const h = Yui.linkify("## 今天的计划\n起床", "#00f");
    assert.ok(h.includes("<b>今天的计划</b>") && !h.includes("#"));
    const c = Yui.linkify("代码：\n```qml\nText { text: \"<a>\" }\n```\n好了", "#00f");
    assert.ok(c.includes("<pre") && c.includes("&lt;a&gt;") && !c.includes("```"));
    const i = Yui.linkify("用 `notepad` 打开", "#00f");
    assert.ok(i.includes("Consolas") && i.includes("notepad"));
    const k = Yui.linkify("看 https://a.com/x 和 **它**", "#00f");
    assert.ok(k.includes('href="https://a.com/x"') && k.includes("<b>它</b>"));
    assert.strictEqual(Yui.linkify("1 * 2 * 3 = 6", "#00f"), "");
});

test("settings differ from their defaults", () => {
    assert.strictEqual(Yui.anyChanged([{ value: 3, defaultValue: 3 }, { value: "a", defaultValue: "a" }]), false);
    assert.strictEqual(Yui.anyChanged([{ value: 3, defaultValue: 3 }, { value: true, defaultValue: false }]), true);
    assert.strictEqual(Yui.anyChanged([null, undefined]), false);
    const font = (o) => Object.assign({ family: "Source Han Sans SC", pixelSize: 14, pointSize: -1, weight: 50, italic: false, underline: false, strikeout: false }, o);
    assert.strictEqual(Yui.preferenceChanged({ value: font({}), defaultValue: font({}) }), false);
    assert.strictEqual(Yui.preferenceChanged({ value: font({ pixelSize: -1, pointSize: 10.5 }), defaultValue: font({}) }), false);
    assert.strictEqual(Yui.preferenceChanged({ value: font({ weight: 75 }), defaultValue: font({}) }), true);
    assert.strictEqual(Yui.preferenceChanged({ value: font({ family: "Arial" }), defaultValue: font({}) }), true);
});

test("more system calls", () => {
    const armament = Yui.systemCall("System Call, Enhance Armament!", "爸爸");
    assert.strictEqual(armament.effect.aura, true);
    const recollection = Yui.systemCall("system call release recollection", "爸爸");
    assert.ok(recollection.effect.burst && recollection.effect.shake);
    const durability = Yui.systemCall("System Call, Transfer Durability", "爸爸", { cpu: 41.6, gpu: NaN, ram: 70 });
    assert.ok(durability.reply.includes("CPU 42%") && durability.reply.includes("内存 70%") && !durability.reply.includes("GPU"));
    assert.ok(!Yui.systemCall("System Call, Transfer Durability", "爸爸").reply.includes("消耗"));
    assert.ok(Yui.systemCall("System Call, Inspect Entire Command List", "爸爸").reply.includes("Release Recollection"));
});

test("login greeting kinds", () => {
    const at = (d, h, m) => new Date(2026, 9, d, h, m || 0).getTime();
    assert.strictEqual(Yui.greetingKind(0, at(24, 9)), "");
    assert.strictEqual(Yui.greetingKind(at(24, 8, 50), at(24, 9)), "");
    assert.strictEqual(Yui.greetingKind(at(23, 23), at(24, 8)), "morning");
    assert.strictEqual(Yui.greetingKind(at(24, 6), at(24, 9)), "back");
    assert.strictEqual(Yui.greetingKind(at(23, 23), at(24, 14)), "back");
    assert.strictEqual(Yui.greetingKind(at(20, 9), at(24, 9)), "long");
});

test("recollection log lines", () => {
    const created = new Date(2026, 9, 24, 21, 5).getTime();
    assert.strictEqual(Yui.logLine({ author: "user", message: "你好", created }, "爸爸"), "2026-10-24 21:05  爸爸: 你好");
    assert.strictEqual(Yui.logLine({ author: "ai", message: "a\nb", created }, "爸爸"), "2026-10-24 21:05  结衣: a\n                   b");
});

test("Boss Raid focus tag", () => {
    assert.strictEqual(Yui.parseReply("好的～ <<focus:45>>").focus, 45);
    assert.strictEqual(Yui.parseReply("好的～ <<focus:45>>").text, "好的～");
    assert.strictEqual(Yui.parseReply("<<focus:stop>>").focus, 0);
    assert.strictEqual(Yui.parseReply("<<focus:一会儿>>").focus, -1);
    assert.strictEqual(Yui.parseReply("<<focus:999>>").focus, 180);
    assert.strictEqual(Yui.parseReply("没有标签").focus, null);
});

test("Col Ledger usage", () => {
    assert.strictEqual(JSON.stringify(Yui.usageOf("openai", { usage: { prompt_tokens: 120, completion_tokens: 30 } })), JSON.stringify({ input: 120, output: 30 }));
    assert.strictEqual(Yui.usageOf("openai", { choices: [] }), null);
    let total = Yui.mergeUsage(null, Yui.usageOf("anthropic", { type: "message_start", message: { usage: { input_tokens: 500, output_tokens: 1 } } }));
    total = Yui.mergeUsage(total, Yui.usageOf("anthropic", { type: "message_delta", usage: { output_tokens: 42 } }));
    assert.strictEqual(JSON.stringify(total), JSON.stringify({ input: 500, output: 42 }));
    total = Yui.mergeUsage(null, Yui.usageOf("gemini", { usageMetadata: { promptTokenCount: 80, candidatesTokenCount: 5 } }));
    total = Yui.mergeUsage(total, Yui.usageOf("gemini", { usageMetadata: { promptTokenCount: 80, candidatesTokenCount: 20 } }));
    assert.strictEqual(JSON.stringify(total), JSON.stringify({ input: 80, output: 20 }));
    const oct = new Date(2026, 9, 24).getTime(), nov = new Date(2026, 10, 1).getTime();
    let ledger = Yui.addToLedger(null, { input: 100, output: 10 }, oct);
    ledger = Yui.addToLedger(Object.assign(ledger, { warned: true }), { input: 50, output: 5 }, oct);
    assert.strictEqual(JSON.stringify(ledger), JSON.stringify({ month: "2026-10", input: 150, output: 15, requests: 2, warned: true }));
    assert.strictEqual(JSON.stringify(Yui.addToLedger(ledger, { input: 1, output: 1 }, nov)), JSON.stringify({ month: "2026-11", input: 1, output: 1, requests: 1, warned: false }));
});

test("Mental Record mood tag and context", () => {
    assert.strictEqual(JSON.stringify(Yui.parseReply("太好了！<<mood:4|考试通过了>>").mood), JSON.stringify({ score: 4, note: "考试通过了" }));
    assert.strictEqual(JSON.stringify(Yui.moodFrom("9")), JSON.stringify({ score: 5, note: "" }));
    assert.strictEqual(Yui.moodFrom("开心"), null);
    assert.strictEqual(Yui.parseReply("<<mood:3>>好的").text, "好的");
    assert.ok(Yui.moodContext("爸爸", false, []).includes("今天还没问过"));
    assert.ok(Yui.moodContext("爸爸", true, []).includes("已经记下"));
    const low = [{ day: "2026-10-22", score: 2, note: "" }, { day: "2026-10-23", score: 1, note: "加班" }, { day: "2026-10-24", score: 2, note: "" }];
    assert.ok(Yui.moodContext("爸爸", true, low).includes("10-23 1/5 加班"));
    assert.ok(!Yui.moodContext("爸爸", true, low.slice(1)).includes("不太好"));
});

test("Bond birthday and anniversary", () => {
    const birthday = Yui.bondContext("爸爸", "10-24", "", "2026-10-24", "");
    assert.ok(birthday.includes("10 月 24 日") && birthday.includes("请在这次回复里"));
    assert.ok(Yui.bondContext("爸爸", "2000-10-24", "2024-10-24", "2026-10-24", "").includes("2 周年"));
    const done = Yui.bondContext("爸爸", "10-24", "", "2026-10-24", "2026-10-24");
    assert.ok(done.includes("10 月 24 日") && done.includes("已经祝贺过") && !done.includes("请在这次回复里"));
    assert.ok(!Yui.bondContext("爸爸", "", "2026-10-24", "2026-10-24", "").includes("周年"));
    const other = Yui.bondContext("爸爸", "05-01", "2025-03-02", "2026-10-24", "");
    assert.ok(other.includes("5 月 1 日") && other.includes("2025 年 3 月 2 日") && !other.includes("今天"));
    assert.strictEqual(Yui.bondContext("爸爸", "生日", "", "2026-10-24", ""), "");
});

test("Closing programs is left to the confirmation", () => {
    const text = Yui.featureInstructions("爸爸", "", {}, "tags");
    assert.ok(text.includes("Taskmgr.exe") && text.includes("不要自己判断危险"));
});

test("Core Tuning fields per server", () => {
    const none = { maxTokens: 0, temperature: -1, topP: -1, presencePenalty: -1, frequencyPenalty: -1, topK: 0, seed: 0, contextWindow: 0, thinking: "default" };
    assert.strictEqual(JSON.stringify(Yui.tuningFields("openai", "deepseek", none)), "{}");
    assert.strictEqual(JSON.stringify(Yui.tuningFields("gemini", "google", none)), "{}");
    assert.strictEqual(JSON.stringify(Yui.tuningFields("anthropic", "anthropic", none)), JSON.stringify({ max_tokens: 1024 }));
    const all = Object.assign({}, none, { maxTokens: 800, temperature: 0.7, topP: 0.9, presencePenalty: 0.5, frequencyPenalty: 0.3, topK: 40, seed: 7, contextWindow: 8192, thinking: "low" });
    assert.strictEqual(JSON.stringify(Yui.tuningFields("openai", "openai", all)), JSON.stringify({ max_completion_tokens: 800, reasoning_effort: "low", temperature: 0.7, top_p: 0.9, presence_penalty: 0.5, frequency_penalty: 0.3, seed: 7 }));
    const ollama = Yui.tuningFields("openai", "custom", Object.assign({}, all, { thinking: "off" }));
    assert.strictEqual(ollama.reasoning_effort, "none");
    assert.strictEqual(ollama.top_k, 40);
    assert.strictEqual(JSON.stringify(ollama.options), JSON.stringify({ num_ctx: 8192 }));
    assert.strictEqual(JSON.stringify(Yui.tuningFields("anthropic", "anthropic", all)), JSON.stringify({ max_tokens: 1824, thinking: { type: "enabled", budget_tokens: 1024 } }));
    assert.strictEqual(Yui.tuningFields("anthropic", "anthropic", Object.assign({}, all, { temperature: 1.5, thinking: "default" })).temperature, 1);
    const gemini = Yui.tuningFields("gemini", "google", Object.assign({}, all, { thinking: "off" }));
    assert.strictEqual(gemini.thinkingConfig.thinkingBudget, 0);
    assert.strictEqual(gemini.topK, 40);
    assert.ok(!("num_ctx" in gemini));
});

console.log(passed + " tests passed");
