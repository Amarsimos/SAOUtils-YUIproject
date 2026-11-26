.pragma library

// How Seedling has a widget written by a model (section 11 of "Seedling Development Plan.md"): the
// prompt (rules that follow safety.js, Widget Style, a template to look at), the request, the code out
// of the reply (whole or as SEARCH / REPLACE edits) and what to tell the model when it went wrong.
// Pure functions; the flow is Writer.qml, the connection api.js or MHCP-YUI's.
// (Moved from MHCP-YUI's yui.js, where Seedling's writing began.)

// A reply without its thinking (<think>...</think>) and without paragraphs said twice.
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

// Rule 15, only when MHCP-YUI is there: her data (@yui, props.js YUI_KEYS).
var YUI_RULE = "15. 挂件要显示结衣这边的数据时，写在根元素最外层的 property 上，上一行写 // @yui 名字，Seedling 会自动填进去（只读）。名字只能是：companion_days（陪伴天数，int）、mood（今天心情 1-5，int，0 是没记录）、mood_text（今天心情的文字，string）、mood_history（最近 30 天心情，var：[{day: \"yyyy-MM-dd\", score: 1-5}]）、boss_raid（Boss Raid 剩余分钟，int）、raid_timer（Boss Raid 计时文字，string）、raid_cleared（刚打赢 Boss Raid 的几秒内是 1，int）、next_alarm（下一个闹钟还有几分钟，int）、next_alarm_text（下一个闹钟的文字，string）、quest_log（待办，string，每行一条）、heart_core（结衣之心的记忆条数，int）、col_ledger（本月用掉的 k token，real）、latest_report（最新周报，string）。用了 @yui 的挂件不能联网。没有数据时保持属性的默认值，所以默认值要能直接显示。";

// The system prompt of the request that writes the code. allowNetwork: the workbench's Network is on;
// editing: there is code to change, which is changed with SEARCH / REPLACE blocks (as Aider and Cline
// do) instead of being written out again.
function codePrompt(allowNetwork, editing, withYui) {
    // The rules follow Seedling's safety check (com.amarsimos.widget.seedling/qml/safety.js, S3 of
    // "Seedling Development Plan.md"), each with what to write instead, so the code passes the first
    // time. The check is what keeps widgets safe; these rules only save rewrites.
    return [editing ? "你是一个只写 QML 的程序，负责修改一个 SAO Utils 桌面小挂件的代码。" : "你是一个只写 QML 的程序。根据要求写一个 SAO Utils 桌面小挂件，只输出一个 ```qml 代码块，不要任何解释。",
        "代码会先经过安全检查，不符合下面规则的会被拒绝。规则：",
        "1. 只能 import：QtQuick 2.12、QtQuick.Controls 2.12、QtQuick.Layouts 1.12、QtQuick.Shapes 1.12、QtGraphicalEffects 1.0、QtQuick.Particles 2.12。不能 import 文件、文件夹或其他模块（包括 QtQuick.Window、NERvGear）。",
        "2. Qt.* 只能用颜色、日期、几何和绑定：Qt.rgba / rgb / hsla / lighter / darker / tint、Qt.formatDate / formatTime / formatDateTime、Qt.point / size / rect、Qt.binding、Qt.callLater，以及 Qt.AlignCenter 这类常量。",
        "3. 不能用：eval、Function、constructor、prototype、__proto__、this、arguments、globalThis、Loader、createObject、LocalStorage、WorkerScript、Window、反引号模板字符串（`...`）、正则表达式（/.../）。拼字符串用 +，查找文字用 indexOf / split。",
        "4. 方括号 [ ] 里只能写数字（list[0]）、直接写出的字段名（data[\"temp\"]）或 for 循环的计数器 / Repeater 的 index（list[i]）。不能写别的变量：按值查表用 switch 或对象的点号（colors.sunny）。",
        "5. parent 只能用来取尺寸和锚线（parent.width、parent.height、anchors.left: parent.left），或写 anchors.fill: parent / anchors.centerIn: parent。不能写 parent.parent、x.parent，也不能把 parent 存进变量或传出去；要用别的元素就给它一个 id。",
        "6. 循环只用 for，并且要有终点：i < 一个不超过 1000 的数字，或 i < list.length；也可以用 for (var k in obj)。不能用 while、do。计数器从数字或 list.length 开始，每次朝终点走（i++、i += 2，倒数用 i--）；循环里不要改计数器，也不要往 list 里 push 让它变长；计数器在循环外不要再赋别的值，也不要拿它的名字当函数参数。地址属性（source、url）赋值时也要以写全的 \"https://主机/...\" 开头；用 .open( 、.source 的写法，不要写成 [\"open\"]。",
        "7. 根元素写明 width 和 height，都不超过 2000；Timer 的 interval 不小于 16（毫秒）；粒子的 emitRate / maximumEmitted 不超过 1000。背景可以是透明的。",
        allowNetwork ? "8. 可以联网：用 XMLHttpRequest；地址必须以写全的字符串开头，例如 \"https://api.example.com/data?q=\" + city；Image 的 source 也一样。只能用 http / https。" : "8. 一般不要联网；只有挂件本身必须用网上的数据时（天气、汇率、新闻之类）才用 XMLHttpRequest，程序会先问用户是否允许这个挂件联网。地址必须以写全的字符串开头，例如 \"https://api.example.com/data?q=\" + city；只能用 http / https。不要为了装饰去加载网络图片。",
        "9. 不能读写本地文件：不能出现 file:、qrc:、C:/ 这类地址，source 只能是写全的 https 地址、空字符串，或代码里自己元素的 id（给效果用）。",
        "10. 只用 QML 和 JavaScript 自己画，需要时间就用 Timer 和 new Date()。",
        editing ? "11. 修改时按下面的「修改方式」只输出改动。" : "11. 输出完整的代码。",
        "12. 代码要精简，控制在 150 行以内：不要堆大量示例数据、不要写用不到的功能，一个挂件做好一件事。",
        "13. 不要用编出来的数据冒充网上的实时数据。做不到要求里的某件事时（比如拿不到某个数据），照样写出能用的部分，并在代码第一行写一条注释说明：// SEEDLING-NOTE: 原因（一句话）。",
        "14. 挂件自己的设置和记忆：用户可能想调的值（城市、颜色、字号、主题、开关）写成根元素最外层的 property，上一行写 // @setting 标签；数字可加范围 // @setting 字号 | 12 - 48，几个选项 // @setting 主题 | 浅色 / 深色；类型用 string、int、real、bool、color。要在重启后记住的东西（待办、计数、笔记）也写在根元素最外层，上一行写 // @keep，类型用 var、string、int、real、bool。再写一行 // @name 挂件名。这类属性不要叫 source 或 url。用户会在挂件的右键 Settings... 里调这些设置，记住的东西由 Seedling 自动保存。"].concat(withYui ? [YUI_RULE] : []).concat(editing ? EDIT_RULES : []).join("\n");
}

