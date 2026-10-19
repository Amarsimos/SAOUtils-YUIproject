.pragma library

// Yui features that do not depend on the UI: control tags in replies, the "System Call" easter
// egg, canned lines and the extra instructions added to the system prompt.

// Expressions the AI may choose with <<emotion:...>>; "normal" uses the main character image.
var EMOTIONS = ["normal", "happy", "sad", "surprised", "angry", "shy"];

// Yui's Heart (結衣の心), the long-term memory, named after the crystal Kirito saved Yui's core
// program in. Each entry is {id, text, kind, created, updated, lastUsed, uses, pinned}:
//   kind "core"      the heart core: who the user is, how to call them, important promises. At most
//                    MAX_CORE, all sent with every request (kept first and unchanged, so providers
//                    can cache that part of the prompt).
//   kind "fragment"  everything else, unlimited; only the RECALL_COUNT fragments that share the most
//                    keywords with the user's message are sent.
// The complete chat history is kept separately and never sent.
var MAX_CORE = 20;
var RECALL_COUNT = 5;
// Two memories at least this similar (see memorySimilarity) are the same memory: the newer text
// replaces the older one instead of being added. Kept high, since short memories that differ in one
// word ("喜欢猫" / "喜欢狗") already share most keywords; real changes go through <<forget:>>.
var SAME_MEMORY = 0.8;

// Load levels of the crystal and the Cardinal bars: 0 green (normal), 1 yellow (notice), 2 red (high).
// Default [yellow, red] thresholds in percent; GPU is higher because games and video keep it busy,
// memory lower because a full memory slows the whole computer. Editable in the System Console.
var LOAD_THRESHOLDS = {
    "cpu": [70, 90],
    "gpu": [85, 97],
    "ram": [75, 90]
};
// A level changes only after the new one held for LOAD_HOLD samples (one per second), and drops only
// once the value is LOAD_HYSTERESIS points below the threshold that raised it, so short peaks and
// values hovering at a threshold do not make the crystal flicker.
var LOAD_HOLD = 5;
var LOAD_HYSTERESIS = 5;

// [yellow, red] thresholds of a metric: the user's (settings.load_thresholds) when valid, else the default.
function loadThresholds(custom, metric) {
    var pair = custom && custom[metric];
    if (pair && pair.length === 2 && pair[0] > 0 && pair[1] > pair[0] && pair[1] <= 100)
        return [Number(pair[0]), Number(pair[1])];

    return LOAD_THRESHOLDS[metric].slice();
}

// Level of a value right now; current: the level shown so far (for the hysteresis).
function loadLevel(value, pair, current) {
    if (!(value >= 0))
        return 0;

    var level = value >= pair[1] ? 2 : value >= pair[0] ? 1 : 0;
    // Stay at the current (higher) level until the value is clearly below its threshold.
    if (level < (current || 0) && value >= pair[current - 1] - LOAD_HYSTERESIS)
        return current;

    return level;
}

// One sample of a metric: state {level, candidate, count} -> the next state. The shown level follows
// a new one once it held for LOAD_HOLD samples in a row.
function loadStep(state, value, pair) {
    state = state || {
        "level": 0,
        "candidate": 0,
        "count": 0
    };
    var level = loadLevel(value, pair, state.level);
    var count = level === state.candidate ? state.count + 1 : 1;
    return {
        "level": level !== state.level && count >= LOAD_HOLD ? level : state.level,
        "candidate": level,
        "count": count
    };
}

// Control tags the AI may append to a reply:
//   <<emotion:happy>>  <<memory:Papa likes cats>>  <<open:https://...>>  <<search:words>>
//   <<launch:notepad>>  <<find:report.docx>>  <<kill:chrome.exe>>
function tagPattern() {
    return /<<\s*(emotion|memory|core|forget|open|search|launch|find|kill)\s*[:：]\s*([^<>]*?)\s*>>/gi;
}

