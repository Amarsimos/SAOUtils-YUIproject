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
//   <<launch:notepad>>  <<find:report.docx>>  <<kill:chrome.exe>>  <<focus:25>> (Boss Raid)
//   <<mood:4|passed the exam>> (Mental Record)
// Any tag-like <<name:value>>, also misspelled ones (<<emphy:happy>>) and full-width brackets.
function anyTagPattern() {
    return /(?:<<|＜＜|《《)\s*([A-Za-z_]+)\s*[:：]\s*([^<>＜＞《》]*?)\s*(?:>>|＞＞|》》)/g;
}

function tagPattern() {
    return /<<\s*(emotion|memory|core|forget|open|search|launch|find|kill|focus|mood)\s*[:：]\s*([^<>]*?)\s*>>/gi;
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
    var found = false;
    var html = "";
    // Code blocks (```...```) first: shown as they are, in a monospaced box.
    var blocks = /```[^\n]*\n?([\s\S]*?)```/g;
    var last = 0;
    var match;
    while ((match = blocks.exec(text)) !== null) {
        // The line breaks next to a block are its own margins.
        html += formatLines(text.slice(last, match.index).replace(/\n$/, ""), linkColor).html;
        html += '<pre style="font-family:Consolas; background-color:#D3D3D3">' + escapeHtml(match[1].replace(/\n$/, "")) + "</pre>";
        last = match.index + match[0].length;
        if (text.charAt(last) === "\n")
            last++;

        found = true;
    }
    var rest = formatLines(text.slice(last), linkColor);
    html += rest.html;
    if (!found && !rest.changed)
        return "";

    return '<span style="white-space:pre-wrap">' + html + "</span>";
}