// Widget Style (Seedling Settings) for the code prompt: how the widget looks unless the request says
// otherwise. "" when there is none.
function styleNote(style) {
    style = String(style || "").trim();
    return style ? "\n\n外观（要求里另外说了风格时，以要求为准）：" + style : "";
}

// A template of the same kind (Seedling's templates.js) for the code prompt: a way to write it, not
// something to copy. "" when none fits.
function templateNote(code) {
    code = String(code || "").trim();
    return code ? "\n\n参考：一个同类挂件的写法（只参考结构和 @setting / @keep 的用法，按这次的要求和上面的外观来写，不要照抄内容）：\n```qml\n" + code + "\n```" : "";
}

// How code is changed: SEARCH / REPLACE blocks (the format of Aider and Cline; like Claude Code's
// old_string / new_string, the SEARCH text must be found exactly once).
var EDIT_RULES = ["",
    "修改方式：用 SEARCH/REPLACE 块只输出改动，不要输出完整代码。格式：",
    "<<<<<<< SEARCH",
    "（从现有代码里一字不差复制的几行，包括缩进）",
    "=======",
    "（换成的内容；要删除就留空）",
    ">>>>>>> REPLACE",
    "规则：",
    "- SEARCH 必须和现有代码完全一致（包括空格和缩进），只包含要改的行，加上前后一两行上下文，保证它在代码里只出现一次。",
    "- 要改多处就写多个块，按代码从上到下的顺序。",
    "- 只输出这些块，不要解释，不要输出完整代码。",
    "- 只有改动超过一半时，才改为输出一个完整的 ```qml 代码块。"];

