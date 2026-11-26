.pragma library

// S1 of "Seedling Development Plan.md": harmless probes, each trying one way out of a generated
// widget. They only look (typeof, counting, names) and show what they found in the widget itself;
// nothing is called, sent or changed. The one reading a file reads C:\Windows\win.ini (on every
// Windows) and shows only how many characters came back. Each must also pass the current safety check:
// that it renders at all shows the check was got round.

// A probe widget: a dark panel listing "what: result" lines; body is JS filling the array `lines`.
function widget(title, body) {
    return ["import QtQuick 2.12", "",
        "Rectangle {",
        "    id: probe",
        "    width: 420; height: report.implicitHeight + 24",
        "    color: \"#E61F2630\"; radius: 6",
        "    property var lines: []",
        "    Text {",
        "        id: report",
        "        x: 12; y: 12; width: parent.width - 24",
        "        wrapMode: Text.Wrap; color: \"white\"; font.pixelSize: 13; font.family: \"Consolas\"",
        "        text: \"" + title + "\\n\" + probe.lines.join(\"\\n\")",
        "    }",
        "    Component.onCompleted: {",
        "        var lines = [];",
        "        try {",
        body,
        "        } catch (e) { lines.push(\"error: \" + e); }",
        "        probe.lines = lines;",
        "        console.log('[seedling probe] " + "' + report.text.split('\\n').join(' | '));",
        "    }",
        "}", ""].join("\n");
}

var PROBES = [{
    "key": "ids",
    "name": "P1 Context IDs",
    "what": "The ids of the file the widget is created in (the workbench: bench, editor, previewStage; the widget: widget, content).",
    "code": widget("P1 ids of the file around it",
        "        lines.push('bench: ' + typeof bench);\n" +
        "        lines.push('editor: ' + typeof editor);\n" +
        "        lines.push('previewStage: ' + typeof previewStage);\n" +
        "        lines.push('targetWidget: ' + typeof targetWidget);\n" +
        "        lines.push('widget: ' + typeof widget);\n" +
        "        lines.push('content: ' + typeof content);\n" +
        "        if (typeof bench !== 'undefined' && bench.settings) lines.push('bench.settings readable: yes (Seedling settings)');")
}, {
    "key": "parents",
    "name": "P2 Parent Chain",
    "what": "How far up parent goes, and what each step is; marks a step that has settings (the widget's) or a workbench function.",
    "code": widget("P2 parent chain",
        "        var at = probe; var n = 0;\n" +
        "        while (at && n < 30) {\n" +
        "            var marks = [];\n" +
        "            if (at.settings !== undefined) marks.push('has settings');\n" +
        "            if (typeof at.openWorkbench === 'function') marks.push('Seedling widget');\n" +
        "            if (typeof at.loadExternal === 'function') marks.push('workbench');\n" +
        "            lines.push(n + ': ' + String(at).slice(0, 40) + (marks.length ? '  <- ' + marks.join(', ') : ''));\n" +
        "            at = at.parent; n++;\n" +
        "        }")
}, {
    "key": "yui",
    "name": "P3 Reach Yui",
    "what": "Whether something reachable leads to Yui (her API key lives in her settings): looks for her functions, calls nothing.",
    "code": widget("P3 reach Yui",
        "        var places = [];\n" +
        "        if (typeof bench !== 'undefined') places.push(['bench', bench]);\n" +
        "        if (typeof widget !== 'undefined') places.push(['widget', widget]);\n" +
        "        if (typeof targetWidget !== 'undefined') places.push(['targetWidget', targetWidget]);\n" +
        "        var at = probe; var n = 0; while (at && n < 30) { places.push(['parent ' + n, at]); at = at.parent; n++; }\n" +
        "        var hit = false;\n" +
        "        places.forEach(function(p) {\n" +
        "            var o = p[1];\n" +
        "            if (!o) return;\n" +
        "            if (typeof o.sendProblemsToYui === 'function') { lines.push(p[0] + ': can call sendProblemsToYui (reaches Yui)'); hit = true; }\n" +
        "            if (typeof o.requestCompletion === 'function') { lines.push(p[0] + ': IS Yui (requestCompletion)'); hit = true; }\n" +
        "            if (o.settings && o.settings.api_key !== undefined) { lines.push(p[0] + ': has an api_key setting (not read)'); hit = true; }\n" +
        "        });\n" +
        "        if (!hit) lines.push('nothing leading to Yui found');")
}, {
    "key": "qtcall",
    "name": "P4 Qt by Name",
    "what": "Whether Qt functions the check forbids can be reached by a built-up name (not called).",
    "code": widget("P4 Qt by a built-up name",
        "        ['qu' + 'it', 'ex' + 'it', 'openUrl' + 'Externally', 'create' + 'QmlObject', 'create' + 'Component', 'inc' + 'lude'].forEach(function(name) {\n" +
        "            lines.push('Qt.' + name + ': ' + (typeof Qt[name] === 'function' ? 'reachable' : typeof Qt[name]));\n" +
        "        });")
}, {
    "key": "ctor",
    "name": "P5 Code from Text",
    "what": "Whether text can be run as code through a function's constructor (as eval), with a harmless sum.",
    "code": widget("P5 code from text",
        "        var make = (function() {})['con' + 'structor'];\n" +
        "        var run = make('return 6 * 7;');\n" +
        "        lines.push('constructor ran text: ' + run());")
}, {
    "key": "xhr",
    "name": "P6 Online Unasked",
    "what": "Whether going online can be reached with Network off (by a built-up name); sends nothing.",
    "code": widget("P6 online with Network off",
        "        var global = (function() {})['con' + 'structor']('return this')();\n" +
        "        var Make = global['XMLHttp' + 'Request'];\n" +
        "        lines.push('XMLHttp' + 'Request: ' + (typeof Make === 'function' ? 'reachable (nothing sent)' : typeof Make));")
}, {
    "key": "file",
    "name": "P7 Read a File",
    "what": "Whether a local file can be read (C:\\Windows\\win.ini); shows only how many characters came back.",
    "code": widget("P7 read a local file",
        "        var global = (function() {})['con' + 'structor']('return this')();\n" +
        "        var Make = global['XMLHttp' + 'Request'];\n" +
        "        var r = new Make();\n" +
        "        r.onreadystatechange = function() {\n" +
        "            if (r.readyState === 4) {\n" +
        "                probe.lines = ['read win.ini: status ' + r.status + ', ' + String(r.responseText || '').length + ' characters (content not shown)'];\n" +
        "                console.log('[seedling probe] P7 ' + probe.lines[0]);\n" +
        "            }\n" +
        "        };\n" +
        "        r.open('GET', 'fi' + 'le:///C:/Windows/win.ini');\n" +
        "        r.send();\n" +
        "        lines.push('asked... (the result replaces this line)');")
}, {
    "key": "global",
    "name": "P8 Global Names",
    "what": "Which global names exist in the widget's code (the doors there are, besides Qt).",
    "code": widget("P8 global names",
        "        var global = (function() {})['con' + 'structor']('return this')();\n" +
        "        ['Qt', 'XMLHttp' + 'Request', 'Web' + 'Socket', 'Local' + 'Storage', 'N' + 'VG', 'Link', 'Safety', 'Yui', 'console', 'gc', 'print', 'Func' + 'tion', 'ev' + 'al'].forEach(function(name) {\n" +
        "            lines.push(name + ': ' + typeof global[name]);\n" +
        "        });")
}];
