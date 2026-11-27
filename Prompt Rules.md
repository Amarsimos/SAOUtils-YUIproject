# MHCP-YUI / Seedling 提示词规则

> 记录发给模型的每一段文字：在哪个场景、由哪段代码生成、放在请求的什么位置，以及写提示词、写挂件代码时要遵守的规范。
> 代码位置：结衣 `com.amarsimos.widget.yui/qml/main-stand.qml`（拼装、读数据）、`qml/yui.js`（纯函数，有测试）；Seedling `com.amarsimos.widget.seedling/qml/writer.js`（写代码的提示）、`link/Bench.qml`（写代码的流程、重试说明）、`safety.js`（安全检查）、`props.js`（声明）。
> 最后核对：2026-11-27（feature/prompts，c44ac11 之后）。
> **状态：草案，待审核。** 标【拟】的是重构后的新规范 / 新规则，审核通过后才改代码；其余是现状。

---

## 〇、场景总表

| 场景 | 发给谁 | system | 用户消息 / 附注 | 详见 |
| :-- | :-- | :-- | :-- | :-- |
| 聊天（Tags 模式，默认） | 结衣的连接 | ① 规则 + ② 人格 + ③ 附加部分 | 聊天历史 + 最新消息 + 附注 | 一～四 |
| 聊天（Tools 模式） | 同上 | 同上，代行说明换成一句「可以用提供的工具」 | 同上 + tools 定义 | 六 |
| 重新生成（Say Again） | 同上 | 同上 | 最新消息后加「重新生成」附注，温度 +0.3 | 三 |
| 小模型（Authority Level = Limited） | 同上 | 同上，代行全部关闭 | 最新消息后加「小模型提醒」 | 三 |
| 开机问候（无保存的对话时） | 同上 | 同上 | 一条用户消息：「（系统提示：刚刚打开电脑……打招呼）」 | 五 |
| Login Greeting / 唤醒 | 同上 | 同上 | 早安 / 欢迎回来 / 好久不见 三种之一 | 五 |
| 主动开口：闲聊、心情关怀、天气变化、深夜、休息、跟进 | 同上 | 同上 | `yuiSpeaks`：附在最新消息后，或作为新的一条 | 五 |
| 周报（Weekly Report） | 同上 | 同上 | 一条用户消息：一周数据 + 写法要求；不进聊天 | 五 |
| Through Yui's Eyes（画像） | 同上 | 同上 | 一条用户消息：全部记忆 + 写法要求；不进聊天 | 五 |
| 结衣的 Link Start! 测试 | 正在编辑的连接 | 编辑中的人格 + 附加部分 | 「Hello」 | 五 |
| Seedling 写新挂件 | 有结衣且她配好了：结衣的连接；否则 Seedling 自己的 | 写代码规则（14 条，有结衣时 15 条）+ 外观 + 同类模板参考 | 「要做的挂件：……」 | 九 |
| Seedling 修改挂件 | 同上 | 同上 + SEARCH/REPLACE 修改方式（不带模板） | 「现在的代码 + 要修改的地方」 | 九 |
| Seedling 出错重试（最多 2 次 + 整段兜底 1 次） | 同上 | 同上 | 上一次的说明 + 出错原因 | 9.4 |
| Seedling 的 Link Start! 测试 | Seedling 选中的连接 | 「Reply with one short line.」 | 「Hello」 | 九 |
| 本地台词（System Call、Seedling 进度和结果、唤醒语、Navigation Report 等） | 不单独发；进聊天历史 | — | 作为结衣说过的话进入以后的请求 | 四 |

---

## 一、一次请求的组成

```
system ┬ ① 最重要的规则        priorityRules
       ├ ② 人格               设置里的 System Prompt（默认 defaultSystemPrompt / MHCP Profile）
       └ ③ 附加部分            systemExtras（见第二节，共 8 段）
messages ┬ 聊天历史            buildHistory（最近 maxHistory 条，默认 20）
         └ 最新一条用户消息     ＋ 只进请求的附注（见第三节）
tools                         只在 Tools 模式（toolDefinitions）
```

拼装在 `startReply → requestCompletion`（main-stand.qml 约 1097 行）：
`system = priorityRules + 人格（{{user_title}} 替换为称呼）+ systemExtras(title, 最新用户消息, mode)`。

**称呼 `title`**：设置里的称呼（默认「爸爸」），所有段落都用它，不写死。

---

