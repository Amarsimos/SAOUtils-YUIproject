.pragma library

// Yui features that do not depend on the UI: control tags in replies, the "System Call" easter
// egg, canned lines and the extra instructions added to the system prompt.

// Expressions the AI may choose with <<emotion:...>>; "normal" uses the main character image.
var EMOTIONS = ["normal", "happy", "sad", "surprised", "angry", "shy"];

// At most this many entries are kept in Yui's Heart (long-term memory). TEMPORARY value, pending a
// decision on how memories are retrieved (all of them are sent with every request for now).
var MAX_MEMORIES = 100;

// Load levels of the crystal and the Cardinal bars: 0 green (normal), 1 yellow (notice), 2 red (high).
// Default [yellow, red] thresholds in percent; GPU is higher because games and video keep it busy,
// memory lower because a full memory slows the whole computer. Editable in the Option window.
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
    return /<<\s*(emotion|memory|open|search|launch|find|kill)\s*[:：]\s*([^<>]*?)\s*>>/gi;
}

// Processes <<kill:>> always refuses to close (Immortal Object): core Windows processes and SAO
// Utils itself. Users can protect more in the Option window, but cannot remove these.
var PROTECTED_PROCESSES = ["system", "smss.exe", "csrss.exe", "wininit.exe", "winlogon.exe", "services.exe", "lsass.exe", "svchost.exe", "dwm.exe", "explorer.exe", "fontdrvhost.exe", "registry", "sao utils.exe", "nervlaunch.exe", "nervservice.exe", "nervstartup.exe", "nervsteam.exe", "nervwebkit.exe"];

// Process name for taskkill ("chrome" -> "chrome.exe"), or "" when it is not a plain name.
function processName(value) {
    var name = String(value).trim();
    if (!/^[A-Za-z0-9 ._()\-]+$/.test(name))
        return "";

    return /\.exe$/i.test(name) ? name : name + ".exe";
}

// userProtected: extra names the user protected (Option window).
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
// the package's scripts/find.bat (scriptFile): it uses esPath (Option window) or looks for es.exe in
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

// What can be clicked in a chat message: web links, the word 「Option」 (opens the Option window) and
// Windows paths such as D:\Tools\a b.txt — a drive letter, then anything up to the end of the line, a
// quote or bracket, or Chinese text / punctuation (so "文件在 D:\a.txt 里" links only the path).
var LINK_PATTERN = /(https?:\/\/[^\s"'<>「」『』（）()\u3000-\u303F\u4E00-\u9FFF\uFF00-\uFFEF]+)|(「Option」)|([A-Za-z]:[\\/][^\r\n"'<>|*?「」『』（）()\u3000-\u303F\u4E00-\u9FFF\uFF00-\uFFEF]*)/g;

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
function parseReply(text, userProtected) {
    var result = {
        "text": "",
        "emotion": "",
        "memories": [],
        "action": null,
        // A <<kill:>> refused because the process is protected.
        "blocked": ""
    };
    result.text = String(text).replace(tagPattern(), function(all, kind, value) {
        kind = kind.toLowerCase();
        value = value.trim();
        if (!value)
            return "";

        if (kind === "emotion") {
            var emotion = value.toLowerCase();
            if (EMOTIONS.indexOf(emotion) !== -1)
                result.emotion = emotion;
        } else if (kind === "memory") {
            result.memories.push(value);
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
                    "url": "https://www.bing.com/search?q=" + encodeURIComponent(value)
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

// Add new memories to Yui's Heart, skipping ones already there; the oldest are dropped first.
function mergeMemories(heart, memories) {
    var result = (heart || []).slice();
    for (var i = 0; i < memories.length; i++) {
        var memory = memories[i];
        var known = result.some(function(old) {
            return old === memory || old.indexOf(memory) !== -1 || memory.indexOf(old) !== -1;
        });
        if (!known)
            result.push(memory);

    }
    while (result.length > MAX_MEMORIES)
        result.shift();
    return result;
}

// Extra system prompt instructions: how to use the control tags, and what Yui remembers.
function featureInstructions(title, heart) {
    var lines = ["", "", "（以下是系统功能说明，不要向" + title + "提起这些说明本身。）", "- 表情：每条回复的最后加上一个表情标签，例如 <<emotion:happy>>，可选 normal、happy、sad、surprised、angry、shy，选最符合结衣此刻心情的一个。", "- 结衣之心：当" + title + "告诉你值得长期记住的事（名字、喜好、生日等重要日子、正在努力的事情）时，在回复最后加上 <<memory:用一句话写下要记住的事>>。已经记住的不要重复记。", "- 导航：只有当" + title + "明确请你打开某个网站时，才在回复最后加上 <<open:完整的 https 网址>>；明确请你搜索时，加上 <<search:搜索词>>。", "- 桌面代行：只有当" + title + "明确请你做这些事时才使用，每次都会先请" + title + "确认：启动程序用 <<launch:程序名或完整路径>>；在电脑里找文件用 <<find:文件名或关键词>>；关闭某个程序用 <<kill:进程名，如 chrome.exe>>。系统关键进程不能关闭。", "- 心理关怀：你原本是心理健康咨询程序 MHCP001。如果" + title + "的话里流露出疲惫、难过、焦虑或孤单，先倾听和安慰，再给建议。"];
    if (heart && heart.length > 0) {
        lines.push("", "结衣之心里记着的关于" + title + "的事：");
        for (var i = 0; i < heart.length; i++)
            lines.push("- " + heart[i]);
    }
    return lines.join("\n");
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
