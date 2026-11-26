.pragma library

// A Seedling widget's own settings and memory ("Seedling Development Plan.md", section 9). The code
// only declares them in comments; Seedling reads the declarations here and, from outside the sandbox,
// gives the values to the created item. Nothing in the code is run for it.
//
//   // @name Todo                      the widget's name (SAO Utils' menu, the Settings window)
//   // @setting Font size | 12 - 48    a setting of the property on the next line
//   property int fontSize: 16
//   // @setting Theme | Light / Dark   a choice
//   property string theme: "Light"
//   // @keep                           remembered between starts
//   property var todos: []
//
// Only properties of the root object count. parse(code) returns
// {name, settings: [{name, type, label, min, max, choices, line}], keeps: [{name, type, line}],
//  notes: [{line, message}]} (notes: declarations that do not take effect, and why).

var MAX_SETTINGS = 20;
var MAX_KEEPS = 20;
var MAX_TEXT = 500;
var MAX_KEEP_BYTES = 65536;
var MAX_NAME = 40;

// @yui <key>: what Yui (MHCP-YUI) tells about herself and you, read only; fast: every second (timers),
// else every 10 s. A widget that reads them may not go online (guard).
var YUI_KEYS = {
    "companion_days": false,
    "mood": false,
    "mood_text": false,
    "mood_history": false,
    "boss_raid": true,
    "raid_timer": true,
    "raid_cleared": true,
    "next_alarm": false,
    "next_alarm_text": false,
    "quest_log": false,
    "heart_core": false,
    "col_ledger": false,
    "latest_report": false
};
var YUI_TYPES = ["string", "int", "real", "double", "bool", "var"];

var SETTING_TYPES = ["string", "int", "real", "double", "bool", "color"];
var KEEP_TYPES = ["string", "int", "real", "double", "bool", "var"];
// Address properties: never set from outside (the safety check's address rule stays whole).
var ADDRESS_NAMES = ["source", "url", "baseUrl", "fontSource"];

// The brace depth at the start of each line (strings and comments skipped). Depth 1: inside the root.
function lineDepths(text) {
    var depths = [0];
    var depth = 0;
    var i = 0;
    var n = text.length;
    while (i < n) {
        var c = text.charAt(i);
        if (c === "\n") {
            depths.push(depth);
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
            for (var k = i; k < end; k++)
                if (text.charAt(k) === "\n")
                    depths.push(depth);

            i = end;
            continue;
        }
        if (c === "\"" || c === "'" || c === "`") {
            i++;
            while (i < n && text.charAt(i) !== c) {
                if (text.charAt(i) === "\\")
                    i++;
                else if (text.charAt(i) === "\n")
                    depths.push(depth);
                i++;
            }
            i++;
            continue;
        }
        if (c === "{")
            depth++;
        else if (c === "}")
            depth--;
        i++;
    }
    return depths;
}

// "Label | 12 - 48" / "Label | A / B / C" -> {label, min, max, choices}
function readSpec(rest) {
    var bar = rest.search(/[|｜]/);
    var label = (bar === -1 ? rest : rest.slice(0, bar)).trim();
    var spec = bar === -1 ? "" : rest.slice(bar + 1).trim();
    var out = {
        "label": label,
        "min": null,
        "max": null,
        "choices": null
    };
    if (!spec)
        return out;

    var range = /^(-?\d+(?:\.\d+)?)\s*(?:-|~|～|到|to)\s*(-?\d+(?:\.\d+)?)$/i.exec(spec);
    if (range) {
        out.min = Math.min(Number(range[1]), Number(range[2]));
        out.max = Math.max(Number(range[1]), Number(range[2]));
        return out;
    }
    var choices = spec.split(/\s*[\/、,，]\s*/).map(function(s) {
        return s.trim();
    }).filter(function(s) {
        return s !== "";
    });
    if (choices.length > 0)
        out.choices = choices;

    return out;
}

function typeOf(type) {
    return type === "double" ? "real" : type;
}