## 二、system 提示的各段（按顺序）

| # | 段落 | 生成 | 什么时候出现 | 内容要点 |
| :-- | :-- | :-- | :-- | :-- |
| ① | 最重要的规则 | `Yui.priorityRules(title, allowed, mode)` | 每次 | 表情标签必写；操作电脑 / 记忆必须写标签或调用工具（只说不做电脑上什么都不会发生）；开着网页功能时「实时信息必须搜索，不编造」；最后一条始终在：「电脑上的事，结衣只能……（只列开着的，含控制音乐播放）；其他事做不到就直接说，请{title}自己操作，绝不假装已经做了」（都关掉时为「结衣不能操作电脑」）。放在人格**前面**，因为用户可能改人格，小模型也容易丢后面的规则 |
| ② | 人格 | 设置 `system_prompt`；默认 `defaultSystemPrompt`（main-stand.qml 313 行）；MHCP Profile 切换 | 每次 | 身份、性格、说话方式。用户可编辑 |
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
* **保留** `local` 消息（唤醒语、Navigation Report、System Call 的回复、Seedling 的进度和结果、测试消息等程序自己写的），让后面的回复能接上。【拟】进请求时在这类消息前标「（系统生成）」，让模型知道那不是它自己说的，不去模仿（第十节第 11 条）。
* 连续同一角色的消息合并（Gemini / Claude 要求一问一答交替）；开头必须是 user。
* Clear Log（Yui's Heart）会同时清空聊天窗口，否则旧对话仍会进上下文。

---

## 五、独立的请求（不走聊天上下文）

| 请求 | 生成 | 要点 |
| :-- | :-- | :-- |
| 开机问候 | `getInitialMessage`（main-stand.qml 约 1751 行） | 启动时没有保存的对话：「（系统提示：{t}刚刚打开电脑……打招呼）」；缺「不要提起这条提示」【拟：补上】 |
| Login Greeting | `welcomeBack` | 启动时，以及点醒待机的结衣时（2026-11-26 起，代替本地唤醒语；不需要问候时仍用本地唤醒语）。早安（带天气）/ 欢迎回来（≥ 30 分钟）/ 好久不见（≥ 2 天，原 3 天）三种；「一两句话即可，不要提起这条提示」 |
| Spontaneous Talk | `careTick` → `idleChat` | 告诉她现在的样子（水晶 / 妖精 / 立绘）和位置（只作背景，叫她不要说起自己的样子或位置），请她主动说一句；有由头时加「可以从这个由头说起：…」（`Yui.chatHooks` 20 种：节日、去年今天、快到的跟进 / 生日、正在听的歌、深夜听歌、电脑一直很忙、周五晚上、周末早上、周一早上、午饭、晚饭、月末、下雨下雪、冷、热、陪了很久、心情不错、一条较早的记忆、今天还没说过话；特别的日子优先，其余随机，同一个由头当天只用一次） |
| Mood Care | `careTick` → `Yui.moodCareInstruction` | 中优先级，09–22 点；最近 3 次心情平均 ≤ 2 且最近一次在 3 天内；带这几天的记录，「温柔地问问要不要说说，不要说教，也不要列一串建议」 |
| Weather Changes | `careTick` → `Yui.weatherChangeInstruction` | 中优先级，07–22 点，变化后 1 小时内；开始下雨 / 下雪（带之前和现在的天气）→ 提醒带伞；3 小时内降温 ≥ 5° → 提醒保暖 |
| 深夜关怀 / 休息提醒 | `careTick` | 带具体时刻或连续使用时长 |
| Weekly Report | `Yui.weeklyReportPrompt` | 一周数据 + 要求（三到五段、不用 Markdown、重点关心心情、不逐条复述数字、不加标签）；不进聊天 |
| 跟进 | `careTick` → `Yui.followupInstruction` | 高优先级；当天「主动打打气、关心一下」，之后 7 天内「自然地问问结果怎么样」；带原话和「就是今天 / 那是 N 天前的事」；一两句话，不要提起提示 |
| Through Yui's Eyes | `Yui.portraitPrompt` | 全部记忆 + 要求（两到四段、只根据记忆、不加标签）；不进聊天 |

| Link Start!（Cardinal System） | CardinalSystem.qml 约 530 行 | 用正在编辑的设置发「Hello」测试连接；带完整的 system。【拟】改成中文 |

