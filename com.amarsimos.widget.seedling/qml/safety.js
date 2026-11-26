.pragma library

// Seedling's safety check (S3 of "Seedling Development Plan.md"), run on the code before it is
// created in the sandbox. Second line of defence: the sandbox (sandbox.js) keeps the names around the
// widget out of reach; this keeps the widget to what a widget needs. It reads the code as tokens
// (strings decoded, comments dropped), not as text, and lets through only what is allowed:
// - imports: the Qt Quick modules below;
// - Qt.*: the functions below (colors, dates, geometry, bindings) and Qt's constants;
// - no eval, Function, constructor, prototype, this, arguments, template strings, regular
//   expressions, while / do, Loader, createObject, LocalStorage...;
// - [ ]: a number, a plain string that is not a dangerous name, or a loop counter (for (var i = 0; ...))
//   or index, with + - * / % between them;
// - parent: only parent.width / .height / the anchor lines..., or as the value of an anchor;
//   never .parent (climbing out of the widget);
// - addresses (strings with "scheme:"): only http(s), with Network on, written out at least up to the
//   host ("https://host/" + ...); file:, qrc:, nvg:... never. XMLHttpRequest only with Network on, and
//   its open() takes such an address;
// - limits: width / height up to 2000, Timer intervals from 16 ms, for loops with an end (a number up
//   to 1000 or a .length), particles bounded.
// check(code, allowNetwork) returns [{line, message, network}] ([] when it may be created);
// network: refused only because Network is off.

var ALLOWED_MODULES = ["QtQuick", "QtQuick.Controls", "QtQuick.Layouts", "QtQuick.Shapes", "QtQuick.Particles", "QtGraphicalEffects"];

// Qt.<name> allowed (besides constants, which start with a capital: Qt.AlignCenter, Qt.LeftButton...).
var QT_ALLOWED = ["rgba", "rgb", "hsla", "hsva", "tint", "lighter", "darker", "colorEqual", "formatDate", "formatTime", "formatDateTime", "point", "size", "rect", "vector2d", "vector3d", "vector4d", "quaternion", "matrix4x4", "font", "binding", "callLater", "md5", "btoa", "atob"];

// Names never allowed anywhere (as a name, after a dot, or as a plain string key in [ ]).
var FORBIDDEN_NAMES = {
    "eval": "runs text as code",
    "Function": "runs text as code",
    "constructor": "reaches the function maker (runs text as code)",
    "prototype": "changes how objects behave",
    "__proto__": "changes how objects behave",
    "__defineGetter__": "changes how objects behave",
    "__defineSetter__": "changes how objects behave",
    "getPrototypeOf": "reaches the function maker",
    "setPrototypeOf": "changes how objects behave",
    "globalThis": "reaches everything",
    "this": "reaches the object around the code",
    "arguments": "reaches the caller",
    "caller": "reaches the caller",
    "callee": "reaches the caller",
    "LocalStorage": "uses a database",
    "openDatabaseSync": "uses a database",
    "Loader": "loads other code",
    "createObject": "creates objects from code",
    "incubateObject": "creates objects from code",
    "createQmlObject": "loads other code",
    "createComponent": "loads other code",
    "include": "loads other code",
    "importScripts": "loads other code",
    "openUrlExternally": "opens links or programs",
    "quit": "quits SAO Utils",
    "exit": "quits SAO Utils",
    "gc": "is not for widgets",
    "while": "can loop forever (use a for loop with an end)",
    "do": "can loop forever (use a for loop with an end)",
    "WorkerScript": "runs code elsewhere",
    "Window": "reaches the window around the widget",
    "ApplicationWindow": "reaches the window around the widget",
    "SystemCall": "runs system commands",
    "NVG": "uses SAO Utils' own functions",
    "NERvGear": "uses SAO Utils' own functions",
    "WebSocket": "goes online in a way that is not allowed",
    "fetch": "goes online in a way that is not allowed",
    "Proxy": "changes how objects behave",
    "Reflect": "changes how objects behave"
};

// What may follow "parent.": its size, place, anchor lines and look.
var PARENT_MEMBERS = ["width", "height", "x", "y", "z", "left", "right", "top", "bottom", "horizontalCenter", "verticalCenter", "baseline", "implicitWidth", "implicitHeight", "opacity", "visible", "color", "radius", "scale", "rotation", "enabled", "clip"];

// QML properties that take an address.
var URL_PROPERTIES = ["source", "url", "baseUrl", "fontSource"];