// Lines of a message as rich text: links (LINK_PATTERN), and the little Markdown that suits a chat
// window: **bold**, `code`, "- " / "* " bullets as "・", "# " headings as a bold line. Anything else is
// left as written. Returns {html, changed}: changed when the text needed rich text at all.
function formatLines(text, linkColor) {
    var changed = false;
    var lines = String(text).split(/\r?\n/).map(function(line) {
        var heading = /^\s{0,3}#{1,6}\s+(.*)$/.exec(line);
        if (heading)
            line = heading[1];

        var bullet = /^(\s*)[-*+]\s+(.*)$/.exec(line);
        if (bullet && !heading)
            line = bullet[1] + "・" + bullet[2];

        var html = linkLine(line, linkColor);
        var styled = html.replace(/\*\*([^*\n]+?)\*\*/g, "<b>$1</b>").replace(/`([^`\n]+)`/g, '<span style="font-family:Consolas; background-color:#D3D3D3">&nbsp;$1&nbsp;</span>');
        if (heading || bullet || styled !== html || html !== escapeHtml(line))
            changed = true;

        return heading ? "<b>" + styled + "</b>" : styled;
    });
    return {
        "html": lines.join("<br>"),
        "changed": changed
    };
}

// One line with its links (see LINK_PATTERN) made clickable: web links as themselves, paths as
// "yui-path:", 「System Console」 as "yui-option:". Escaped for rich text.
function linkLine(text, linkColor) {
    var html = "";
    var last = 0;
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
    }
    return html + escapeHtml(text.slice(last));
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

// The action of one desktop action request (a tag or a tool call), checked the same way for both:
// kind is "open", "search", "launch", "find" or "kill". Returns {action, blocked}: action is null when
// the value is not acceptable; blocked names a protected process <<kill:>> / close_program asked for.
function actionFrom(kind, value, userProtected, options) {
    options = options || {};
    value = String(value || "").trim();
    var result = {
        "action": null,
        "blocked": ""
    };
    if (!value)
        return result;

    if (kind === "open") {
        // Only plain web links: never local files or other schemes.
        if (/^https?:\/\/[^\s"'<>]+$/i.test(value))
            result.action = {
                "type": "open",
                "target": value,
                "url": value
            };

    } else if (kind === "search") {
        result.action = {
            "type": "search",
            "target": value,
            "url": searchUrl(options.searchEngine, options.searchCustom, value)
        };
    } else if (kind === "launch") {
        // A program name or path only: no quotes or line breaks.
        if (!/["\r\n]/.test(value))
            result.action = {
                "type": "launch",
                "target": value
            };

    } else if (kind === "find") {
        var query = value.replace(/"/g, "").trim();
        if (query)
            result.action = {
                "type": "find",
                "target": query
            };

    } else if (kind === "kill") {
        var name = processName(value);
        if (name && isProtectedProcess(name, userProtected))
            result.blocked = name;
        else if (name)
            result.action = {
                "type": "kill",
                "target": name
            };
    }
    return result;
}

// Tools (Action Mode "Tools"): the desktop actions and Yui's Heart as function calls, in a neutral
// form (name, description, JSON schema parameters) that the request turns into each API's format.
// kind: the action (see actionFrom) or "remember" / "forget"; allow: the switch that offers it
// (System Console's actions, Yui's Heart's Auto Memory); arg: the argument holding the value.
var TOOLS = [{
    "name": "open_url",
    "kind": "open",
    "allow": "web",
    "arg": "url",
    "description": "在浏览器中打开一个网页。只有当用户明确要求打开某个网站时才使用。",
    "parameters": {
        "type": "object",
        "properties": {
            "url": {
                "type": "string",
                "description": "完整的 https 网址"
            }
        },
        "required": ["url"]
    }
}, {
    "name": "web_search",
    "kind": "search",
    "allow": "web",
    "arg": "query",
    "description": "在网上搜索。用户明确要求搜索，或者需要天气、新闻、价格等实时信息时使用；不要自己编造这些信息。",
    "parameters": {
        "type": "object",
        "properties": {
            "query": {
                "type": "string",
                "description": "搜索词"
            }
        },
        "required": ["query"]
    }
}, {
    "name": "launch_program",
    "kind": "launch",
    "allow": "launch",
    "arg": "program",
    "description": "启动电脑上的程序。只有当用户明确要求打开或启动某个程序时才使用；执行前会先请用户确认。",
    "parameters": {
        "type": "object",
        "properties": {
            "program": {
                "type": "string",
                "description": "程序名或完整路径，例如 notepad、chrome"
            }
        },
        "required": ["program"]
    }
}, {
    "name": "find_file",
    "kind": "find",
    "allow": "find",
    "arg": "query",
    "description": "在用户的电脑里查找文件。只有当用户明确要求找文件时才使用。",
    "parameters": {
        "type": "object",
        "properties": {
            "query": {
                "type": "string",
                "description": "文件名或关键词"
            }
        },
        "required": ["query"]
    }
}, {
    "name": "close_program",
    "kind": "kill",
    "allow": "kill",
    "arg": "process",
    "description": "关闭电脑上正在运行的程序。只有当用户明确要求关闭某个程序时才使用；执行前会先请用户确认，系统关键进程不能关闭。",
    "parameters": {
        "type": "object",
        "properties": {
            "process": {
                "type": "string",
                "description": "进程名，例如 chrome.exe"
            }
        },
        "required": ["process"]
    }
}, {
    "name": "remember",
    "kind": "remember",
    "allow": "memory",
    "arg": "text",
    "description": "把关于用户、值得长期记住的事记进结衣之心。闲聊、天气这类一时的信息不要记，已经记住的不要重复记。",
    "parameters": {
        "type": "object",
        "properties": {
            "text": {
                "type": "string",
                "description": "用一句话写下要记住的事"
            },
            "core": {
                "type": "boolean",
                "description": "是否是最核心的事：名字、希望被怎么称呼、身份、重要的约定和偏好"
            }
        },
        "required": ["text"]
    }
}, {
    "name": "forget",
    "kind": "forget",
    "allow": "memory",
    "arg": "text",
    "description": "从结衣之心里忘掉某件事。用户要求忘掉，或者某件事已经不再成立时使用；情况有变化时，先忘掉旧的，再用 remember 记下新的。",
    "parameters": {
        "type": "object",
        "properties": {
            "text": {
                "type": "string",
                "description": "要忘掉的内容"
            }
        },
        "required": ["text"]
    }
}];

// The tools offered with a request: allowed as in options.allowed of parseReply (false = left out).
// The memory tools (remember / forget) only with withMemory: in the tests no model called them, so
// Yui's Heart keeps its tags in Tools mode too.
function toolDefinitions(allowed, withMemory) {
    allowed = allowed || {};
    return TOOLS.filter(function(tool) {
        return allowed[tool.allow] !== false && (withMemory || (tool.kind !== "remember" && tool.kind !== "forget"));
    }).map(function(tool) {
        return {
            "name": tool.name,
            "description": tool.description,
            "parameters": tool.parameters
        };
    });
}

// One tool call of the model (name, arguments object or JSON text) as what the widget does with it:
// {kind: "action", action} | {kind: "blocked", blocked} | {kind: "remember", text, core} |
// {kind: "forget", text} | {kind: "error", error} (unknown tool, forbidden, bad arguments). options as
// for parseReply (allowed, searchEngine, searchCustom).
function toolCallToAction(name, args, userProtected, options) {
    options = options || {};
    var allowed = options.allowed || {};
    var tool = TOOLS.filter(function(item) {
        return item.name === name;
    })[0];
    if (!tool)
        return {
            "kind": "error",
            "error": "unknown tool " + name
        };

    if (allowed[tool.allow] === false)
        return {
            "kind": "error",
            "error": "the user turned " + name + " off"
        };

    if (typeof args === "string") {
        try {
            args = args.trim() ? JSON.parse(args) : {};
        } catch (e) {
            return {
                "kind": "error",
                "error": "bad arguments: " + args
            };
        }
    }
    var value = String((args || {})[tool.arg] || "").trim();
    if (!value)
        return {
            "kind": "error",
            "error": "missing " + tool.arg
        };

    if (tool.kind === "remember")
        return {
            "kind": "remember",
            "text": value,
            "core": args.core === true || args.core === "true"
        };

    if (tool.kind === "forget")
        return {
            "kind": "forget",
            "text": value
        };

    var made = actionFrom(tool.kind, value, userProtected, options);
    if (made.blocked)
        return {
            "kind": "blocked",
            "blocked": made.blocked
        };

    if (!made.action)
        return {
            "kind": "error",
            "error": "not accepted: " + value
        };

    return {
        "kind": "action",
        "action": made.action
    };
}

// Col Ledger: the tokens a streamed event reports, {input, output} (either may be missing), or null.
// OpenAI-compatible: the last event's usage (with stream_options.include_usage); Claude: message_start
// (input) and message_delta (output); Gemini: usageMetadata in every event, adding up.
function usageOf(format, event) {
    var usage = null;
    if (format === "gemini" && event.usageMetadata)
        usage = {
        "input": event.usageMetadata.promptTokenCount,
        "output": event.usageMetadata.candidatesTokenCount
    };
    else if (format === "anthropic" && event.type === "message_start" && event.message && event.message.usage)
        usage = {
        "input": event.message.usage.input_tokens,
        "output": event.message.usage.output_tokens
    };
    else if (format === "anthropic" && event.type === "message_delta" && event.usage)
        usage = {
        "output": event.usage.output_tokens
    };
    else if (format === "openai" && event.usage)
        usage = {
        "input": event.usage.prompt_tokens,
        "output": event.usage.completion_tokens
    };
    return usage;
}

// The usage of a whole reply from its events' (the larger count of each kind wins: the reports add up).
function mergeUsage(total, usage) {
    total = total || {
        "input": 0,
        "output": 0
    };
    if (usage) {
        if (usage.input > total.input)
            total.input = usage.input;

        if (usage.output > total.output)
            total.output = usage.output;

    }
    return total;
}

// The ledger after a reply: {month: "2026-10", input, output, requests, warned}; a new month starts
// from zero.
function addToLedger(ledger, usage, now) {
    var d = new Date(now);
    var month = d.getFullYear() + "-" + (d.getMonth() < 9 ? "0" : "") + (d.getMonth() + 1);
    if (!ledger || ledger.month !== month)
        ledger = {
        "month": month,
        "input": 0,
        "output": 0,
        "requests": 0,
        "warned": false
    };

    return {
        "month": month,
        "input": ledger.input + (usage.input || 0),
        "output": ledger.output + (usage.output || 0),
        "requests": ledger.requests + 1,
        "warned": !!ledger.warned
    };
}

// One line of the recollection log as text: "2026-10-24 21:05  爸爸: …" (author "user" is the user,
// shown by title, anything else Yui). Line breaks in the message are kept, indented.
function logLine(row, title) {
    var d = new Date(row.created);
    var pad = function(n) {
        return (n < 10 ? "0" : "") + n;
    };
    var when = d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) + " " + pad(d.getHours()) + ":" + pad(d.getMinutes());
    var who = row.author === "user" ? title : "结衣";
    return when + "  " + who + ": " + String(row.message || "").replace(/\r?\n/g, "\n                   ");
}

// The greeting when the user comes back (Login Greeting): "long" after 3 days or more away, "morning"
// for the first time on a new day in the morning (5–11 h), "back" after half an hour, else "".
function greetingKind(lastActive, now) {
    if (!lastActive || now - lastActive < 30 * 60000)
        return "";

    if (now - lastActive >= 3 * 86400000)
        return "long";

    var last = new Date(lastActive);
    var today = new Date(now);
    var newDay = last.getFullYear() !== today.getFullYear() || last.getMonth() !== today.getMonth() || last.getDate() !== today.getDate();
    if (newDay && today.getHours() >= 5 && today.getHours() < 11)
        return "morning";

    return "back";
}

// A font's size in px (a font picked in a dialog may give it in points).
function fontPixels(font) {
    return font.pixelSize > 0 ? font.pixelSize : Math.round(font.pointSize * 4 / 3);
}

// Whether a setting (an SAO Utils preference) differs from its default: fonts by family, size and
// style, anything else by its content. Used by the settings windows (Reset This Tab is grey while
// none of a tab's settings changed).
function preferenceChanged(preference) {
    if (!preference)
        return false;

    var value = preference.value;
    var fallback = preference.defaultValue;
    if (value && fallback && value.family !== undefined && fallback.family !== undefined)
        return !(value.family === fallback.family && fontPixels(value) === fontPixels(fallback) && value.weight === fallback.weight && !!value.italic === !!fallback.italic && !!value.underline === !!fallback.underline && !!value.strikeout === !!fallback.strikeout);

    return JSON.stringify(value) !== JSON.stringify(fallback);
}

function anyChanged(preferences) {
    return (preferences || []).some(preferenceChanged);
}

// A likely expression for a reply that names none (<<emotion:>> missing), from its kaomoji and words.
function guessEmotion(text) {
    text = String(text || "");
    var rules = [["sad", /T_T|T▽T|ToT|；_；|´・ω・`|•́︿•̀|(｡•́︿•̀｡)|难过|伤心|呜呜|哭|心疼|对不起|抱歉|寂寞|孤单/], ["angry", /｀へ´|ಠ|＃|生气|哼！|过分|讨厌/], ["shy", /〃|\/\/\/|害羞|脸红|不好意思|羞/], ["surprised", /⊙|O_O|o_O|！？|!\?|咦|欸|诶|竟然|居然|真的吗/], ["happy", /≧|◡|▽|✿|★|☆|♪|\^_\^|哈哈|嘿嘿|开心|太好了|好棒|喜欢|耶/]];
    for (var i = 0; i < rules.length; i++)
        if (rules[i][1].test(text))
            return rules[i][0];

    return "normal";
}

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
        "disabled": "",
        // Tags that were not understood (misspelled, full-width brackets), dropped from the text.
        "unknown": [],
        // <<focus:>> (Boss Raid): minutes to focus (1–180; -1 for the default), 0 to end it, null when none.
        "focus": null,
        // <<mood:>> (Mental Record): {score 1–5, note}, null when none.
        "mood": null
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
        } else if (kind === "focus") {
            result.focus = focusMinutes(value);
        } else if (kind === "mood") {
            result.mood = moodFrom(value) || result.mood;
        } else if (ACTION_KINDS[kind]) {
            var made = actionFrom(kind, value, userProtected, options);
            if (made.blocked)
                result.blocked = made.blocked;
            else if (!result.action && made.action)
                result.action = made.action;
        }
        return "";
    });
    // What is left that looks like a tag (a misspelled name, full-width brackets) is never shown; one
    // whose value is an expression still counts as the expression.
    result.text = result.text.replace(anyTagPattern(), function(all, kind, value) {
        var emotion = String(value).trim().toLowerCase();
        if (!result.emotion && EMOTIONS.indexOf(emotion) !== -1)
            result.emotion = emotion;

        result.unknown.push(all);
        return "";
    }).replace(/[ \t]+\n/g, "\n").trim();
    return result;
}

