# MHCP-YUI 提示词规则

> 记录结衣每次请求发给模型的内容：由哪些部分组成、按什么顺序、什么时候出现、由哪段代码生成，以及修改提示词时要遵守的规则。
> 代码位置：`com.amarsimos.widget.yui/qml/main-stand.qml`（拼装、读取数据）、`qml/yui.js`（纯函数，有测试）。最后核对：2026-11-25（dev，5fd2a04 之后）。

---

## 一、一次请求的组成

```
system ┬ ① 最重要的规则        priorityRules
       ├ ② 人格               设置里的 System Prompt（默认 defaultSystemPrompt / MHCP Profile）
       └ ③ 附加部分            systemExtras（见第二节，共 11 段）
messages ┬ 聊天历史            buildHistory（最近 maxHistory 条，默认 20）
         └ 最新一条用户消息     ＋ 只进请求的附注（见第三节）
tools                         只在 Tools 模式（toolDefinitions）
```

拼装在 `startReply → requestCompletion`（main-stand.qml 约 1020～1060 行）：
`system = priorityRules + 人格（{{user_title}} 替换为称呼）+ systemExtras(title, 最新用户消息, mode)`。

**称呼 `title`**：设置里的称呼（默认「爸爸」），所有段落都用它，不写死。

---

## 二、system 提示的各段（按顺序）

| # | 段落 | 生成 | 什么时候出现 | 内容要点 |
| :-- | :-- | :-- | :-- | :-- |
| ① | 最重要的规则 | `Yui.priorityRules(title, allowed, mode)` | 每次 | 表情标签必写；操作电脑 / 记忆必须写标签或调用工具（只说不做电脑上什么都不会发生）；开着网页功能时「实时信息必须搜索，不编造」；最后一条始终在：「电脑上的事，结衣只能……（只列开着的，含控制音乐播放）；其他事做不到就直接说，请{title}自己操作，绝不假装已经做了」（都关掉时为「结衣不能操作电脑」）。放在人格**前面**，因为用户可能改人格，小模型也容易丢后面的规则 |
| ② | 人格 | 设置 `system_prompt`；默认 `defaultSystemPrompt`（main-stand.qml 约 320 行）；MHCP Profile 切换 | 每次 | 身份、性格、说话方式。用户可编辑 |
| ③-1 | 系统功能说明 | `Yui.featureInstructions(title, 心核, allowed, mode)` | 每次 | 开头「以下是系统功能说明，不要向{title}提起」。表情、结衣之心（core / memory / forget 标签与记忆规则）、心理关怀、导航（web）、桌面代行（launch / find / kill）、音乐（Control Media）、快捷回复、小工具（隐藏时不出现）；最后附**心核**（`[MM-dd] 内容`）。只写开着的功能；Tools 模式去掉导航 / 代行 / 音乐的标签说明，改成一句「你可以用提供的工具……」 |
| ③-2 | 羁绊 | `Yui.bondFacts` | 设了生日 / 相遇日时 | 两个日子作为事实，「被问到时以此为准」（当天的祝贺移到「此刻」） |
| ③-3 | 相关回忆 | `Yui.recallContext(title, recall(query))` | 有相关记忆碎片时 | 结衣之心里和最新消息相关的碎片（`[MM-dd] 内容`），数量由 Yui's Heart → Recall 设定 |
| ③-4 | 笔记 | `notesExtras` | 小工具开着且消息提到笔记 / 待办（现在隐藏，不出现） | 未完成的 Quest Log |
| ③-5 | 说话风格微调 | `Yui.traitContext` | Character Traits 有不是默认的项时 | 一句话列出偏离默认的几项 |
| ③-6 | 回忆日志 | `logRecallExtras` → `Yui.logRecallContext` | Log Recall > 0 且找到相关旧对话 | 最多 N 条旧聊天（排除仍在上下文里的），每条 ≤ 100 字，「只作参考」 |
| ③-7 | **此刻** | `nowExtras` → `Yui.nowBlock` | 每次，**放在最后** | 一行事实，只写有值的项，用｜隔开：日期 星期 时刻 时段｜结衣醒着陪{title} N（≥ 30 分钟，从醒来 / 启动算起；SAO Utils 没有电脑空闲时间）｜距上次聊天 N（≥ 6 小时；回答用户消息时取这条消息之前的那次）｜天气（每次，原来只在提到天气时）｜正在播放 / 播放器里是 歌手《曲名》（播放器）｜电脑负载偏高 / 很高（正常不写）｜今天心情 n/5 概括｜今天是生日 / 相遇 N 周年 |
| ③-8 | 此刻的说明 | `Yui.nowGuidance(asks)` | 每次，紧跟「此刻」 | 「以上是程序刚刚读到的，以此为准，以前说过的不同的话已经不对了；和话题无关的不用提起」，再接当下要她做的事：深夜关心；心情（`Yui.moodAsks`：今天还没问→自然时问一句并用 `<<mood:分数|概括>>` 记；已记→明显变化可更新；最近 3 天平均 ≤ 2→多关心、不说教）；Bond 当天第一次→真诚地祝贺（回复后记为已祝贺） |