// Schemes refused even when not followed by "/".
var OTHER_SCHEMES = ["file", "qrc", "nvg", "data", "javascript", "about", "blob", "image", "ftp", "ws", "wss", "mailto", "jar", "assets", "content"];

var MAX_SIZE = 2000;
var MIN_INTERVAL = 16;
var MAX_LOOP = 1000;
var MAX_PARTICLES = 1000;

// ---- tokens
// [{type: "string" | "number" | "name" | "punct", value, line}]; comments dropped. Problems found while
// reading (template strings, regular expressions, escaped names, unclosed strings) go to problems.
function tokenize(code, problems) {
    var text = String(code || "");
    var tokens = [];
    var line = 1;
    var i = 0;
    var n = text.length;
    var punct = ["===", "!==", ">>>=", "...", "<<=", ">>=", ">>>", "==", "!=", "<=", ">=", "&&", "||", "++", "--", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "=>", "<<", ">>", "**"];
    while (i < n) {
        var c = text.charAt(i);
        if (c === "\n") {
            line++;
            i++;
            continue;
        }
        if (/\s/.test(c)) {
            i++;
            continue;
        }
        if (c === "/" && text.charAt(i + 1) === "/") {
            while (i < n && text.charAt(i) !== "\n")
                i++;
            continue;
        }
        if (c === "/" && text.charAt(i + 1) === "*") {
            var close = text.indexOf("*/", i + 2);
            var end = close === -1 ? n : close + 2;
            line += text.slice(i, end).split("\n").length - 1;
            i = end;
            continue;
        }
        if (c === "`") {
            problems.push({
                "line": line,
                "message": "template strings (`...`) are not allowed"
            });
            i++;
            continue;
        }
        if (c === "\"" || c === "'") {
            var start = line;
            var value = "";
            i++;
            var closed = false;
            while (i < n) {
                var ch = text.charAt(i);
                if (ch === c) {
                    closed = true;
                    i++;
                    break;
                }
                if (ch === "\n") {
                    line++;
                    value += ch;
                    i++;
                    continue;
                }
                if (ch === "\\") {
                    var next = text.charAt(i + 1);
                    if (next === "x") {
                        value += String.fromCharCode(parseInt(text.substr(i + 2, 2), 16));
                        i += 4;
                    } else if (next === "u") {
                        if (text.charAt(i + 2) === "{") {
                            var brace = text.indexOf("}", i);
                            value += String.fromCharCode(parseInt(text.slice(i + 3, brace), 16));
                            i = brace + 1;
                        } else {
                            value += String.fromCharCode(parseInt(text.substr(i + 2, 4), 16));
                            i += 6;
                        }
                    } else {
                        var simple = {
                            "n": "\n",
                            "t": "\t",
                            "r": "\r",
                            "b": "\b",
                            "f": "\f",
                            "v": "\v",
                            "0": "\0"
                        };
                        value += simple[next] !== undefined ? simple[next] : next;
                        if (next === "\n")
                            line++;

                        i += 2;
                    }
                    continue;
                }
                value += ch;
                i++;
            }
            if (!closed)
                problems.push({
                "line": start,
                "message": "a string is not closed"
            });

            tokens.push({
                "type": "string",
                "value": value,
                "line": start
            });
            continue;
        }
        if (/[0-9]/.test(c) || (c === "." && /[0-9]/.test(text.charAt(i + 1)))) {
            var m = /^(0[xX][0-9a-fA-F]+|[0-9]*\.?[0-9]+([eE][+-]?[0-9]+)?)/.exec(text.slice(i));
            tokens.push({
                "type": "number",
                "value": Number(m[0]),
                "line": line
            });
            i += m[0].length;
            continue;
        }
        if (/[A-Za-z_$\\]/.test(c) || c.charCodeAt(0) > 127) {
            var word = "";
            while (i < n && (/[A-Za-z0-9_$\\]/.test(text.charAt(i)) || text.charCodeAt(i) > 127)) {
                word += text.charAt(i);
                i++;
            }
            if (word.indexOf("\\") !== -1)
                problems.push({
                "line": line,
                "message": "names written with \\u escapes are not allowed"
            });

            tokens.push({
                "type": "name",
                "value": word,
                "line": line
            });
            continue;
        }
        // A "/" where a value is expected starts a regular expression.
        if (c === "/") {
            var prev = tokens.length ? tokens[tokens.length - 1] : null;
            var valueExpected = !prev || (prev.type === "punct" && [")", "]", "}"].indexOf(prev.value) === -1) || (prev.type === "name" && ["return", "typeof", "case", "in", "of", "new", "delete", "void"].indexOf(prev.value) !== -1);
            if (valueExpected) {
                problems.push({
                    "line": line,
                    "message": "regular expressions are not allowed"
                });
                // Skip it, to keep reading what follows.
                i++;
                while (i < n && text.charAt(i) !== "/" && text.charAt(i) !== "\n") {
                    if (text.charAt(i) === "\\")
                        i++;

                    i++;
                }
                i++;
                continue;
            }
        }
        var op = null;
        for (var k = 0; k < punct.length && !op; k++)
            if (text.substr(i, punct[k].length) === punct[k])
                op = punct[k];
        op = op || c;
        tokens.push({
            "type": "punct",
            "value": op,
            "line": line
        });
        i += op.length;
    }
    return tokens;
}

