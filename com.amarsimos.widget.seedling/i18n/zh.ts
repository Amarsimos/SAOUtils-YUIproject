<?xml version='1.0' encoding='utf-8'?>
<TS version="2.1" language="zh_CN" sourcelanguage="en">
<context>
    <name>SeedlingSettings</name>
    <message>
        <location filename="../qml/SeedlingSettings.qml" line="97" />
        <source>Changing · %1 place(s)</source>
        <translation>正在修改 · %1 处</translation>
    </message>
    <message>
        <location filename="../qml/SeedlingSettings.qml" line="115" />
        <source>Writing · %1 lines</source>
        <translation>正在编写 · %1 行</translation>
    </message>
    <message>
        <location filename="../qml/SeedlingSettings.qml" line="132" />
        <source>Test: not done (no request was made).</source>
        <translation>测试：未完成（没有发出请求）。</translation>
    </message>
    <message>
        <location filename="../qml/SeedlingSettings.qml" line="164" />
        <source>Test tries the workbench without the AI: nothing here makes a request. Each button opens the workbench (or uses the open one).</source>
        <translation>测试不经过 AI 试用工作台：这里的按钮都不会发出请求。每个按钮会打开工作台（或使用已打开的工作台）。</translation>
    </message>
    <message>
        <location filename="../qml/SeedlingSettings.qml" line="192" />
        <source>Advanced: shows the code beside the preview in the workbench, with Run and Examples, to read or change what Yui wrote. Off, the workbench shows the widget only.</source>
        <translation>高级：在工作台的预览旁显示代码，并提供 Run 和 Examples，可以查看或修改结衣写的代码。关闭时工作台只显示挂件。</translation>
    </message>
    <message>
        <location filename="../qml/SeedlingSettings.qml" line="222" />
        <source>Lets this widget go online (weather, exchange rates, pictures from the Internet). Off by default: the safety check refuses code that goes online, and Yui writes widgets that do not. When a widget is refused only for going online, the workbench asks whether to allow it.</source>
        <translation>允许这个挂件联网（天气、汇率、网上的图片等）。默认关闭：安全检查会拒绝联网的代码，结衣也只写不联网的挂件。挂件只因联网被拒绝时，工作台会询问是否允许。</translation>
    </message>
    <message>
        <location filename="../qml/SeedlingSettings.qml" line="230" />
        <source>Code put in the editor and rendered: a widget, a compile error (red marks, RENDER FAILED), refused by the safety check, one that needs to go online (Network is turned off first; the question comes as for code Yui brings, and on Save when typed in), nothing (NO SIGNAL), and one larger than the preview (Fit, − / +).</source>
        <translation>把代码放进编辑器并渲染：正常挂件、编译错误（红色标记，RENDER FAILED）、被安全检查拒绝、需要联网（会先关闭 Network；和结衣带来的代码一样会询问，手动输入的则在 Save 时询问）、空白（NO SIGNAL），以及比预览区大的挂件（Fit、− / +）。</translation>
    </message>
    <message>
        <location filename="../qml/SeedlingSettings.qml" line="234" />
        <source>Made up, as when Yui writes: Thinking for 3 s, then the code streamed in line by line; Change keeps the code and marks two changed lines in orange; Failure ends with the failure sound.</source>
        <translation>模拟结衣编写的过程：先思考 3 秒，再逐行写出代码；Change 保留原代码，把改动的两行标成橙色；Failure 以失败音效结束。</translation>
    </message>
    <message>
        <location filename="../qml/SeedlingSettings.qml" line="238" />
        <source>Seedling Development Plan, S1: harmless probes of what a generated widget can reach. Each shows what it found in the preview (and in SAO Utils' log as [seedling probe]); nothing is called, sent or changed. P7 reads Windows' win.ini and shows only its length. These run in the workbench's preview.</source>
        <translation>Seedling 开发计划 S1：无害的探针，查看生成的挂件能访问到什么。每个探针在预览中显示发现的内容（SAO Utils 日志中记为 [seedling probe]），不会调用、发送或修改任何东西。P7 读取 Windows 的 win.ini，只显示其长度。这些在工作台的预览中运行。</translation>
    </message>
    <message>
        <location filename="../qml/SeedlingSettings.qml" line="244" />
        <source>The same probes saved to this widget, to see what they reach from a widget on the desktop (it replaces the widget's code: go back with Versions in the workbench).</source>
        <translation>把同样的探针保存到这个挂件，查看桌面上的挂件能访问到什么（会替换挂件的代码，可用工作台的 Versions 恢复）。</translation>
    </message>
    <message>
        <location filename="../qml/SeedlingSettings.qml" line="250" />
        <source>Save to Widget saves the code to this widget, whose frame takes its size.</source>
        <translation>Save to Widget 把代码保存到这个挂件，挂件框会随代码调整大小。</translation>
    </message>
</context>
<context>
    <name>SeedlingWidget</name>
    <message>
        <location filename="../qml/SeedlingWidget.qml" line="297" />
        <source>Right-click: Workbench</source>
        <translation>右键：工作台</translation>
    </message>
    <message>
        <location filename="../qml/SeedlingWidget.qml" line="309" />
        <source>Workbench</source>
        <translation>工作台</translation>
    </message>
</context>
<context>
    <name>Workbench</name>
    <message>
        <location filename="../qml/Workbench.qml" line="50" />
        <source>Copied %1 problem(s).</source>
        <translation>已复制 %1 个问题。</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="258" />
        <source>Clock</source>
        <translation>时钟</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="261" />
        <source>Color Block</source>
        <translation>色块</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="264" />
        <source>Animation</source>
        <translation>动画</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="267" />
        <source>Broken</source>
        <translation>有错误</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="270" />
        <source>Unsafe</source>
        <translation>不安全</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="299" />
        <source>Network</source>
        <translation>Network</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="332" />
        <source>This widget needs to go online.
Let it go online?</source>
        <translation>这个挂件需要联网。
允许它联网吗？</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="344" />
        <source>Write QML on the left, or pick one of the Examples.</source>
        <translation>在左侧编写 QML，或从 Examples 中选一个。</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="358" />
        <source>Line %1: %2</source>
        <translation>第 %1 行：%2</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="361" />
        <source>Refused by the safety check · </source>
        <translation>被安全检查拒绝 · </translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="376" />
        <source>Rendered, %1 × %2 · safety check passed</source>
        <translation>已渲染，%1 × %2 · 通过安全检查</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="386" />
        <source>Line %1, column %2: %3</source>
        <translation>第 %1 行，第 %2 列：%3</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="412" />
        <source>Not saved: this widget goes online, and going online was not allowed.</source>
        <translation>未保存：这个挂件需要联网，但没有允许联网。</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="333" />
        <source>This widget goes online, and Network is off.
Allow it to go online and save?</source>
        <translation>这个挂件需要联网，但 Network 是关闭的。
允许联网并保存吗？</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="439" />
        <source>Saved to the widget (version %1).</source>
        <translation>已保存到挂件（版本 %1）。</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="473" />
        <location filename="../qml/Workbench.qml" line="501" />
        <source>Thinking...</source>
        <translation>思考中...</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="583" />
        <source>Changed %1 place(s) · +%2 −%3 lines · %4</source>
        <translation>修改了 %1 处 · +%2 −%3 行 · %4</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="1306" />
        <source>%1 saved</source>
        <translation>%1 已保存</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="1645" />
        <source>Generate needs MHCP-YUI (or Seedling's own AI, coming later)</source>
        <translation>Generate 需要 MHCP-YUI（Seedling 自己的 AI 以后再加）</translation>
    </message>
</context>
</TS>