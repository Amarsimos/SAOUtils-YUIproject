// Writes the end of section 13 of "Seedling Development Plan.md": Seedling's code rules as writer.js
// makes them, so the document never holds a hand-copied rule. Yui's data (rule 15) comes from the
// stand-in of her port (yui_port.js), so this runs without MHCP-YUI's code. Everything between the two
// markers is replaced. Run after changing a prompt: node tests/seedling/prompt_doc.js
const fs = require("fs");
const vm = require("vm");
const path = require("path");

const root = path.join(__dirname, "..", "..");
const W = {};
vm.runInNewContext(fs.readFileSync(path.join(root, "com.amarsimos.widget.seedling/qml/writer.js"), "utf8").replace(/^\.pragma library\s*$/m, ""), W);
const KEYS = require("./yui_port.js").dataKeys;

const START = "<!-- seedling/prompt_doc.js: start -->";
const END = "<!-- seedling/prompt_doc.js: end -->";
const fence = (text) => ["````", String(text).trim(), "````", ""];

const out = [START, "",
    "### 13.6 规则原文（由 `tests/seedling/prompt_doc.js` 从代码生成，不要手改）", "",
    "#### 写新挂件（`codePrompt`，不联网，有结衣）", ""].concat(
    fence(W.codePrompt(false, false, KEYS)),
    ["#### 修改挂件时多出的修改方式（`EDIT_RULES`）", ""], fence(W.EDIT_RULES.join("\n")),
    ["#### 联网打开时规则 9 换成", ""], fence(W.codePrompt(true, false, null).split("\n").find((l) => l.indexOf("9. ") === 0)),
    [END]).join("\n");

const file = path.join(root, "Seedling Development Plan.md");
let doc = fs.readFileSync(file, "utf8").replace(/\r\n/g, "\n");
const a = doc.indexOf(START);
const b = doc.indexOf(END);
doc = a !== -1 && b > a ? doc.slice(0, a) + out + doc.slice(b + END.length) : doc.trimEnd() + "\n\n" + out + "\n";
fs.writeFileSync(file, doc);
console.log("Seedling Development Plan.md: section 13.6 written");
