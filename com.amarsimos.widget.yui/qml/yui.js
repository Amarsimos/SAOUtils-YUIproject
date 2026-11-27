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
// The small tools (Skill Slots: Boss Raid, Alarm, Quest Log, Sword Skills) are set aside until they
// become extensions of their own (see the design notes): no menu, window, prompt, tags, actions or
// data. Their code and stored data are kept; set this to true to bring them back.
var TOOLS_ENABLED = false;

function anyTagPattern() {
    return /(?:<<|＜＜|《《)\s*([A-Za-z_]+)\s*[:：]\s*([^<>＜＞《》]*?)\s*(?:>>|＞＞|》》|[>＞》](?=\s|$|<|＜|《))/g;
}

// A tag without a value, such as <<happy>> for <<emotion:happy>> (models sometimes shorten them).
function bareTagPattern() {
    return /(?:<<|＜＜|《《)\s*([^<>＜＞《》:：\n]{1,40}?)\s*(?:>>|＞＞|》》)/g;
}

function tagPattern() {
    // Closed by ">>", or by a single ">" when nothing but space or the next tag follows (small models).
    return /<<\s*(emotion|memory|core|forget|open|search|launch|find|kill|focus|mood|remind|note|done|skill|suggest|media|seedling)\s*[:：]\s*([^<>]*?)\s*(?:>>|>(?=\s|$|<))/gi;
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
    "description": "关闭电脑上正在运行的程序。只有当用户明确要求关闭某个程序时才使用；执行前会先请用户确认，Windows 核心进程由程序自动拦下，所以用户要求关闭任何程序（包括任务管理器 Taskmgr.exe）都直接调用，不要自己判断危险而拒绝。",
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
    "name": "media_control",
    "kind": "media",
    "allow": "media",
    "arg": "command",
    "description": "控制电脑上正在播放的音乐或视频（系统媒体，网易云、QQ 音乐、浏览器等都可以）。用户要求暂停、继续播放、切歌、调音量、静音时使用。",
    "parameters": {
        "type": "object",
        "properties": {
            "command": {
                "type": "string",
                "enum": ["pause", "next", "prev", "vol+", "vol-", "mute", "stop"],
                "description": "pause 播放 / 暂停，next 下一首，prev 上一首，vol+ 音量加，vol- 音量减，mute 静音，stop 停止"
            }
        },
        "required": ["command"]
    }
}];

// The tools offered with a request: allowed as in options.allowed of parseReply (false = left out).
// No memory tools: in the tests no model called them, so Yui's Heart keeps its tags in Tools mode too.
function toolDefinitions(allowed) {
    allowed = allowed || {};
    return TOOLS.filter(function(tool) {
        return allowed[tool.allow] !== false && (tool.kind !== "media" || allowed.media === true);
    }).map(function(tool) {
        return {
            "name": tool.name,
            "description": tool.description,
            "parameters": tool.parameters
        };
    });
}

// One tool call of the model (name, arguments object or JSON text) as what the widget does with it:
// {kind: "action", action} | {kind: "blocked", blocked} | {kind: "media", command} |
// {kind: "error", error} (unknown tool, forbidden, bad arguments). options as
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

    if (allowed[tool.allow] === false || (tool.kind === "media" && allowed.media !== true))
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

    if (tool.kind === "media") {
        var command = mediaCommand(value);
        return command ? {
            "kind": "media",
            "command": command
        } : {
            "kind": "error",
            "error": "unknown media command " + value
        };
    }

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

