// Writes the appendix of "Prompt Rules.md": MHCP-YUI's prompt texts as yui.js makes them, so the
// document never holds a hand-copied rule. Everything between the two markers is replaced. Run after
// changing a prompt: node tests/yui/prompt_doc.js (Seedling's: tests/seedling/prompt_doc.js)
const fs = require("fs");
const vm = require("vm");
const path = require("path");

const root = path.join(__dirname, "..", "..");
const Y = {};
vm.runInNewContext(fs.readFileSync(path.join(root, "com.amarsimos.widget.yui/qml/yui.js"), "utf8").replace(/^\.pragma library\s*$/m, ""), Y);
const qml = fs.readFileSync(path.join(root, "com.amarsimos.widget.yui/qml/main-stand.qml"), "utf8");
const persona = JSON.parse(qml.match(/readonly property string defaultSystemPrompt: ("(?:[^"\\]|\\.)*")/)[1]);

const START = "<!-- yui/prompt_doc.js: start -->";
const END = "<!-- yui/prompt_doc.js: end -->";
const fence = (text) => ["````", String(text).trim(), "````", ""];
const title = "爸爸";
// The widget's defaults (main-stand allowedActions): Authority Level Full, settings untouched.
const allowed = { web: true, launch: true, find: false, kill: false, memory: true, focus: true, alarm: true, notes: true, suggest: true, media: false, seedling: true, console: true, skills: [] };

const out = [START, "",
    "## 附录：提示词原文（由 `tests/yui/prompt_doc.js` 从代码生成，不要手改）", "",
    "称呼取「" + title + "」，功能开关取默认设置（Authority Level = Full，装了 Seedling）。Seedling 的写代码规则原文在 `Seedling Development Plan.md` 第十三节末尾。", "",
    "### A. 最重要的规则（`Yui.priorityRules`，Tags 模式）", ""].concat(
    fence(Y.priorityRules(title, allowed, "tags")),
    ["### B. 默认人格（`defaultSystemPrompt`）", ""], fence(Y.withTitle(persona, title)),
    ["### C. 系统功能说明（`Yui.featureInstructions`，Tags 模式）", ""], fence(Y.featureInstructions(title, [], allowed, "tags")),
    ["#### 要的挂件开始不了时，带着这条再问一次（`Yui.seedlingBlockedNote`）", ""], fence(["missing", "busy"].map((k) => k + "：" + Y.seedlingBlockedNote(k, title)).join("\n")),
    ["### D. 小模型提醒（`Yui.smallModelReminder`）", ""], fence(Y.smallModelReminder("tags", { web: false, launch: false, find: false, kill: false, memory: true, suggest: true })),
    [END]).join("\n");

const file = path.join(root, "Prompt Rules.md");
let doc = fs.readFileSync(file, "utf8").replace(/\r\n/g, "\n");
const a = doc.indexOf(START);
const b = doc.indexOf(END);
doc = a !== -1 && b > a ? doc.slice(0, a) + out + doc.slice(b + END.length) : doc.trimEnd() + "\n\n---\n\n" + out + "\n";
fs.writeFileSync(file, doc);
console.log("Prompt Rules.md: appendix written");
