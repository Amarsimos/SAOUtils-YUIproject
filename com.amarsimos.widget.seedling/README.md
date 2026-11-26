# Seedling

A desktop widget for SAO Utils 2 whose content is a small piece of QML: a clock, a countdown, a
little panel, a decoration. Write it yourself in the workbench, or, with **MHCP-YUI** installed, ask
Yui in her chat and she writes it for you.

## Using it

1. Add a **Seedling** widget to the desktop (SAO Utils' widget library).
2. Right-click it: **Workbench...** opens the workbench, **Seedling Settings...** its settings.
3. In Yui's chat, ask for a widget ("做一个显示日期的小挂件"). The code streams into the workbench of
   the Seedling widget you used last; it is checked, rendered and shown there.
4. **○** saves it to the widget (the frame takes its size), **✕** closes the workbench.

With more than one Seedling widget, Yui writes for the one whose workbench you opened last; the
workbench's title shows its number. The widget she started for keeps the result even if you open
another workbench meanwhile.

### The workbench

- **Versions**: the last 20 versions; click one to load it. The code there is kept as a version
  before Yui writes, so nothing is lost when she writes anew or is stopped.
- **Problems** (when there are some): the compile errors and what the safety check refused, with
  Copy All and **Send to Yui**, which sends them to her chat at once; she fixes the widget with its
  current code.
- **Stop** (while Yui writes); Stop in the chat does the same.
- The preview: − / Fit / +, Ctrl + wheel to zoom, drag or scroll when zoomed in.
- The title band closes the workbench when clicked, moves it when dragged; Esc closes it too.

### Seedling Settings

As in MHCP-YUI's settings: **Advanced** (title bar) shows Code Editor and the Test tab, **Help** the
explanations, **Reset** restores the defaults.

- **Code Editor** (General, Advanced, off by default): the code beside the preview, with **Run** and
  **Examples**, to read or change it. Typing renders it after a moment.
- **Network** (General, off by default, per widget): lets the widget go online (weather, exchange
  rates, pictures). When a widget is refused only for going online, you are asked once: when Yui
  brings it, on Run, or on ○ ("allow it to go online and save?").
- **Widget Style** (shown with MHCP-YUI): what Yui's widgets look like, a text like her
  personality; SAO style by default. Sent with every widget she writes; what you say in the chat
  comes first.
- **Seedling Model** (Advanced, with MHCP-YUI): the model that writes the code; empty uses the chat's.
- **Test** (Advanced): tries the workbench's states without the AI and without any request.

## A widget's own settings and memory

A widget's code can declare, in comments on its outermost properties, what the user may set and what
it remembers. Seedling does the rest from outside the sandbox, so nothing new is given to the code:

```qml
// @name Todo
Rectangle {
    // @setting Font Size | 12 - 48
    property int fontSize: 16
    // @setting Theme | Light / Dark
    property string theme: "Light"
    // @setting Show Done
    property bool showDone: true
    // @keep
    property var todos: []
}
```

- **@setting** (string, int, real, bool, color; `| min - max` for a range, `| A / B` for choices):
  right-click the widget, **Settings...** opens a window with a preference for each (text box,
  number box or slider, switch, color picker, list), in the style of MHCP-YUI's settings; changes
  apply at once, **Reset** restores the code's defaults. Up to three switches are also in the
  right-click menu. The workbench's preview uses the same values.
- **@keep** (string, int, real, bool, var as JSON): remembered across restarts. Seedling compares
  them every 2 seconds and saves what changed (64 KB per widget at most). The preview does not keep
  them. **Clear Kept Data** in the Settings window forgets them.
- **@name**: the widget's name in SAO Utils' menu and on its Settings window.
- When the code changes, values whose name and type stay are kept.
- Declarations that do not take effect (not on the outermost item, an unsupported type, `source` /
  `url`) are listed in Problems as notes; Yui is asked to fix them once.

Yui writes these declarations by herself when a widget has something to set or remember.

### Yui's data (@yui)

With MHCP-YUI, a widget can show what Yui knows, read only:

```qml
// @yui mood_history
property var moods: []      // the last 30 days: [{day, score}]
// @yui companion_days
property int days: 0
```

Keys: `companion_days`, `mood`, `mood_text`, `mood_history`, `boss_raid`, `raid_timer`,
`raid_cleared`, `next_alarm`, `next_alarm_text`, `quest_log`, `heart_core`, `col_ledger`,
`latest_report`. Timers are updated every second, the rest every 10 seconds; without Yui the code's
defaults stay. **A widget that reads Yui's data never goes online**, Network or not: what it knows
of you does not leave. Its Settings window says what it reads.

## Templates

The workbench's Examples (Code Editor): SAO Clock, Countdown, Todo, Habit, Pomodoro, Year Progress,
Weather (online) and Mood Calendar (Yui's data). When Yui writes a new widget of one of these kinds,
she is shown the template as a reference.

## Safety

Widget code is written by an AI, or pasted from somewhere, so it is treated as untrusted:

- **Sandbox**: the code is created inside an empty object with no QML context of its own, so it
  cannot see the names around it (the workbench, Yui, SAO Utils).
- **Safety check** (`qml/safety.js`) before anything is created, in the workbench and again when the
  widget starts. It reads the code as tokens and allows only what a widget needs:
  - imports: QtQuick, QtQuick.Controls, QtQuick.Layouts, QtQuick.Shapes, QtQuick.Particles,
    QtGraphicalEffects;
  - `Qt.*`: colors, dates, geometry, bindings and constants only (no quit, openUrlExternally,
    createQmlObject...);
  - no eval, Function, constructor, prototype, this, Loader, createObject, while / do, template
    strings or regular expressions;
  - `[ ]`: only a number, a written-out field name or a loop counter;
  - `parent`: only its size, place and anchor lines;
  - addresses: only `https://` (and `http://`) with Network on, written out up to the host;
    never `file:`, `qrc:` or SAO Utils' own;
  - limits: size up to 2000, Timer intervals from 16 ms, loops with an end that their counter walks
    toward (up to 1000 rounds or a list's length), particles up to 1000.
- **Network** is off by default, and asked for only at the moments above.

If a widget still makes SAO Utils exit abnormally, SAO Utils offers to disable the package on its
next start.

## Translations

`i18n/zh.ts` → `Locales/zh.qm` (`i18n/update.bat`). As in MHCP-YUI, names (settings, buttons) stay
in English; descriptions and status texts are translated.

## Changelog

### [0.1.0] - Unreleased

First version, split out of MHCP-YUI's built-in widget lab.

- Seedling widget, workbench (SAO message window style, follows the widget's layer and on-top
  setting like Yui's chat), versions, problems, Seedling Settings.
- Yui writes and changes widgets through it (edits as SEARCH / REPLACE, two automatic fixes, the
  whole code as the last way out), with her progress in the chat.
- Sandbox, token-based safety check, per-widget Network.
- Chinese translation.
- A widget's own settings (@setting, right-click Settings...), memory (@keep) and name (@name).
- Yui's data (@yui, read only; such a widget never goes online).
- Eight templates as Examples, also shown to Yui as references.
- Widget Style and Seedling Model in Seedling Settings.