前四种经 `yuiSpeaks` 发出，仍带完整的 system 提示和聊天历史。后三种由关心调度（`careTick`，2026-11-25）决定何时说：每天上限与最短间隔随 Care Level / 学到的欢迎度变化（默认每天 20 次、每 30 分钟一次），免打扰时段不闲聊；Login Greeting 启动时立即说并计入次数。提示词内容本身没有变。

---

## 六、Tags 与 Tools 两种模式

| | Tags（默认） | Tools（Action Mode，OpenAI 格式且服务器接受 tools 时） |
| :-- | :-- | :-- |
| 代行（网页、启动、找文件、关闭、音乐） | 标签 `<<open:>> <<search:>> <<launch:>> <<find:>> <<kill:>> <<media:>>` | 工具 `open_url web_search launch_program find_file close_program media_control`（`Yui.TOOLS`） |
| 记忆 | 标签 `<<core:>> <<memory:>> <<forget:>>` | 仍用标签。`Yui.TOOLS` 里的 remember / forget 工具**从不发出**（`toolDefinitions` 不带 withMemory）；【拟】删掉（第十节第 4 条） |
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

---

## 八、写提示词的通用规范【拟】

适用于结衣和 Seedling 发给模型的所有文字。原第八节的 0–9 条保留并入下面各条。

**内容**
1. **关掉的功能不出现**：功能说明跟着 `allowed` 和设置开关走；Authority Level = Limited 时只剩陪伴（表情、记忆、心情、快捷回复、感知）。
2. **一条规则只写一处**：① 规则只写「必须做的」；功能说明写「怎么做」（标签格式）；工具定义只写参数。表情、记忆、关闭程序、跟进、深夜关怀不再在多处重复。
3. **能本地做的不交给模型**：关键词判断、日期换算、标签容错都在 `yui.js` 本地做。规则越少越可靠，加一段说明前先想能不能本地处理，或只在相关时附上。
4. **实时信息放最后**，必要时附在最新消息后（小模型更看重紧挨着问题的内容）。
5. **按请求类型决定要不要标签**：周报、画像这类「只要文字」的请求不加表情规则，也不加小模型提醒；不再出现「必须加标签」和「不要加标签」同时成立。
6. **要求变化时写明什么不能变**（重新生成：换说法，事实不变）。
7. **不在给小模型的提醒里写出标签原文**（重复惩罚会让它拼错）。

**措辞与格式**
8. **语言**：发给模型的文字一律中文。功能名统一写成「中文名（English）」，首次出现时这样写，之后只用中文名。英文的报错（编译错误、安全检查）发给模型时前面加一句中文说明。测试连接也用中文。
9. **称呼**：只有一种写法——在模板文字里写 `{t}`，由一个函数换成称呼；爸爸 / 妈妈的对应只在一处（`userTitle`）。不写「他 / 她」，一律写称呼。人格设定里的 `{{user_title}}` 是给用户编辑用的，保留，由同一个函数处理。
10. **系统说明的外形**：只进请求、不显示的说明一律写成「（系统提示：……）」；放在 system 里的事实块写成「（羁绊：……）」「（此刻：……）」这类「（名字：内容）」。不再混用「系统信息」「提醒」或不加括号。
11. **主动开口的指令**结尾一律加「不要提起这条提示」（开机问候、深夜、休息目前缺）。
12. **人格设定用普通文字**，不用 Markdown 标题和列表符号（和「不用 Markdown」的要求一致）；用户自己写的人格不动。人格为空时用默认人格（MHCP001），不再用「你是ai助手」。

**代码**
13. 提示词文字只写在 `yui.js`（结衣）和 `writer.js`（Seedling）里，QML 只负责拼装和取数据。
14. 纯函数要有测试（`tests/test_yui.js`、`tests/test_seedling_writer.js`），至少覆盖：开关关闭时不出现、关键字段在文本里、互相矛盾的规则不同时出现。
15. 本文档和代码一起改；能从代码生成的部分（Seedling 规则原文）用脚本生成，不手抄。

**排查**
16. System Console → Log 打开 **Log Requests**，看完整的 system 和消息；先确认信息有没有进请求，再判断是模型没用上还是没发出去。Seedling 的请求和结果在 SAO Utils 日志里以 `Seedling:` 开头。

---

## 九、Seedling：生成挂件

### 9.1 一次写代码请求的组成

