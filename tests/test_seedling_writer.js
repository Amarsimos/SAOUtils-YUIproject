// How Seedling has a widget written (com.amarsimos.widget.seedling/qml/writer.js), section 11 of
// "Seedling Development Plan.md": the prompt, the request, the code out of a reply, SEARCH / REPLACE
// edits, and what is told to the model when they do not fit. Run: node tests/test_seedling_writer.js
const fs = require("fs");
const vm = require("vm");
const path = require("path");
const assert = require("assert");

const load = (file) => {
    const box = {};
    vm.runInNewContext(fs.readFileSync(path.join(__dirname, "..", "com.amarsimos.widget.seedling", "qml", file), "utf8").replace(/^\.pragma library\s*$/m, ""), box);
    return box;
};
const W = load("writer.js");
const P = load("props.js");

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
const same = (a, b) => assert.deepStrictEqual(JSON.parse(JSON.stringify(a)), b);

test("SEARCH / REPLACE edits", () => {
    const code = "import QtQuick 2.12\n\nRectangle {\n    width: 200; height: 84\n    color: \"#E61F2630\"\n    Text {\n        color: \"white\"\n        text: \"hi\"\n    }\n}\n";
    const block = (search, replace) => "<<<<<<< SEARCH\n" + search + "\n=======\n" + replace + "\n>>>>>>> REPLACE";
    // parsing: several blocks, in order, also inside a code fence; an empty REPLACE deletes
    const reply = "```\n" + block("    color: \"#E61F2630\"", "    color: \"transparent\"") + "\n" + block("        text: \"hi\"", "") + "\n```";
    const blocks = W.edits(reply);
    assert.strictEqual(blocks.length, 2);
    assert.strictEqual(blocks[1].replace, "");
    assert.strictEqual(W.editCount("<<<<<<< SEARCH\nx\n=======\ny\n>>>>>>> REPLACE\n<<<<<<< SEARCH\nz"), 2);
    // exact
    let r = W.applyEdits(code, blocks);
    assert.ok(r.ok);
    assert.ok(r.code.indexOf("color: \"transparent\"") !== -1 && r.code.indexOf("text: \"hi\"") === -1);
    assert.strictEqual(r.removed, 2);
    same(r.changed, [4]);
    // loose: wrong indentation still fits, and the replacement takes the code's indentation
    r = W.applyEdits(code, [{ "search": "color: \"white\"\ntext: \"hi\"", "replace": "color: \"orange\"\ntext: \"yo\"" }]);
    assert.ok(r.ok);
    assert.ok(r.code.indexOf("        color: \"orange\"\n        text: \"yo\"") !== -1);
    // found more than once: refused
    r = W.applyEdits(code, [{ "search": "    color: ", "replace": "    colour: " }]);
    assert.ok(!r.ok);
    assert.strictEqual(r.failed[0].reason, "many");
    // all or nothing
    r = W.applyEdits(code, [{ "search": "    width: 200; height: 84", "replace": "    width: 300; height: 84" }, { "search": "    radius: 10", "replace": "    radius: 4" }]);
    assert.ok(!r.ok);
    assert.strictEqual(r.code, code);
    assert.strictEqual(r.failed[0].index, 2);
    assert.strictEqual(r.failed[0].reason, "missing");
    assert.ok(W.editProblem(r.failed).indexOf("第 2 个块") !== -1);
    // nearest lines are offered when it is missing
    r = W.applyEdits(code, [{ "search": "    width: 200; height: 90\n    color: \"#E61F2630\"", "replace": "x" }]);
    assert.ok(r.failed[0].nearest.indexOf("width: 200; height: 84") !== -1);
});

test("the prompt: edit rules only when editing; rule 15 (Yui's data) only with MHCP-YUI; its keys are props.js's", () => {
    assert.ok(W.codePrompt(false, true, false).indexOf("SEARCH/REPLACE") !== -1);
    assert.ok(W.codePrompt(false, false, false).indexOf("SEARCH/REPLACE") === -1);
    assert.ok(W.codePrompt(false, false, false).indexOf("SEEDLING-NOTE") !== -1);
    assert.ok(W.codePrompt(false, false, false).indexOf("@yui") === -1);
    const rule = W.codePrompt(false, false, true).split("\n").find((l) => l.indexOf("15. ") === 0);
    assert.ok(rule);
    const named = (rule.match(/[a-z_]+（/g) || []).map((m) => m.slice(0, -1));
    same(named.sort(), Object.keys(P.YUI_KEYS).sort());
});

test("style and template notes only when there are some", () => {
    assert.strictEqual(W.styleNote(""), "");
    assert.strictEqual(W.templateNote("  "), "");
    assert.ok(W.styleNote("极简黑白").indexOf("极简黑白") !== -1);
    assert.ok(W.templateNote("Item {}").indexOf("```qml\nItem {}\n```") !== -1);
});