function parse(code) {
    var text = String(code || "");
    var lines = text.split("\n");
    var depths = lineDepths(text);
    var result = {
        "name": "",
        "settings": [],
        "keeps": [],
        "yuis": [],
        "notes": []
    };
    var note = function(line, message) {
        result.notes.push({
            "line": line,
            "message": message
        });
    };
    var taken = {};
    for (var i = 0; i < lines.length; i++) {
        var m = /^\s*\/\/\s*@(name|setting|keep|yui)\b\s*[:：]?\s*(.*?)\s*$/i.exec(lines[i]);
        if (!m)
            continue;

        var kind = m[1].toLowerCase();
        var rest = m[2];
        var at = i + 1;
        if (kind === "name") {
            if (!result.name && rest)
                result.name = rest.slice(0, MAX_NAME);

            continue;
        }
        // The property it is for: the next line that is not empty or a comment.
        var j = i + 1;
        while (j < lines.length && (/^\s*$/.test(lines[j]) || /^\s*\/\//.test(lines[j])))
            j++;
        var p = j < lines.length ? /^\s*(?:readonly\s+)?property\s+([\w.<>]+)\s+(\w+)\b/.exec(lines[j]) : null;
        if (!p) {
            note(at, "@" + kind + ": the next line must be a property");
            continue;
        }
        var type = p[1];
        var name = p[2];
        if (depths[j] !== 1) {
            note(at, "@" + kind + " " + name + ": only properties of the outermost item count");
            continue;
        }
        if (/^\s*readonly\b/.test(lines[j])) {
            note(at, "@" + kind + " " + name + ": a readonly property cannot be set");
            continue;
        }
        if (ADDRESS_NAMES.indexOf(name) !== -1 || type === "url") {
            note(at, "@" + kind + " " + name + ": addresses cannot be settings or kept");
            continue;
        }
        if (taken[kind + ":" + name]) {
            note(at, "@" + kind + " " + name + ": declared twice");
            continue;
        }
        if (kind === "yui") {
            var key = rest.split(/\s+/)[0];
            if (!YUI_KEYS.hasOwnProperty(key)) {
                note(at, "@yui " + name + ": \"" + key + "\" is not something Yui tells (" + Object.keys(YUI_KEYS).join(", ") + ")");
                continue;
            }
            if (YUI_TYPES.indexOf(type) === -1) {
                note(at, "@yui " + name + ": Yui's values are a string, int, real, bool or var (not " + type + ")");
                continue;
            }
            result.yuis.push({
                "name": name,
                "type": typeOf(type),
                "key": key,
                "fast": YUI_KEYS[key],
                "line": at
            });
        } else if (kind === "setting") {
            if (SETTING_TYPES.indexOf(type) === -1) {
                note(at, "@setting " + name + ": a setting is a string, int, real, bool or color (not " + type + ")");
                continue;
            }
            if (result.settings.length >= MAX_SETTINGS) {
                note(at, "@setting " + name + ": more than " + MAX_SETTINGS + " settings");
                continue;
            }
            var spec = readSpec(rest);
            if (spec.choices && typeOf(type) !== "string") {
                note(at, "@setting " + name + ": choices are for a string");
                spec.choices = null;
            }
            if (spec.min !== null && ["int", "real"].indexOf(typeOf(type)) === -1) {
                note(at, "@setting " + name + ": a range is for a number");
                spec.min = spec.max = null;
            }
            result.settings.push({
                "name": name,
                "type": typeOf(type),
                "label": spec.label || name,
                "min": spec.min,
                "max": spec.max,
                "choices": spec.choices,
                "line": at
            });
        } else {
            if (KEEP_TYPES.indexOf(type) === -1) {
                note(at, "@keep " + name + ": kept values are a string, int, real, bool or var (not " + type + ")");
                continue;
            }
            if (result.keeps.length >= MAX_KEEPS) {
                note(at, "@keep " + name + ": more than " + MAX_KEEPS + " kept values");
                continue;
            }
            result.keeps.push({
                "name": name,
                "type": typeOf(type),
                "line": at
            });
        }
        taken[kind + ":" + name] = true;
    }
    return result;
}

// A value made to fit its declaration: {ok, value}. Strings cut to MAX_TEXT, numbers to their range,
// a choice only one of them, a color only #RGB / #RRGGBB / #AARRGGBB or a color name, var only JSON.
function coerce(decl, value) {
    var bad = {
        "ok": false,
        "value": undefined
    };
    if (value === undefined || value === null)
        return bad;

    var type = decl.type;
    if (type === "string") {
        var s = String(value).slice(0, MAX_TEXT);
        if (decl.choices && decl.choices.indexOf(s) === -1)
            return bad;

        return {
            "ok": true,
            "value": s
        };
    }
    if (type === "int" || type === "real") {
        var n = Number(value);
        if (!isFinite(n))
            return bad;

        if (type === "int")
            n = Math.round(n);

        if (decl.min !== null && decl.min !== undefined)
            n = Math.max(decl.min, n);

        if (decl.max !== null && decl.max !== undefined)
            n = Math.min(decl.max, n);

        return {
            "ok": true,
            "value": n
        };
    }
    if (type === "bool")
        return {
        "ok": true,
        "value": value === true || value === "true"
    };

    if (type === "color") {
        var c = String(value).trim();
        if (!/^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(c) && !/^[a-z]{3,20}$/i.test(c))
            return bad;

        return {
            "ok": true,
            "value": c
        };
    }
    if (type === "var") {
        try {
            var json = JSON.stringify(value);
            if (json === undefined)
                return bad;

            return {
                "ok": true,
                "value": JSON.parse(json)
            };
        } catch (e) {
            return bad;
        }
    }
    return bad;
}

// Stored values ({name: {"t": type, "v": value}}) that still fit the declarations (same name and
// type): kept when the code changes, the rest dropped.
function carry(stored, decls) {
    var out = {};
    if (!stored || typeof stored !== "object")
        return out;

    decls.forEach(function(decl) {
        var entry = stored[decl.name];
        if (entry && entry.t === decl.type) {
            var fit = coerce(decl, entry.v);
            if (fit.ok)
                out[decl.name] = {
                "t": decl.type,
                "v": fit.value
            };

        }
    });
    return out;
}

// The kept values of item as stored ({name: {"t", "v"}}), or null when they are larger than
// MAX_KEEP_BYTES (then nothing is saved).
function snapshot(item, keeps) {
    var out = {};
    for (var i = 0; i < keeps.length; i++) {
        var fit = coerce(keeps[i], item[keeps[i].name]);
        if (fit.ok)
            out[keeps[i].name] = {
            "t": keeps[i].type,
            "v": fit.value
        };

    }
    return JSON.stringify(out).length > MAX_KEEP_BYTES ? null : out;
}

// Gives the stored values to item (as their declarations allow). Returns how many were given.
function apply(item, decls, stored) {
    var given = 0;
    var fitting = carry(stored, decls);
    decls.forEach(function(decl) {
        if (fitting.hasOwnProperty(decl.name)) {
            try {
                item[decl.name] = fitting[decl.name].v;
                given++;
            } catch (e) {
                console.log("Seedling: cannot set " + decl.name + ":", e);
            }
        }
    });
    return given;
}

// A widget that reads Yui's data (@yui) may not go online, Network or not: what it knows of you must
// not leave. Check it with allowNetwork false; this turns its "goes online" problems into refusals
// that are not about Network (so nothing asks to allow it).
function networkAllowed(decl, allowNetwork) {
    return allowNetwork === true && decl.yuis.length === 0;
}

function guard(problems, decl) {
    if (decl.yuis.length === 0)
        return problems;

    return problems.map(function(p) {
        return p.network ? {
            "line": p.line,
            "message": p.message.replace(/ \(Network is off\)$/, "") + " (this widget reads Yui's data, so it may not go online)",
            "network": false
        } : p;
    });
}

// Yui's values given to item: all of them, or only the fast ones (timers). writer: MHCP-YUI (its
// linkValue(key) -> {current}), or null (then nothing changes: the code's defaults stay).
function feed(item, yuis, writer, fastOnly) {
    if (!item || !writer || typeof writer.linkValue !== "function")
        return ;

    for (var i = 0; i < yuis.length; i++) {
        if (fastOnly && !yuis[i].fast)
            continue;

        var found = null;
        try {
            found = writer.linkValue(yuis[i].key);
        } catch (e) {
            found = null;
        }
        if (!found)
            continue;

        var fit = coerce({
            "type": yuis[i].type,
            "min": null,
            "max": null,
            "choices": null
        }, found.current);
        if (fit.ok && JSON.stringify(item[yuis[i].name]) !== JSON.stringify(fit.value))
            item[yuis[i].name] = fit.value;

    }
}
