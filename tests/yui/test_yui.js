// Unit tests for qml/yui.js (the ".pragma library" line is stripped before evaluation).
const fs = require("fs");
const vm = require("vm");
const assert = require("assert");

const src = fs.readFileSync(process.argv[2] || require("path").join(__dirname, "..", "..", "com.amarsimos.widget.yui", "qml", "yui.js"), "utf8").replace(/^\.pragma library\s*$/m, "");
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

test("feature instructions mention desktop actions", () => {
    const text = Yui.featureInstructions("爸爸", []);
    assert.ok(text.includes("<<launch:") && text.includes("<<find:") && text.includes("<<kill:"));
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
    assert.strictEqual(Yui.toolCallToAction("remember", '{"text":"喜欢猫"}', []).kind, "error");
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
    assert.ok(!Yui.parseReply("（系统生成）你好", []).text.includes("系统生成"), "the mark copied by the model is dropped");
    assert.strictEqual(Yui.historyContent("早安", true), "（系统生成）早安");
    assert.strictEqual(Yui.historyContent("早安", false), "早安");
    assert.strictEqual(Yui.titleOf("mama") + Yui.titleOf("papa") + Yui.titleOf(undefined), "妈妈爸爸爸爸");
    assert.strictEqual(Yui.withTitle("{t}和{{user_title}}", "妈妈"), "妈妈和妈妈");
    assert.ok(!/[他她]/.test(Yui.featureInstructions("妈妈", [], {}, "tags").replace(/其他/g, "")), "no 他 / 她, the title");
    assert.strictEqual(Yui.priorityRules("爸爸", {}, "text"), "", "a text-only request (weekly report, portrait) has no tag rules");
    const tools = Yui.priorityRules("爸爸", {}, "tools");
    assert.ok(tools.startsWith("【最重要的规则】") && tools.includes("必须调用提供的工具") && tools.includes("记住、忘记事情时，必须在回复里写对应的标签") && tools.includes("必须搜索"));
    const tags = Yui.priorityRules("爸爸", { web: false }, "tags");
    assert.ok(tags.includes("写对应的标签") && !tags.includes("必须搜索") && !tags.includes("打开网页"));
    const none = Yui.priorityRules("爸爸", { web: false, launch: false, find: false, kill: false, memory: false }, "tools");
    assert.ok(none.includes("2. 结衣不能操作电脑") && !none.includes("3."));
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
    assert.strictEqual(Yui.greetingKind(at(22, 8), at(24, 9)), "long");
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
    assert.ok(Yui.moodAsks("爸爸", false, [])[0].includes("今天还没问过"));
    assert.ok(Yui.moodAsks("爸爸", true, [])[0].includes("明显变化"));
    const low = [{ day: "2026-10-22", score: 2, note: "" }, { day: "2026-10-23", score: 1, note: "加班" }, { day: "2026-10-24", score: 2, note: "" }];
    assert.ok(Yui.moodAsks("爸爸", true, low)[1].includes("10-23 1/5 加班"));
    assert.strictEqual(Yui.moodAsks("爸爸", true, low.slice(1)).length, 1);
});

test("Bond birthday and anniversary", () => {
    assert.ok(Yui.bondFacts("爸爸", "10-24", "").includes("10 月 24 日"));
    same(Yui.bondDays("爸爸", "10-24", "", "2026-10-24"), ["今天是爸爸的生日"]);
    same(Yui.bondDays("爸爸", "2000-10-24", "2024-10-24", "2026-10-24"), ["今天是爸爸的生日", "今天是相遇 2 周年的纪念日"]);
    same(Yui.bondDays("爸爸", "", "2026-10-24", "2026-10-24"), []);
    const other = Yui.bondFacts("爸爸", "05-01", "2025-03-02");
    assert.ok(other.includes("5 月 1 日") && other.includes("2025 年 3 月 2 日"));
    same(Yui.bondDays("爸爸", "05-01", "2025-03-02", "2026-10-24"), []);
    assert.strictEqual(Yui.bondFacts("爸爸", "生日", ""), "");
});

test("Closing programs is left to the confirmation", () => {
    const text = Yui.featureInstructions("爸爸", "", {}, "tags");
    assert.ok(text.includes("Taskmgr.exe") && text.includes("不要自己判断危险"));
});