test("the request: current code, what is wanted, the problem, whole code asked for", () => {
    const fresh = W.codeRequest("一个时钟", "", "", false);
    assert.ok(fresh.indexOf("要做的挂件：一个时钟") !== -1 && fresh.indexOf("现在的代码") === -1);
    const again = W.codeRequest("改成红色", "Item {}", "Line 1: x", true);
    assert.ok(again.indexOf("```qml\nItem {}\n```") !== -1);
    assert.ok(again.indexOf("要修改的地方：改成红色") !== -1);
    assert.ok(again.indexOf("Line 1: x") !== -1);
    assert.ok(again.indexOf("完整代码") !== -1);
});

test("code out of a reply: thinking dropped, the first block, partial while streaming, cut off", () => {
    assert.strictEqual(W.cleanReply("<think>plan</think>\n\nhello\n\nhello"), "hello");
    assert.strictEqual(W.codeFrom("<think>x</think>Here:\n```qml\nimport QtQuick 2.12\nItem {}\n```\nbye"), "import QtQuick 2.12\nItem {}\n");
    assert.strictEqual(W.codeFrom("import QtQuick 2.12\nItem {}"), "import QtQuick 2.12\nItem {}\n");
    assert.strictEqual(W.codeFrom("no code here"), "");
    assert.strictEqual(W.partialCode("```qml\nimport QtQuick 2.12\nIte"), "import QtQuick 2.12\nIte");
    assert.ok(W.codeCut("```qml\nimport QtQuick 2.12\nItem {"));
    assert.ok(!W.codeCut("```qml\nItem {}\n```"));
});

test("what the writer could not do, and whether it goes online", () => {
    assert.strictEqual(W.noteOf("// SEEDLING-NOTE: 拿不到实时汇率\nimport QtQuick 2.12"), "拿不到实时汇率");
    assert.strictEqual(W.noteOf("import QtQuick 2.12"), "");
    assert.ok(W.goesOnline("var r = new XMLHttpRequest();"));
    assert.ok(!W.goesOnline("// https://example.com in a comment\nItem {}"));
});

const A = load("api.js");

test("api.js: what is missing before a request", () => {
    assert.strictEqual(A.missing({ provider: "openai", apiKey: "k", model: "m" }), "");
    assert.strictEqual(A.missing({ provider: "openai", apiKey: "", model: "m" }), "Access Key");
    assert.strictEqual(A.missing({ provider: "ollama", apiKey: "", model: "qwen" }), "");
    assert.strictEqual(A.missing({ provider: "custom", apiKey: "k", model: "m" }), "Server Address");
    assert.strictEqual(A.missing({ provider: "anthropic", apiKey: "k", model: " " }), "Core Program");
});

test("api.js: the three request shapes", () => {
    const o = A.build({ provider: "deepseek", apiKey: "k", model: "m" }, "SYS", "USER", 100);
    assert.strictEqual(o.url, "https://api.deepseek.com/chat/completions");
    same(o.headers, [["Authorization", "Bearer k"]]);
    same(o.body.messages, [{ role: "system", content: "SYS" }, { role: "user", content: "USER" }]);
    assert.strictEqual(o.body.stream, true);
    const c = A.build({ provider: "anthropic", apiKey: "k", model: "claude" }, "SYS", "USER", 100);
    assert.strictEqual(c.body.system, "SYS");
    assert.strictEqual(c.body.max_tokens, 100);
    assert.ok(c.headers.some((h) => h[0] === "anthropic-version"));
    const g = A.build({ provider: "google", apiKey: "k", model: "gemini-x" }, "SYS", "USER", 100);
    assert.strictEqual(g.url, "https://generativelanguage.googleapis.com/v1beta/models/gemini-x:streamGenerateContent?alt=sse");
    assert.strictEqual(g.body.systemInstruction.parts[0].text, "SYS");
    // no key (Ollama): no Authorization header
    same(A.build({ provider: "ollama", apiKey: "", model: "q" }, "S", "U", 1).headers, []);
    // own address
    assert.strictEqual(A.build({ provider: "custom", endpoint: "http://x/v1/chat/completions", apiKey: "k", model: "m" }, "S", "U", 1).url, "http://x/v1/chat/completions");
});

test("api.js: reading the stream, line by line, in pieces", () => {
    const body = 'data: {"choices":[{"delta":{"content":"im"}}]}\n\ndata: {"choices":[{"delta":{"content":"port"}}]}\ndata: [DONE]\n';
    let r = A.readStream("openai", body.slice(0, 60), 0, false);
    assert.strictEqual(r.text, "im");
    r = A.readStream("openai", body, r.next, true);
    assert.strictEqual(r.text, "port");
    const claude = 'event: content_block_delta\ndata: {"type":"content_block_delta","delta":{"text":"Hi"}}\n';
    assert.strictEqual(A.readStream("anthropic", claude, 0, true).text, "Hi");
    const gemini = 'data: {"candidates":[{"content":{"parts":[{"text":"Yo"}]}}]}\n';
    assert.strictEqual(A.readStream("gemini", gemini, 0, true).text, "Yo");
    assert.throws(() => A.readStream("openai", 'data: {"error":{"message":"bad key"}}\n', 0, true), /bad key/);
    assert.strictEqual(A.textOf("openai", { choices: [{ message: { content: "whole" } }] }), "whole");
});

console.log(passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
