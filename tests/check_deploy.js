// Checks before deploying (cp.bat runs it; exit code 1 stops the copy). Catches the mistakes that
// broke the widgets before and that the tests do not see:
//  1. a function named <prop>Changed next to property <prop> (clashes with its change signal),
//  2. a redefined FINAL property of the host's View (minimumWidth, ...),
//  3. what Qt 5.13 (SAO Utils) does not have: newer imports, WheelHandler, ?? and ?. ,
//  4. synchronous XMLHttpRequest (open(..., false) froze SAO Utils),
//  5. a function / property that is gone since the last commit but still used,
//  6. each package's test suites (tests/yui, tests/seedling),
//  7. the Link interface between them (section 12 of "Seedling Development Plan.md"): each side calls
//     only what the other lists, both say the same version, and Seedling's stand-in of Yui
//     (tests/seedling/yui_port.js) says what her yui.js says.
// Usage: node tests/check_deploy.js   (from anywhere; paths are relative to the repo)
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const root = path.resolve(__dirname, "..");
const packages = ["com.amarsimos.widget.yui", "com.amarsimos.widget.seedling"].filter((p) => fs.existsSync(path.join(root, p)));
const errors = [];
const notes = [];

function filesOf(dir) {
    let out = [];
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory())
            out = out.concat(filesOf(full));
        else if (/\.(qml|js)$/.test(entry.name))
            out.push(full);
    }
    return out;
}