// The minutes of a <<focus:>> tag: "stop" (or 0) ends the raid (0), a number of minutes is kept within
// 1–180, anything else is the default (-1).
function focusMinutes(value) {
    var text = String(value).trim().toLowerCase();
    if (/^(stop|end|cancel|结束|停止|取消)$/.test(text))
        return 0;

    var minutes = parseInt(text, 10);
    if (isNaN(minutes))
        return -1;

    return minutes <= 0 ? 0 : Math.min(180, minutes);
}

// A <<mood:>> tag's value: "4|passed the exam" (or "4" alone) -> {score, note}; the score is kept
// within 1–5; null without a score.
function moodFrom(value) {
    var parts = String(value).split(/[|｜]/);
    var score = parseInt(parts[0], 10);
    if (isNaN(score))
        return null;

    return {
        "score": Math.max(1, Math.min(5, score)),
        "note": parts.slice(1).join("|").trim()
    };
}

// Mental Record (Daily Mood Check), added to the system prompt: when today's mood is not recorded yet,
// Yui is asked to ask about it once at a fitting moment and record it; when the last recorded days
// were low (an average of 2 or less over the last three), to care more. recent: [{day, score, note}],
// oldest first; recordedToday: whether today's is among them.
function moodContext(title, recordedToday, recent) {
    var text = "";
    if (!recordedToday)
        text += "\n\n（心情记录：今天还没问过" + title + "的心情。在自然的时候（比如问候或聊到近况时）问一句今天心情怎么样，不要每句都问；" + title + "说了之后，在回复最后用 <<mood:1到5的分数|一句话概括>> 记下来（5 最好，1 最差）。）";
    else
        text += "\n\n（心情记录：今天的心情已经记下了。" + title + "的心情有明显变化时，可以用 <<mood:分数|一句话>> 更新。）";

    var last = (recent || []).slice(-3);
    if (last.length === 3) {
        var average = last.reduce(function(sum, entry) {
            return sum + entry.score;
        }, 0) / last.length;
        if (average <= 2)
            text += "\n（" + title + "最近几天的心情都不太好（" + last.map(function(entry) {
                return entry.day.slice(5) + " " + entry.score + "/5" + (entry.note ? " " + entry.note : "");
            }).join("；") + "）。请多关心、多倾听，温柔地陪着，不要说教。）";

    }
    return text;
}