**顺序原则**：不常变的在前（规则、人格、功能说明、心核、羁绊），随请求变化的在后；实时信息集中成「此刻」放**最后**（2026-11-26 起，原来的时间、心情、羁绊当天、天气、正在播放各段合并进来）。

---

## 三、只进请求、不显示也不保存的附注

都加在**最新一条用户消息**后面（`messages` 的副本，聊天窗口和数据库里看不到）。小模型对紧挨着问题的内容最敏感。

| 附注 | 生成 | 条件 | 内容 |
| :-- | :-- | :-- | :-- |
| 重新生成 | requestCompletion 内（`regenerate`） | 点 Say Again | 「换一种说法和角度…但事实（歌名、时间、记住的事）不要改」；温度 +0.3（≤ 2） |
| 小模型提醒 | `Yui.smallModelReminder(mode, allowed)` | Authority Level = Limited（默认；原 Small Model Mode，设置键 `small_model`，未设置即 Limited） | 「回复最后加上表情标签；需要操作电脑或记忆时写对应的标签」。**不写出标签本身**（有重复惩罚时，前面刚出现过的标签会被模型拼错，如 `<<emphy:happy>>`） |
| 换歌提示 | `Yui.mediaChangeNote(info)` | 曲目与上次请求不同（含重载后第一次），或点 Say Again | 「播放器里现在的歌是 …，之前提到的歌如果不是这首，说明已经换歌了」 |
| 主动开口的指令 | `yuiSpeaks(instruction)` | 结衣主动说话时 | 见第五节；没有用户消息时作为一条新的 user 消息 |
| 跟进 | `Yui.followupNote(due, title)`（`sendMessage`） | Follow-ups 打开、08:00–22:00、有到期的跟进（当天未打气，或之后 7 天内未问过）；附上即算已说 | 「结衣记得：爸爸之前说过「11月28日考试」（就是今天 / 那是昨天的事）。合适的话可以顺口关心、打气 / 问问怎么样了，和这次的话题不搭就不提」 |

---

## 四、聊天历史（`buildHistory`）

* 从 `historyStart` 起的聊天记录，取最近 `maxHistory` 条（Yui's Heart → Context，默认 20）。
* 跳过：还在生成的消息、`isError` 的消息（请求失败、设置提示）。
* **保留** `local` 消息（唤醒语、Navigation Report、测试消息等程序自己写的），让后面的回复能接上。
* 连续同一角色的消息合并（Gemini / Claude 要求一问一答交替）；开头必须是 user。
* Clear Log（Yui's Heart）会同时清空聊天窗口，否则旧对话仍会进上下文。

---

## 五、独立的请求（不走聊天上下文）