// Comments and strings blanked (same length), so the checks do not trip on them.
function codeOnly(text) {
    return text.replace(/\/\*[\s\S]*?\*\/|\/\/[^\n]*|"(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*'/g, (m) => m.replace(/[^\n]/g, " "));
}

function lineOf(text, index) {
    return text.slice(0, index).split("\n").length;
}

const FINAL = ["minimumWidth", "minimumHeight", "maximumWidth", "maximumHeight"];
const files = [];
for (const pkg of packages)
    files.push(...filesOf(path.join(root, pkg, "qml")));

for (const file of files) {
    const rel = path.relative(root, file).replace(/\\/g, "/");
    const raw = fs.readFileSync(file, "utf8");
    const code = codeOnly(raw);
    const at = (i) => rel + ":" + lineOf(raw, i);
    let m;

    if (file.endsWith(".qml")) {
        // 1. function xChanged + property x
        const props = new Set();
        for (const p of code.matchAll(/\bproperty\s+(?:var|int|real|bool|string|color|url|date|double|list<\w+>|alias|[\w.]+)\s+(\w+)/g))
            props.add(p[1]);
        for (const f of code.matchAll(/\bfunction\s+(\w+)Changed\s*\(/g))
            if (props.has(f[1]))
                errors.push(at(f.index) + ": function " + f[1] + "Changed clashes with property " + f[1] + "'s change signal");

        // 1b. a property or function declared twice on the root object (indented 4 spaces): the
        // whole file then fails to load (e.g. a settings window that no longer opens)
        const rootNames = new Map();
        for (const d of code.matchAll(/^ {4}(?:readonly\s+|default\s+)*(?:property\s+\S+|function)\s+(\w+)/gm)) {
            if (rootNames.has(d[1]))
                errors.push(at(d.index) + ": " + d[1] + " is declared twice (also line " + lineOf(raw, rootNames.get(d[1])) + ")");
            else
                rootNames.set(d[1], d.index);
        }

        // 2. FINAL properties (only on a window: the root is a View / Window)
        const rootType = (code.match(/^\s*([A-Z][\w.]*)\s*\{/m) || [])[1] || "";
        if (/(^|\.)(View|Window|ApplicationWindow)$/.test(rootType))
            for (const p of code.matchAll(/\bproperty\s+\w+\s+(\w+)/g))
                if (FINAL.includes(p[1]))
                    errors.push(at(p.index) + ": property " + p[1] + " is FINAL in the host's View; use another name");

        // 3a. imports newer than Qt 5.13
        for (const i of raw.matchAll(/^import\s+(QtQuick|QtQuick\.Controls|QtQuick\.Layouts|QtQml|QtQuick\.Window)\s+2\.(\d+)/gm))
            if (Number(i[2]) > 13)
                errors.push(at(i.index) + ": import " + i[1] + " 2." + i[2] + " (SAO Utils has Qt 5.13)");
        for (const w of code.matchAll(/\b(WheelHandler|BoundaryRule|TableView\.Column)\b/g))
            errors.push(at(w.index) + ": " + w[1] + " is not in Qt 5.13");
    }

    // 3b. JavaScript Qt 5.13 does not parse
    while ((m = /\?\?|\?\.(?!\d)/g.exec(code)) !== null) {
        errors.push(at(m.index) + ": '" + m[0] + "' is not supported by Qt 5.13's JavaScript");
        break;
    }

    // 4. synchronous XMLHttpRequest: open(method, url, false). A local file read may be synchronous:
    // mark its line with "// sync-ok".
    for (const x of raw.matchAll(/\.open\s*\(([^()]*(?:\([^()]*\))?[^()]*)\)[^\n]*/g)) {
        const args = x[1].split(",");
        if (args.length >= 3 && args[2].trim() === "false" && x[0].indexOf("sync-ok") === -1)
            errors.push(at(x.index) + ": synchronous XMLHttpRequest (open(..., false)) freezes SAO Utils");
    }
}

// 5. names gone since the last commit but still used
function namesIn(text) {
    const names = new Set();
    for (const n of codeOnly(text).matchAll(/\bfunction\s+(\w+)\s*\(|\bproperty\s+[\w.<>]+\s+(\w+)/g))
        names.add(n[1] || n[2]);
    return names;
}
let allCode = "";
const definedNow = new Set();
for (const file of files) {
    const text = fs.readFileSync(file, "utf8");
    allCode += codeOnly(text) + "\n";
    namesIn(text).forEach((n) => definedNow.add(n));
}
// Files deleted since the last commit count too (their names may still be called elsewhere).
let deleted = [];
try {
    deleted = execFileSync("git", ["diff", "--name-only", "--diff-filter=D", "HEAD", "--"].concat(packages), { cwd: root, encoding: "utf8" }).split("\n").filter((f) => /\.(qml|js)$/.test(f));
} catch (e) {
    deleted = [];
}
const compared = files.map((file) => path.relative(root, file).replace(/\\/g, "/")).concat(deleted);
// Used: called (name(...), not its own definition) or reached as a member (x.name).
const usedIn = (name, code) => new RegExp("(^|[^\\w.])(?<!function\\s+)" + name + "\\s*\\(|\\." + name + "\\b").test(code);
for (const rel of compared) {
    let before;
    try {
        before = execFileSync("git", ["show", "HEAD:" + rel], { cwd: root, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] });
    } catch (e) {
        continue; // new file
    }
    const now = fs.existsSync(path.join(root, rel)) ? namesIn(fs.readFileSync(path.join(root, rel), "utf8")) : new Set();
    // Gone from this file and not defined anywhere else now (moved names are fine).
    const gone = [...namesIn(before)].filter((n) => !now.has(n) && !definedNow.has(n));
    for (const name of gone) {
        const used = usedIn(name, allCode);
        if (used)
            errors.push(rel + ": " + name + " was removed since the last commit but is still used");
        else
            notes.push(rel + ": " + name + " removed since the last commit (not used any more)");
    }
}

// 6. tests, each package its own
const suites = {
    "com.amarsimos.widget.yui": ["yui/test_yui.js"],
    "com.amarsimos.widget.seedling": ["seedling/test_seedling_safety.js", "seedling/test_seedling_props.js", "seedling/test_seedling_writer.js"]
};
for (const pkg of packages) {
    for (const test of suites[pkg] || []) {
        if (!fs.existsSync(path.join(root, "tests", test)))
            continue;
        try {
            execFileSync(process.execPath, [path.join(root, "tests", test)], { cwd: root, stdio: ["ignore", "pipe", "pipe"] });
        } catch (e) {
            const out = String(e.stdout || "") + String(e.stderr || "");
            errors.push("tests/" + test + " failed:\n    " + out.trim().split("\n").filter((l) => /FAIL|Error|failed/i.test(l)).slice(0, 8).join("\n    "));
        }
    }
}

// 7. the Link interface (only when both packages are here)
if (packages.length === 2) {
    const vm = require("vm");
    const read = (rel) => fs.readFileSync(path.join(root, rel), "utf8");
    const yuiDir = "com.amarsimos.widget.yui/qml";
    const seedDir = "com.amarsimos.widget.seedling/qml";
    const port = read(yuiDir + "/SeedlingPort.qml");
    const bench = read(seedDir + "/link/Bench.qml");
    const members = (text) => new Set((text.match(/(?:function|property(?:\s+\w+)?)\s+([a-zA-Z_]\w*)/g) || []).map((m) => m.split(/\s+/).pop()));
    // What Yui may call of Bench: its Link list (the comment above linkVersion).
    const listed = (bench.match(/what MHCP-YUI may call here\s*\/\/\s*\(([^)]*)\)/) || [])[1];
    const benchLink = new Set(String(listed || "").split(/,\s*/).concat(["widgetsChanged"]));
    const benchMembers = members(bench);
    const portMembers = members(port);
    const yuiCode = filesOf(path.join(root, yuiDir)).map((f) => fs.readFileSync(f, "utf8")).join("\n");
    const seedCode = filesOf(path.join(root, seedDir)).filter((f) => !/[\\/](props|writer)\.js$/.test(f)).map((f) => fs.readFileSync(f, "utf8")).join("\n");
    for (const name of new Set((yuiCode.match(/\bbench\.([a-zA-Z_]\w*)/g) || []).map((m) => m.slice(6)))) {
        if (!benchLink.has(name))
            errors.push("Link: MHCP-YUI calls bench." + name + ", which is not in Bench's Link interface");
        else if (name !== "widgetsChanged" && !benchMembers.has(name))
            errors.push("Link: bench." + name + " is listed but Bench has no such member");
    }
    for (const name of new Set((seedCode.match(/(?:Bench\.yui|[^\w.]yui)\.([a-zA-Z_]\w*)/g) || []).map((m) => m.split(".").pop()))) {
        if (name !== "js" && !portMembers.has(name))
            errors.push("Link: Seedling calls yui." + name + ", which MHCP-YUI's SeedlingPort does not have");
    }
    const version = (text) => (text.match(/linkVersion:\s*(\d+)/) || [])[1];
    const yuiVersion = (read(yuiDir + "/main-stand.qml").match(/seedlingLinkVersion:\s*(\d+)/) || [])[1];
    if (version(bench) !== version(port) || version(bench) !== yuiVersion)
        errors.push("Link: versions differ (Bench " + version(bench) + ", SeedlingPort " + version(port) + ", main-stand " + yuiVersion + ")");
    const box = {};
    vm.runInNewContext(read(yuiDir + "/yui.js").replace(/^\.pragma library\s*$/m, ""), box);
    const standIn = require(path.join(root, "tests/seedling/yui_port.js"));
    if (JSON.stringify(box.SEEDLING_DATA) !== JSON.stringify(standIn.dataKeys) || String(standIn.linkVersion) !== version(port))
        errors.push("Link: tests/seedling/yui_port.js no longer says what MHCP-YUI says (SEEDLING_DATA / linkVersion); copy hers");
}

for (const note of notes)
    console.log("note: " + note);
if (errors.length) {
    console.log("\nCHECK FAILED (" + errors.length + "):");
    for (const error of errors)
        console.log("  " + error);
    process.exit(1);
}
console.log("check passed: " + files.length + " files, tests ok");
