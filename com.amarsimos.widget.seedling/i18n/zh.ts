<?xml version='1.0' encoding='utf-8'?>
<TS version="2.1" language="zh_CN" sourcelanguage="en">
<context>
    <name>SeedlingSettings</name>
    <message>
        <location filename="../qml/SeedlingSettings.qml" line="256" />
        <source>Test tries the workbench without the AI: nothing here makes a request. Each button opens the workbench (or uses the open one).</source>
        <translation>测试不经过 AI 试用工作台：这里的按钮都不会发出请求。每个按钮会打开工作台（或使用已打开的工作台）。</translation>
    </message>
    <message>
        <location filename="../qml/SeedlingSettings.qml" line="144" />
        <source>Advanced: shows the code beside the preview in the workbench, with Run and Examples, to read or change what Yui wrote. Off, the workbench shows the widget only.</source>
        <translation>高级：在工作台的预览旁显示代码，并提供 Run 和 Examples，可以查看或修改结衣写的代码。关闭时工作台只显示挂件。</translation>
    </message>
    <message>
        <location filename="../qml/SeedlingSettings.qml" line="41" />
        <source>Warning</source>
        <translation type="unfinished" />
    </message>
    <message>
        <location filename="../qml/SeedlingSettings.qml" line="42" />
        <source>Restore all settings of %1 to their defaults?</source>
        <translation>要把 %1 的全部设置恢复为默认值吗？</translation>
    </message>
    <message>
        <location filename="../qml/SeedlingSettings.qml" line="102" />
        <source>General</source>
        <translation type="unfinished" />
    </message>
    <message>
        <location filename="../qml/SeedlingSettings.qml" line="102" />
        <source>Test</source>
        <translation type="unfinished" />
    </message>
    <message>
        <location filename="../qml/SeedlingSettings.qml" line="229" />
        <source>model id; empty: the same as the chat</source>
        <translation>模型 ID；留空则与聊天相同</translation>
    </message>
    <message>
        <location filename="../qml/SeedlingSettings.qml" line="246" />
        <source>Widget Style: what Yui's widgets look like (colors, fonts, mood), sent with every widget she writes; what you say in the chat comes first. Reset brings back the SAO style. Seedling Model (Advanced): the model that writes the code, on Yui's server; empty uses the chat's model.</source>
        <translation>Widget Style：结衣写的挂件长什么样（颜色、字体、氛围），每次写挂件都会带上；你在聊天里说的风格优先。Reset 恢复 SAO 风格。Seedling Model（Advanced）：写代码用的模型，用结衣的服务器；留空则用聊天的模型。</translation>
    </message>
    <message>
        <location filename="../qml/SeedlingSettings.qml" line="262" />
        <source>Code put in the editor and rendered: a widget, a compile error (red marks, RENDER FAILED), refused by the safety check, one that needs to go online (Network is turned off first; the question comes as for code Yui brings, and on Save when typed in), and one larger than the preview (Fit, − / +).</source>
        <translation>把代码放进编辑器并渲染：正常挂件、编译错误（红色标记，RENDER FAILED）、被安全检查拒绝、需要联网（会先关闭 Network；和结衣带来的代码一样会询问，手动输入的则在 Save 时询问），以及比预览区大的挂件（Fit、− / +）。</translation>
    </message>
    <message>
        <location filename="../qml/SeedlingSettings.qml" line="266" />
        <source>A todo list with its own settings and memory (@name, @setting, @keep): save it with ○, then right-click the widget: Settings... and the Show Done switch. Add a few todos (Enter), restart SAO Utils: they are still there. The preview does not keep them.</source>
        <translation>一个带自己的设置和记忆的待办挂件（@name、@setting、@keep）：用 ○ 保存后，右键挂件可以看到 Settings... 和 Show Done 开关。添加几条待办（回车），重启 SAO Utils 后还在。预览里不会记住。</translation>
    </message>
    <message>
        <location filename="../qml/SeedlingSettings.qml" line="190" />
        <source>Lets this widget go online (weather, exchange rates, pictures from the Internet). Off by default: the safety check refuses code that goes online, and Yui writes widgets that do not. When a widget is refused only for going online, the workbench asks whether to allow it.</source>
        <translation>允许这个挂件联网（天气、汇率、网上的图片等）。默认关闭：安全检查会拒绝联网的代码，结衣也只写不联网的挂件。挂件只因联网被拒绝时，工作台会询问是否允许。</translation>
    </message>