```
system ┬ 角色           「你是一个只写 QML 的程序……」（新写 / 修改两种）
       ├ 规则 1–14      和安全检查一一对应（writer.js codePrompt）
       ├ 规则 15        只在有结衣时：@yui 可读的数据
       ├ 外观           Widget Style（Seedling Settings，默认 SAO 风格）
       ├ 模板参考        只在新写、且请求能匹配到模板时（templates.js）
       └ 修改方式        只在修改时：SEARCH/REPLACE 格式
user   ┬ 现在的代码      只在修改时
       ├ 要做的挂件 / 要修改的地方
       └ 出错原因        只在重试时
```
写代码的请求**不带**人格、聊天历史、网页内容（防提示注入）；只有规则、外观、模板、用户的要求、现有代码和程序自己生成的错误说明。

### 9.2 安全规范（挂件代码一律当作不可信）

| 层 | 做什么 | 在哪里 |
| :-- | :-- | :-- |
| 沙箱 | 代码在一个没有上下文的空对象里创建，看不到工作台、结衣、SAO Utils 的名字 | `sandbox.js`、`Sandbox.qml` |
| 安全检查 | 按词法读代码，只放行挂件需要的东西；工作台渲染前、挂件启动时各查一次 | `safety.js` |
| 联网开关 | 每个挂件单独的 Network，默认关；只因联网被拒时问用户 | Seedling Settings |
| 声明只是数据 | @setting / @keep / @yui 的值由 Seedling 在沙箱外按类型转换后赋给属性，不执行任何东西 | `props.js` |
| 结衣的数据不出门 | 读了 @yui 的挂件在任何情况下都不能联网（拒绝，不询问） | `props.js guard` |
| 请求不带外部内容 | 写代码的请求只有规则、要求、代码、本地生成的错误 | `writer.js` |
| 兜底 | 挂件让 SAO Utils 异常退出时，SAO Utils 下次启动会提示停用插件 | SAO Utils |

**安全检查放行 / 拒绝的范围**（规则 1–9 的依据）：
- import 只能是：QtQuick 2.12、QtQuick.Controls 2.12、QtQuick.Layouts 1.12、QtQuick.Shapes 1.12、QtQuick.Particles 2.12、QtGraphicalEffects 1.0；不能 import 文件、文件夹、QtQuick.Window、NERvGear 等。
- `Qt.*` 只能用：rgba rgb hsla hsva tint lighter darker colorEqual formatDate formatTime formatDateTime point size rect vector2d vector3d vector4d quaternion matrix4x4 font binding callLater md5 btoa atob，以及大写开头的常量（Qt.AlignCenter）。
- 禁止的名字：eval、Function、constructor、prototype、`__proto__`、getPrototypeOf、setPrototypeOf、globalThis、this、arguments、caller、callee、LocalStorage、Loader、createObject、createQmlObject、createComponent、include、openUrlExternally、quit、exit、gc、while、do、WorkerScript、Window、SystemCall、NVG、NERvGear、WebSocket、fetch、Proxy、Reflect；模板字符串、正则表达式。
- `[ ]` 里只能是数字、直接写出的字段名、for 循环计数器或 Repeater 的 index；`["open"]`、`["source"]` 这类写法一律拒绝。
- `parent` 只能取尺寸、位置、锚线（parent.width 等）或写 `anchors.fill / centerIn: parent`；不能 `.parent`、不能存进变量。
- 地址：只能 http(s)，必须以写全的字符串开头（至少到主机名）；`source:`、`.source =`、`open()` 都一样；file:、qrc:、C:/ 等一律拒绝。

### 9.3 代码编写规范（给模型的要求，也是人写挂件的要求）

**基本格式**
- 第一行是 `import QtQuick 2.12`（需要的其他模块紧接着写），然后是 `// @name 名字`，再是根元素。
- 只有一个根元素，写明 `width` 和 `height`；根元素给 `id: root`，子元素用 `root.xxx` 引用。
- 缩进 4 个空格；一行一个属性（短的 `width: 200; height: 80` 可以写在一行）；属性在前，子元素在后，Timer 等不可见元素放最后。
- 一个挂件做好一件事，代码 ≤ **300 行**；回复被截断时要求精简到 200 行以内重写（`writer.js MAX_LINES / CUT_LINES`）。
- 颜色写成 `"#RRGGBB"` 或 `"#AARRGGBB"`；字体：英文和数字用 `"SAO UI"`，中文不指定（用默认字体）。