function isName(t, v) {
    return t && t.type === "name" && (v === undefined || t.value === v);
}

function isPunct(t, v) {
    return t && t.type === "punct" && (v === undefined || t.value === v);
}

// An address: http(s) written out up to the host and a "/", or anything with a scheme.
function addressKind(value) {
    var s = String(value).trim();
    if (/^https?:\/\/[^\/\s"']+\//i.test(s) || /^https?:\/\/[^\/\s"']+$/i.test(s))
        return "web";

    // A scheme: "xxx:/..." (file:///, C:/...), or a known one without slashes (data:, javascript:).
    // "hh:mm", "Temp: 20" are not addresses.
    var scheme = /^([a-z][a-z0-9+.\-]*):/i.exec(s);
    if (scheme && (s.charAt(scheme[0].length) === "/" || s.charAt(scheme[0].length) === "\\" || OTHER_SCHEMES.indexOf(scheme[1].toLowerCase()) !== -1))
        return "other";

    return "";
}

function check(code, allowNetwork) {
    var problems = [];
    var add = function(line, message, network) {
        problems.push({
            "line": line,
            "message": message,
            "network": network === true
        });
    };
    var tokens = tokenize(code, problems);
    var T = function(j) {
        return tokens[j];
    };
    // Loop counters: for (var|let NAME = <number> ...
    var counters = {
        "index": -1
    };
    // The ids the code gives its own items: an effect's "source: someId" points at one of them.
    var ids = {};
    for (var d = 0; d + 2 < tokens.length; d++)
        if (isName(T(d), "id") && isPunct(T(d + 1), ":") && isName(T(d + 2)))
            ids[T(d + 2).value] = true;
    for (var j = 0; j + 4 < tokens.length; j++)
        if (isName(T(j), "for") && isPunct(T(j + 1), "(") && (isName(T(j + 2), "var") || isName(T(j + 2), "let")) && isName(T(j + 3)) && isPunct(T(j + 4), "=") && T(j + 5) && T(j + 5).type === "number")
            counters[T(j + 3).value] = j + 3;

    // A counter (or index) given another value anywhere else is not a counter: "k = 'constructor'"
    // after its loop would open [k].
    for (j = 0; j < tokens.length; j++)
        if (isName(T(j)) && counters.hasOwnProperty(T(j).value) && counters[T(j).value] !== j && (isPunct(T(j + 1), "=") || isPunct(T(j + 1), "+=") || isPunct(T(j + 1), "-=") || isName(T(j - 1), "var") || isName(T(j - 1), "let") || isName(T(j - 1), "const")) && !isPunct(T(j - 1), "."))
            counters[T(j).value] = false;

    for (j = 0; j < tokens.length; j++) {
        var t = T(j);
        var before = T(j - 1);
        var after = T(j + 1);
        // ---- imports
        if (isName(t, "import") && (!before || isPunct(before, ";") || before.line < t.line)) {
            var target = after;
            if (target && target.type === "string") {
                add(t.line, "import \"" + target.value + "\": imports of files or folders are not allowed");
                continue;
            }
            var module = "";
            var k2 = j + 1;
            while (T(k2) && (isName(T(k2)) || isPunct(T(k2), ".")) && T(k2).line === t.line) {
                module += T(k2).value;
                k2++;
            }
            if (ALLOWED_MODULES.indexOf(module) === -1)
                add(t.line, "import " + module + ": not an allowed module");

            continue;
        }
        if (t.type === "name") {
            var memberOf = isPunct(before, ".") ? T(j - 2) : null;
            // ---- names never allowed (a property named like one, e.g. "exit:", is fine in QML only
            // when it is not reached: so they are refused everywhere)
            if (FORBIDDEN_NAMES.hasOwnProperty(t.value)) {
                // "do" / "while" only as statements; QML has no property called so.
                add(t.line, t.value + ": " + FORBIDDEN_NAMES[t.value]);
                continue;
            }
            // ---- Qt.<member>
            if (t.value === "Qt" && !memberOf) {
                if (!isPunct(after, ".") || !isName(T(j + 2))) {
                    add(t.line, "Qt: only Qt.<function> may be used");
                    continue;
                }
                var member = T(j + 2).value;
                if (!/^[A-Z]/.test(member) && QT_ALLOWED.indexOf(member) === -1)
                    add(t.line, "Qt." + member + ": not allowed in a widget");

                continue;
            }
            // ---- parent: never climbed
            if (t.value === "parent") {
                if (isPunct(before, ".")) {
                    add(t.line, ".parent: a widget may not climb out of itself");
                    continue;
                }
                if (isPunct(after, ".")) {
                    var pm = T(j + 2);
                    if (!pm || pm.type !== "name" || PARENT_MEMBERS.indexOf(pm.value) === -1)
                        add(t.line, "parent." + (pm ? pm.value : "") + ": only parent's size, place and anchor lines may be used");

                    continue;
                }
                // As a value: "anchors.fill: parent", "anchors.centerIn: parent", "anchors.left: parent.left"
                var bindingOf = isPunct(before, ":") ? T(j - 2) : null;
                var isAnchor = bindingOf && bindingOf.type === "name" && ["fill", "centerIn"].indexOf(bindingOf.value) !== -1 && isPunct(T(j - 3), ".") && isName(T(j - 4), "anchors");
                var endsHere = !after || isPunct(after, ";") || isPunct(after, "}") || after.line > t.line;
                if (!(isAnchor && endsHere))
                    add(t.line, "parent: may only be used as parent.<size or anchor> or as an anchor");

                continue;
            }
            // ---- going online
            if (t.value === "XMLHttpRequest") {
                if (!allowNetwork)
                    add(t.line, "XMLHttpRequest: goes online (Network is off)", true);

                continue;
            }
            // ---- QML properties that take an address: the value must be a string, written out
            if (URL_PROPERTIES.indexOf(t.value) !== -1 && isPunct(after, ":") && !memberOf) {
                var v = T(j + 2);
                var w = T(j + 3);
                var ownItem = isName(v) && ids[v.value] === true && (!w || isPunct(w, ";") || isPunct(w, "}") || w.line > v.line);
                if (!ownItem && !startsWithAddress(v, true))
                    add(t.line, t.value + ": an address must start written out (\"https://host/...\"), not computed");

                continue;
            }
            // ---- XMLHttpRequest's open(method, address): the address starts written out
            if (t.value === "open" && isPunct(before, ".") && isPunct(after, "(") && !isPunct(T(j + 2), ")")) {
                var comma = j + 2;
                var level = 0;
                while (T(comma) && !(level === 0 && isPunct(T(comma), ","))) {
                    if (isPunct(T(comma), "("))
                        level++;

                    if (isPunct(T(comma), ")")) {
                        if (level === 0)
                            break;

                        level--;
                    }
                    comma++;
                }
                if (isPunct(T(comma), ",") && !startsWithAddress(T(comma + 1), false))
                    add(t.line, "open(): the address must start written out (\"https://host/...\"), not computed");

                continue;
            }
            // ---- limits
            if ((t.value === "width" || t.value === "height" || t.value === "implicitWidth" || t.value === "implicitHeight") && isPunct(after, ":") && T(j + 2) && T(j + 2).type === "number" && T(j + 2).value > MAX_SIZE) {
                add(t.line, t.value + ": " + T(j + 2).value + " is larger than " + MAX_SIZE);
                continue;
            }
            if (t.value === "interval" && isPunct(after, ":") && T(j + 2) && T(j + 2).type === "number" && T(j + 2).value < MIN_INTERVAL) {
                add(t.line, "interval: " + T(j + 2).value + " ms is shorter than " + MIN_INTERVAL + " ms");
                continue;
            }
            if ((t.value === "emitRate" || t.value === "maximumEmitted" || t.value === "count") && isPunct(after, ":") && T(j + 2) && T(j + 2).type === "number" && T(j + 2).value > MAX_PARTICLES) {
                add(t.line, t.value + ": " + T(j + 2).value + " is more than " + MAX_PARTICLES);
                continue;
            }
            // ---- for loops: an end that is a number up to MAX_LOOP or a .length / .count
            if (t.value === "for" && isPunct(after, "(")) {
                checkFor(tokens, j, add);
                continue;
            }
        }
        if (t.type === "string") {
            var kind = addressKind(t.value);
            if (kind === "other")
                add(t.line, "\"" + t.value.slice(0, 40) + "\": only http(s) addresses are allowed");
            else if (kind === "web" && !allowNetwork)
                add(t.line, "\"" + t.value.slice(0, 40) + "\": loads from the Internet (Network is off)", true);
            // A string with a scheme glued from pieces ("fi" + "le:") is caught by its pieces:
            // "le:..." has a scheme too. A bare "file" next to "+" and a string with ":" is refused:
            if (/^[a-z]+$/i.test(t.value) && isPunct(after, "+") && T(j + 2) && T(j + 2).type === "string" && /^[a-z0-9+.\-]*:/i.test(T(j + 2).value))
                add(t.line, "\"" + t.value + "\" + \"" + T(j + 2).value.slice(0, 20) + "\": an address glued from pieces");

            if (FORBIDDEN_NAMES.hasOwnProperty(t.value) && isPunct(before, "["))
                add(t.line, "[\"" + t.value + "\"]: " + FORBIDDEN_NAMES[t.value]);

            continue;
        }
        // ---- [ ] after a value: what is inside must be a number, a plain string or a counter
        if (isPunct(t, "[") && before && (before.type === "name" && ["return", "typeof", "case", "in", "of", "new", "delete", "void", "var", "let", "const"].indexOf(before.value) === -1 || isPunct(before, ")") || isPunct(before, "]") || before.type === "string")) {
            var depth = 0;
            var ok = true;
            for (var q = j + 1; q < tokens.length; q++) {
                var u = T(q);
                if (isPunct(u, "["))
                    depth++;

                if (isPunct(u, "]")) {
                    if (depth === 0)
                        break;

                    depth--;
                }
                var fine = u.type === "number" || (u.type === "string" && !FORBIDDEN_NAMES.hasOwnProperty(u.value) && q === j + 1 && isPunct(T(q + 1), "]")) || (u.type === "name" && counters.hasOwnProperty(u.value) && counters[u.value] !== false) || (isPunct(u) && ["+", "-", "*", "/", "%", "(", ")"].indexOf(u.value) !== -1);
                if (!fine) {
                    ok = false;
                    break;
                }
            }
            if (!ok)
                add(t.line, "[ ]: only a number, a written-out name or a loop counter may go between [ ]");

        }
    }
    problems.sort(function(a, b) {
        return a.line - b.line;
    });
    // One line per problem kind and line.
    var seen = {};
    return problems.filter(function(p) {
        var key = p.line + "|" + p.message;
        if (seen[key])
            return false;

        seen[key] = true;
        return true;
    });
}

// A value starting with a written-out web address string ("https://host/..." + ...); orEmpty: "" too.
// (Whether the Network allows it is checked on the string itself.)
function startsWithAddress(token, orEmpty) {
    if (!token || token.type !== "string")
        return false;

    return addressKind(token.value) === "web" || (orEmpty && token.value === "");
}

// for ( ... ; <end> ; ... ): the end compares with a number up to MAX_LOOP, or with x.length / x.count.
// for (x in y) and for (x of y) go over what is there.
function checkFor(tokens, j, add) {
    var depth = 0;
    var parts = [[]];
    for (var q = j + 1; q < tokens.length; q++) {
        var u = tokens[q];
        if (u.type === "punct" && u.value === "(") {
            depth++;
            if (depth === 1)
                continue;

        }
        if (u.type === "punct" && u.value === ")") {
            depth--;
            if (depth === 0)
                break;

        }
        if (depth === 1 && u.type === "punct" && u.value === ";") {
            parts.push([]);
            continue;
        }
        parts[parts.length - 1].push(u);
    }
    if (parts.length === 1)
        return ;

    // for (x in / of y)
    var cond = parts[1] || [];
    var numbers = cond.filter(function(u) {
        return u.type === "number";
    });
    var bounded = cond.some(function(u, k) {
        return u.type === "name" && (u.value === "length" || u.value === "count") && k > 0 && cond[k - 1].type === "punct" && cond[k - 1].value === ".";
    }) || (numbers.length > 0 && numbers.every(function(u) {
        return u.value <= MAX_LOOP;
    }));
    if (cond.length === 0 || !bounded)
        add(tokens[j].line, "for: a loop needs an end (a number up to " + MAX_LOOP + " or a .length)");

}

// Refused only for going online (Network off): the workbench then asks whether to allow it.
function onlyNetwork(problems) {
    return problems.length > 0 && problems.every(function(p) {
        return p.network === true;
    });
}

// "Line 3: import NERvGear: not an allowed module; ..."
function describe(problems) {
    return problems.map(function(p) {
        return "Line " + p.line + ": " + p.message;
    }).join("\n");
}
