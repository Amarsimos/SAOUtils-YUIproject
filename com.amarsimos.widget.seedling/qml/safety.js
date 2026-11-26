.pragma library

// Seedling's safety check: run on the code before it is rendered. A widget may only use the Qt Quick
// modules below; it may not run commands, touch files, open links or load other code, and it may only
// go online when the user allows it (Network in the workbench). Returns a list of
// {line, message}; empty when the code may be rendered.

var ALLOWED_MODULES = ["QtQuick", "QtQuick.Controls", "QtQuick.Layouts", "QtQuick.Shapes", "QtQuick.Particles", "QtGraphicalEffects", "QtQuick.Window"];

var FORBIDDEN = [
    [/\bSystemCall\b/, "runs system commands"],
    [/\bexecute\s*\(/, "runs commands"],
    [/Qt\.openUrlExternally/, "opens links or programs"],
    [/Qt\.createQmlObject|Qt\.createComponent|Qt\.include/, "loads other code"],
    [/\bLoader\s*\{[^}]*\bsource\s*:/, "loads other code"],
    [/\beval\s*\(|\bFunction\s*\(/, "runs code from text"],
    [/LocalStorage|openDatabaseSync/, "uses a database"],
    [/["']file:|\bfile:\/\//i, "reads local files"],
    [/\bNVG\b|NERvGear/, "uses SAO Utils' own functions"]
];

var NETWORK = [
    [/\bXMLHttpRequest\b/, "goes online (XMLHttpRequest)"],
    [/\bWebSocket\b/, "goes online (WebSocket)"],
    [/["']https?:\/\//i, "loads from the Internet"]
];

// The code with comments and the text of strings kept in place but comments blanked, so line numbers
// stay right and a word in a comment does not count.
function stripComments(code) {
    return String(code).replace(/\/\*[\s\S]*?\*\//g, function(m) {
        return m.replace(/[^\n]/g, " ");
    }).replace(/(^|[^:"'])\/\/.*$/gm, "$1");
}

function lineOf(text, index) {
    return text.slice(0, index).split("\n").length;
}

function check(code, allowNetwork) {
    var text = stripComments(code);
    var problems = [];
    var importRe = /^\s*import\s+([^\s;]+)/gm;
    var m;
    while ((m = importRe.exec(text)) !== null) {
        var name = m[1];
        if (name.charAt(0) === "\"" || name.charAt(0) === "'")
            problems.push({ "line": lineOf(text, m.index), "message": "import " + name + ": imports of files or folders are not allowed" });
        else if (ALLOWED_MODULES.indexOf(name) < 0)
            problems.push({ "line": lineOf(text, m.index), "message": "import " + name + ": not an allowed module" });
    }
    var rules = FORBIDDEN.concat(allowNetwork ? [] : NETWORK);
    for (var i = 0; i < rules.length; i++) {
        var re = new RegExp(rules[i][0].source, "g" + (rules[i][0].ignoreCase ? "i" : ""));
        var found = re.exec(text);
        if (found)
            problems.push({ "line": lineOf(text, found.index), "message": found[0].trim().slice(0, 30) + ": " + rules[i][1] });
    }
    problems.sort(function(a, b) {
        return a.line - b.line;
    });
    return problems;
}

// "Line 3: import NERvGear: not an allowed module; ..."
function describe(problems) {
    return problems.map(function(p) {
        return "Line " + p.line + ": " + p.message;
    }).join("\n");
}