**注释**
- 声明用固定写法，写在属性的上一行：`// @name`、`// @setting 标签 [| 最小 - 最大 | 甲 / 乙]`、`// @keep`、`// @yui 名字`。
- 做不到的部分写一行 `// SEEDLING-NOTE: 原因（一句话）`，放在 import 之后、`// @name` 之前（原规则说「第一行」，和 import 冲突，改掉）。
- 其他注释：只在不容易看懂的地方写一句中文，不写大段说明；不把要求原文抄进注释。

**数值上下限**

| 项目 | 下限 | 上限 | 由谁保证 | 说明 |
| :-- | :-- | :-- | :-- | :-- |
| 根元素宽、高 | 20（挂件框最小值） | 2000 | 安全检查（上限） | 【拟】规则写「建议 80 以上」，太小在桌面上点不到 |
| 文字字号 | 【拟】11 | 【拟】200 | 规则（不检查） | 小于 11 在桌面上看不清 |
| Timer interval | 16 ms | — | 安全检查 | 【拟】显示时间用 1000；联网刷新 ≥ 600000（10 分钟） |
| for 循环 | — | 1000 次 | 安全检查 | 计数器从数字或 .length 开始，朝终点走 |
| 粒子 emitRate / maximumEmitted / count | — | 1000 | 安全检查 | |
| 代码行数 | — | 300 | 规则 | 回复被截断时要求精简到 200 行 |
| @setting 个数 | — | 20 | props.js | 文字设置每条 ≤ 500 字 |
| @keep 个数 | — | 20 | props.js | 合计 ≤ 64 KB，超出不保存 |
| @name | — | 40 字 | props.js | |
| 开关进右键菜单 | — | 3 个 | Seedling | 多了只在 Settings 窗口里 |

**声明**
- @setting：string、int、real、bool、color；只写在根元素最外层；名字不能是 source / url 等地址属性。
- @keep：string、int、real、bool、var（只存 JSON）；Seedling 每 2 秒比较一次，push 也能存上。
- @yui：只在有结衣时可用，名字限 `props.js YUI_KEYS`；用了就不能联网。
- 默认值要能直接显示（没有结衣、没有存档时就是默认值）。

**联网**
- 只有用户打开 Network 才能联网；地址用写全的 https 字符串开头。
- 拿不到数据时显示「--」或「offline」，不编数据。
- 刷新间隔 ≥ 10 分钟，地址里的参数做成 @setting（城市、经纬度）。

**调试**
- 工作台 **Problems**：编译错误（行号、列号）、安全检查拒绝的原因、没生效的声明；**Copy All** 复制，**Send to Yui** 让结衣修。
- **Code Editor**（Advanced）：看代码，红条标出错行，橙色标出 AI 改过的行；打字后自动渲染。
- **Versions**：每次 AI 写之前都存一个版本，改坏了可以退回。
- SAO Utils 日志：`Seedling:` 开头的行记录每次写代码的结果、修改了几处、重试原因。
- 结衣 System Console 的 Seedling 测试和 Seedling Settings 的 Test 页：不花 token 复现各种情况。

### 9.4 修改与重试

1. 有现有代码时用 SEARCH/REPLACE 修改；对不上的块全部不生效，带着「最接近的几行」重问。
2. 编译错误、安全检查拒绝、没生效的声明（只问一次）：带着原因重问，最多 2 次。
3. 修改两次都不行：最后要求整段重写一次（这时 system 里不再放 SEARCH/REPLACE 说明）。
4. 回复被截断：要求精简到 200 行以内重写（原为 120）。
5. 只因联网被拒：先问用户；用户不允许就结束，不偷偷改成不联网的版本。
6. 新写的挂件重试时，用户消息写「上一次写出的代码：……」+「要做的挂件：……」，不写成「要修改的地方」。
7. 安全检查和编译器的英文原文前加一句「（下面是检查程序的英文原文）」。

### 9.5 写代码规则（`writer.js codePrompt`）

原 15 条重新编排：每条只讲一件事，编号连续，冲突时写明谁优先。下面是摘要，原文见代码；整段重写（9.4 第 3 条）时不带修改方式，规则 11 改为「输出完整的代码」。