| 请求 | 生成 | 要点 |
| :-- | :-- | :-- |
| Login Greeting | `welcomeBack` | 启动时，以及点醒待机的结衣时（2026-11-26 起，代替本地唤醒语；不需要问候时仍用本地唤醒语）。早安（带天气）/ 欢迎回来（≥ 30 分钟）/ 好久不见（≥ 2 天，原 3 天）三种；「一两句话即可，不要提起这条提示」 |
| Spontaneous Talk | `careTick` → `idleChat` | 告诉她现在的样子（水晶 / 妖精 / 立绘）和位置（只作背景，叫她不要说起自己的样子或位置），请她主动说一句；有由头时加「可以从这个由头说起：…」（`Yui.chatHooks` 20 种：节日、去年今天、快到的跟进 / 生日、正在听的歌、深夜听歌、电脑一直很忙、周五晚上、周末早上、周一早上、午饭、晚饭、月末、下雨下雪、冷、热、陪了很久、心情不错、一条较早的记忆、今天还没说过话；特别的日子优先，其余随机，同一个由头当天只用一次） |
| Mood Care | `careTick` → `Yui.moodCareInstruction` | 中优先级，09–22 点；最近 3 次心情平均 ≤ 2 且最近一次在 3 天内；带这几天的记录，「温柔地问问要不要说说，不要说教，也不要列一串建议」 |
| Weather Changes | `careTick` → `Yui.weatherChangeInstruction` | 中优先级，07–22 点，变化后 1 小时内；开始下雨 / 下雪（带之前和现在的天气）→ 提醒带伞；3 小时内降温 ≥ 5° → 提醒保暖 |
| 深夜关怀 / 休息提醒 | `careTick` | 带具体时刻或连续使用时长 |
| Weekly Report | `Yui.weeklyReportPrompt` | 一周数据 + 要求（三到五段、不用 Markdown、重点关心心情、不逐条复述数字、不加标签）；不进聊天 |
| 跟进 | `careTick` → `Yui.followupInstruction` | 高优先级；当天「主动打打气、关心一下」，之后 7 天内「自然地问问结果怎么样」；带原话和「就是今天 / 那是 N 天前的事」；一两句话，不要提起提示 |
| Through Yui's Eyes | `Yui.portraitPrompt` | 全部记忆 + 要求（两到四段、只根据记忆、不加标签）；不进聊天 |

前四种经 `yuiSpeaks` 发出，仍带完整的 system 提示和聊天历史。后三种由关心调度（`careTick`，2026-11-25）决定何时说：每天上限与最短间隔随 Care Level / 学到的欢迎度变化（默认每天 20 次、每 30 分钟一次），免打扰时段不闲聊；Login Greeting 启动时立即说并计入次数。提示词内容本身没有变。

---

## 六、Tags 与 Tools 两种模式

| | Tags（默认） | Tools（Action Mode，OpenAI 格式且服务器接受 tools 时） |
| :-- | :-- | :-- |
| 代行（网页、启动、找文件、关闭、音乐） | 标签 `<<open:>> <<search:>> <<launch:>> <<find:>> <<kill:>> <<media:>>` | 工具 `open_url web_search launch_program find_file close_program media_control`（`Yui.TOOLS`） |
| 记忆 | 标签 `<<core:>> <<memory:>> <<forget:>>` | 仍用标签（测试中没有模型主动调用 remember / forget 工具） |
| 表情、心情、快捷回复 | 标签 | 标签 |
| 服务器拒绝 tools | — | 自动退回 Tags 并记住（`toolsRejected`） |

---

## 七、回复的处理（`Yui.parseReply` / `cleanReply`）