test("Core Tuning fields per server", () => {
    const none = { maxTokens: 0, temperature: -1, topP: -1, presencePenalty: -1, frequencyPenalty: -1, topK: 0, seed: 0, thinking: "default" };
    assert.strictEqual(JSON.stringify(Yui.tuningFields("openai", "deepseek", none)), "{}");
    assert.strictEqual(JSON.stringify(Yui.tuningFields("gemini", "google", none)), "{}");
    assert.strictEqual(JSON.stringify(Yui.tuningFields("anthropic", "anthropic", none)), JSON.stringify({ max_tokens: 1024 }));
    const all = Object.assign({}, none, { maxTokens: 800, temperature: 0.7, topP: 0.9, presencePenalty: 0.5, frequencyPenalty: 0.3, topK: 40, seed: 7, thinking: "low" });
    assert.strictEqual(JSON.stringify(Yui.tuningFields("openai", "openai", all)), JSON.stringify({ max_completion_tokens: 800, reasoning_effort: "low", temperature: 0.7, top_p: 0.9, presence_penalty: 0.5, frequency_penalty: 0.3, seed: 7 }));
    const ollama = Yui.tuningFields("openai", "custom", Object.assign({}, all, { thinking: "off" }));
    assert.strictEqual(ollama.reasoning_effort, "none");
    assert.strictEqual(ollama.top_k, 40);
    assert.ok(!("options" in ollama));
    assert.strictEqual(Yui.tuningFields("openai", "ollama", all).top_k, 40);
    // Claude: the 4.5 family keeps a budget; newer ones adaptive thinking with an effort
    assert.strictEqual(JSON.stringify(Yui.tuningFields("anthropic", "anthropic", Object.assign({ model: "claude-sonnet-4-5" }, all))), JSON.stringify({ max_tokens: 1824, thinking: { type: "enabled", budget_tokens: 1024 } }));
    same(Yui.tuningFields("anthropic", "anthropic", Object.assign({}, all, { model: "claude-opus-4-7" })), { max_tokens: 1824, thinking: { type: "adaptive" }, output_config: { effort: "low" } });
    const claudeOff = model => Yui.tuningFields("anthropic", "anthropic", Object.assign({}, none, { thinking: "off", model }));
    same(claudeOff("claude-opus-4-6"), { max_tokens: 1024 });
    same(claudeOff("claude-sonnet-5"), { max_tokens: 1024, thinking: { type: "disabled" } });
    same(claudeOff("claude-haiku-5-5"), { max_tokens: 1024, thinking: { type: "disabled" } });
    same(claudeOff("claude-sonnet-5-5"), { max_tokens: 1024, thinking: { type: "between_tools" }, output_config: { effort: "low" } });
    same(claudeOff("claude-opus-5-5"), { max_tokens: 2048, output_config: { effort: "low" } });
    assert.strictEqual(Yui.claudeThinkingKind("claude-sonnet-4-20250514"), "legacy");
    assert.strictEqual(Yui.claudeThinkingKind("claude-fable-5-2"), "always");
    // Gemini: 2.5 by budget, 3 and later by level
    same(Yui.tuningFields("gemini", "google", Object.assign({}, none, { thinking: "off", model: "gemini-2.5-flash" })).thinkingConfig, { thinkingBudget: 0 });
    same(Yui.tuningFields("gemini", "google", Object.assign({}, none, { thinking: "off", model: "gemini-2.5-pro" })).thinkingConfig, { thinkingBudget: 128 });
    assert.ok(!("thinkingConfig" in Yui.tuningFields("gemini", "google", Object.assign({}, none, { thinking: "off", model: "gemini-2.5-flash-lite" }))));
    same(Yui.tuningFields("gemini", "google", Object.assign({}, none, { thinking: "off", model: "gemini-3-flash-preview" })).thinkingConfig, { thinkingLevel: "MINIMAL" });
    same(Yui.tuningFields("gemini", "google", Object.assign({}, none, { thinking: "off", model: "gemini-4-carbon" })).thinkingConfig, { thinkingLevel: "LOW" });
    same(Yui.tuningFields("gemini", "google", Object.assign({}, none, { thinking: "medium", model: "gemini-3-pro-preview" })).thinkingConfig, { thinkingLevel: "HIGH" });
    // DeepSeek, Qwen (DashScope), OpenAI GPT-6
    same(Yui.tuningFields("openai", "deepseek", Object.assign({}, none, { thinking: "off" })), { thinking: { type: "disabled" } });
    same(Yui.tuningFields("openai", "deepseek", Object.assign({}, none, { thinking: "medium" })), { reasoning_effort: "high" });
    same(Yui.tuningFields("openai", "custom", Object.assign({}, none, { thinking: "off", endpoint: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions" })), { enable_thinking: false });
    same(Yui.tuningFields("openai", "openai", Object.assign({}, none, { thinking: "off", model: "gpt-6.1-sol" })), { reasoning_effort: "low" });
    same(Yui.tuningFields("openai", "openai", Object.assign({}, none, { thinking: "off", model: "gpt-5.2" })), { reasoning_effort: "none" });
    assert.strictEqual(Yui.tuningFields("anthropic", "anthropic", Object.assign({}, all, { temperature: 1.5, thinking: "default" })).temperature, 1);
    const gemini = Yui.tuningFields("gemini", "google", Object.assign({}, all, { thinking: "off", model: "gemini-2.5-flash" }));
    assert.strictEqual(gemini.thinkingConfig.thinkingBudget, 0);
    assert.strictEqual(gemini.topK, 40);
});

test("Tags without a value", () => {
    const reply = Yui.parseReply("最满足了～ ✨\n<<happy>>");
    assert.strictEqual(reply.text, "最满足了～ ✨");
    assert.strictEqual(reply.emotion, "happy");
    const odd = Yui.parseReply("好的<<wave>>");
    assert.strictEqual(odd.text, "好的");
    assert.strictEqual(odd.unknown.length, 1);
    assert.strictEqual(Yui.displayText("嗯<<shy>>"), "嗯");
    assert.strictEqual(Yui.parseReply("读了《三体》").text, "读了《三体》");
});

test("Alarm reminder times", () => {
    const now = new Date(2026, 9, 26, 21, 0).getTime();
    const at = Yui.remindFrom("2026-10-27 08:00|交作业", now);
    assert.strictEqual(at.due, new Date(2026, 9, 27, 8, 0).getTime());
    assert.strictEqual(at.text, "交作业");
    assert.strictEqual(at.daily, false);
    assert.strictEqual(Yui.remindFrom("+30|开会", now).due, now + 30 * 60000);
    assert.strictEqual(Yui.remindFrom("08:00|起床", now).due, new Date(2026, 9, 27, 8, 0).getTime());
    assert.strictEqual(Yui.remindFrom("22:30|洗澡", now).due, new Date(2026, 9, 26, 22, 30).getTime());
    const daily = Yui.remindFrom("每天 23:00|该睡觉了", now);
    assert.strictEqual(daily.daily, true);
    assert.strictEqual(daily.due, new Date(2026, 9, 26, 23, 0).getTime());
    assert.strictEqual(Yui.remindFrom("2026-10-25 08:00|过去的", now), null);
    assert.strictEqual(Yui.remindFrom("明天|没有时间", now), null);
    assert.strictEqual(Yui.remindFrom("+5", now), null);
    const reply = Yui.parseReply("好的～<<remind:+10|喝水>>", [], { now: now });
    assert.strictEqual(reply.reminders.length, 1);
    assert.strictEqual(reply.text, "好的～");
    assert.strictEqual(Yui.parseReply("<<remind:+10|喝水>>", [], { now: now, allowed: { alarm: false } }).reminders.length, 0);
});

test("Quest Log notes", () => {
    const reply = Yui.parseReply("记下啦<<note:买牛奶>><<done:交水费>>");
    assert.strictEqual(JSON.stringify(reply.notes), JSON.stringify(["买牛奶"]));
    assert.strictEqual(JSON.stringify(reply.dones), JSON.stringify(["交水费"]));
    assert.ok(Yui.notesWanted("我记了哪些待办？"));
    assert.ok(!Yui.notesWanted("今天天气怎么样"));
    assert.ok(Yui.notesContext("爸爸", [{ text: "买牛奶" }]).includes("- 买牛奶"));
    const text = Yui.featureInstructions("爸爸", "", { alarm: false, notes: true }, "tags");
    assert.ok(text.includes("<<note:") && !text.includes("<<remind:"));
});

// A QML file with two functions or properties of the same name does not load at all (the widget
// shows as unknown), and qmllint does not catch it.
test("No duplicate members in the QML files", () => {
    const dir = require("path").join(__dirname, "..", "..", "com.amarsimos.widget.yui", "qml");
    fs.readdirSync(dir).filter((name) => name.endsWith(".qml")).forEach((name) => {
        const names = [...fs.readFileSync(require("path").join(dir, name), "utf8").matchAll(/^    (?:function (\w+)|(?:readonly )?property \w+ (\w+))/gm)].map((m) => m[1] || m[2]);
        const twice = names.filter((n, i) => names.indexOf(n) !== i);
        assert.strictEqual(twice.join(", "), "", name);
    });
});

test("Weekly Report prompt", () => {
    const stats = { from: "2026-10-20", to: "2026-10-26", messages: 42, moods: [{ day: "2026-10-21", score: 2, note: "加班" }, { day: "2026-10-22", score: 4, note: "" }], raids: { count: 3, minutes: 75 }, notesDone: ["交作业"], notesOpen: 2, tokens: 120 };
    const text = Yui.weeklyReportPrompt("爸爸", stats);
    assert.ok(text.includes("42 条") && text.includes("10-21 2（加班）") && text.includes("平均 3.0") && text.includes("3 次，共 75 分钟") && text.includes("交作业") && text.includes("2 件"));
    const empty = Yui.weeklyReportPrompt("爸爸", Object.assign({}, stats, { moods: [], raids: { count: 0, minutes: 0 }, notesDone: [], notesOpen: 0 }));
    assert.ok(empty.includes("这周没有记录") && !empty.includes("完成的待办"));
});

test("Sword Skills and Weather Report", () => {
    const names = ["开始工作", "Game Time", ""];
    assert.strictEqual(Yui.swordSkillIndex("开始工作", names), 0);
    assert.strictEqual(Yui.swordSkillIndex("game time", names), 1);
    assert.strictEqual(Yui.swordSkillIndex("工作", names), 0);
    assert.strictEqual(Yui.swordSkillIndex("睡觉", names), -1);
    assert.strictEqual(Yui.parseReply("好的<<skill:开始工作>>", [], { allowed: { skills: ["开始工作"] } }).skill, "开始工作");
    assert.strictEqual(Yui.parseReply("好的<<skill:开始工作>>", [], { allowed: {} }).skill, "");
    assert.ok(Yui.featureInstructions("爸爸", "", { skills: ["开始工作"] }, "tags").includes("<<skill:名字>>"));
    assert.ok(!Yui.featureInstructions("爸爸", "", {}, "tags").includes("<<skill:"));
});

test("Alarm days in words", () => {
    const now = new Date(2026, 9, 26, 21, 0).getTime(); // a Monday
    assert.strictEqual(Yui.remindFrom("明天 08:00|交作业", now).due, new Date(2026, 9, 27, 8, 0).getTime());
    assert.strictEqual(Yui.remindFrom("后天 9:30|体检", now).due, new Date(2026, 9, 28, 9, 30).getTime());
    assert.strictEqual(Yui.remindFrom("周五 15:00|开会", now).due, new Date(2026, 9, 30, 15, 0).getTime());
    assert.strictEqual(Yui.remindFrom("星期一 10:00|周会", now).due, new Date(2026, 10, 2, 10, 0).getTime());
    assert.strictEqual(Yui.remindFrom("周日 10:00|休息", now).due, new Date(2026, 10, 1, 10, 0).getTime());
    assert.strictEqual(Yui.remindFrom("明天|没有时间", now), null);
});

test("Tools set aside", () => {
    assert.strictEqual(Yui.TOOLS_ENABLED, false);
    const off = { focus: false, alarm: false, notes: false, skills: [] };
    const text = Yui.featureInstructions("爸爸", "", off, "tags");
    assert.ok(!text.includes("<<focus:") && !text.includes("<<remind:") && !text.includes("<<note:") && !text.includes("<<skill:"));
    assert.strictEqual(Yui.parseReply("好<<focus:25>>", [], { allowed: off }).focus, null);
    assert.strictEqual(Yui.parseReply("好<<focus:25>>", [], { allowed: off }).text, "好");
    const report = Yui.weeklyReportPrompt("爸爸", { from: "2026-10-20", to: "2026-10-26", messages: 3, moods: [], raids: null, notesDone: null, notesOpen: 0, tokens: 1 });
    assert.ok(!report.includes("Boss Raid") && !report.includes("待办"));
});

test("Quick Replies, Character Traits, Log Recall and Through Yui's Eyes", () => {
    const reply = Yui.parseReply("要不要休息一下？<<suggest:好呀|再玩一会|好呀|你呢？|第四个>>", [], { allowed: { suggest: true } });
    assert.strictEqual(JSON.stringify(reply.suggestions), JSON.stringify(["好呀", "再玩一会", "你呢？"]));
    assert.strictEqual(reply.text, "要不要休息一下？");
    assert.strictEqual(Yui.parseReply("嗯<<suggest:好>>", [], { allowed: { suggest: false } }).suggestions.length, 0);
    assert.ok(Yui.featureInstructions("爸爸", "", { suggest: true }, "tags").includes("<<suggest:"));
    assert.ok(!Yui.featureInstructions("爸爸", "", {}, "tags").includes("<<suggest:"));
    assert.strictEqual(Yui.traitContext({ warmth: 1, energy: 1, kaomoji: 1, length: 1, format: 0 }), "");
    const style = Yui.traitContext({ warmth: 2, energy: 0, kaomoji: 0, length: 1, format: 1 });
    assert.ok(style.includes("更温柔") && style.includes("沉稳") && style.includes("很少用颜文字") && style.includes("列表"));
    const rows = [{ author: "user", message: "我下周要去京都旅行", created: new Date(2026, 8, 1).getTime() }, { author: "ai", message: "今天天气很好", created: 2 }, { author: "user", message: "京都的红叶很漂亮吧", created: new Date(2026, 8, 3).getTime() }];
    const picked = Yui.logRecallPick(rows, "京都旅行怎么样", 2);
    assert.strictEqual(picked.length, 2);
    assert.ok(picked.every((row) => row.message.includes("京都")));
    const context = Yui.logRecallContext("爸爸", picked);
    assert.ok(context.indexOf("09-01 爸爸：我下周要去京都旅行") < context.indexOf("09-03"));
    assert.strictEqual(Yui.logRecallPick(rows, "", 3).length, 0);
    const portrait = Yui.portraitPrompt("爸爸", [{ kind: "core", text: "名字是小明", created: 1 }, { kind: "fragment", text: "喜欢拉面" }]);
    assert.ok(portrait.includes("- 名字是小明") && portrait.includes("- 喜欢拉面"));
});

test("Memories keep their dates", () => {
    const now = new Date(2026, 9, 27, 21, 0).getTime();
    assert.strictEqual(Yui.datedMemory("明天要考数学", now), "10月28日要考数学");
    assert.strictEqual(Yui.datedMemory("昨天和朋友去吃了拉面", now), "10月26日和朋友去吃了拉面");
    assert.strictEqual(Yui.datedMemory("下周去京都", now), "11月3日那周去京都");
    assert.strictEqual(Yui.datedMemory("今年开始学吉他", now), "2026年开始学吉他");
    assert.strictEqual(Yui.datedMemory("喜欢豚骨拉面", now), "喜欢豚骨拉面");
    assert.strictEqual(Yui.datedMemory("今天是10月27日", now), "");
    assert.strictEqual(Yui.datedMemory("现在是21:30", now), "");
    assert.strictEqual(Yui.datedMemory("2026年10月27日星期二", now), "");
    assert.strictEqual(Yui.memoryLine({ text: "喜欢拉面", created: new Date(2026, 9, 12).getTime() }), "[10-12] 喜欢拉面");
    assert.strictEqual(Yui.memoryLine({ text: "喜欢拉面" }), "喜欢拉面");
    assert.ok(Yui.recallContext("爸爸", [{ text: "喜欢拉面", created: new Date(2026, 9, 12).getTime() }]).includes("- [10-12] 喜欢拉面"));
    assert.ok(Yui.featureInstructions("爸爸", [{ text: "名字叫小明", kind: "core", created: new Date(2026, 9, 1).getTime() }], {}, "tags").includes("- [10-01] 名字叫小明"));
});

test("Replies of small models", () => {
    const raw = "爸爸回来了！想听故事吗？<<mood:8|情绪正在回升。>\n<<suggest:好温暖/继续休息/不想动>\n\n\n</think>\n\n爸爸回来了！想听故事吗？\n\n<<forget:上次误用了sad表情>\n</think>\n\n爸爸回来了！想听故事吗？\n\n<<mood:8|情绪正在回升。>\n\n\n<<suggest:好温暖啊/继续休息吧/不想动>";
    const reply = Yui.parseReply(raw, [], { allowed: { suggest: true } });
    assert.strictEqual(reply.text, "爸爸回来了！想听故事吗？");
    assert.strictEqual(reply.mood.score, 5);
    assert.strictEqual(JSON.stringify(reply.suggestions), JSON.stringify(["好温暖啊", "继续休息吧", "不想动"]));
    assert.strictEqual(Yui.cleanReply("<think>想一想</think>你好"), "你好");
    assert.strictEqual(Yui.cleanReply("一\n\n二\n\n一"), "一\n\n二");
    assert.strictEqual(Yui.displayText("<think>正在想"), "");
    assert.strictEqual(Yui.displayText("想了很多</think>\n你好"), "你好");
    // a ">" inside the text is no tag end
    assert.strictEqual(Yui.parseReply("3 > 2 是对的<<emotion:happy>>").text, "3 > 2 是对的");
});

test("Media", () => {
    assert.strictEqual(Yui.mediaCommand("下一首"), "next");
    assert.strictEqual(Yui.mediaCommand("Play"), "pause");
    assert.strictEqual(Yui.mediaCommand("跳舞"), "");
    const on = { media: true };
    same(Yui.parseReply("好的<<media:next>><<media:vol+>><<media:乱写>>", [], { allowed: on }).media, ["next", "vol+"]);
    same(Yui.parseReply("好的<<media:next>>", [], { allowed: {} }).media, []);
    assert.strictEqual(Yui.parseReply("好的<<media:next>>", [], { allowed: {} }).text, "好的");
    assert.ok(Yui.toolDefinitions(on).some(t => t.name === "media_control"));
    assert.ok(!Yui.toolDefinitions({}).some(t => t.name === "media_control"));
    same(Yui.toolCallToAction("media_control", "{\"command\":\"mute\"}", [], { allowed: on }), { kind: "media", command: "mute" });
    assert.strictEqual(Yui.toolCallToAction("media_control", { command: "mute" }, [], { allowed: {} }).kind, "error");
    assert.ok(Yui.featureInstructions("爸爸", "", on, "tags").includes("<<media:"));
    assert.ok(!Yui.featureInstructions("爸爸", "", {}, "tags").includes("<<media:"));
    assert.ok(!Yui.featureInstructions("爸爸", "", on, "tools").includes("<<media:"));
    assert.strictEqual(Yui.mediaTrack({ title: "Yui", artist: "Kajiura", player: "网易云音乐" }), "Kajiura《Yui》（网易云音乐）");
    assert.strictEqual(Yui.mediaTrack({ title: "Yui" }), "《Yui》");
    assert.strictEqual(Yui.mediaTrack({ title: "" }), "");
    assert.ok(Yui.mediaChangeNote({ title: "I can do it now", artist: "倉木麻衣" }).includes("倉木麻衣 -《I can do it now》"));
    assert.strictEqual(Yui.mediaChangeNote(null), "");
});

test("Claims of actions not done", () => {
    for (const said of ["好哒，爸爸！音乐已经重新动起来啦", "好的，结衣已经帮你打开记事本了！", "结衣这就帮你把音量调大了哦", "闹钟已经帮爸爸设好了～", "好的，已经为你搜索好了"])
        assert.ok(Yui.claimsDone(said), said);
    for (const said of ["爸爸已经打开了吗？", "你已经关掉了呀，真棒", "结衣帮你打开它，好吗？", "这首歌真好听呢", "要不要结衣帮你打开？", "我已经记住啦", "昨天你让我打开的那个文件还在哦"])
        assert.ok(!Yui.claimsDone(said), said);
    const rules = Yui.priorityRules("爸爸", { web: false, launch: false, find: false, kill: false }, "tags");
    assert.ok(rules.includes("结衣不能操作电脑") && rules.includes("绝不假装已经做了"));
    assert.ok(Yui.priorityRules("爸爸", { find: false, kill: false, media: true }, "tags").includes("结衣只能打开网页、搜索、启动程序、控制音乐播放"));
    for (const said of ["明天早上8点一定要准时叫爸爸起床哦", "到时候结衣会提醒你的", "结衣会记得提醒爸爸喝水哦"])
        assert.ok(Yui.promisesReminder(said), said);
    for (const said of ["要不要结衣提醒你？", "爸爸记得定闹钟提醒自己哦", "结衣不能提醒爸爸，对不起"])
        assert.ok(!Yui.promisesReminder(said), said);
    assert.ok(Yui.priorityRules("爸爸", { alarm: false }, "tags").includes("也不要答应以后提醒、叫醒爸爸"));
    assert.ok(!Yui.priorityRules("爸爸", {}, "tags").includes("也不要答应以后提醒"));
});

test("Quick Replies stay talk", () => {
    same(Yui.suggestionsFrom("好呀|帮我打开记事本|下一首|今天好累"), ["好呀", "今天好累"]);
    same(Yui.suggestionsFrom("提醒我8点起床/想听你唱歌"), ["想听你唱歌"]);
    assert.ok(Yui.featureInstructions("爸爸", "", { suggest: true }, "tags").includes("不要想请结衣操作电脑"));
});

test("Care Scheduler", () => {
    same(Yui.careBudget(0.5), { perDay: 20, gapMinutes: 30 });
    same(Yui.careBudget(0), { perDay: 6, gapMinutes: 50 });
    same(Yui.careBudget(1), { perDay: 34, gapMinutes: 10 });
    assert.strictEqual(Yui.careScore("quiet", 0.9), 0.15);
    assert.strictEqual(Yui.careScore("auto", 0.9), 0.9);
    assert.strictEqual(Yui.careScore("auto", undefined), 0.5);
    assert.ok(Yui.inQuietHours(new Date(2026, 10, 25, 1, 0), "00:00", "08:00"));
    assert.ok(!Yui.inQuietHours(new Date(2026, 10, 25, 8, 0), "00:00", "08:00"));
    assert.ok(Yui.inQuietHours(new Date(2026, 10, 25, 23, 30), "23:00", "07:00"));
    assert.ok(!Yui.inQuietHours(new Date(2026, 10, 25, 12, 0), "23:00", "07:00"));
    const now = new Date(2026, 10, 25, 14, 0).getTime();
    const fresh = Yui.careToday(null, "2026-11-25");
    const offer = [{ kind: "chat", priority: "low" }, { kind: "rest", priority: "medium" }];
    assert.strictEqual(Yui.carePick(offer, fresh, { now, score: 0.5, hour: 14 }).pick.kind, "rest");
    // within the gap: only high priority
    const recent = Object.assign({}, fresh, { last: now - 10 * 60000 });
    assert.strictEqual(Yui.carePick(offer, recent, { now, score: 0.5, hour: 14 }).pick, null);
    assert.strictEqual(Yui.carePick(offer.concat([{ kind: "greeting", priority: "high" }]), recent, { now, score: 0.5, hour: 14 }).pick.kind, "greeting");
    // budget spent, said today, quiet hours, muted, an hour not answered
    assert.strictEqual(Yui.carePick(offer, Object.assign({}, fresh, { count: 20 }), { now, score: 0.5, hour: 14 }).pick, null);
    assert.strictEqual(Yui.carePick(offer, Object.assign({}, fresh, { said: { rest: true } }), { now, score: 0.5, hour: 14 }).pick.kind, "chat");
    assert.strictEqual(Yui.carePick([offer[0]], fresh, { now, score: 0.5, quiet: true, hour: 14 }).pick, null);
    assert.strictEqual(Yui.carePick(offer, Object.assign({}, fresh, { mutedUntil: now + 1000 }), { now, score: 0.5, hour: 14 }).pick, null);
    const hours = []; hours[14] = [6, 1];
    assert.strictEqual(Yui.carePick([offer[0]], fresh, { now, score: 0.5, hours, hour: 14 }).pick, null);
    // a new day keeps the last time and the mute, resets the rest
    const next = Yui.careToday({ day: "2026-11-25", count: 4, said: { rest: true }, last: 5, mutedUntil: 9 }, "2026-11-26");
    same(next, { day: "2026-11-26", count: 0, said: {}, last: 5, mutedUntil: 9 });
    assert.strictEqual(Yui.careLearn(0.5, "answered"), 0.55);
    assert.strictEqual(Yui.careLearn(0.1, "rejected"), 0);
    assert.strictEqual(Yui.careLearn(0.95, "welcomed"), 1);
    assert.strictEqual(Yui.careFeedback("别烦我了"), "rejected");
    assert.strictEqual(Yui.careFeedback("结衣多陪陪我嘛"), "welcomed");
    assert.strictEqual(Yui.careFeedback("今天好累"), "");
    const liked = []; liked[21] = [4, 3]; liked[9] = [5, 2]; liked[14] = [3, 1];
    same(Yui.careLikedHours(liked), ["21:00", "09:00"]);
});

test("Now block", () => {
    const now = new Date(2026, 10, 26, 21, 30).getTime();
    // only what there is
    assert.strictEqual(Yui.nowBlock({ now }, "爸爸"), "\n\n（此刻：11月26日 周四 21:30 晚上）");
    const all = Yui.nowBlock({ now, awake: 130 * 60000, sinceChat: 2 * 86400000, weather: "小雨，8℃", track: "倉木麻衣《I can do it now》", playing: true, load: 1, mood: { score: 3, note: "有点累" }, days: ["今天是爸爸的生日"] }, "爸爸");
    assert.strictEqual(all, "\n\n（此刻：11月26日 周四 21:30 晚上｜结衣醒着陪爸爸 2 小时 10 分钟｜距上次聊天 2 天｜小雨，8℃｜正在播放 倉木麻衣《I can do it now》｜电脑负载偏高｜今天心情 3/5 有点累｜今天是爸爸的生日）");
    // thresholds: awake from 30 min, away from 6 h; a paused track
    const short = Yui.nowBlock({ now, awake: 20 * 60000, sinceChat: 3 * 3600000, track: "《Yui》", playing: false }, "爸爸");
    assert.ok(!short.includes("醒着") && !short.includes("上次聊天") && short.includes("播放器里是 《Yui》"));
    assert.strictEqual(Yui.nowPeriod(3), "深夜");
    assert.strictEqual(Yui.nowPeriod(7), "早上");
    assert.strictEqual(Yui.nowPeriod(23), "深夜");
    assert.ok(Yui.nowGuidance(["请祝贺。"]).endsWith("不用提起。请祝贺。）"));
});

test("Care moments", () => {
    const now = new Date(2026, 10, 26, 15, 0).getTime();
    const low = [{ day: "2026-11-23", score: 2, note: "" }, { day: "2026-11-24", score: 1, note: "加班" }, { day: "2026-11-25", score: 2, note: "" }];
    same(Yui.moodLow(low, now), low);
    assert.strictEqual(Yui.moodLow(low.slice(1), now), null);
    assert.strictEqual(Yui.moodLow(low, new Date(2026, 10, 30).getTime()), null);
    assert.strictEqual(Yui.moodLow([low[0], low[1], { day: "2026-11-25", score: 4 }], now), null);
    assert.ok(Yui.moodCareInstruction(low, "爸爸").includes("11-24 1/5 加班"));
    // weather: rain starting, snow, a 5° fall within 3 h, nothing else
    const h = 3600000;
    const was = [{ at: now - 2 * h, text: "多云", temp: 12 }, { at: now - h, text: "多云", temp: 10 }];
    same(Yui.weatherChange(was, { at: now, text: "小雨", temp: 9 }), { kind: "rain", from: "多云", to: "小雨" });
    assert.strictEqual(Yui.weatherChange(was, { at: now, text: "小雪", temp: 9 }).kind, "snow");
    same(Yui.weatherChange(was, { at: now, text: "多云", temp: 7 }), { kind: "cold", from: "12°", to: "7°" });
    assert.strictEqual(Yui.weatherChange(was, { at: now, text: "多云", temp: 9 }), null);
    assert.strictEqual(Yui.weatherChange([{ at: now - 4 * h, text: "晴", temp: 20 }], { at: now, text: "小雨", temp: 10 }), null);
    assert.strictEqual(Yui.weatherChange([{ at: now - h, text: "小雨", temp: 10 }], { at: now, text: "大雨", temp: 10 }), null);
    assert.ok(Yui.weatherChangeInstruction({ kind: "rain", from: "多云", to: "小雨" }, "爸爸").includes("带伞"));
    // hooks
    const keys = f => Yui.chatHooks(Object.assign({ now }, f), "爸爸").map(x => x.key);
    assert.ok(keys({ playing: true, track: "《Yui》" }).includes("music"));
    assert.ok(keys({ busyMinutes: 40 }).includes("busy_pc"));
    assert.ok(keys({ temp: 3 }).includes("cold") && !keys({ temp: 12 }).includes("cold"));
    assert.ok(keys({ chattedToday: false }).includes("first_today") && !keys({ chattedToday: true }).includes("first_today"));
    const lateNight = Yui.chatHooks({ now: new Date(2026, 11, 25, 23, 30).getTime(), playing: true, track: "《Yui》" }, "爸爸").map(x => x.key);
    assert.ok(lateNight.includes("holiday") && lateNight.includes("late_music") && !lateNight.includes("music"));
    assert.ok(Yui.chatHooks({ now: new Date(2026, 10, 30, 12, 0).getTime() }, "爸爸").some(x => x.key === "month_end"));
    assert.ok(Yui.chatHooks({ now: new Date(2026, 10, 27, 20, 0).getTime() }, "爸爸").some(x => x.key === "friday_night"));
    // special first, used ones left out
    const hooks = [{ key: "music", text: "a" }, { key: "holiday", text: "b", special: true }];
    assert.strictEqual(Yui.pickChatHook(hooks, [], 0.9).key, "holiday");
    assert.strictEqual(Yui.pickChatHook(hooks, ["holiday"], 0.9).key, "music");
    assert.strictEqual(Yui.pickChatHook(hooks, ["holiday", "music"], 0.5), null);
});

test("Follow-ups", () => {
    const at = (m, d, h) => new Date(2026, m, d, h || 10).getTime();
    const written = at(10, 25);
    // dates, with or without the year; none for birthdays or texts without a date
    assert.strictEqual(Yui.followupDate("11月28日考试", written), new Date(2026, 10, 28).getTime());
    assert.strictEqual(Yui.followupDate("2027年1月5日面试", written), new Date(2027, 0, 5).getTime());
    assert.strictEqual(Yui.followupDate("1月5日面试", at(11, 20)), new Date(2027, 0, 5).getTime());
    assert.strictEqual(Yui.followupDate("12月20日去了游乐园", at(0, 3)), new Date(2025, 11, 20).getTime());
    assert.strictEqual(Yui.followupDate("3月8日是爸爸的生日", written), 0);
    assert.strictEqual(Yui.followupDate("爸爸喜欢猫", written), 0);
    const entries = [
        { id: 1, text: "11月28日考试", created: written },
        { id: 2, text: "11月20日去了游乐园", created: written },
        { id: 3, text: "11月25日面试", created: written },
        { id: 4, text: "爸爸喜欢猫", created: written }
    ];
    // ahead, then on the day (written earlier: cheer), then after (ask)
    let list = Yui.followups(entries, at(10, 26), {});
    same(list.map(i => [i.id, i.phase, i.days]), [[3, "after", -1], [1, "ahead", 2]]);
    assert.strictEqual(Yui.followupsDue(list, 14).kind, "ask");
    assert.strictEqual(Yui.followupsDue(list, 23), null);
    list = Yui.followups(entries, at(10, 28), { "3@2026-11-25": "asked" });
    const due = Yui.followupsDue(list, 9);
    same([due.kind, due.items.map(i => i.id)], ["cheer", [1]]);
    assert.ok(Yui.followupInstruction(due, "爸爸").indexOf("「11月28日考试」（就是今天）") !== -1);
    assert.ok(Yui.followupNote(due, "爸爸").indexOf("打气") !== -1);
    // written on the day itself: no cheering, asked the day after
    const today = [{ id: 5, text: "11月25日面试", created: written }];
    assert.strictEqual(Yui.followupsDue(Yui.followups(today, at(10, 25, 15), {}), 15), null);
    assert.strictEqual(Yui.followupsDue(Yui.followups(today, at(10, 26), {}), 15).kind, "ask");
    // asked, dismissed, more than 7 days past, more than 60 days ahead
    assert.strictEqual(Yui.followupsDue(Yui.followups(today, at(10, 26), { "5@2026-11-25": "asked" }), 15), null);
    same(Yui.followups(today, at(10, 26), { "5@2026-11-25": "dismissed" }), []);
    same(Yui.followups(today, at(11, 3), {}), []);
    same(Yui.followups([{ id: 6, text: "2月10日旅行", created: written }], at(10, 25), {}), []);
});

test("Seedling is checked when a widget is asked for: not installed, she says how to awaken it", () => {
    const missing = Yui.seedlingChatLine("missing", "爸爸");
    assert.ok(missing.indexOf("Seedling") !== -1 && missing.indexOf("程序包") !== -1 && missing.indexOf("爸爸") !== -1);
    assert.ok(Yui.seedlingChatLine("busy", "爸爸").indexOf("培育") !== -1);
    assert.ok(Yui.seedlingChatLine("unset", "爸爸").indexOf("Connection") === -1);
});

test("Seedling cannot start: she is asked again with why, in her own words and without the tag", () => {
    const missing = Yui.seedlingBlockedNote("missing", "爸爸");
    assert.ok(missing.indexOf("（系统提示：") === 0 && missing.indexOf("The Seed") !== -1 && missing.indexOf("程序包") !== -1);
    assert.ok(missing.indexOf("不要加 <<seedling:>>") !== -1 && missing.indexOf("不要提起这条提示") !== -1);
    assert.ok(Yui.seedlingBlockedNote("busy", "爸爸").indexOf("培育中") !== -1);
    // the note goes on the last message only, the messages given stay as they were
    const asked = [{ role: "user", content: "早" }, { role: "assistant", content: "早呀" }, { role: "user", content: "做个时钟" }];
    const again = Yui.withNote(asked, "（系统提示：x）");
    assert.strictEqual(again[2].content, "做个时钟\n\n（系统提示：x）");
    assert.strictEqual(asked[2].content, "做个时钟");
    assert.strictEqual(again[0], asked[0]);
    const withImage = Yui.withNote([{ role: "user", content: [{ type: "text", text: "看" }] }], "n");
    assert.strictEqual(withImage[0].content.length, 2);
});

test("Seedling in Yui's words (the writing itself is Seedling's: tests/seedling/test_seedling_writer.js)", () => {
    // the chat line: thinking until something is written, no numbers
    assert.ok(Yui.seedlingNoteLine({ "stage": "writing", "lines": 0, "edits": 0, "seconds": 3 }, "爸爸").indexOf("在想") !== -1);
    const writing = Yui.seedlingNoteLine({ "stage": "writing", "lines": 24, "edits": 0, "seconds": 9 }, "爸爸");
    assert.ok(writing.indexOf("在写") !== -1 && !/\d/.test(writing));
    assert.ok(Yui.seedlingNoteLine({ "stage": "editing", "lines": 0, "edits": 2, "seconds": 5 }, "爸爸").indexOf("在改") !== -1);
    assert.ok(Yui.seedlingChatLine("edited", "妈妈").indexOf("妈妈") !== -1);
    assert.ok(Yui.seedlingChatLine("unset", "爸爸").indexOf("Seedling Settings") !== -1);
    // going online is said, and what the writer could not do (its note) is passed on
    assert.ok(Yui.SEEDLING_INSTRUCTION.indexOf("只回复") !== -1 && Yui.SEEDLING_INSTRUCTION.indexOf("不要写任何话") !== -1);
    assert.ok(Yui.SEEDLING_INSTRUCTION.indexOf("<<seedling:修好这些问题") !== -1);
    assert.strictEqual(Yui.SEEDLING_FIX_PREFIX, "帮我修好这个挂件：");
    // from what Seedling tells (write's onDone info), never from the code
    assert.strictEqual(Yui.seedlingExtra({ online: false, note: "" }, "爸爸"), "");
    assert.strictEqual(Yui.seedlingExtra(undefined, "爸爸"), "");
    const extra = Yui.seedlingExtra({ online: true, note: "拿不到实时汇率" }, "爸爸");
    assert.ok(extra.indexOf("联网") !== -1 && extra.indexOf("爸爸：拿不到实时汇率") !== -1);
    assert.ok(typeof Yui.seedlingNoteOf === "undefined" && typeof Yui.seedlingGoesOnline === "undefined", "Yui no longer reads Seedling's code");
    assert.ok(Yui.seedlingChatLine("offline", "爸爸").indexOf("没有允许联网") !== -1);
});

console.log(passed + " tests passed");

test("System Console: <<console:>> names a page, offered unless turned off; /help lists the commands", () => {
    assert.strictEqual(Yui.parseReply("好的～<<console:memories>><<emotion:happy>>", [], {}).console, "memories");
    assert.strictEqual(Yui.parseReply("<<console:心情>>", [], {}).console, "status");
    assert.strictEqual(Yui.parseReply("<<console:2>>", [], {}).console, "records");
    assert.strictEqual(Yui.parseReply("<<console:log>>", [], {}).console, "operations");
    assert.strictEqual(Yui.parseReply("<<console:memories>>", [], { "allowed": { "console": false } }).console, "");
    assert.ok(Yui.featureInstructions("爸爸", [], { "console": true }, "tags").indexOf("<<console:页面>>") !== -1);
    assert.ok(Yui.featureInstructions("爸爸", [], { "console": false }, "tags").indexOf("<<console:") === -1);
    assert.ok(Yui.commandHelp().indexOf("/console") !== -1 && Yui.commandHelp().indexOf("/help") !== -1);
});
