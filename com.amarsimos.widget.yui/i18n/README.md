# Translations

All text in the settings dialogs, the widget menu and the input row is written in English in
the QML files and wrapped in `qsTr()`. SAO Utils loads `Locales/<language>.qm` from this package
for its UI language (same convention as the bundled gpbeta packages: `zh`, `zh_TW`, `ja`, ...).

- `i18n/<language>.ts` – translation sources, edited by hand or with Qt Linguist.
- `Locales/<language>.qm` – compiled translations shipped with the package.

The SAO-style names (Cardinal System, Seed Server, Link Start!, Yui's Heart, ...) are left
untranslated on purpose, so they stay in English; the descriptions under each setting and the
status texts are translated.

## Updating

After changing any `qsTr()` text, run `i18n/update.bat` (needs Qt 5 `lupdate` / `lrelease` in
PATH). It adds new strings to every `.ts` file as unfinished and recompiles the `.qm` files.
Translate the new entries in the `.ts` file, then run the script again.

## Adding a language

Add a `call :lang <file name> <Qt language code>` line to `update.bat`, e.g.
`call :lang ja ja_JP`, run it, translate `i18n/ja.ts`, and run it again.

Yui's own lines (greetings, warnings, the System Call easter egg in `qml/yui.js`, and the
default personality prompt) are character content in Chinese and are not part of these files.