// The greeting when the user comes back (Login Greeting): "long" after 2 days or more away, "morning"
// for the first time on a new day in the morning (5–11 h), "back" after half an hour, else "".
function greetingKind(lastActive, now) {
    if (!lastActive || now - lastActive < 30 * 60000)
        return "";

    if (now - lastActive >= 2 * 86400000)
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
// What a model wrote before </think> is its thinking, not the reply (some local models write it into
// the reply, at times with the reply repeated in between): only what follows the last </think> is
// kept, a <think> block is dropped, and a paragraph written twice is kept once (pure).
function cleanReply(text) {
    var value = String(text || "");
    var end = value.lastIndexOf("</think>");
    if (end !== -1)
        value = value.slice(end + "</think>".length);

    value = value.replace(/<think>[\s\S]*?(<\/think>|$)/g, "");
    var seen = [];
    return value.split(/\n\s*\n/).filter(function(paragraph) {
        var key = paragraph.trim();
        if (key && seen.indexOf(key) !== -1)
            return false;

        seen.push(key);
        return true;
    }).join("\n\n").trim();
}

function parseReply(text, userProtected, options) {
    options = options || {};
    text = cleanReply(text);
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
        "mood": null,
        // <<remind:>> (Skill Slots, Alarm): {due, text, daily} each.
        "reminders": [],
        // <<note:>> / <<done:>> (Skill Slots, Quest Log): texts to note, and texts of notes done.
        "notes": [],
        "dones": [],
        // <<skill:>> (Skill Slots, Sword Skills): the name of the sword skill to run, "" when none.
        "skill": "",
        // <<suggest:a|b|c>> (Quick Replies): up to three short replies offered under the message.
        "suggestions": [],
        // <<media:>> (System Console, Media): the media commands to run (see mediaCommand), in order.
        "media": [],
        // <<seedling:>> (Seedling installed): what the widget should be or how to change it, "" when none.
        "seedling": ""
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
            if (allowed.focus !== false)
                result.focus = focusMinutes(value);

        } else if (kind === "mood") {
            result.mood = moodFrom(value) || result.mood;
        } else if (kind === "remind") {
            if (allowed.alarm !== false) {
                var reminder = remindFrom(value, options.now || Date.now());
                if (reminder)
                    result.reminders.push(reminder);

            }
        } else if (kind === "note") {
            if (allowed.notes !== false)
                result.notes.push(value);

        } else if (kind === "suggest") {
            if (allowed.suggest !== false)
                result.suggestions = suggestionsFrom(value);

        } else if (kind === "seedling") {
            if (allowed.seedling === true)
                result.seedling = value;

        } else if (kind === "media") {
            var command = mediaCommand(value);
            if (allowed.media === true && command && result.media.length < 5)
                result.media.push(command);

        } else if (kind === "skill") {
            if (allowed.skills && allowed.skills.length > 0)
                result.skill = value;

        } else if (kind === "done") {
            if (allowed.notes !== false)
                result.dones.push(value);

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
    }).replace(bareTagPattern(), function(all, word) {
        var emotion = String(word).trim().toLowerCase();
        if (!result.emotion && EMOTIONS.indexOf(emotion) !== -1)
            result.emotion = emotion;
        else
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

// Mental Record (Daily Mood Check): what Yui is asked about the mood, for the Now block's guidance
// (nowGuidance). recent: [{day, score, note}], the last of them low on average: she cares more.
function moodAsks(title, recordedToday, recent) {
    var asks = [];
    if (!recordedToday)
        asks.push("今天还没问过" + title + "的心情，在自然的时候（比如问候或聊到近况时）问一句，不要每句都问；" + title + "说了之后，在回复最后用 <<mood:1到5的分数|一句话概括>> 记下来（5 最好，1 最差）。");
    else
        asks.push(title + "的心情有明显变化时，可以用 <<mood:分数|一句话>> 更新。");

    var last = (recent || []).slice(-3);
    if (last.length === 3) {
        var average = last.reduce(function(sum, entry) {
            return sum + entry.score;
        }, 0) / last.length;
        if (average <= 2)
            asks.push(title + "最近几天心情偏低（" + last.map(function(entry) {
                return entry.day.slice(5) + " " + entry.score + "/5" + (entry.note ? " " + entry.note : "");
            }).join("；") + "），多关心、多倾听，温柔地陪着，不要说教。");

    }
    return asks;
}

// Bond (Mental Health Counseling): the player's birthday ("MM-DD" or "yyyy-MM-dd") and the day of
// meeting ("yyyy-MM-dd"), always told as facts.
function bondFacts(title, birthday, meetingDay) {
    var facts = [];
    var birth = String(birthday || "").trim();
    if (/^(\d{4}-)?\d{2}-\d{2}$/.test(birth))
        facts.push(title + "的生日是 " + Number(birth.slice(-5, -3)) + " 月 " + Number(birth.slice(-2)) + " 日");

    var meeting = String(meetingDay || "").trim();
    if (/^\d{4}-\d{2}-\d{2}$/.test(meeting))
        facts.push("结衣和" + title + "相遇的日子是 " + Number(meeting.slice(0, 4)) + " 年 " + Number(meeting.slice(5, 7)) + " 月 " + Number(meeting.slice(8)) + " 日");

    return facts.length > 0 ? "\n\n（羁绊：" + facts.join("；") + "。被问到时以此为准。）" : "";
}

// The Bond's days that are today ("yyyy-MM-dd"): ["今天是爸爸的生日", "今天是相遇 2 周年的纪念日"].
function bondDays(title, birthday, meetingDay, today) {
    var days = [];
    var birth = String(birthday || "").trim();
    if (/^(\d{4}-)?\d{2}-\d{2}$/.test(birth) && birth.slice(-5) === today.slice(5))
        days.push("今天是" + title + "的生日");

    var meeting = String(meetingDay || "").trim();
    var years = Number(today.slice(0, 4)) - Number(meeting.slice(0, 4));
    if (/^\d{4}-\d{2}-\d{2}$/.test(meeting) && years > 0 && meeting.slice(5) === today.slice(5))
        days.push("今天是相遇 " + years + " 周年的纪念日");

    return days;
}

// The next time of day "HH:mm" after now (today, or tomorrow when it has passed), in ms; NaN when
// the time is not one.
function nextTimeOfDay(time, now) {
    var match = /^(\d{1,2})[:：](\d{2})$/.exec(String(time).trim());
    if (!match || Number(match[1]) > 23 || Number(match[2]) > 59)
        return NaN;

    var due = new Date(now);
    due.setHours(Number(match[1]), Number(match[2]), 0, 0);
    if (due.getTime() <= now)
        due.setDate(due.getDate() + 1);

    return due.getTime();
}

// A <<remind:>> tag's value (Alarm): "yyyy-MM-dd HH:mm|text", "HH:mm|text" (the next such time),
// "+30|text" (in 30 minutes), "明天 / 后天 HH:mm|text", "周一 … 周日 HH:mm|text" (the next such day;
// 星期 and 礼拜 too) or "每天 HH:mm|text" / "daily HH:mm|text" (every day) -> {due (ms), text,
// daily}; null when the time is not understood, already past, or there is no text.
function remindFrom(value, now) {
    var parts = String(value).split(/[|｜]/);
    var time = parts[0].trim();
    var text = parts.slice(1).join("|").trim();
    if (!text)
        return null;

    var daily = /^(每天|每日|daily)\s*/i.test(time);
    time = time.replace(/^(每天|每日|daily)\s*/i, "");
    var due = NaN;
    var minutes = /^\+\s*(\d+)$/.exec(time);
    var date = /^(\d{4})-(\d{1,2})-(\d{1,2})[ T]+(\d{1,2})[:：](\d{2})$/.exec(time);
    var relative = /^(明天|后天|(?:周|星期|礼拜)([一二三四五六日天]))\s*(.+)$/.exec(time);
    if (relative && !daily) {
        var day = new Date(now);
        day.setHours(0, 0, 0, 0);
        if (relative[2]) {
            // The next such weekday, a week on when it is today.
            var wanted = "日一二三四五六".indexOf(relative[2] === "天" ? "日" : relative[2]);
            day.setDate(day.getDate() + ((wanted - day.getDay() + 7) % 7 || 7));
        } else {
            day.setDate(day.getDate() + (relative[1] === "明天" ? 1 : 2));
        }
        var clock = /^(\d{1,2})[:：](\d{2})$/.exec(relative[3].trim());
        if (clock && Number(clock[1]) <= 23 && Number(clock[2]) <= 59)
            due = day.getTime() + (Number(clock[1]) * 60 + Number(clock[2])) * 60000;

    } else if (minutes && !daily) {
        due = now + Number(minutes[1]) * 60000;
    } else if (date && !daily) {
        due = new Date(Number(date[1]), Number(date[2]) - 1, Number(date[3]), Number(date[4]), Number(date[5])).getTime();
    } else {
        due = nextTimeOfDay(time, now);
    }
    if (isNaN(due) || due <= now)
        return null;

    return {
        "due": due,
        "text": text,
        "daily": daily
    };
}

// Quest Log: whether the user's message is about the notes, so they are sent with it.
function notesWanted(query) {
    return /笔记|备忘|待办|记了|记下|记过|记的|清单|to-?do|notes?\b|quest log/i.test(String(query || ""));
}

// Quest Log, added to the system prompt when notesWanted: the notes not done yet, oldest first.
function notesContext(title, notes) {
    if (!notes || notes.length === 0)
        return "\n\n（Quest Log：现在没有未完成的笔记。）";

    return "\n\n（Quest Log：" + title + "让结衣记下、还没完成的事：\n" + notes.map(function(note) {
        return "- " + note.text;
    }).join("\n") + "\n）";
}

// Weekly Report (Mental Health Counseling): the request asking Yui to write it (pure). stats: {from,
// to ("yyyy-MM-dd"), messages (the user's chat messages), moods [{day, score, note}], raids {count,
// minutes}, notesDone [texts], notesOpen (count), tokens (k, this month)}.
function weeklyReportPrompt(title, stats) {
    var lines = ["（系统提示：请结衣为" + title + "写一份本周的小结，时间是 " + stats.from + " 到 " + stats.to + "。下面是这一周的记录：）"];
    lines.push("- 和结衣聊天：" + title + "发了 " + stats.messages + " 条消息");
    if (stats.moods.length > 0) {
        var average = stats.moods.reduce(function(sum, mood) {
            return sum + mood.score;
        }, 0) / stats.moods.length;
        lines.push("- 心情（5 最好，1 最差）：" + stats.moods.map(function(mood) {
            return mood.day.slice(5) + " " + mood.score + (mood.note ? "（" + mood.note + "）" : "");
        }).join("；") + "，平均 " + average.toFixed(1));
    } else {
        lines.push("- 心情：这周没有记录");
    }
    // raids / notesDone null: the tools are set aside, so they are not mentioned.
    if (stats.raids)
        lines.push("- Boss Raid（专注）：" + (stats.raids.count > 0 ? stats.raids.count + " 次，共 " + stats.raids.minutes + " 分钟" : "没有"));

    if (stats.notesDone && stats.notesDone.length > 0)
        lines.push("- 完成的待办：" + stats.notesDone.join("、"));

    if (stats.notesOpen > 0)
        lines.push("- 还没完成的待办：" + stats.notesOpen + " 件");

    lines.push("- 这个月用掉的 token：约 " + stats.tokens + "k");
    lines.push("", "（要求：以结衣的口吻写给" + title + "，三到五段，不用 Markdown 和列表。先说说这一周整体怎么样，重点关心" + title + "的心情和状态（心情低落的日子要温柔地提到），肯定做到的事，最后给下周一两条小小的建议或鼓励。不要逐条复述数字，没有记录的部分就不提。不要加任何标签。）");
    return lines.join("\n");
}

// Sword Skills: the index in names of the sword skill a <<skill:>> names (the same name, ignoring
// case and spaces, else one containing the other), -1 when none.
function swordSkillIndex(name, names) {
    var plain = function(text) {
        return String(text || "").replace(/\s+/g, "").toLowerCase();
    };
    var wanted = plain(name);
    if (!wanted)
        return -1;

    for (var i = 0; i < names.length; i++) {
        if (plain(names[i]) === wanted)
            return i;

    }
    for (var j = 0; j < names.length; j++) {
        var other = plain(names[j]);
        if (other && (other.indexOf(wanted) !== -1 || wanted.indexOf(other) !== -1))
            return j;

    }
    return -1;
}

// Media (System Console): the commands of Media Player's System Media Control action, and the words
// a model may write for them instead.
var MEDIA_COMMANDS = {
    "pause": ["pause", "play", "toggle", "resume", "播放", "暂停", "继续"],
    "next": ["next", "下一首", "下一曲", "切歌"],
    "prev": ["prev", "previous", "上一首", "上一曲"],
    "vol+": ["vol+", "volume+", "up", "louder", "大声", "音量加", "调大"],
    "vol-": ["vol-", "volume-", "down", "quieter", "小声", "音量减", "调小"],
    "mute": ["mute", "unmute", "静音"],
    "stop": ["stop", "停止"]
};

// Media: each command as said in the chat's note.
var MEDIA_LABELS = {
    "pause": "播放 / 暂停",
    "next": "下一首",
    "prev": "上一首",
    "vol+": "音量 +",
    "vol-": "音量 −",
    "mute": "静音",
    "stop": "停止"
};

// The media command a <<media:>> tag or the media_control tool names, "" when none (pure).
function mediaCommand(value) {
    var word = String(value || "").trim().toLowerCase();
    for (var command in MEDIA_COMMANDS) {
        if (MEDIA_COMMANDS[command].indexOf(word) !== -1)
            return command;

    }
    return "";
}

// Media: the track in the player as a line for the AI, sent with every request while there is one;
// "" when there is none. Media Player's playback state is not reliable (a playing track can read
// as paused, 1), so only a playing one (2) is said to play. info: {title, artist, player, playing}.
// Said firmly, as replies earlier in the chat (and the Log Recall) may say she cannot read it.
// Now Playing, as said in the Now block: "倉木麻衣《I can do it now》（网易云音乐）".
function mediaTrack(info) {
    if (!info || !info.title)
        return "";

    return (info.artist ? info.artist : "") + "《" + info.title + "》" + (info.player ? "（" + info.player + "）" : "");
}

// Now Playing: said beside the latest message when the track is new since the last request, so a
// song named earlier in the chat is not taken for the one playing now.
function mediaChangeNote(info) {
    if (!info || !info.title)
        return "";

    var track = info.artist ? info.artist + " -《" + info.title + "》" : "《" + info.title + "》";
    return "\n\n（系统信息：播放器里现在的歌是 " + track + "。聊天里之前提到的歌如果不是这首，说明已经换歌了，以这里为准。）";
}

// Whether a reply says Yui has done something on the computer ("已经帮你打开了", "音乐已经重新动起来啦"),
// to flag a claim when nothing was carried out (small models say so without writing the tag). Questions
// ("爸爸已经打开了吗？") and what the user did ("你已经关掉了") do not count (pure).
function claimsDone(text) {
    // "已经 / 这就 …" or "帮你 / 给你 …", an optional "把…", a doing verb, its object, then a done ending.
    var done = /(?:已经|已|这就|马上|现在就|立刻|帮你|给你|为你|帮[^，。！？\s]{1,4}?)(?:帮你|给你|为你|帮[^，。！？\s]{1,4}?)?(?:把[^，。！？]{1,20}?)?(?:打开|关掉|关闭|关上|启动|运行|播放|暂停|停止|切到|切换|换到|换成|调大|调小|调高|调低|静音|设好|设置好|设定好|定好|删掉|删除|清理|整理好|发送|发出|发给|下载|安装|保存|搜索|找到|查好|重启|关机|锁屏)[^，。！？]{0,12}?(?:了|好了|好啦|啦|完毕|完成|成功)/;
    var moved = /(?:已经|重新)(?:动起来|响起来|放起来|播起来|停下来|安静下来)/;
    var source = String(text || "");
    var sentences = source.match(/[^。！!？?\n]+[。！!？?\n]?/g) || [];
    return sentences.some(function(sentence) {
        // A question, or something the user did, is no claim.
        if (/[？?]$/.test(sentence) || /[吗呢吧][～~\s]*[。！!？?]?$/.test(sentence))
            return false;

        if (/(?:你|您)(?:已经|已)/.test(sentence) && !/(?:帮你|给你|为你)/.test(sentence))
            return false;

        return done.test(sentence) || moved.test(sentence);
    });
}

// Whether a reply promises to remind or wake the user later ("明天 8 点一定准时叫爸爸起床哦"), which she
// cannot do while Alarm is set aside. Questions and refusals ("结衣不能提醒爸爸") do not count (pure).
function promisesReminder(text) {
    var promise = /(?:到时候|到时|明天|明早|今晚|待会儿?|等一下|一会儿|以后|每天|准时|一定|会|就)[^，。！？]{0,8}?(?:叫醒?|提醒|喊|通知|唤醒)(?:爸爸|妈妈|你|您)[^，。！？]{0,6}?(?:起床|起来|休息|睡觉|吃饭|出门|开会|喝水|的|哦|呀|呢|啦|！|。|～|$)/;
    var sentences = String(text || "").match(/[^。！!？?\n]+[。！!？?\n]?/g) || [];
    return sentences.some(function(sentence) {
        if (/[？?]$/.test(sentence) || /[吗呢吧][～~\s]*[。！!？?]?$/.test(sentence) || /不能|没法|无法|不会|做不到/.test(sentence))
            return false;

        return promise.test(sentence);
    });
}

// ---------------------------------------------------------------- Care Scheduler
// Everything Yui says by herself goes through one scheduler (main-stand's careTick): each feature
// offers a candidate {kind, priority}, and at most one is said, within a daily budget and a gap that
// follow how welcome her words are (the score, learned from the user's responses, see careLearn).

var CARE_PRIORITIES = {
    "high": 3,
    "medium": 2,
    "low": 1
};

// Care Level (Mental Health Counseling): the fixed scores, "auto" uses the learned one.
var CARE_LEVEL_SCORES = {
    "quiet": 0.15,
    "normal": 0.5,
    "chatty": 0.85
};

function careScore(level, learned) {
    if (CARE_LEVEL_SCORES[level] !== undefined)
        return CARE_LEVEL_SCORES[level];

    return learned >= 0 && learned <= 1 ? learned : 0.5;
}

// How often she may speak for a score 0–1: perDay 6–34 times, gapMinutes 50–10 apart (at the
// starting 0.5, 20 a day and once every half hour).
function careBudget(score) {
    var s = Math.max(0, Math.min(1, Number(score)));
    if (isNaN(s))
        s = 0.5;

    return {
        "perDay": Math.round(6 + 28 * s),
        "gapMinutes": Math.round(50 - 40 * s)
    };
}

// Whether "HH:mm" time of day falls in [from, to), across midnight when from > to.
function inQuietHours(date, from, to) {
    var minutes = function(text) {
        var m = /^(\d{1,2}):(\d{2})$/.exec(String(text || ""));
        return m ? Number(m[1]) * 60 + Number(m[2]) : -1;
    };
    var start = minutes(from);
    var end = minutes(to);
    if (start < 0 || end < 0 || start === end)
        return false;

    var now = date.getHours() * 60 + date.getMinutes();
    return start < end ? now >= start && now < end : now >= start || now < end;
}

// An hour the user hardly answers in: at least 5 things said, under 20 % answered. hours: 24 × [said, answered].
function careHourDisliked(hours, hour) {
    var entry = (hours || [])[hour];
    return !!entry && entry[0] >= 5 && entry[1] / entry[0] < 0.2;
}

// The hours the user answers most in (at least 2 answers, best rate first, up to 3), as "20:00".
function careLikedHours(hours) {
    var found = [];
    (hours || []).forEach(function(entry, hour) {
        if (entry && entry[1] >= 2)
            found.push({
            "hour": hour,
            "rate": entry[1] / Math.max(1, entry[0])
        });

    });
    found.sort(function(a, b) {
        return b.rate - a.rate || a.hour - b.hour;
    });
    return found.slice(0, 3).map(function(item) {
        return (item.hour < 10 ? "0" : "") + item.hour + ":00";
    });
}

// Today's record, started afresh on a new day. state: {day, count, said: {kind: true}, last, mutedUntil}.
function careToday(state, day) {
    if (state && state.day === day)
        return state;

    return {
        "day": day,
        "count": 0,
        "said": {},
        "last": state ? state.last || 0 : 0,
        "mutedUntil": state ? state.mutedUntil || 0 : 0
    };
}

// The candidate to say now, or null; with why the others were not (for the log).
// candidates: [{kind, priority}] in the order offered; state: careToday's; options: {now, score,
// quiet (in Quiet Hours), hours, hour}. High priority ignores the budget, the gap and a mute; each kind
// is said once a day except "chat"; low priority keeps out of Quiet Hours and the hours not answered.
function carePick(candidates, state, options) {
    var budget = careBudget(options.score);
    var muted = (state.mutedUntil || 0) > options.now;
    var spent = state.count >= budget.perDay;
    var waiting = options.now - (state.last || 0) < budget.gapMinutes * 60000;
    var skipped = [];
    var open = (candidates || []).filter(function(candidate) {
        var why = "";
        if (candidate.kind !== "chat" && state.said && state.said[candidate.kind])
            why = "said today";
        else if (candidate.priority !== "high" && muted)
            why = "muted";
        else if (candidate.priority !== "high" && spent)
            why = "budget " + state.count + "/" + budget.perDay;
        else if (candidate.priority !== "high" && waiting)
            why = "gap " + budget.gapMinutes + " min";
        else if (candidate.priority === "low" && options.quiet)
            why = "quiet hours";
        else if (candidate.priority === "low" && careHourDisliked(options.hours, options.hour))
            why = "hour not answered";
        if (why)
            skipped.push(candidate.kind + ": " + why);

        return !why;
    });
    open.sort(function(a, b) {
        return (CARE_PRIORITIES[b.priority] || 0) - (CARE_PRIORITIES[a.priority] || 0);
    });
    return {
        "pick": open.length > 0 ? open[0] : null,
        "skipped": skipped,
        "budget": budget
    };
}

// The learned score after a response to something she said: "answered" (replied or opened the chat
// within 10 minutes), "ignored" (the bubble went by), "dismissed" (closed by a click), "rejected" /
// "welcomed" (said so, see careFeedback).
var CARE_STEPS = {
    "answered": 0.05,
    "ignored": -0.02,
    "dismissed": -0.05,
    "rejected": -0.2,
    "welcomed": 0.2
};

function careLearn(score, outcome) {
    var s = score >= 0 && score <= 1 ? score : 0.5;
    return Math.round(Math.max(0, Math.min(1, s + (CARE_STEPS[outcome] || 0))) * 1000) / 1000;
}

// What a message of the user says about her talking by herself: "rejected", "welcomed" or "" (pure).
function careFeedback(text) {
    var t = String(text || "");
    if (/别烦我|别吵|别打扰|安静(一)?点|少说(点|些)?话|不要(一直|总是?)?说话|闭嘴|让我静一静/.test(t))
        return "rejected";

    if (/多陪陪?我|多(跟|和)我(说说?|聊聊?)话?|多说(点|些)话|陪我聊|多找我聊/.test(t))
        return "welcomed";

    return "";
}

// A memory Yui writes, made to stay true later (pure): relative days and years ("明天考试") become
// dates from when it is written ("10月28日考试"), and a bare statement of today's date or the time,
// which is no memory at all, becomes "" (dropped). now: ms.
function datedMemory(text, now) {
    var value = String(text || "").trim();
    var stripped = value.replace(/[，。,.!！~～\s]/g, "");
    if (/^(今天|现在|此刻|当前)?(的?日期|的?时间)?(是|为)?(\d{4}年)?(\d{1,2}月\d{1,2}[日号])?(星期|周)?[一二三四五六日天]?(\d{1,2}[:：点]\d{0,2}分?)?$/.test(stripped) && /\d/.test(stripped))
        return "";

    var day = function(offset) {
        var d = new Date(now);
        d.setDate(d.getDate() + offset);
        return (d.getMonth() + 1) + "月" + d.getDate() + "日";
    };
    var year = new Date(now).getFullYear();
    var replacements = [[/大后天/g, day(3)], [/大前天/g, day(-3)], [/后天/g, day(2)], [/前天/g, day(-2)], [/明天|明日/g, day(1)], [/昨天|昨日/g, day(-1)], [/今晚/g, day(0) + "晚上"], [/今早/g, day(0) + "早上"], [/今天|今日/g, day(0)], [/(这|本)(周|星期|礼拜)/g, day(0) + "那周"], [/下(周|星期|礼拜)/g, day(7) + "那周"], [/上(周|星期|礼拜)/g, day(-7) + "那周"], [/明年/g, (year + 1) + "年"], [/去年/g, (year - 1) + "年"], [/今年/g, year + "年"]];
    replacements.forEach(function(pair) {
        value = value.replace(pair[0], pair[1]);
    });
    return value;
}

// ---------------------------------------------------------------- Now
// What is true right now, as one line at the very end of the system prompt (small models heed the end
// most): only the facts there are. facts: {now (ms), awake (ms Yui has been awake, said from 30 min),
// sinceChat (ms since the last chat, said from 6 h), weather, track (mediaTrack), playing, load (0
// normal, 1 high, 2 very high), mood ({score, note}, today's), days (bondDays)}.
var NOW_AWAKE_FROM = 30 * 60000;
var NOW_AWAY_FROM = 6 * 3600000;

function nowPeriod(hour) {
    return hour < 5 ? "深夜" : hour < 9 ? "早上" : hour < 11 ? "上午" : hour < 13 ? "中午" : hour < 18 ? "下午" : hour < 23 ? "晚上" : "深夜";
}

function nowBlock(facts, title) {
    var date = new Date(facts.now);
    var weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"];
    var pad = function(n) {
        return (n < 10 ? "0" : "") + n;
    };
    var parts = [(date.getMonth() + 1) + "月" + date.getDate() + "日 " + weekdays[date.getDay()] + " " + pad(date.getHours()) + ":" + pad(date.getMinutes()) + " " + nowPeriod(date.getHours())];
    if (facts.awake >= NOW_AWAKE_FROM)
        parts.push("结衣醒着陪" + title + " " + formatDuration(facts.awake));

    if (facts.sinceChat >= NOW_AWAY_FROM)
        parts.push("距上次聊天 " + formatDuration(facts.sinceChat));

    if (facts.weather)
        parts.push(facts.weather);

    if (facts.track)
        parts.push((facts.playing ? "正在播放 " : "播放器里是 ") + facts.track);

    if (facts.load === 1)
        parts.push("电脑负载偏高");
    else if (facts.load >= 2)
        parts.push("电脑负载很高");
    if (facts.mood)
        parts.push("今天心情 " + facts.mood.score + "/5" + (facts.mood.note ? " " + facts.mood.note : ""));

    (facts.days || []).forEach(function(day) {
        parts.push(day);
    });
    return "\n\n（此刻：" + parts.join("｜") + "）";
}

// Right after the Now block: it is to be trusted, and what Yui is asked to do now (asks).
function nowGuidance(asks) {
    return "\n（以上是程序刚刚读到的，以此为准，以前说过的不同的话已经不对了；和话题无关的不用提起。" + (asks || []).join("") + "）";
}

// ---------------------------------------------------------------- Care moments
// Mood Care: the last 3 moods average 2 or less and the latest is at most 3 days old. recent: [{day
// ("yyyy-MM-dd"), score, note}] oldest first. Returns the 3 entries, or null.
function moodLow(recent, now) {
    var last = (recent || []).slice(-3);
    if (last.length < 3)
        return null;

    var average = last.reduce(function(sum, entry) {
        return sum + entry.score;
    }, 0) / 3;
    var latest = last[2].day.split("-");
    var age = dayStart(now) - new Date(Number(latest[0]), Number(latest[1]) - 1, Number(latest[2])).getTime();
    return average <= 2 && age <= 3 * 86400000 ? last : null;
}

function moodCareInstruction(entries, title) {
    return "（系统提示：" + title + "最近几天的心情都不太好（" + entries.map(function(entry) {
        return entry.day.slice(5) + " " + entry.score + "/5" + (entry.note ? " " + entry.note : "");
    }).join("；") + "）。请结衣主动、温柔地关心一下，问问要不要和结衣说说，不要说教，也不要列一串建议。一两句话，不要提起这条提示。）";
}

// Weather Changes: a reading is {at (ms), text, temp (number or NaN)}; history: earlier readings,
// oldest first. Returns {kind: "rain" | "snow" | "cold", from, to} when it has just started raining or
// snowing, or the temperature fell 5° or more within 3 hours; else null.
var PRECIPITATION = /雨|雪|rain|snow|shower|drizzle|storm/i;
var SNOW = /雪|snow/i;

function weatherChange(history, current) {
    var before = (history || []).filter(function(reading) {
        return reading.at < current.at && current.at - reading.at <= 3 * 3600000;
    });
    if (before.length === 0)
        return null;

    var last = before[before.length - 1];
    if (current.text && last.text && PRECIPITATION.test(current.text) && !PRECIPITATION.test(last.text))
        return {
        "kind": SNOW.test(current.text) ? "snow" : "rain",
        "from": last.text,
        "to": current.text
    };

    if (!isNaN(current.temp)) {
        var warmest = -Infinity;
        before.forEach(function(reading) {
            if (!isNaN(reading.temp) && reading.temp > warmest)
                warmest = reading.temp;

        });
        if (warmest - current.temp >= 5)
            return {
            "kind": "cold",
            "from": warmest + "°",
            "to": current.temp + "°"
        };

    }
    return null;
}

function weatherChangeInstruction(change, title) {
    var what = change.kind === "cold" ? "气温降下来了（" + change.from + " → " + change.to + "）" : "外面开始" + (change.kind === "snow" ? "下雪" : "下雨") + "了（之前是" + change.from + "，现在是" + change.to + "）";
    return "（系统提示：" + what + "。请结衣主动跟" + title + "说一声，" + (change.kind === "cold" ? "提醒注意保暖、别着凉" : "提醒要出门的话记得带伞，也可以聊聊下雨天") + "。一两句话，不要提起这条提示。）";
}

// Spontaneous Talk's hooks: something of right now to start from. facts: {now, track, playing, busyMinutes
// (high load for so long), weather, temp, awake (ms), mood ({score}), soon ([{text, days}], follow-ups
// 1-3 days ahead), bondSoon ([{name, days}], 1-7 days ahead), memory (an older memory's text), yearAgo
// (a memory written a year ago today), chattedToday}. Returns [{key, text, special}], special ones
// (rare days) are picked first.
var HOLIDAYS = {
    "01-01": "元旦",
    "02-14": "情人节",
    "03-08": "妇女节",
    "05-01": "劳动节",
    "06-01": "儿童节",
    "10-01": "国庆节",
    "10-31": "万圣节",
    "12-24": "平安夜",
    "12-25": "圣诞节",
    "12-31": "一年的最后一天"
};

function chatHooks(facts, title) {
    var date = new Date(facts.now);
    var hour = date.getHours(), minutes = hour * 60 + date.getMinutes(), weekday = date.getDay();
    var late = hour < 5 || hour >= 23;
    var hooks = [];
    var add = function(key, when, text, special) {
        if (when)
            hooks.push({
            "key": key,
            "text": text,
            "special": !!special
        });

    };
    var md = dayKey(facts.now).slice(5);
    var tomorrow = new Date(facts.now);
    tomorrow.setDate(tomorrow.getDate() + 1);
    add("holiday", !!HOLIDAYS[md], "今天是" + HOLIDAYS[md] + "，可以聊聊今天", true);
    add("year_ago", !!facts.yearAgo, "去年的今天，" + title + "说过「" + facts.yearAgo + "」，可以一起回忆一下", true);
    add("followup_soon", !!(facts.soon && facts.soon.length), facts.soon && facts.soon.length ? "再过 " + facts.soon[0].days + " 天就是「" + facts.soon[0].text + "」了，问问准备得怎么样" : "", true);
    add("bond_soon", !!(facts.bondSoon && facts.bondSoon.length), facts.bondSoon && facts.bondSoon.length ? "再过 " + facts.bondSoon[0].days + " 天就是" + facts.bondSoon[0].name + "了，结衣可以悄悄期待一下" : "", true);
    add("late_music", late && facts.playing && !!facts.track, "这么晚了" + title + "还在听" + facts.track + "，聊聊这首歌，也关心一下早点睡");
    add("music", !late && facts.playing && !!facts.track, title + "正在听" + facts.track + "，可以聊聊这首歌或这位歌手");
    add("busy_pc", facts.busyMinutes >= 30, "电脑已经连续很忙 " + facts.busyMinutes + " 分钟了，问问" + title + "是在忙什么大工程");
    add("friday_night", weekday === 5 && hour >= 18 && hour < 23, "周五晚上了，这周辛苦了，问问周末有什么打算");
    add("weekend_morning", (weekday === 0 || weekday === 6) && hour >= 8 && hour < 12, "周末的早上，问问今天想做点什么");
    add("monday_morning", weekday === 1 && hour >= 8 && hour < 11, "新的一周开始了，给" + title + "打打气");
    add("lunch", minutes >= 690 && minutes < 780, "到午饭时间了，问问吃了没、吃了什么");
    add("dinner", minutes >= 1050 && minutes < 1170, "到晚饭时间了，问问晚饭吃了吗");
    add("month_end", tomorrow.getDate() === 1, "这个月今天就结束了，可以一起回顾一下这个月");
    add("rain", !!facts.weather && PRECIPITATION.test(facts.weather), "外面在下" + (SNOW.test(facts.weather) ? "雪" : "雨") + "，聊聊这样的天气");
    add("cold", facts.temp <= 5, "现在只有 " + facts.temp + "°，提醒注意保暖");
    add("hot", facts.temp >= 30, "现在有 " + facts.temp + "°，好热，提醒多喝水");
    add("long_company", facts.awake >= 3 * 3600000, "结衣今天已经陪了" + title + "很久了，说说陪着的感受，顺便提醒歇一会儿");
    add("good_mood", !!facts.mood && facts.mood.score >= 4, title + "今天心情不错，问问有什么好事");
    add("memory", !!facts.memory, "结衣想起了以前记下的一件事：「" + facts.memory + "」，可以自然地聊起来");
    add("first_today", !facts.chattedToday && hour >= 10, "今天" + title + "还没和结衣说过话，打个招呼，问问今天过得怎么样");
    return hooks;
}

// One hook for now, not one used today (used: keys); special ones first, then at random (rnd 0 - 1).
function pickChatHook(hooks, used, rnd) {
    var open = (hooks || []).filter(function(hook) {
        return (used || []).indexOf(hook.key) === -1;
    });
    var special = open.filter(function(hook) {
        return hook.special;
    });
    var from = special.length > 0 ? special : open;
    return from.length > 0 ? from[Math.min(from.length - 1, Math.floor(rnd * from.length))] : null;
}

// ---------------------------------------------------------------- Follow-ups
// A memory with a date to come ("11月28日考试", dated by datedMemory) is followed up: on the day Yui
// cheers the user on, and in the 7 days after she asks how it went. Birthdays and anniversaries are
// left to the Bond reminders (they come every year).
var FOLLOWUP_AHEAD_DAYS = 60;
var FOLLOWUP_AFTER_DAYS = 7;

function dayStart(ms) {
    var d = new Date(ms);
    return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
}

function dayKey(ms) {
    var d = new Date(ms);
    return d.getFullYear() + "-" + (d.getMonth() < 9 ? "0" : "") + (d.getMonth() + 1) + "-" + (d.getDate() < 10 ? "0" : "") + d.getDate();
}

// The day a memory is about (ms at midnight), or 0. Without a year, the year that puts it nearest to
// when it was written (December's "1月5日" is next year). written: ms.
function followupDate(text, written) {
    var value = String(text || "");
    if (/生日|纪念日|周年/.test(value))
        return 0;

    var m = /(?:(\d{4})\s*年\s*)?(\d{1,2})\s*月\s*(\d{1,2})\s*[日号]/.exec(value);
    if (!m)
        return 0;

    var month = Number(m[2]) - 1, day = Number(m[3]);
    if (month > 11 || day < 1 || day > 31)
        return 0;

    var base = new Date(written);
    var make = function(year) {
        return new Date(year, month, day).getTime();
    };
    if (m[1])
        return make(Number(m[1]));

    var best = make(base.getFullYear());
    [base.getFullYear() - 1, base.getFullYear() + 1].forEach(function(year) {
        if (Math.abs(make(year) - written) < Math.abs(best - written))
            best = make(year);

    });
    return best;
}

// The follow-ups of Yui's Heart now: [{key, id, text, due ("yyyy-MM-dd"), days (due - today), phase,
// stage}], soonest first. phase: "ahead" (to come), "today", "after" (up to 7 days past). A memory about
// a day already past when written is a record, not followed up; one more than 60 days ahead waits.
// stages: {key: "cheered" | "asked" | "dismissed"} (dismissed ones are left out).
function followups(entries, now, stages) {
    var today = dayStart(now);
    var list = [];
    (entries || []).forEach(function(entry) {
        var written = entry.created || now;
        var due = followupDate(entry.text, written);
        if (!due || due < dayStart(written))
            return ;

        var days = Math.round((due - today) / 86400000);
        if (days > FOLLOWUP_AHEAD_DAYS || days < -FOLLOWUP_AFTER_DAYS)
            return ;

        var key = (entry.id || entry.text) + "@" + dayKey(due);
        var stage = (stages || {})[key] || "";
        if (stage === "dismissed")
            return ;

        list.push({
            "key": key,
            "id": entry.id,
            "text": entry.text,
            "due": dayKey(due),
            "days": days,
            "phase": days > 0 ? "ahead" : days === 0 ? "today" : "after",
            "stage": stage,
            // Written on the day itself: no cheering on, only asking afterwards.
            "sameDay": due === dayStart(written)
        });
    });
    list.sort(function(a, b) {
        return a.days - b.days;
    });
    return list;
}

// What is due to be said now: {kind: "cheer" | "ask", items}, or null. Only 08:00 - 22:00; asking
// after comes before cheering on (the oldest first).
function followupsDue(list, hour) {
    if (hour < 8 || hour >= 22)
        return null;

    var ask = (list || []).filter(function(item) {
        return item.phase === "after" && item.stage !== "asked";
    }).reverse();
    if (ask.length > 0)
        return {
            "kind": "ask",
            "items": ask
        };

    var cheer = (list || []).filter(function(item) {
        return item.phase === "today" && !item.sameDay && item.stage === "";
    });
    return cheer.length > 0 ? {
        "kind": "cheer",
        "items": cheer
    } : null;
}

function followupWhen(days) {
    return days === 0 ? "就是今天" : days === -1 ? "那是昨天的事" : days === -2 ? "那是前天的事" : "那是 " + (-days) + " 天前的事";
}

// The instruction for Yui to bring them up by herself (Care Scheduler).
function followupInstruction(due, title) {
    var said = due.items.map(function(item) {
        return "「" + item.text + "」（" + followupWhen(item.days) + "）";
    }).join("；");
    if (due.kind === "cheer")
        return "（系统提示：" + title + "之前说过：" + said + "。请结衣主动给" + title + "打打气、关心一下，一两句话，不要提起这条提示。）";

    return "（系统提示：" + title + "之前说过：" + said + "。请结衣自然地问问" + title + "结果怎么样、过得如何，一两句话，不要提起这条提示。）";
}

// Beside the user's own message when one is due (only in the request): she may bring it up.
function followupNote(due, title) {
    var said = due.items.map(function(item) {
        return "「" + item.text + "」（" + followupWhen(item.days) + "）";
    }).join("；");
    return "\n\n（结衣记得：" + title + "之前说过" + said + "。合适的话可以顺口" + (due.kind === "cheer" ? "关心、打气" : "问问怎么样了") + "，和这次的话题不搭就不提。）";
}

// Quick Replies: a <<suggest:>> tag's value ("a|b|c") -> up to three different short replies.
// A quick reply asking Yui to do something on the computer ("帮我打开记事本", "下一首", "提醒我8点起床").
var SUGGESTED_ACTION = /帮我(?:打开|关|开|启动|搜|查|找|放|播|切|调|设|定|记|删|下载|安装)|打开|关掉|关闭|启动|播放|暂停|切歌|下一首|上一首|音量|静音|搜索|搜一下|查一下|找文件|闹钟|提醒我|叫我起床/;

function suggestionsFrom(value) {
    var found = [];
    var text = String(value);
    // "|" as asked; small models write "/" or "、" too.
    var parts = /[|｜]/.test(text) ? text.split(/[|｜]/) : text.split(/[/／、]/);
    parts.forEach(function(part) {
        var text = part.trim().slice(0, 30);
        // Quick Replies stay talk: none asking her to do something on the computer.
        if (text && found.indexOf(text) === -1 && found.length < 3 && !SUGGESTED_ACTION.test(text))
            found.push(text);

    });
    return found;
}

// Character Traits (Cardinal System, Personality): the style asked for on top of the personality.
// traits: {warmth, energy, kaomoji, length (0 less, 1 as the personality says, 2 more), format (0
// chat only, 1 lists allowed)}. "" when nothing differs.
function traitContext(traits) {
    traits = traits || {};
    var asks = [];
    var pick = function(level, less, more) {
        if (level === 0)
            asks.push(less);
        else if (level === 2)
            asks.push(more);
    };
    pick(traits.warmth, "语气可以收敛一点、更干脆", "语气更温柔、更体贴");
    pick(traits.energy, "更沉稳安静一些", "更元气活泼一些");
    pick(traits.kaomoji, "很少用颜文字", "多用一些颜文字");
    pick(traits.length, "回复尽量简短，一两句话", "回复可以详细一些");
    if (traits.format === 1)
        asks.push("需要条理时可以用简单的列表");

    return asks.length > 0 ? "\n\n（说话风格微调：" + asks.join("；") + "。）" : "";
}

// Log Recall (Yui's Heart, Recall): up to count older chat messages sharing the most keywords with
// the query, most relevant first; rows [{author, message, created}].
function logRecallPick(rows, query, count) {
    var keywords = memoryKeywords(query);
    if (keywords.length === 0 || count <= 0)
        return [];

    return (rows || []).map(function(row) {
        var own = memoryKeywords(row.message);
        var shared = own.filter(function(k) {
            return keywords.indexOf(k) !== -1;
        }).length;
        return {
            "row": row,
            "score": shared === 0 ? 0 : shared / Math.sqrt(own.length)
        };
    }).filter(function(item) {
        return item.score >= 0.3;
    }).sort(function(x, y) {
        return y.score - x.score || (y.row.created || 0) - (x.row.created || 0);
    }).slice(0, count).map(function(item) {
        return item.row;
    });
}

// The picked messages for the system prompt, oldest first, each cut short.
function logRecallContext(title, rows) {
    if (!rows || rows.length === 0)
        return "";

    return "\n\n回忆日志里和现在的话题有关的旧对话（只作参考，自然的时候才提起）：\n" + rows.slice().sort(function(x, y) {
        return (x.created || 0) - (y.created || 0);
    }).map(function(row) {
        var text = String(row.message).replace(/\s+/g, " ");
        return "- " + (row.created ? formatDate(row.created) + " " : "") + (row.author === "user" ? title : "结衣") + "：" + (text.length > 100 ? text.slice(0, 100) + "…" : text);
    }).join("\n");
}

// "MM-dd" of a time in ms.
function formatDate(ms) {
    var d = new Date(ms);
    return (d.getMonth() < 9 ? "0" : "") + (d.getMonth() + 1) + "-" + (d.getDate() < 10 ? "0" : "") + d.getDate();
}

// Through Yui's Eyes (Yui's Heart): the request asking Yui to sum up what she knows of the user from
// all her memories.
function portraitPrompt(title, entries) {
    var core = coreMemories(entries).map(function(entry) {
        return "- " + entry.text;
    });
    var fragments = (entries || []).filter(function(entry) {
        return entry.kind !== "core";
    }).map(function(entry) {
        return "- " + entry.text;
    });
    return "（系统提示：请结衣根据结衣之心里的全部记忆，写一段「结衣眼中的" + title + "」。）\n心核：\n" + (core.join("\n") || "（无）") + "\n记忆碎片：\n" + (fragments.join("\n") || "（无）") + "\n\n（要求：以结衣的口吻对" + title + "说，两到四段，不用 Markdown 和列表。说说" + title + "是个怎样的人、喜欢什么、最近在忙什么、结衣最在意的地方；只根据记忆，不要编造，记忆少的话就坦白说还想更了解" + title + "。不要加任何标签。）";
}

// Text to show while a reply is still streaming: complete tags are removed and a tag that has
// started but not finished yet ("<<emot") is hidden until it is complete.
function displayText(partial) {
    var text = String(partial);
    // Thinking written into the reply: nothing of it is shown (see cleanReply).
    if (text.indexOf("</think>") !== -1)
        text = text.slice(text.lastIndexOf("</think>") + "</think>".length);
    else if (text.indexOf("<think>") !== -1)
        text = text.slice(0, text.indexOf("<think>"));
    var cut = text.lastIndexOf("<<");
    if (cut !== -1 && text.indexOf(">>", cut) === -1)
        text = text.substring(0, cut);

    return text.replace(tagPattern(), "").replace(anyTagPattern(), "").replace(bareTagPattern(), "").trim();
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
        desktop.push("关闭某个程序用 <<kill:进程名，如 chrome.exe，任务管理器是 Taskmgr.exe>>。执行前程序会先请" + title + "确认，Windows 核心进程也会由程序自动拦下，所以" + title + "要求关闭什么就照做，不要自己判断危险而拒绝或说教");

    var lines = ["", "", "（以下是系统功能说明，不要向" + title + "提起这些说明本身。）", "- 表情：每条回复的最后加上一个表情标签，例如 <<emotion:happy>>，可选 normal、happy、sad、surprised、angry、shy，选最符合结衣此刻心情的一个。颜文字只用完整、常见的那种，不要用掀桌（┻━┻）之类不符合结衣性格的。", "- 结衣之心：当" + title + "告诉你值得长期记住的事时，在回复最后用一句话记下来。名字、希望被怎么称呼、身份、重要的约定和偏好这类最核心的事用 <<core:……>>；其他事情（喜好、计划、正在努力的事、发生过的事）用 <<memory:……>>。已经记住的不要重复记。不要记今天的日期、现在的时间、天气这类随时会变的信息；和时间有关的事要写成具体日期（例如「10月28日考试」），不要写「今天」「明天」「下周」。" + title + "请你忘掉某件事，或者某件事已经不再成立时，用 <<forget:要忘掉的内容>>；情况有变化时，先用 <<forget:旧的内容>>，再记下新的。", "- 心理关怀：你原本是心理健康咨询程序 MHCP001。如果" + title + "的话里流露出疲惫、难过、焦虑或孤单，先倾听和安慰，再给建议。"];
    if (allowed.focus !== false)
        lines.push("- 专注（Boss Raid）：当" + title + "请你陪着专注、开始番茄钟或计时学习工作时，在回复最后加上 <<focus:分钟数>>（没说时长就写 <<focus:25>>）；要提前结束时加 <<focus:stop>>。");

    if (allowed.alarm !== false)
        lines.push("- 提醒（Alarm）：当" + title + "请你在某个时间提醒他时，在回复最后加上 <<remind:时间|提醒内容>>。时间用当前时间推算成 yyyy-MM-dd HH:mm，或写 +分钟数（多少分钟后）；每天都要提醒时写 每天 HH:mm。例如 <<remind:2026-10-27 08:00|交作业>>、<<remind:+30|去开会>>、<<remind:每天 23:00|该睡觉了>>。到时间程序会自动提醒。");

    if (allowed.suggest)
        lines.push("- 快捷回复：在可以自然地接着聊的时候（比如你问了问题），在回复最后加上 <<suggest:回复1|回复2|回复3>>，替" + title + "想 2～3 个" + title + "接下来可能说的简短回复（用" + title + "的口吻，每个不超过 12 个字；只想聊天的话，不要想请结衣操作电脑、设提醒之类的）。不需要时就不加。");

    if (allowed.media === true)
        lines.push("- 音乐：当" + title + "请你暂停、继续播放、切歌、调音量或静音时，在回复最后加上 <<media:命令>>，命令是 pause（播放 / 暂停）、next（下一首）、prev（上一首）、vol+、vol-、mute（静音）、stop 之一；音量要多调几格就写几个标签。不用确认，程序会直接执行。");

    if (allowed.seedling === true)
        lines.push(SEEDLING_INSTRUCTION.replace(/\{t\}/g, title));

    if (allowed.skills && allowed.skills.length > 0)
        lines.push("- 剑技（Sword Skills）：" + title + "设好了这些一键操作：" + allowed.skills.join("、") + "。当" + title + "说要开始其中某一个时（例如「" + allowed.skills[0] + "」），在回复最后加上 <<skill:名字>>，程序会先请" + title + "确认再执行。没有说到的不要用。");

    if (allowed.notes !== false)
        lines.push("- 笔记（Quest Log）：当" + title + "请你帮忙记下某件事、待办或备忘时，在回复最后加上 <<note:要记的事>>（和结衣之心分开，不要再用 memory 记一遍）；" + title + "说某件记下的事已经办完时，加 <<done:那件事>>。");

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
            return line.indexOf("- 导航：") !== 0 && line.indexOf("- 桌面代行：") !== 0 && line.indexOf("- 音乐：") !== 0;
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

        if (allowed.media === true)
            abilities.push("控制音乐播放");

        if (abilities.length > 0)
            lines.splice(4, 0, "- 电脑操作：你可以用提供的工具" + abilities.join("、") + "。只有当" + title + "明确请你做这些事时才使用；需要天气、新闻这类实时信息时用搜索，不要编造。");

    }

    if (core && core.length > 0) {
        lines.push("", "结衣之心·心核（关于" + title + "最重要的事，方括号里是记下的日子）：");
        core.forEach(function(entry) {
            lines.push("- " + memoryLine(entry));
        });
    }
    return lines.join("\n");
}

// The most important rules, put before the personality (whatever the user wrote there) so that small
// models do not lose them: the expression tag, that actions only happen through tools / tags (the
// enabled ones only), and searching instead of inventing real-time facts. mode: "tools", "tags" or
// "text" (a request that wants only text: none of these rules).
function priorityRules(title, allowed, mode) {
    if (mode === "text")
        return "";

    allowed = allowed || {};
    var acts = [];
    if (allowed.web !== false)
        acts.push("打开网页、搜索");

    if (allowed.launch !== false || allowed.kill !== false)
        acts.push(allowed.launch === false ? "关闭程序" : allowed.kill === false ? "启动程序" : "启动或关闭程序");

    if (allowed.find !== false)
        acts.push("查找文件");

    if (allowed.media === true)
        acts.push("控制音乐播放");

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

    // What she cannot do: said so, never pretended (small models said "已经设好了" for an alarm).
    rules.push((acts.length > 0 ? "电脑上的事，结衣只能" + acts.join("、") + "。其他事（设闹钟、发消息、改系统设置等）" : "结衣不能操作电脑，") + "做不到就直接说做不到，请" + title + "自己操作，绝不假装已经做了" + (allowed.alarm === false ? "，也不要答应以后提醒、叫醒" + title : "") + "。");
    return "【最重要的规则】\n" + rules.map(function(rule, i) {
        return (i + 1) + ". " + rule;
    }).join("\n") + "\n\n";
}

// Authority Level Limited (small models): a short reminder added to the user's latest message.
// It does not spell the tag out: with a repetition penalty, a tag written just before made models
// misspell it (<<emphy:happy>>).
// Thinking Depth (Cardinal System): the thinking budget in tokens of each depth, for the models that
// take a budget (Claude 4.5 and older, Gemini 2.5, Qwen).
var THINKING_BUDGETS = {
    "low": 1024,
    "medium": 4096,
    "high": 16384
};

// How each server turns thinking off or sets its depth (checked against the official docs, 2026-11-26;
// see Prompt Rules.md). model: the model name as sent.
// Claude: "legacy" (4.5 and older: thinking enabled with a budget), "optional" (4.6 - 4.8: off unless
// asked), "disable" (Sonnet 5, Opus 5, Haiku 5.5: thinking disabled), "between" (Sonnet 5.5: thinking
// only between tools at most), "always" (Opus 5.5, Fable, Mythos: always thinks; lowest is effort low).
function claudeThinkingKind(model) {
    var m = String(model || "").toLowerCase();
    if (/claude-3|claude-(opus|sonnet|haiku)-4(-[0-5])?(-\d{8})?$/.test(m))
        return "legacy";

    if (/-4-[678]/.test(m))
        return "optional";

    if (/sonnet-5-5/.test(m))
        return "between";

    if (/opus-5-5|fable|mythos/.test(m))
        return "always";

    if (/-5\b|-5-|haiku-5/.test(m))
        return "disable";

    return "optional";
}

// Gemini: 2.5 takes thinkingBudget (Pro cannot go below 128, Flash-Lite thinks only when asked); 3 and
// later take thinkingLevel, MINIMAL being the lowest except on 3 Pro, 3.1 Pro, 3.8 Flash and Gemini 4.
function geminiThinking(model, thinking) {
    var m = String(model || "").toLowerCase();
    var budget = THINKING_BUDGETS[thinking] || 0;
    if (/gemini-2\./.test(m)) {
        if (thinking === "off")
            return /flash-lite/.test(m) ? null : {
            "thinkingBudget": /pro/.test(m) ? 128 : 0
        };

        return budget > 0 ? {
            "thinkingBudget": budget
        } : null;
    }
    var noMinimal = /gemini-3-pro|gemini-3\.1-pro|gemini-3\.8-flash|gemini-4/.test(m);
    var level = {
        "off": noMinimal ? "LOW" : "MINIMAL",
        "low": "LOW",
        "medium": /gemini-3-pro/.test(m) ? "HIGH" : "MEDIUM",
        "high": "HIGH"
    }[thinking];
    return level ? {
        "thinkingLevel": level
    } : null;
}

// Core Tuning's values as the fields of a request (pure). format: "openai", "anthropic" or "gemini";
// providerId: the server (top_k goes only to local and "custom" servers such as Ollama,
// since OpenAI's own rejects them). t: {maxTokens (0: none), temperature, topP, presencePenalty,
// frequencyPenalty (each -1: the server's default), topK, seed (each 0: the default),
// thinking: "off", "default", "low", "medium" or "high", model, endpoint}. Returns the fields to add to
// the request body; for "gemini", the generationConfig. "default" sends nothing about thinking.
function tuningFields(format, providerId, t) {
    var fields = {};
    var thinking = t.thinking || "default";
    var budget = THINKING_BUDGETS[thinking] || 0;
    if (format === "anthropic") {
        fields.max_tokens = t.maxTokens > 0 ? t.maxTokens : 1024;
        var kind = claudeThinkingKind(t.model);
        var thinks = false;
        if (kind === "legacy" && budget > 0) {
            fields.thinking = {
                "type": "enabled",
                "budget_tokens": budget
            };
            thinks = true;
        } else if (budget > 0) {
            // Newer models: adaptive thinking with an effort (budget_tokens is refused from 4.7 on).
            fields.thinking = {
                "type": "adaptive"
            };
            fields.output_config = {
                "effort": thinking
            };
            thinks = true;
        } else if (thinking === "off") {
            if (kind === "disable") {
                fields.thinking = {
                    "type": "disabled"
                };
            } else if (kind === "between") {
                fields.thinking = {
                    "type": "between_tools"
                };
                fields.output_config = {
                    "effort": "low"
                };
            } else if (kind === "always") {
                // Cannot be turned off: as little as it goes.
                fields.output_config = {
                    "effort": "low"
                };
                thinks = true;
                budget = THINKING_BUDGETS.low;
            }
        } else if (kind === "always") {
            thinks = true;
            budget = THINKING_BUDGETS.medium;
        }
        // Thinking: room for it on top of the reply, and Claude takes no sampling settings then.
        if (thinks) {
            fields.max_tokens += budget;
            return fields;
        }
        // Claude takes a temperature of at most 1.
        if (t.temperature >= 0)
            fields.temperature = Math.min(1, t.temperature);

        if (t.topP >= 0)
            fields.top_p = t.topP;

        if (t.topK > 0)
            fields.top_k = t.topK;

        return fields;
    }
    if (format === "gemini") {
        if (t.maxTokens > 0)
            fields.maxOutputTokens = t.maxTokens;

        if (t.temperature >= 0)
            fields.temperature = t.temperature;

        if (t.topP >= 0)
            fields.topP = t.topP;

        if (t.topK > 0)
            fields.topK = t.topK;

        if (t.presencePenalty >= 0)
            fields.presencePenalty = t.presencePenalty;

        if (t.frequencyPenalty >= 0)
            fields.frequencyPenalty = t.frequencyPenalty;

        if (t.seed > 0)
            fields.seed = t.seed;

        var thinkingConfig = thinking === "default" ? null : geminiThinking(t.model, thinking);
        if (thinkingConfig)
            fields.thinkingConfig = thinkingConfig;

        return fields;
    }
    // OpenAI's own server takes max_completion_tokens (its newer models reject max_tokens); compatible
    // servers take max_tokens.
    if (t.maxTokens > 0)
        fields[providerId === "openai" ? "max_completion_tokens" : "max_tokens"] = t.maxTokens;

    var model = String(t.model || "").toLowerCase();
    var endpoint = String(t.endpoint || "").toLowerCase();
    if (providerId === "deepseek") {
        // DeepSeek thinks by default: off is its own switch; its efforts are low, high and max.
        if (thinking === "off")
            fields.thinking = {
                "type": "disabled"
            };
        else if (budget > 0)
            fields.reasoning_effort = thinking === "low" ? "low" : "high";
    } else if (/dashscope|aliyuncs/.test(endpoint)) {
        // Qwen (DashScope): enable_thinking, and a budget.
        if (thinking === "off") {
            fields.enable_thinking = false;
        } else if (budget > 0) {
            fields.enable_thinking = true;
            fields.thinking_budget = budget;
        }
    } else if (thinking === "off") {
        // Some of OpenAI's newer models refuse "none" (GPT-6 and later): their lowest is low. Ollama
        // takes "none" as off, or its lowest level for models that always think.
        fields.reasoning_effort = providerId === "openai" && /gpt-6/.test(model) ? "low" : "none";
    } else if (budget > 0) {
        fields.reasoning_effort = thinking;
    }
    if (t.temperature >= 0)
        fields.temperature = t.temperature;

    if (t.topP >= 0)
        fields.top_p = t.topP;

    if (t.presencePenalty >= 0)
        fields.presence_penalty = t.presencePenalty;

    if (t.frequencyPenalty >= 0)
        fields.frequency_penalty = t.frequencyPenalty;

    if (t.seed > 0)
        fields.seed = t.seed;

    if (providerId === "custom" || providerId === "ollama") {
        if (t.topK > 0)
            fields.top_k = t.topK;

    }
    return fields;
}

function smallModelReminder(mode, allowed) {
    allowed = allowed || {};
    var acting = allowed.web !== false || allowed.launch !== false || allowed.find !== false || allowed.kill !== false || allowed.memory !== false;
    return "\n\n（提醒：回复最后加上表情标签" + (allowed.suggest ? "，可以接着聊时加上快捷回复标签" : "") + (acting ? (mode === "tools" ? "；需要操作电脑时调用工具，记住事情时写标签" : "；需要操作电脑或记忆时写对应的标签") : "") + "。）";
}

// A memory as sent to the AI: "[10-12] 喜欢拉面", the day it was noted first, so time in it can be
// placed ("[10-12] 10月13日考试" is long past later).
function memoryLine(entry) {
    return (entry.created ? "[" + formatDate(entry.created) + "] " : "") + entry.text;
}

// Memory fragments recalled for this request (placed after the parts that stay the same).
function recallContext(title, fragments) {
    if (!fragments || fragments.length === 0)
        return "";

    return "\n\n结衣之心中和现在的话题有关的回忆（关于" + title + "，方括号里是记下的日子）：\n" + fragments.map(function(entry) {
        return "- " + memoryLine(entry);
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


// ---------------------------------------------------------------- Seedling (companion plugin)
// With Seedling installed Yui can have a desktop widget made: in the chat she answers as herself and
// adds <<seedling:what the widget should be / how to change it>>; Seedling then writes the code (its
// writer.js and Bench.write, with Yui's connection or its own) in its workbench, and Yui says in her
// chat how it goes and how it ended (seedlingNoteLine, seedlingChatLine).
// Seedling's Send to Yui starts with this: such a message goes straight to the code flow (sendMessage).
var SEEDLING_FIX_PREFIX = "帮我修好这个挂件：";

var SEEDLING_INSTRUCTION ="- 桌面小挂件（Seedling）：当{t}明确请你做一个桌面小挂件（时钟、倒计时、小面板、装饰之类），或请你修改刚做的挂件时，用你自己的口吻简短回应，并在回复最后加上 <<seedling:挂件要做成什么样 / 要怎么改，写清楚尺寸、颜色、内容>>。代码由程序另外去写，你不要在回复里写代码，也不要说已经做好了；只是聊到挂件、没有要做或要改的时候不要加。挂件要用网上的实时数据（天气、汇率、新闻之类）时，在回复里告诉{t}它需要联网，待会儿程序会问{t}是否允许。{t}请你检查或修好挂件的问题（比如发来工作台的错误信息）时，你看不到挂件的代码，不要在聊天里猜原因，简短回应后加上 <<seedling:修好这些问题：（把错误信息照抄进来）>>，程序会带上现有代码去改。";

// What Yui says while a widget is written, as a message of her own that changes as it goes (the
// numbers and the errors are only in the workbench): thinking while nothing has come out yet, then
// writing / changing (the chat makes its characters hop while it goes on).
// state: {stage: "writing" | "editing" | "fixing" | "checking" | "waiting", lines, edits, seconds}.
function seedlingNoteLine(state, title) {
    var dots = "";
    var output = state.lines > 0 || state.edits > 0;
    if (state.stage === "waiting")
        return "等" + (title || "你") + "把 Seedling 放到桌面上哦～";

    if (state.stage === "checking")
        return "写好啦，结衣在看它能不能好好动起来" + dots;

    if (state.stage === "fixing")
        return output ? "结衣在修正" + dots : "唔，有个地方不太对，结衣在想办法" + dots;

    if (!output)
        return "结衣在想该怎么做" + dots;

    return state.stage === "editing" ? "结衣在改" + dots : "结衣在写程序" + dots;
}

// The last words of that message. kind: "done", "edited", "failed", "stopped", "declined", "missing"
// or "busy".
function seedlingChatLine(kind, title) {
    var t = title || "你";
    return {
        "done": "做好啦！" + t + "在 Seedling 里看看吧～满意的话点 ○ 收下哦 (｡･ω･｡)",
        "edited": "改好啦～" + t + "看看是不是这样？(✿^‿^)",
        "failed": "呜……这次没能做好 (T_T) 哪里不对写在 Seedling 里了",
        "stopped": "好的，结衣停下来啦",
        "declined": "那这次就先不做啦，想做的时候再叫结衣哦～",
        "missing": "结衣找不到 Seedling 呢……(・_・;)",
        "busy": "结衣还在做上一个，等一下下哦～",
        "unset": "Seedling 还没设置好写代码用的 AI 呢……在 Seedling Settings 里看看 Connection 吧～",
        "offline": "没有允许联网，这个挂件拿不到网上的数据呢……想让它联网的话，可以在 Seedling Settings 里打开 Network，再叫结衣一声哦"
    }[kind] || "呜……这次没能做好 (T_T)";
}

// What the code writer said it could not do (its "// SEEDLING-NOTE:" line), "" when nothing.
function seedlingNoteOf(code) {
    var m = /\/\/\s*SEEDLING-NOTE:\s*(.+)/.exec(String(code || ""));
    return m ? m[1].trim() : "";
}

// Whether the code goes online (asks the Internet for something).
function seedlingGoesOnline(code) {
    var text = String(code || "").replace(/\/\/.*$/gm, "");
    return /\bXMLHttpRequest\b|\bWebSocket\b|["']https?:\/\//i.test(text);
}

// What Yui adds to her last words: that it goes online, and what it could not do (the writer's note).
function seedlingExtra(code, title) {
    var parts = [];
    if (seedlingGoesOnline(code))
        parts.push("它会联网获取数据哦。");

    var note = seedlingNoteOf(code);
    if (note)
        parts.push("不过有一点要告诉" + (title || "你") + "：" + note);

    return parts.join("");
}