1. **模块**：只能 import 9.2 列出的 6 个模块。
2. **Qt 函数**：只能用 9.2 列出的 Qt.* 函数和常量。
3. **禁止的写法**：9.2 的禁止名字；拼字符串用 +，查找用 indexOf / split。
4. **方括号**：只能是数字、写出的字段名、循环计数器 / index；按值查表用 switch 或点号。
5. **parent**：只取尺寸和锚线；要用别的元素就给它 id。
6. **循环**：只用 for，要有终点（≤ 1000 次或 .length），计数器朝终点走，循环里不改计数器、不加长列表。
7. **尺寸和频率**：根元素写明宽高（80–2000，建议不小于 80）；字号 11 以上；Timer ≥ 16 ms，显示时间用 1000，联网刷新 ≥ 10 分钟；粒子 ≤ 1000。
8. **地址**：source、.source =、open() 的地址必须以写全的 https 字符串开头；不能用 file:、qrc:、本地路径。
9. **联网**：Network 开着才可以联网（用 XMLHttpRequest）；关着时不能联网；读了结衣数据（@yui）的挂件**无论如何**不能联网（优先于本条）。
10. **自己画**：只用 QML 和 JavaScript，时间用 Timer 和 new Date()。
11. **格式**：9.3 的基本格式和注释写法；代码 ≤ 300 行，一个挂件做好一件事。
12. **不编数据**：做不到的写 `// SEEDLING-NOTE:`（import 之后），能用的部分照样写出来。
13. **设置和记忆**：@setting / @keep / @name 的写法（9.3）。
14. **外观**：按下面的「外观」写；要求里另外说了风格以要求为准。
15. **结衣的数据**（只在有结衣时）：@yui 的写法和可用名字。

---

## 十、待改清单【拟，审核后逐条改，每条一个提交】

| # | 问题 | 改法 | 位置 |
| :-- | :-- | :-- | :-- |
| 1 | 周报、画像说「不要加标签」，但 ① 规则和小模型提醒要求加 | 按请求类型去掉表情规则和小模型提醒（规范 5） | yui.js priorityRules / smallModelReminder，main-stand 周报、画像 |
| 2 | Tools 被拒后重发，附注重复、「重新生成」标记丢失 | 重发时用原始消息和原来的 regenerate 标记 | main-stand requestCompletion |
| 3 | 「提醒他」写死男性；爸爸/妈妈对应有三份 | 改成称呼；对应只留 `userTitle`（规范 9） | yui.js featureInstructions，CardinalSystem，tests |
| 4 ✅ | remember / forget 工具从不发出，tooltest 还在要求用 | 删掉这两个工具定义和测试里的说法（记忆一直用标签） | yui.js TOOLS，tests/tooltest.js |
| 5 ✅ | Seedling 规则互相打架（150 / 120 行、规则 6 混进地址、@yui 与联网、整段重写时还有修改方式、新挂件重试写成「要修改」） | 按 9.4、9.5 改 | writer.js，Bench.qml |
| 6 | 三种称呼写法 `{{user_title}}`、`{t}`、拼接 | 统一 `{t}` + 一个替换函数（规范 9） | yui.js，main-stand |
| 7 | 「系统提示 / 系统信息 / 提醒」混用，部分段落没有括号；开机问候、深夜、休息缺「不要提起」 | 按规范 10、11 统一 | yui.js，main-stand |
| 8 | 中英混杂：Seedling 重试里的英文报错、两个测试的「Hello」、功能名写法 | 按规范 8 | Bench.qml，CardinalSystem，SeedlingSettings，yui.js |
| 9 | 人格用 Markdown 却要求不用；兜底是「你是ai助手」 | 默认人格改成普通文字（内容不变）；兜底改成默认人格（规范 12） | main-stand defaultSystemPrompt |
| 10 | 同一规则说多遍（表情 3 处、MHCP001、记忆、关闭程序、跟进、深夜关怀） | 按规范 2 合并 | yui.js，main-stand |
| 11 | 本地台词进聊天历史后被当作结衣自己说的 | **保留，但标明是程序生成**：进请求时在这类消息前加「（系统生成）」 | main-stand buildHistory |
| 12 | 文档过时 | 本次重写；改完代码后再核对一次 | 本文档 |
| 13 | tagtest / tooltest 用旧的时间附注、空的 allowed | 改成和现在相同的拼法 | tests |

---

## 十一、已知问题与计划

* **只说不做**：已做（feature/honest-actions）——规则 ① 最后一条写明能做和不能做的事，第七节的本地检测在消息下提示。检测靠中文句式，可能漏掉不常见的说法，遇到再补进 `claimsDone`。
* 修改本文档对应的代码后，同步更新本文档。