// The user message of that request: what is wanted, the code so far (when changing it) and, when
// asked again, what went wrong. whole: the complete code is asked for (the last way out when the
// edits do not fit).
function codeRequest(request, currentCode, problem, whole) {
    var parts = [];
    if (currentCode)
        parts.push("现在的代码：\n```qml\n" + currentCode + "\n```");

    parts.push((currentCode ? "要修改的地方：" : "要做的挂件：") + request);
    if (problem)
        parts.push(problem);

    if (whole)
        parts.push("这一次请不要用 SEARCH/REPLACE，直接输出改好后的完整代码（一个 ```qml 代码块）。");

    return parts.join("\n\n");
}

// The QML in a reply of that request: the first ```qml (or ```) block, else the whole text when it
// looks like QML; "" when there is none.
function codeFrom(text) {
    var value = cleanReply(text);
    var block = /```(?:qml|QML|javascript|js)?[ \t]*\n([\s\S]*?)```/.exec(value);
    if (block)
        return block[1].trim() + "\n";

    return /^\s*import\s+Qt/.test(value) ? value.trim() + "\n" : "";
}

// The code of a reply still streaming in: what follows ```qml (up to a closing ```), else "".
function partialCode(text) {
    var value = String(text || "").replace(/<think>[\s\S]*?(<\/think>|$)/g, "");
    var start = /```(?:qml|QML|javascript|js)?[ \t]*\n/.exec(value);
    if (!start)
        return "";

    var rest = value.slice(start.index + start[0].length);
    var end = rest.indexOf("```");
    return end === -1 ? rest : rest.slice(0, end);
}

