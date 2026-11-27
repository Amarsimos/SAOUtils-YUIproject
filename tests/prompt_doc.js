// Writes the appendix of "Prompt Rules.md": the prompt texts as the code makes them (yui.js and
// Seedling's writer.js), so the document never holds a hand-copied rule. Everything between the two
// markers is replaced. Run after changing a prompt: node tests/prompt_doc.js
const fs = require("fs");
const vm = require("vm");
const path = require("path");

const root = path.join(__dirname, "..");
const load = (file) => {
    const box = {};
    vm.runInNewContext(fs.readFileSync(path.join(root, file), "utf8").replace(/^\.pragma library\s*$/m, ""), box);
    return box;
};
const Y = load("com.amarsimos.widget.yui/qml/yui.js");
const W = load("com.amarsimos.widget.seedling/qml/writer.js");
const qml = fs.readFileSync(path.join(root, "com.amarsimos.widget.yui/qml/main-stand.qml"), "utf8");
const persona = JSON.parse(qml.match(/readonly property string defaultSystemPrompt: ("(?:[^"\\]|\\.)*")/)[1]);

const START = "<!-- prompt_doc.js: start -->";
const END = "<!-- prompt_doc.js: end -->";
const fence = (text) => ["````", String(text).trim(), "````", ""];
const title = "爸爸";
// The widget's defaults (main-stand allowedActions): Authority Level Full, settings untouched.
const allowed = { web: true, launch: true, find: false, kill: false, memory: true, focus: true, alarm: true, notes: true, suggest: true, media: false, seedling: true, skills: [] };

const out = [START, "",
    "## 附录：提示词原文（由 `tests/prompt_doc.js` 从代码生成，不要手改）", "",
    "称呼取「" + title + "」，功能开关取默认设置（Authority Level = Full，装了 Seedling）。", "",
    "### A. 最重要的规则（`Yui.priorityRules`，Tags 模式）", ""].concat(
    fence(Y.priorityRules(title, allowed, "tags")),
    ["### B. 默认人格（`defaultSystemPrompt`）", ""], fence(Y.withTitle(persona, title)),
    ["### C. 系统功能说明（`Yui.featureInstructions`，Tags 模式）", ""], fence(Y.featureInstructions(title, [], allowed, "tags")),
    ["### D. 小模型提醒（`Yui.smallModelReminder`）", ""], fence(Y.smallModelReminder("tags", { web: false, launch: false, find: false, kill: false, memory: true, suggest: true })),
    ["### E. Seedling 写新挂件（`codePrompt`，不联网，有结衣）", ""], fence(W.codePrompt(false, false, true)),
    ["### F. Seedling 修改挂件时多出的修改方式（`EDIT_RULES`）", ""], fence(W.EDIT_RULES.join("\n")),
    ["### G. 联网打开时规则 9 换成", ""], fence(W.codePrompt(true, false, false).split("\n").find((l) => l.indexOf("9. ") === 0)),
    [END]).join("\n");

const file = path.join(root, "Prompt Rules.md");
let doc = fs.readFileSync(file, "utf8").replace(/\r\n/g, "\n");
const a = doc.indexOf(START);
const b = doc.indexOf(END);
doc = a !== -1 && b > a ? doc.slice(0, a) + out + doc.slice(b + END.length) : doc.trimEnd() + "\n\n---\n\n" + out + "\n";
fs.writeFileSync(file, doc);
console.log("Prompt Rules.md: appendix written");