* **标签**：`emotion memory core forget open search launch find kill focus mood remind note done skill suggest media`。允许单个 `>` 收尾（小模型），其后只能是空白、行尾或下一个标签。
* 关掉的功能：标签被丢弃且不执行，聊天显示「🚫 已在 System Console 中关闭这类代行，没有执行」。
* 拼错 / 全角括号的标签：从文字中去掉，记进 Log（`tags not understood`）。
* `cleanReply`：只保留最后一个 `</think>` 之后的内容，去掉 `<think>…</think>`，同一段落只留一次。
* **只说不做**：回复声称做了（`Yui.claimsDone`：「已经 / 这就 / 帮你 + 动作动词 + 了 / 好了」、「音乐已经重新动起来」，问句和说用户做的不算），但这一轮没有执行任何动作、媒体、剑技、专注、提醒，也没有被关闭或拦截时，消息下加「⚠ 结衣说做了，但这次什么都没有执行」，Log 记 `claimed an action, none carried out`。不改她的原话。
* **快捷回复只聊天**：说明里要求不要替用户想请结衣操作电脑、设提醒的回复；`suggestionsFrom` 再在本地去掉这类选项（`SUGGESTED_ACTION`：帮我打开…、下一首、音量、闹钟、提醒我等）。
* **答应以后提醒**：Alarm 没开时，回复里承诺「到时候 / 明天 / 一定 / 会 … 叫 / 提醒 / 喊 … 爸爸」（`Yui.promisesReminder`，问句和「不能提醒」不算），消息下加「⚠ 结衣现在没有提醒功能，到时候不会提醒你」，Log 记 `promised a reminder, none set`。规则 ① 最后一条在 Alarm 没开时加上「也不要答应以后提醒、叫醒{title}」。
* 记忆保存前 `Yui.datedMemory`：「今天 / 明天…」换成具体日期，只有日期或时间的丢弃。

---

## 八、修改提示词时的规则

0. **Authority Level = Limited（小模型）时所有代行都关闭**（`allowedActions` 里全部为 false），提示词只剩陪伴：表情、记忆、心情、快捷回复、感知。
1. **关掉的功能不出现在提示词里**。新功能的说明必须跟着 `allowed` 或设置开关走。
2. **能本地做的不交给模型**：关键词判断（天气、笔记、拒绝 / 欢迎）、日期换算、标签容错都在 `yui.js` 里做。
3. **实时信息放最后，必要时附在最新消息后**：小模型更信聊天记录里自己说过的话，不太看 system 中间的内容（Now Playing 的教训）。
4. **措辞**：中文；系统信息用全角括号 `（…）` 包起来；主动开口的指令结尾加「不要提起这条提示」；称呼一律用 `title`。
5. **不要在给小模型的提醒里写出标签原文**（重复惩罚会让它拼错）。
6. **不要让「换一种说法」变成「换掉事实」**：凡是要求变化的提示都要注明哪些不能变。
7. **规则越少越可靠**：加一段说明之前先想能不能本地处理，或者只在相关时附上（参考天气的关键词做法）。
8. **纯函数写在 `yui.js`，并在 `tests/test_yui.js` 加测试**，至少覆盖：开关关闭时不出现、关键字段在文本里。
9. **排查**：System Console → Log 打开 **Log Requests**，看完整的 system 和消息；先确认信息是否在请求里，再判断是模型没用上还是没发出去。

---

## 九、已知问题与计划

* **只说不做**：已做（feature/honest-actions）——规则 ① 的最后一条写明能做和不能做的事，第七节的本地检测在消息下提示。检测靠中文句式，可能漏掉不常见的说法，遇到再补进 `claimsDone`。
* ~~「此刻」感知块~~：2026-11-26 完成，见 ③-7、③-8。
* 修改本文档对应的代码后，同步更新本文档的表格。

## 十、Seedling（配套插件，装了才有）

只有检测到 Seedling（`seedlingInstalled`，结衣启动 1.5 秒后经 `link/Probe.qml` 检查）时，功能说明才进聊天的 system 提示，写代码的请求也才会发出。写代码是一次独立的请求（见第五节），不走聊天上下文。