// Processes <<kill:>> always refuses to close (Immortal Object): core Windows processes and SAO
// Utils itself. Users can protect more in the System Console, but cannot remove these.
var PROTECTED_PROCESSES = ["system", "smss.exe", "csrss.exe", "wininit.exe", "winlogon.exe", "services.exe", "lsass.exe", "svchost.exe", "dwm.exe", "explorer.exe", "fontdrvhost.exe", "registry", "sao utils.exe", "nervlaunch.exe", "nervservice.exe", "nervstartup.exe", "nervsteam.exe", "nervwebkit.exe"];

// Process name for taskkill ("chrome" -> "chrome.exe"), or "" when it is not a plain name.
function processName(value) {
    var name = String(value).trim();
    if (!/^[A-Za-z0-9 ._()\-]+$/.test(name))
        return "";

    return /\.exe$/i.test(name) ? name : name + ".exe";
}

// userProtected: extra names the user protected (System Console).
function isProtectedProcess(name, userProtected) {
    name = String(name).toLowerCase();
    return PROTECTED_PROCESSES.indexOf(name) !== -1 || processListHas(userProtected, name);
}

// Lower-case process names of a user list (whitelist, extra protected processes) with "x" -> "x.exe",
// invalid names and duplicates removed.
function processList(names) {
    var result = [];
    (names || []).forEach(function(value) {
        var name = processName(value).toLowerCase();
        if (name && result.indexOf(name) === -1)
            result.push(name);
    });
    return result;
}

function processListHas(names, name) {
    return processList(names).indexOf(processName(name).toLowerCase()) !== -1;
}

// Command lines run with NVG.SystemCall.command(). kill asks the program to close (no /F). find runs
// the package's scripts/find.bat (scriptFile): it uses esPath (System Console) or looks for es.exe in
// PATH and the usual install folders, writes up to 20 results as UTF-8 text to resultFile and its exit
// code and the es.exe it used to statusFile (see parseFindStatus).
function actionCommand(action, resultFile, esPath, statusFile, scriptFile) {
    if (action.type === "find") {
        var es = String(esPath || "").replace(/"/g, "").trim();
        return 'cmd /c ""' + scriptFile + '" "' + es + '" "' + action.target + '" "' + resultFile + '" "' + statusFile + '""';
    }

    if (action.type === "kill")
        return 'taskkill /IM "' + action.target + '"';

    return "";
}

// The status file of scripts/find.bat: {code: es.exe exit code as text, or "missing" when no es.exe
// was found; es: the es.exe path used ("" when none)}, or null while it has not been written.
function parseFindStatus(text) {
    var code = /code=(\S+)/.exec(String(text || ""));
    if (!code)
        return null;

    var es = /es="([^"]*)"/.exec(text);
    return {
        "code": code[1],
        "es": es ? es[1] : ""
    };
}