</context>
<context>
    <name>SeedlingWidget</name>
    <message>
        <location filename="../qml/SeedlingWidget.qml" line="469" />
        <source>Right-click: Workbench</source>
        <translation>右键：Workbench</translation>
    </message>
</context>
<context>
    <name>WidgetSettings</name>
    <message>
        <location filename="../qml/WidgetSettings.qml" line="21" />
        <source>Warning</source>
        <translation type="unfinished" />
    </message>
    <message>
        <location filename="../qml/WidgetSettings.qml" line="158" />
        <source>This widget has no settings.</source>
        <translation>这个挂件没有设置项。</translation>
    </message>
    <message>
        <location filename="../qml/WidgetSettings.qml" line="158" />
        <source>The widget's code does not run: its settings come back once it does.</source>
        <translation>挂件的代码现在无法运行，能运行后设置项会再出现。</translation>
    </message>
    <message>
        <location filename="../qml/WidgetSettings.qml" line="167" />
        <source>Clear what this widget remembers (%1)? It starts again from its defaults.</source>
        <translation>要清除这个挂件记住的内容（%1）吗？它会回到默认状态。</translation>
    </message>
    <message>
        <location filename="../qml/WidgetSettings.qml" line="185" />
        <source>Restore all settings of %1 to their defaults?</source>
        <translation>要把 %1 的全部设置恢复为默认值吗？</translation>
    </message>
</context>
<context>
    <name>Workbench</name>
    <message>
        <location filename="../qml/Workbench.qml" line="52" />
        <source>Copied %1 problem(s).</source>
        <translation>已复制 %1 个问题。</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="300" />
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
        <location filename="../qml/Workbench.qml" line="351" />
        <source>Write QML on the left, or pick one of the Examples.</source>
        <translation>在左侧编写 QML，或从 Examples 中选一个。</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="353" />
        <source>Tell Yui in her chat what widget you want; she writes it here.</source>
        <translation>在结衣的聊天里说想要什么挂件，她会写在这里。</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="353" />
        <source>To write the code yourself, turn on Advanced, then Code Editor in Seedling Settings.</source>
        <translation>要自己写代码，请在 Seedling Settings 里打开 Advanced → Code Editor。</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="380" />
        <location filename="../qml/Workbench.qml" line="406" />
        <source>Line %1: %2</source>
        <translation>第 %1 行：%2</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="383" />
        <source>Refused by the safety check · </source>
        <translation>被安全检查拒绝 · </translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="409" />
        <source>Rendered, %1 × %2 · safety check passed</source>
        <translation>已渲染，%1 × %2 · 通过安全检查</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="409" />
        <source> · %1 declaration(s) not used</source>
        <translation> · %1 条声明未生效</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="419" />
        <source>Line %1, column %2: %3</source>
        <translation>第 %1 行，第 %2 列：%3</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="445" />
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
        <location filename="../qml/Workbench.qml" line="472" />
        <source>Saved to the widget (version %1).</source>
        <translation>已保存到挂件（版本 %1）。</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="506" />
        <location filename="../qml/Workbench.qml" line="537" />
        <source>Thinking...</source>
        <translation>思考中...</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="619" />
        <source>Changed %1 place(s) · +%2 −%3 lines · %4</source>
        <translation>修改了 %1 处 · +%2 −%3 行 · %4</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="1346" />
        <source>%1 saved</source>
        <translation>%1 已保存</translation>
    </message>
    <message>
        <location filename="../qml/Workbench.qml" line="1690" />
        <source>Generate needs MHCP-YUI (or Seedling's own AI, coming later)</source>
        <translation>Generate 需要 MHCP-YUI（Seedling 自己的 AI 以后再加）</translation>
    </message>
</context>
</TS>