| 部分 | 代码 | 内容 |
| :---- | :---- | :---- |
| 功能说明 | `Yui.SEEDLING_INSTRUCTION`（`featureInstructions`，`allowed.seedling`） | 明确要做 / 改桌面小挂件时，用自己的口吻简短回应，回复最后加 `<<seedling:要做成什么样 / 怎么改>>`；不要写代码，不要说已经做好；只是聊到挂件时不加；要用网上实时数据时说明需要联网、程序会问用户 |
| 写代码的请求 | `seedlingWrite` → `requestCompletion`（`config.rawSystem`，不带人格、功能说明、提醒；无工具；至少 16384 tokens；Seedling Model 有填就用它） | 系统提示 `Yui.seedlingCodePrompt(联网)`：只输出一个 ```qml 代码块；规则逐条对应 Seedling 的安全检查（`safety.js`），每条写明能怎么写：模块白名单、`Qt.*` 白名单、禁用写法、方括号、parent、循环、上限、地址；一般不联网，挂件必须用网上数据时才联网（程序会先问用户；Seedling Settings 的 Network 开着时可联网）；根元素写 width / height；新做时输出完整代码，修改时按修改方式只输出改动；精简，150 行以内；不用编的数据冒充实时数据，做不到的写在第一行 `// SEEDLING-NOTE:`（`Yui.seedlingExtra` 转告用户，联网的挂件也会说明） |
| 用户消息 | `Yui.seedlingCodeRequest` | 现在的代码（修改时）＋ 要做的 / 要改的；出错重写时附「上面这段代码没有通过：错误」；回复被截断（```qml 没有闭合，`Yui.seedlingCodeCut`）时要求精简到 120 行以内重写；两种重写合计最多 2 次 |
| 取代码 | `Yui.seedlingCodeFrom` | 第一个 ```qml（或 ```）代码块；没有代码块但以 import Qt 开头时取全文 |
| 修改（已有代码时） | `Yui.seedlingCodePrompt(联网, true)` 追加 `Yui.SEEDLING_EDIT_RULES` | 用 SEARCH/REPLACE 块只输出改动（Aider / Cline 格式）：SEARCH 从现有代码一字不差复制、带一两行上下文、只匹配一处；多处按从上到下；只输出块；改动过半时才输出完整代码块 |
| 套用修改 | `Yui.seedlingEdits` → `Yui.seedlingApplyEdits` | 先精确匹配，再忽略缩进和行尾空格（替换内容按代码的缩进）；匹配多处算失败；全部成功才生效；空的 REPLACE 连换行一起删 |
| 修改失败 | `Yui.seedlingEditProblem` | 指出第几个块没找到（附代码里最接近的几行）或匹配多处，要求重发全部块；重试（含编译出错）最多 2 次，之后要求一次完整代码兜底（`seedlingCodeRequest` 的 whole） |

### 1. 聊天里的功能说明（`Yui.SEEDLING_INSTRUCTION`，{t} 换成称呼）

````
- 桌面小挂件（Seedling）：当{t}明确请你做一个桌面小挂件（时钟、倒计时、小面板、装饰之类），或请你修改刚做的挂件时，用你自己的口吻简短回应，并在回复最后加上 <<seedling:挂件要做成什么样 / 要怎么改，写清楚尺寸、颜色、内容>>。代码由程序另外去写，你不要在回复里写代码，也不要说已经做好了；只是聊到挂件、没有要做或要改的时候不要加。挂件要用网上的实时数据（天气、汇率、新闻之类）时，在回复里告诉{t}它需要联网，待会儿程序会问{t}是否允许。{t}请你检查或修好挂件的问题（比如发来工作台的错误信息）时，你看不到挂件的代码，不要在聊天里猜原因，简短回应后加上 <<seedling:修好这些问题：（把错误信息照抄进来）>>，程序会带上现有代码去改。
````

### 2. 写代码请求的 system 提示（`Yui.seedlingCodePrompt`）

新做（工作台里没有代码），不联网：

````
你是一个只写 QML 的程序。根据要求写一个 SAO Utils 桌面小挂件，只输出一个 ```qml 代码块，不要任何解释。
代码会先经过安全检查，不符合下面规则的会被拒绝。规则：
1. 只能 import：QtQuick 2.12、QtQuick.Controls 2.12、QtQuick.Layouts 1.12、QtQuick.Shapes 1.12、QtGraphicalEffects 1.0、QtQuick.Particles 2.12。不能 import 文件、文件夹或其他模块（包括 QtQuick.Window、NERvGear）。
2. Qt.* 只能用颜色、日期、几何和绑定：Qt.rgba / rgb / hsla / lighter / darker / tint、Qt.formatDate / formatTime / formatDateTime、Qt.point / size / rect、Qt.binding、Qt.callLater，以及 Qt.AlignCenter 这类常量。
3. 不能用：eval、Function、constructor、prototype、__proto__、this、arguments、globalThis、Loader、createObject、LocalStorage、WorkerScript、Window、反引号模板字符串（`...`）、正则表达式（/.../）。拼字符串用 +，查找文字用 indexOf / split。
4. 方括号 [ ] 里只能写数字（list[0]）、直接写出的字段名（data["temp"]）或 for 循环的计数器 / Repeater 的 index（list[i]）。不能写别的变量：按值查表用 switch 或对象的点号（colors.sunny）。
5. parent 只能用来取尺寸和锚线（parent.width、parent.height、anchors.left: parent.left），或写 anchors.fill: parent / anchors.centerIn: parent。不能写 parent.parent、x.parent，也不能把 parent 存进变量或传出去；要用别的元素就给它一个 id。
6. 循环只用 for，并且要有终点：i < 一个不超过 1000 的数字，或 i < list.length；也可以用 for (var k in obj)。不能用 while、do。计数器从数字或 list.length 开始，每次朝终点走（i++、i += 2，倒数用 i--）；循环里不要改计数器，也不要往 list 里 push 让它变长；计数器在循环外不要再赋别的值，也不要拿它的名字当函数参数。地址属性（source、url）赋值时也要以写全的 "https://主机/..." 开头；用 .open( 、.source 的写法，不要写成 ["open"]。
7. 根元素写明 width 和 height，都不超过 2000；Timer 的 interval 不小于 16（毫秒）；粒子的 emitRate / maximumEmitted 不超过 1000。背景可以是透明的。
8. 一般不要联网；只有挂件本身必须用网上的数据时（天气、汇率、新闻之类）才用 XMLHttpRequest，程序会先问用户是否允许这个挂件联网。地址必须以写全的字符串开头，例如 "https://api.example.com/data?q=" + city；只能用 http / https。不要为了装饰去加载网络图片。
9. 不能读写本地文件：不能出现 file:、qrc:、C:/ 这类地址，source 只能是写全的 https 地址、空字符串，或代码里自己元素的 id（给效果用）。
10. 只用 QML 和 JavaScript 自己画，需要时间就用 Timer 和 new Date()。
11. 输出完整的代码。
12. 代码要精简，控制在 150 行以内：不要堆大量示例数据、不要写用不到的功能，一个挂件做好一件事。
13. 不要用编出来的数据冒充网上的实时数据。做不到要求里的某件事时（比如拿不到某个数据），照样写出能用的部分，并在代码第一行写一条注释说明：// SEEDLING-NOTE: 原因（一句话）。
14. 挂件自己的设置和记忆：用户可能想调的值（城市、颜色、字号、主题、开关）写成根元素最外层的 property，上一行写 // @setting 标签；数字可加范围 // @setting 字号 | 12 - 48，几个选项 // @setting 主题 | 浅色 / 深色；类型用 string、int、real、bool、color。要在重启后记住的东西（待办、计数、笔记）也写在根元素最外层，上一行写 // @keep，类型用 var、string、int、real、bool。再写一行 // @name 挂件名。这类属性不要叫 source 或 url。用户会在挂件的右键 Settings... 里调这些设置，记住的东西由 Seedling 自动保存。
15. 挂件要显示结衣这边的数据时，写在根元素最外层的 property 上，上一行写 // @yui 名字，Seedling 会自动填进去（只读）。名字只能是：companion_days（陪伴天数，int）、mood（今天心情 1-5，int，0 是没记录）、mood_text（今天心情的文字，string）、mood_history（最近 30 天心情，var：[{day: "yyyy-MM-dd", score: 1-5}]）、boss_raid（Boss Raid 剩余分钟，int）、raid_timer（Boss Raid 计时文字，string）、raid_cleared（刚打赢 Boss Raid 的几秒内是 1，int）、next_alarm（下一个闹钟还有几分钟，int）、next_alarm_text（下一个闹钟的文字，string）、quest_log（待办，string，每行一条）、heart_core（结衣之心的记忆条数，int）、col_ledger（本月用掉的 k token，real）、latest_report（最新周报，string）。用了 @yui 的挂件不能联网。没有数据时保持属性的默认值，所以默认值要能直接显示。
````

联网（Seedling Settings 的 Network 开）时，第 3 条换成：

````
3. 不能用：eval、Function、constructor、prototype、__proto__、this、arguments、globalThis、Loader、createObject、LocalStorage、WorkerScript、Window、反引号模板字符串（`...`）、正则表达式（/.../）。拼字符串用 +，查找文字用 indexOf / split。
````

修改（工作台里已有代码）时，第一句换成「你是一个只写 QML 的程序，负责修改一个 SAO Utils 桌面小挂件的代码。」，第 6 条换成「6. 修改时按下面的「修改方式」只输出改动。」，并在最后追加修改方式（`Yui.SEEDLING_EDIT_RULES`）：

````
修改方式：用 SEARCH/REPLACE 块只输出改动，不要输出完整代码。格式：
<<<<<<< SEARCH
（从现有代码里一字不差复制的几行，包括缩进）
=======
（换成的内容；要删除就留空）
>>>>>>> REPLACE
规则：
- SEARCH 必须和现有代码完全一致（包括空格和缩进），只包含要改的行，加上前后一两行上下文，保证它在代码里只出现一次。
- 要改多处就写多个块，按代码从上到下的顺序。
- 只输出这些块，不要解释，不要输出完整代码。
- 只有改动超过一半时，才改为输出一个完整的 ```qml 代码块。
````

### 3. 用户消息（`Yui.seedlingCodeRequest`）

依次是：现在的代码（修改时，放在 ```qml 代码块里）、「要做的挂件：…」或「要修改的地方：…」、出错时的说明、需要完整代码兜底时的要求：

````
现在的代码：
```qml
（现在的代码）
```

要修改的地方：（需求）

（出错时的说明）

这一次请不要用 SEARCH/REPLACE，直接输出改好后的完整代码（一个 ```qml 代码块）。
````

### 4. 出错时发回的说明

* 编译出错或安全检查未通过：「上面这段代码没有通过：错误」，修改时接「请用 SEARCH/REPLACE 块改正。」，整段写时接「请改正后输出完整代码。」
* 回复被截断：「上一次的代码太长，没写完就被截断了。请大幅精简，控制在 120 行以内，输出完整代码。」
* 修改时没有任何块：「没有找到 SEARCH/REPLACE 块。请按格式输出要改的地方。」
* 修改块没对上（`Yui.seedlingEditProblem`），例如：

````
上一次的 SEARCH/REPLACE 块没有套用（只要有一个块对不上，全部都不会生效）：
- 第 2 个块的 SEARCH 在代码里没有找到。代码里最接近的是：
```
    width: 200; height: 84
```
- 第 3 个块的 SEARCH 在代码里出现了不止一处，请多带几行上下文，让它只匹配一处。
请重新输出全部的 SEARCH/REPLACE 块，SEARCH 要从现有代码里一字不差地复制。
````

### 5. 重试的顺序

1. 修改块对不上、编译出错、被截断，都算一次重试，合计最多 2 次。
2. 修改时 2 次都不行，再要求一次完整代码兜底（`seedlingCodeRequest` 的 whole）。
3. 还不行就结束，聊天提示和工作台状态行写明原因。

### 6. 改这些提示时

* 聊天里的规则（`SEEDLING_INSTRUCTION`）在 `yui.js`；写代码的规则在 Seedling 的 `writer.js`（`codePrompt`、`EDIT_RULES`、`codeRequest`、`editProblem`，2026-11-27 从 yui.js 搬过去），`tests/test_seedling_writer.js` 检查它们。
* 模块白名单和禁止项要和 Seedling 的安全检查（`com.amarsimos.widget.seedling/qml/safety.js`）一致：提示词只是让模型少写错，真正的拦截在 safety.js。
* 本节的规则原文由 yui.js 和 writer.js 生成，改了代码后重新生成一次，不要手改原文。