// What can be clicked in a chat message: web links, the words 「System Console」 (or 「Option」 in older chats; they open the System Console) and
// Windows paths such as D:\Tools\a b.txt — a drive letter, then anything up to the end of the line, a
// quote or bracket, or Chinese text / punctuation (so "文件在 D:\a.txt 里" links only the path).
var LINK_PATTERN = /(https?:\/\/[^\s"'<>「」『』（）()\u3000-\u303F\u4E00-\u9FFF\uFF00-\uFFEF]+)|(「System Console」|「Option」)|([A-Za-z]:[\\/][^\r\n"'<>|*?「」『』（）()\u3000-\u303F\u4E00-\u9FFF\uFF00-\uFFEF]*)/g;

function escapeHtml(text) {
    return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

// Rich text of a message with its links (see LINK_PATTERN) made clickable — paths as "yui-path:",
// 「Option」 as "yui-option:" — or "" when it has none (the message is then shown as plain text).
// Line breaks and spaces are kept as they are.
function linkify(text, linkColor) {
    text = String(text || "");
    var html = "";
    var last = 0;
    var found = false;
    var match;
    LINK_PATTERN.lastIndex = 0;
    while ((match = LINK_PATTERN.exec(text)) !== null) {
        // Trailing spaces and sentence punctuation are not part of a link.
        var shown = match[2] ? match[0] : match[0].replace(/[\s.,;:!]+$/, "");
        var href = match[1] ? shown : match[2] ? "yui-option:" : "yui-path:" + encodeURIComponent(shown);
        if (match[3] && shown.length < 4)
            continue;

        html += escapeHtml(text.slice(last, match.index));
        html += '<a href="' + escapeHtml(href) + '" style="color:' + linkColor + '">' + escapeHtml(shown) + "</a>";
        last = match.index + shown.length;
        found = true;
    }
    if (!found)
        return "";

    html += escapeHtml(text.slice(last));
    return '<span style="white-space:pre-wrap">' + html.replace(/\r?\n/g, "<br>") + "</span>";
}

// The Windows path of a "yui-path:" link ("" for any other link).
function linkedPath(link) {
    link = String(link || "");
    return link.indexOf("yui-path:") === 0 ? decodeURIComponent(link.slice(9)).replace(/\//g, "\\") : "";
}

// Widget type of this package (package.json: com.amarsimos.widget.yui, /widget/mhcp-yui), as SAO Utils
// names it. A Seedling widget saved to "My Widgets" is this widget with seedling_widget and seedling_code in its
// settings.
var WIDGET_SOURCE = "nvg://yui.widget.amarsimos.com/widget/mhcp-yui";

// The files of a "My Widgets" preset (Storages/system/widget-preset/<folder>/) for a Seedling widget, in
// the format SAO Utils saves them: preset.json, and settings.xml with each value as JSON text.
// The code is stored URL-encoded (seedling_code_uri): SAO Utils' settings reader lost the line breaks
// of a plain JSON string, joining the code into one line. now: ISO date. Returns {preset, settings}.
function seedlingPresetFiles(title, code, width, height, now) {
    var values = {
        // Marks a saved Seedling widget: only then does the widget start in seedling widget mode.
        "seedling_widget": true,
        "seedling_title": String(title),
        "seedling_code_uri": encodeURIComponent(String(code)),
        "seedling_width": Math.round(width),
        "seedling_height": Math.round(height)
    };
    var lines = ['<?xml version="1.0" encoding="UTF-8"?>', "<map>"];
    for (var key in values)
        lines.push('    <value name="' + key + '">' + escapeHtml(JSON.stringify(values[key])) + "</value>");
    lines.push("</map>", "");
    return {
        "preset": JSON.stringify({
            "create": now,
            "source": WIDGET_SOURCE,
            "title": String(title),
            "settings": "settings.xml",
            "edit": now
        }, null, 2),
        "settings": lines.join("\n")
    };
}

// Seedling's settings were called lab_* before it got its name (Widget Lab). Moves each one to its
// seedling_* name (a value already there wins) and removes the old key; returns whether any moved.
// Also used for widgets placed from "My Widgets" presets saved before the rename.
var SEEDLING_KEYS = ["code", "code_uri", "editor_code", "height", "in_yui", "sized", "slot_x", "slot_y", "title", "widget", "width"];

function migrateSeedlingKeys(settings) {
    var moved = false;
    SEEDLING_KEYS.forEach(function(key) {
        if (settings["lab_" + key] === undefined)
            return ;

        if (settings["seedling_" + key] === undefined)
            settings["seedling_" + key] = settings["lab_" + key];

        delete settings["lab_" + key];
        moved = true;
    });
    return moved;
}

// The QML of a saved Seedling widget's settings (seedling_code_uri, or seedling_code from before it was encoded).
function seedlingCode(settings) {
    if (!settings)
        return "";

    if (settings.seedling_code_uri)
        return decodeURIComponent(settings.seedling_code_uri);

    return String(settings.seedling_code || "");
}

// Lines of an es.exe -export-txt result file (BOM and blank lines removed).
function parseSearchResults(text) {
    return String(text || "").replace(/^\uFEFF/, "").split(/\r?\n/).map(function(line) {
        return line.trim();
    }).filter(function(line) {
        return line.length > 0;
    });
}

// Split a finished reply into the text to show and the tags it carried.
// userProtected: extra protected process names (see isProtectedProcess).
// Search engines for <<search:>> (Cardinal System); %s is the search term.
var SEARCH_ENGINES = [{
    "id": "bing",
    "url": "https://www.bing.com/search?q=%s"
}, {
    "id": "google",
    "url": "https://www.google.com/search?q=%s"
}, {
    "id": "baidu",
    "url": "https://www.baidu.com/s?wd=%s"
}, {
    "id": "duckduckgo",
    "url": "https://duckduckgo.com/?q=%s"
}];

// The search address of a query: the engine with this id, or with "custom" the user's own address
// (an http(s) address containing %s; Bing otherwise).
function searchUrl(engine, custom, query) {
    var template = SEARCH_ENGINES[0].url;
    SEARCH_ENGINES.forEach(function(item) {
        if (item.id === engine)
            template = item.url;

    });
    custom = String(custom || "").trim();
    if (engine === "custom" && /^https?:\/\/[^\s"'<>]+$/i.test(custom) && custom.indexOf("%s") !== -1)
        template = custom;

    return template.split("%s").join(encodeURIComponent(query));
}

// The desktop actions the user can allow or forbid (System Console), and the tags of each.
var ACTION_KINDS = {
    "open": "web",
    "search": "web",
    "launch": "launch",
    "find": "find",
    "kill": "kill"
};

// options (optional): {searchEngine, searchCustom} for the address of <<search:>> (see searchUrl), and
// allowed: {web, launch, find, kill}, false for actions the user forbade (their tags are dropped and
// result.disabled names the first one).
function parseReply(text, userProtected, options) {
    options = options || {};
    var allowed = options.allowed || {};
    var result = {
        "text": "",
        "emotion": "",
        // <<memory:>> fragments, <<core:>> heart core entries, <<forget:>> memories to remove.
        "memories": [],
        "cores": [],
        "forgets": [],
        "action": null,
        // A <<kill:>> refused because the process is protected.
        "blocked": "",
        // The type of an action tag dropped because the user forbade it ("" when none).
        "disabled": ""
    };
    result.text = String(text).replace(tagPattern(), function(all, kind, value) {
        kind = kind.toLowerCase();
        value = value.trim();
        if (!value)
            return "";

        // Auto Memory off (Yui's Heart): memory tags are dropped.
        if ((kind === "memory" || kind === "core" || kind === "forget") && allowed.memory === false)
            return "";

        if (ACTION_KINDS[kind] && allowed[ACTION_KINDS[kind]] === false) {
            result.disabled = result.disabled || kind;
            return "";
        }
        if (kind === "emotion") {
            var emotion = value.toLowerCase();
            if (EMOTIONS.indexOf(emotion) !== -1)
                result.emotion = emotion;
        } else if (kind === "memory") {
            result.memories.push(value);
        } else if (kind === "core") {
            result.cores.push(value);
        } else if (kind === "forget") {
            result.forgets.push(value);
        } else if (kind === "open") {
            // Only plain web links: never local files or other schemes.
            if (!result.action && /^https?:\/\/[^\s"'<>]+$/i.test(value))
                result.action = {
                    "type": "open",
                    "target": value,
                    "url": value
                };
        } else if (kind === "search") {
            if (!result.action)
                result.action = {
                    "type": "search",
                    "target": value,
                    "url": searchUrl(options.searchEngine, options.searchCustom, value)
                };
        } else if (kind === "launch") {
            // A program name or path only: no quotes or line breaks.
            if (!result.action && !/["\r\n]/.test(value))
                result.action = {
                    "type": "launch",
                    "target": value
                };
        } else if (kind === "find") {
            var query = value.replace(/"/g, "").trim();
            if (!result.action && query)
                result.action = {
                    "type": "find",
                    "target": query
                };
        } else if (kind === "kill") {
            var name = processName(value);
            if (name && isProtectedProcess(name, userProtected))
                result.blocked = name;
            else if (!result.action && name)
                result.action = {
                    "type": "kill",
                    "target": name
                };
        }
        return "";
    }).replace(/[ \t]+\n/g, "\n").trim();
    return result;
}

// Text to show while a reply is still streaming: complete tags are removed and a tag that has
// started but not finished yet ("<<emot") is hidden until it is complete.
function displayText(partial) {
    var text = String(partial);
    var cut = text.lastIndexOf("<<");
    if (cut !== -1 && text.indexOf(">>", cut) === -1)
        text = text.substring(0, cut);

    return text.replace(tagPattern(), "").trim();
}

// Keywords of a text for recall and dedupe: Latin words and numbers whole, Chinese / Japanese runs
// as overlapping two-character pieces ("喜欢猫" -> 喜欢, 欢猫), so no word list is needed.
function memoryKeywords(text) {
    var keywords = [];
    (String(text || "").toLowerCase().match(/[a-z0-9]+|[\u3040-\u30ff\u3400-\u9fff]+/g) || []).forEach(function(run) {
        var pieces = [];
        if (/^[a-z0-9]/.test(run))
            pieces = [run];
        else if (run.length === 1)
            pieces = [run];
        else
            for (var i = 0; i + 1 < run.length; i++)
                pieces.push(run.substr(i, 2));
        pieces.forEach(function(piece) {
            if (keywords.indexOf(piece) === -1)
                keywords.push(piece);
        });
    });
    return keywords;
}

// 0..1: shared keywords over all keywords of both texts (1 when one text contains the other).
function memorySimilarity(a, b) {
    a = String(a || "").trim();
    b = String(b || "").trim();
    if (!a || !b)
        return 0;

    if (a.indexOf(b) !== -1 || b.indexOf(a) !== -1)
        return 1;

    var ka = memoryKeywords(a);
    var kb = memoryKeywords(b);
    var shared = ka.filter(function(k) {
        return kb.indexOf(k) !== -1;
    }).length;
    var all = ka.length + kb.length - shared;
    return all > 0 ? shared / all : 0;
}

function copyEntries(entries) {
    return (entries || []).map(function(entry) {
        var copy = {};
        for (var key in entry)
            copy[key] = entry[key];
        return copy;
    });
}

// Yui's Heart after writing one memory (pure: returns new entries; new ones have no id). A memory
// like an existing one replaces its text (and a core write promotes it); otherwise it is added.
// When the core is over capacity (default MAX_CORE), the least recently used unpinned core entries
// become fragments.
function rememberMemory(entries, text, kind, now, capacity) {
    entries = copyEntries(entries);
    text = String(text || "").trim();
    if (!text)
        return entries;

    kind = kind === "core" ? "core" : "fragment";
    var best = null;
    var bestScore = 0;
    entries.forEach(function(entry) {
        var score = memorySimilarity(entry.text, text);
        if (score > bestScore) {
            best = entry;
            bestScore = score;
        }
    });
    var written;
    if (best && bestScore >= SAME_MEMORY) {
        best.text = text;
        best.updated = now;
        best.lastUsed = now;
        if (kind === "core")
            best.kind = "core";

        written = best;
    } else {
        written = {
            "id": null,
            "text": text,
            "kind": kind,
            "created": now,
            "updated": now,
            "lastUsed": now,
            "uses": 0,
            "pinned": false
        };
        entries.push(written);
    }
    return fitCore(entries, capacity, written);
}

// The entries with at most capacity (default MAX_CORE) core entries: the least recently used unpinned
// ones (never keep) become fragments. Changes the given entries.
function fitCore(entries, capacity, keep) {
    var movable = entries.filter(function(entry) {
        return entry.kind === "core" && !entry.pinned && entry !== keep;
    }).sort(function(x, y) {
        return (x.lastUsed || 0) - (y.lastUsed || 0);
    });
    var over = coreMemories(entries).length - (capacity || MAX_CORE);
    for (var i = 0; i < over && i < movable.length; i++)
        movable[i].kind = "fragment";
    return entries;
}

// Yui's Heart without the memories <<forget:>> names (pure). Returns the removed entries too.
function forgetMemory(entries, text) {
    var kept = [];
    var removed = [];
    copyEntries(entries).forEach(function(entry) {
        if (memorySimilarity(entry.text, text) >= 0.5)
            removed.push(entry);
        else
            kept.push(entry);
    });
    return {
        "entries": kept,
        "removed": removed
    };
}

// Yui's Heart with the memories of an exported file added (pure): memories already remembered (at
// least SAME_MEMORY alike) are skipped, the others keep their kind, dates and pin. Returns
// {entries, added}. A core over capacity (default MAX_CORE) moves its least recently used unpinned
// entries to fragments.
function mergeHeart(entries, imported, capacity) {
    entries = copyEntries(entries);
    var added = 0;
    copyEntries(imported).forEach(function(entry) {
        var text = String(entry.text || "").trim();
        if (!text || entries.some(function(old) {
            return memorySimilarity(old.text, text) >= SAME_MEMORY;
        }))
            return ;

        entries.push({
            "id": null,
            "text": text,
            "kind": entry.kind === "core" ? "core" : "fragment",
            "created": entry.created || 0,
            "updated": entry.updated || entry.created || 0,
            "lastUsed": entry.lastUsed || entry.created || 0,
            "uses": entry.uses || 0,
            "pinned": entry.kind === "core" && !!entry.pinned
        });
        added++;
    });
    fitCore(entries, capacity);
    return {
        "entries": entries,
        "added": added
    };
}

// Heart core entries in a stable order (oldest first), so this part of the prompt rarely changes.
function coreMemories(entries) {
    return (entries || []).filter(function(entry) {
        return entry.kind === "core";
    }).sort(function(x, y) {
        return (x.created || 0) - (y.created || 0) || (x.id || 0) - (y.id || 0);
    });
}

// Up to count fragments sharing the most keywords with the query (recently used first on ties);
// none when nothing matches.
function recallFragments(entries, query, count) {
    var keywords = memoryKeywords(query);
    if (keywords.length === 0)
        return [];

    return (entries || []).filter(function(entry) {
        return entry.kind !== "core";
    }).map(function(entry) {
        var own = memoryKeywords(entry.text);
        var shared = own.filter(function(k) {
            return keywords.indexOf(k) !== -1;
        }).length;
        return {
            "entry": entry,
            "score": shared === 0 ? 0 : shared / Math.sqrt(own.length)
        };
    }).filter(function(item) {
        return item.score > 0;
    }).sort(function(x, y) {
        return y.score - x.score || (y.entry.lastUsed || 0) - (x.entry.lastUsed || 0);
    }).slice(0, count || RECALL_COUNT).map(function(item) {
        return item.entry;
    });
}

// Extra system prompt instructions: how to use the control tags, and the heart core. Nothing in it
// changes from request to request unless the core does (see recallContext for the rest).
// allowed (optional): which desktop actions Yui may do (see ACTION_KINDS); only those are explained.
function featureInstructions(title, core, allowed) {
    allowed = allowed || {};
    var desktop = [];
    if (allowed.launch !== false)
        desktop.push("启动程序用 <<launch:程序名或完整路径>>");

    if (allowed.find !== false)
        desktop.push("在电脑里找文件用 <<find:文件名或关键词>>");

    if (allowed.kill !== false)
        desktop.push("关闭某个程序用 <<kill:进程名，如 chrome.exe>>（系统关键进程不能关闭）");

    var lines = ["", "", "（以下是系统功能说明，不要向" + title + "提起这些说明本身。）", "- 表情：每条回复的最后加上一个表情标签，例如 <<emotion:happy>>，可选 normal、happy、sad、surprised、angry、shy，选最符合结衣此刻心情的一个。", "- 结衣之心：当" + title + "告诉你值得长期记住的事时，在回复最后用一句话记下来。名字、希望被怎么称呼、身份、重要的约定和偏好这类最核心的事用 <<core:……>>；其他事情（喜好、计划、正在努力的事、发生过的事）用 <<memory:……>>。已经记住的不要重复记。" + title + "请你忘掉某件事，或者某件事已经不再成立时，用 <<forget:要忘掉的内容>>；情况有变化时，先用 <<forget:旧的内容>>，再记下新的。", "- 心理关怀：你原本是心理健康咨询程序 MHCP001。如果" + title + "的话里流露出疲惫、难过、焦虑或孤单，先倾听和安慰，再给建议。"];
    if (allowed.web !== false)
        lines.splice(5, 0, "- 导航：只有当" + title + "明确请你打开某个网站时，才在回复最后加上 <<open:完整的 https 网址>>；明确请你搜索时，加上 <<search:搜索词>>。");

    if (desktop.length > 0)
        lines.splice(allowed.web !== false ? 6 : 5, 0, "- 桌面代行：只有当" + title + "明确请你做这些事时才使用，每次都会先请" + title + "确认：" + desktop.join("；") + "。");

    if (allowed.memory === false)
        lines = lines.filter(function(line) {
            return line.indexOf("- 结衣之心：") !== 0;
        });

    if (core && core.length > 0) {
        lines.push("", "结衣之心·心核（关于" + title + "最重要的事）：");
        core.forEach(function(entry) {
            lines.push("- " + entry.text);
        });
    }
    return lines.join("\n");
}

// Memory fragments recalled for this request (placed after the parts that stay the same).
function recallContext(title, fragments) {
    if (!fragments || fragments.length === 0)
        return "";

    return "\n\n结衣之心中和现在的话题有关的回忆（关于" + title + "）：\n" + fragments.map(function(entry) {
        return "- " + entry.text;
    }).join("\n");
}

// "3 小时 20 分钟"-style duration.
function formatDuration(ms) {
    var minutes = Math.max(1, Math.round(ms / 60000));
    if (minutes < 60)
        return minutes + " 分钟";

    var hours = Math.floor(minutes / 60);
    if (hours < 48)
        return hours + " 小时" + (minutes % 60 ? " " + (minutes % 60) + " 分钟" : "");

    return Math.floor(hours / 24) + " 天";
}

function pick(list) {
    return list[Math.floor(Math.random() * list.length)];
}

// Said when the user wakes Yui up by clicking her (no API request needed).
function wakeLine(title) {
    return pick(["唔……" + title + "？结衣刚才在休息呢～ (｡･ω･｡)", "哈啊——欢迎回来，" + title + "！结衣已经重新启动完毕啦！(≧◡≦)", "嗯……？是" + title + "呀！结衣才没有睡着，只是在待机哦～ (〃▽〃)", "系统唤醒完成！" + title + "，有什么需要结衣帮忙的吗？(o^▽^o)"]);
}

// Sacred Arts elements of Underworld (Alicization): command word -> [name, color].
var ELEMENTS = {
    "luminous": ["光素", "#FFF59D"],
    "thermal": ["热素", "#FF7043"],
    "cryogenic": ["冻素", "#4FC3F7"],
    "aerial": ["风素", "#A5D6A7"],
    "aqueous": ["水素", "#4DD0E1"],
    "metallic": ["钢素", "#B0BEC5"],
    "umbra": ["暗素", "#9575CD"]
};

// The "System Call" easter egg. Returns null when the text is not a system call, otherwise
// { reply, effect } where effect is { color, burst } or null.
function systemCall(text, title) {
    var match = /^\s*(?:system\s*call|システムコール|系统呼叫)\s*[,，、.。!！]?\s*(.*)$/i.exec(String(text));
    if (!match)
        return null;

    var command = match[1].toLowerCase().replace(/[.。!！]+$/, "").trim();
    if (command === "")
        return {
            "reply": "嗯？咒语只念了一半哦～" + title + "，后面的指令是什么呢？(・ω・)",
            "effect": null
        };

    if (/inspect\s+entire\s+command\s+list/.test(command))
        return {
            "reply": "系统指令一览 ✧\n· Generate Luminous / Thermal / Cryogenic / Aerial / Aqueous / Metallic / Umbra Element\n· Discharge\n· Burst Element\n格式：System Call, Generate Luminous Element",
            "effect": null
        };

    var generate = /generate\s+(\w+)\s+element/.exec(command);
    if (generate && ELEMENTS[generate[1]]) {
        var element = ELEMENTS[generate[1]];
        return {
            "reply": "哔——！" + element[0] + "因子生成成功！✧ " + title + "的神圣术好厉害！(≧◡≦)",
            "effect": {
                "color": element[1],
                "burst": false
            }
        };
    }
    if (/^(discharge|burst\s+element)/.test(command))
        return {
            "reply": "发射——！！✧✧ 呼……" + title + "，要小心不要伤到自己哦～ (｀・ω・´)",
            "effect": {
                "color": "#FFFFFF",
                "burst": true
            }
        };

    return {
        "reply": "警告！无法识别的系统指令……" + title + "，是不是念错咒语了？试试 System Call, Inspect Entire Command List 吧 (・_・;)",
        "effect": null
    };
}