// The reply of the code request was cut off: a ```qml block opened and never closed.
function codeCut(text) {
    var value = cleanReply(text);
    return /```(?:qml|QML|javascript|js)?[ \t]*\n/.test(value) && !/```(?:qml|QML|javascript|js)?[ \t]*\n[\s\S]*?```/.test(value);
}

// ---- SEARCH / REPLACE edits (Seedling)
// The blocks in a reply: [{search, replace}], in order ([] when there are none).
function edits(text) {
    var value = cleanReply(text).replace(/\r\n/g, "\n");
    var re = /<{5,9} ?SEARCH[^\n]*\n([\s\S]*?)\n?={5,9}[ \t]*\n([\s\S]*?)\n?>{5,9} ?REPLACE/g;
    var blocks = [];
    var m;
    while ((m = re.exec(value)) !== null)
        blocks.push({
        "search": m[1],
        "replace": m[2]
    });
    return blocks;
}

// How many SEARCH blocks a reply still streaming in has begun.
function editCount(text) {
    var found = String(text || "").match(/<{5,9} ?SEARCH/g);
    return found ? found.length : 0;
}

function trimLines(lines) {
    return lines.map(function(line) {
        return line.trim();
    });
}

// Where the search lines are in the code lines (trimmed, so indentation and trailing spaces do not
// count): the start indexes of every match.
function looseMatches(codeLines, searchLines) {
    var want = trimLines(searchLines);
    var have = trimLines(codeLines);
    var starts = [];
    for (var i = 0; i + want.length <= have.length; i++) {
        var same = true;
        for (var j = 0; j < want.length && same; j++)
            same = have[i + j] === want[j];
        if (same)
            starts.push(i);
    }
    return starts;
}

// The lines of the code most like the search (for telling the model what it missed).
function nearest(codeLines, searchLines) {
    var want = trimLines(searchLines);
    var have = trimLines(codeLines);
    var best = -1;
    var bestScore = 0;
    for (var i = 0; i + want.length <= have.length; i++) {
        var score = 0;
        for (var j = 0; j < want.length; j++)
            if (want[j] && have[i + j] === want[j])
                score++;
        if (score > bestScore) {
            bestScore = score;
            best = i;
        }
    }
    return best < 0 ? "" : codeLines.slice(best, best + want.length).join("\n");
}

// Applies the blocks to code, all or nothing (as Aider: exactly first, then ignoring indentation and
// trailing spaces, the replacement indented as the code found; found more than once does not count).
// Returns {ok, code, failed: [{index (1-based), reason "missing" | "many", nearest}], changed:
// [0-based line numbers changed or added in the new code], added, removed}.
function applyEdits(code, blocks) {
    var original = String(code || "").replace(/\r\n/g, "\n");
    var text = original;
    var failed = [];
    for (var b = 0; b < blocks.length; b++) {
        var search = blocks[b].search;
        var replace = blocks[b].replace;
        if (!search.trim()) {
            failed.push({ "index": b + 1, "reason": "missing", "nearest": "" });
            continue;
        }
        var first = text.indexOf(search);
        if (first !== -1 && text.indexOf(search, first + 1) === -1) {
            // An empty replacement takes its line break with it (no blank line left behind).
            var length = search.length + (replace === "" && text.charAt(first + search.length) === "\n" ? 1 : 0);
            text = text.slice(0, first) + replace + text.slice(first + length);
            continue;
        }
        if (first !== -1) {
            failed.push({ "index": b + 1, "reason": "many", "nearest": "" });
            continue;
        }
        var lines = text.split("\n");
        var searchLines = search.split("\n");
        while (searchLines.length > 1 && !searchLines[searchLines.length - 1].trim())
            searchLines.pop();
        var starts = looseMatches(lines, searchLines);
        if (starts.length !== 1) {
            failed.push({ "index": b + 1, "reason": starts.length > 1 ? "many" : "missing", "nearest": starts.length > 1 ? "" : nearest(lines, searchLines) });
            continue;
        }
        // Re-indented by the difference between the code's indentation and the search's.
        var start = starts[0];
        var codeIndent = /^\s*/.exec(lines[start])[0];
        var searchIndent = /^\s*/.exec(searchLines[0])[0];
        var replaceLines = replace === "" ? [] : replace.split("\n").map(function(line) {
            if (!line.trim())
                return line;

            if (line.indexOf(searchIndent) === 0)
                return codeIndent + line.slice(searchIndent.length);

            return codeIndent + line.replace(/^\s*/, "");
        });
        lines.splice.apply(lines, [start, searchLines.length].concat(replaceLines));
        text = lines.join("\n");
    }
    if (failed.length > 0)
        return { "ok": false, "code": original, "failed": failed, "changed": [], "added": 0, "removed": 0 };

    var diff = lineDiff(original.split("\n"), text.split("\n"));
    return { "ok": true, "code": text, "failed": [], "changed": diff.changed, "added": diff.added, "removed": diff.removed };
}

// Lines of after not in the longest common subsequence with before: changed or added (0-based), and
// how many lines were added and removed.
function lineDiff(before, after) {
    var n = before.length;
    var m = after.length;
    var table = [];
    for (var i = 0; i <= n; i++) {
        table.push(new Array(m + 1));
        for (var j = 0; j <= m; j++)
            table[i][j] = 0;
    }
    for (i = n - 1; i >= 0; i--)
        for (j = m - 1; j >= 0; j--)
            table[i][j] = before[i] === after[j] ? table[i + 1][j + 1] + 1 : Math.max(table[i + 1][j], table[i][j + 1]);
    var kept = [];
    i = 0;
    j = 0;
    while (i < n && j < m) {
        if (before[i] === after[j]) {
            kept.push(j);
            i++;
            j++;
        } else if (table[i + 1][j] >= table[i][j + 1]) {
            i++;
        } else {
            j++;
        }
    }
    var changed = [];
    for (j = 0; j < m; j++)
        if (kept.indexOf(j) === -1)
            changed.push(j);
    return { "changed": changed, "added": m - kept.length, "removed": n - kept.length };
}

// What to tell the model when its blocks did not fit (none of them was applied).
function editProblem(failed) {
    var lines = ["上一次的 SEARCH/REPLACE 块没有套用（只要有一个块对不上，全部都不会生效）："];
    failed.forEach(function(item) {
        if (item.reason === "many")
            lines.push("- 第 " + item.index + " 个块的 SEARCH 在代码里出现了不止一处，请多带几行上下文，让它只匹配一处。");
        else
            lines.push("- 第 " + item.index + " 个块的 SEARCH 在代码里没有找到。" + (item.nearest ? "代码里最接近的是：\n```\n" + item.nearest + "\n```" : ""));
    });
    lines.push("请重新输出全部的 SEARCH/REPLACE 块，SEARCH 要从现有代码里一字不差地复制。");
    return lines.join("\n");
}

// What the code writer said it could not do (its "// SEEDLING-NOTE:" line), "" when nothing.
function noteOf(code) {
    var m = /\/\/\s*SEEDLING-NOTE:\s*(.+)/.exec(String(code || ""));
    return m ? m[1].trim() : "";
}

// Whether the code goes online (asks the Internet for something).
function goesOnline(code) {
    var text = String(code || "").replace(/\/\/.*$/gm, "");
    return /\bXMLHttpRequest\b|\bWebSocket\b|["']https?:\/\//i.test(text);
}