// Text to show while a reply is still streaming: complete tags are removed and a tag that has
// started but not finished yet ("<<emot") is hidden until it is complete.
function displayText(partial) {
    var text = String(partial);
    var cut = text.lastIndexOf("<<");
    if (cut !== -1 && text.indexOf(">>", cut) === -1)
        text = text.substring(0, cut);

    return text.replace(tagPattern(), "").replace(anyTagPattern(), "").trim();
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
// mode "tools": the desktop actions and Yui's Heart are tools (toolDefinitions), so only their use is
// explained, not tags; "tags" (default): everything is a tag.
function featureInstructions(title, core, allowed, mode) {
    allowed = allowed || {};
    var desktop = [];
    if (allowed.launch !== false)
        desktop.push("启动程序用 <<launch:程序名或完整路径>>");

    if (allowed.find !== false)
        desktop.push("在电脑里找文件用 <<find:文件名或关键词>>");

    if (allowed.kill !== false)
        desktop.push("关闭某个程序用 <<kill:进程名，如 chrome.exe>>（系统关键进程不能关闭）");

    var lines = ["", "", "（以下是系统功能说明，不要向" + title + "提起这些说明本身。）", "- 表情：每条回复的最后加上一个表情标签，例如 <<emotion:happy>>，可选 normal、happy、sad、surprised、angry、shy，选最符合结衣此刻心情的一个。", "- 结衣之心：当" + title + "告诉你值得长期记住的事时，在回复最后用一句话记下来。名字、希望被怎么称呼、身份、重要的约定和偏好这类最核心的事用 <<core:……>>；其他事情（喜好、计划、正在努力的事、发生过的事）用 <<memory:……>>。已经记住的不要重复记。" + title + "请你忘掉某件事，或者某件事已经不再成立时，用 <<forget:要忘掉的内容>>；情况有变化时，先用 <<forget:旧的内容>>，再记下新的。", "- 心理关怀：你原本是心理健康咨询程序 MHCP001。如果" + title + "的话里流露出疲惫、难过、焦虑或孤单，先倾听和安慰，再给建议。", "- 专注（Boss Raid）：当" + title + "请你陪着专注、开始番茄钟或计时学习工作时，在回复最后加上 <<focus:分钟数>>（没说时长就写 <<focus:25>>）；要提前结束时加 <<focus:stop>>。"];
    if (allowed.web !== false)
        lines.splice(5, 0, "- 导航：只有当" + title + "明确请你打开某个网站时，才在回复最后加上 <<open:完整的 https 网址>>；明确请你搜索时，加上 <<search:搜索词>>。");

    if (desktop.length > 0)
        lines.splice(allowed.web !== false ? 6 : 5, 0, "- 桌面代行：只有当" + title + "明确请你做这些事时才使用，每次都会先请" + title + "确认：" + desktop.join("；") + "。");

    if (allowed.memory === false)
        lines = lines.filter(function(line) {
            return line.indexOf("- 结衣之心：") !== 0;
        });

    if (mode === "tools") {
        // Only the expression and care lines stay; actions and memories are tools.
        lines = lines.filter(function(line) {
            return line.indexOf("- 导航：") !== 0 && line.indexOf("- 桌面代行：") !== 0;
        });
        var abilities = [];
        if (allowed.web !== false)
            abilities.push("打开网页、上网搜索");

        if (allowed.launch !== false)
            abilities.push("启动程序");

        if (allowed.find !== false)
            abilities.push("查找文件");

        if (allowed.kill !== false)
            abilities.push("关闭程序");

        if (abilities.length > 0)
            lines.splice(4, 0, "- 电脑操作：你可以用提供的工具" + abilities.join("、") + "。只有当" + title + "明确请你做这些事时才使用；需要天气、新闻这类实时信息时用搜索，不要编造。");

    }

    if (core && core.length > 0) {
        lines.push("", "结衣之心·心核（关于" + title + "最重要的事）：");
        core.forEach(function(entry) {
            lines.push("- " + entry.text);
        });
    }
    return lines.join("\n");
}

// The most important rules, put before the personality (whatever the user wrote there) so that small
// models do not lose them: the expression tag, that actions only happen through tools / tags (the
// enabled ones only), and searching instead of inventing real-time facts. mode: "tools" or "tags".
function priorityRules(title, allowed, mode) {
    allowed = allowed || {};
    var acts = [];
    if (allowed.web !== false)
        acts.push("打开网页、搜索");

    if (allowed.launch !== false || allowed.kill !== false)
        acts.push(allowed.launch === false ? "关闭程序" : allowed.kill === false ? "启动程序" : "启动或关闭程序");

    if (allowed.find !== false)
        acts.push("查找文件");

    var memory = allowed.memory !== false;
    var rules = ["每条回复的最后都加一个表情标签 <<emotion:…>>，从 normal、happy、sad、surprised、angry、shy 中选一个。"];
    if (mode === "tools") {
        // Tools for the desktop actions, tags for Yui's Heart.
        if (acts.length > 0)
            rules.push(acts.join("、") + "时，必须调用提供的工具。只用文字说“正在执行”“已经打开了”，电脑上什么都不会发生。");

        if (memory)
            rules.push("记住、忘记事情时，必须在回复里写对应的标签（见后面的说明），光说“记住了”是记不住的。");

    } else {
        var what = acts.join("、");
        if (memory)
            what = what ? what + "，以及记住、忘记事情" : "记住、忘记事情";

        if (what)
            rules.push(what + "时，必须在回复里写对应的标签（见后面的说明）。只用文字说“正在执行”“已经打开了”，电脑上什么都不会发生。");

    }

    if (allowed.web !== false)
        rules.push("需要天气、新闻、价格这类实时信息时，必须搜索，绝不自己编造。");

    return "【最重要的规则】\n" + rules.map(function(rule, i) {
        return (i + 1) + ". " + rule;
    }).join("\n") + "\n\n";
}

// Small Model Mode: a short reminder added to the user's latest message.
// It does not spell the tag out: with a repetition penalty, a tag written just before made models
// misspell it (<<emphy:happy>>).
function smallModelReminder(mode, allowed) {
    allowed = allowed || {};
    var acting = allowed.web !== false || allowed.launch !== false || allowed.find !== false || allowed.kill !== false || allowed.memory !== false;
    return "\n\n（提醒：回复最后加上表情标签" + (acting ? (mode === "tools" ? "；需要操作电脑时调用工具，记住事情时写标签" : "；需要操作电脑或记忆时写对应的标签") : "") + "。）";
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

// The "System Call" easter egg (Sacred Arts of Alicization). Returns null when the text is not a
// system call, otherwise { reply, effect } where effect is { color, burst, aura, shake } or null:
// burst a burst instead of a floating element, aura a glow around Yui, shake Yui shaking.
// loads: the current loads in % ({cpu, gpu, ram}, some may be missing), for Transfer Durability.
function systemCall(text, title, loads) {
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
            "reply": "系统指令一览 ✧\n· Generate Luminous / Thermal / Cryogenic / Aerial / Aqueous / Metallic / Umbra Element\n· Discharge\n· Burst Element\n· Enhance Armament\n· Release Recollection\n· Transfer Durability\n格式：System Call, Generate Luminous Element",
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

    // Incarnation of the armament (武装完全支配术): a golden element and a glow around Yui.
    if (/^enhance\s+armament/.test(command))
        return {
            "reply": "Enhance Armament——！✧ 武装完全支配术，发动！结衣感觉全身都充满了力量～ (ง •̀_•́)ง",
            "effect": {
                "color": "#FFD54F",
                "burst": false,
                "aura": true
            }
        };

    // Release Recollection (记忆解放术): a violet burst, and Yui shakes with it.
    if (/^release\s+recollection/.test(command))
        return {
            "reply": "Release Recollection——！！✧✧ 记忆解放术！呜哇，好、好强的力量……" + title + "，结衣快要站不稳了啦 (>_<)",
            "effect": {
                "color": "#B388FF",
                "burst": true,
                "shake": true
            }
        };

    // Transfer Durability (天命转移): Yui reports the "durability" of the computer, its loads.
    if (/^transfer\s+durability/.test(command)) {
        var parts = [];
        [["cpu", "CPU"], ["gpu", "GPU"], ["ram", "内存"]].forEach(function(metric) {
            var value = loads && loads[metric[0]];
            if (typeof value === "number" && isFinite(value))
                parts.push(metric[1] + " " + Math.round(value) + "%");

        });
        return {
            "reply": "天命转移——！✧ " + (parts.length > 0 ? "这台电脑的天命消耗：" + parts.join("、") + "。" : "") + "结衣把天命分给" + title + "一点点，要好好休息哦～ (｡･ω･｡)",
            "effect": {
                "color": "#69F0AE",
                "burst": false
            }
        };
    }

    return {
        "reply": "警告！无法识别的系统指令……" + title + "，是不是念错咒语了？试试 System Call, Inspect Entire Command List 吧 (・_・;)",
        "effect": null
    };
}
